#!/bin/bash
# Generate a debug Containerfile for a BotMinter epic.
# Clones all project repos with in-flight PR branches into a UBI container.
#
# Usage: ./generate-debug-containerfile.sh <epic-number> [--output <path>] [--dry-run]

set -euo pipefail

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
EPIC_NUM=""
OUTPUT_PATH=""
DRY_RUN=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --output)  OUTPUT_PATH="$2"; shift 2 ;;
    --dry-run) DRY_RUN=true; shift ;;
    -h|--help) EPIC_NUM=""; break ;;  # fall through to usage
    -*)        echo "Unknown option: $1" >&2; exit 1 ;;
    *)
      if [ -z "$EPIC_NUM" ]; then
        EPIC_NUM="$1"
      else
        echo "Unexpected argument: $1" >&2; exit 1
      fi
      shift ;;
  esac
done

if [ -z "$EPIC_NUM" ]; then
  cat << 'USAGE'
Usage: generate-debug-containerfile.sh <epic-number> [--output <path>] [--dry-run]

Generate a debug Containerfile that clones all project repos
with in-flight changes for the specified epic.

Options:
  --output <path>  Override output file location
  --dry-run        Print Containerfile to stdout without writing

Example:
  ./scripts/generate-debug-containerfile.sh 14
  ./scripts/generate-debug-containerfile.sh 14 --dry-run
  ./scripts/generate-debug-containerfile.sh 14 --output ./Containerfile.debug
USAGE
  exit 1
fi

# ---------------------------------------------------------------------------
# Environment
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEAM_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BOTMINTER_YML="${TEAM_ROOT}/botminter.yml"

if [ -d "${TEAM_ROOT}/.git" ]; then
  TEAM_REPO=$(git -C "$TEAM_ROOT" remote get-url origin 2>/dev/null \
    | sed 's|.*github.com[:/]\(.*\)\.git$|\1|' \
    | sed 's|.*github.com[:/]\(.*\)$|\1|')
fi
TEAM_REPO="${TEAM_REPO:-openshift-splat-team/splat-team}"
OWNER="${TEAM_REPO%%/*}"
REPO="${TEAM_REPO##*/}"

[ -z "$OUTPUT_PATH" ] && OUTPUT_PATH="${TEAM_ROOT}/debug/Containerfile.epic-${EPIC_NUM}"

echo "Epic Debug Containerfile Generator"
echo "==================================="
echo "Epic:      #${EPIC_NUM}"
echo "Team repo: ${TEAM_REPO}"
echo "Output:    ${OUTPUT_PATH}"
echo ""

# ---------------------------------------------------------------------------
# Prerequisites
# ---------------------------------------------------------------------------
for cmd in gh jq; do
  command -v "$cmd" >/dev/null 2>&1 || { echo "Error: ${cmd} not found"; exit 1; }
done
gh auth status >/dev/null 2>&1 || { echo "Error: gh not authenticated. Run: gh auth login"; exit 1; }
[ -f "$BOTMINTER_YML" ] || { echo "Error: botminter.yml not found at ${BOTMINTER_YML}"; exit 1; }

# ---------------------------------------------------------------------------
# Step 1: Validate epic
# ---------------------------------------------------------------------------
echo "Fetching epic #${EPIC_NUM}..."
EPIC_INFO=$(gh issue view "$EPIC_NUM" --repo "$TEAM_REPO" --json title,labels,state)
EPIC_TITLE=$(echo "$EPIC_INFO" | jq -r '.title')
EPIC_LABELS=$(echo "$EPIC_INFO" | jq -r '[.labels[].name] | join(",")')

if ! echo "$EPIC_LABELS" | grep -q "kind/epic"; then
  echo "Warning: Issue #${EPIC_NUM} does not have the 'kind/epic' label (labels: ${EPIC_LABELS})"
fi
echo "Epic: ${EPIC_TITLE}"
echo ""

# ---------------------------------------------------------------------------
# Step 2: Find stories belonging to this epic
# ---------------------------------------------------------------------------
echo "Finding stories for epic #${EPIC_NUM}..."
STORIES_JSON=$(gh api "repos/${TEAM_REPO}/issues?labels=kind/story&state=all&per_page=100" \
  --jq "[.[] | select(.body != null) | select(.body | contains(\"Parent: #${EPIC_NUM}\")) | {number, title}]")

STORY_COUNT=$(echo "$STORIES_JSON" | jq 'length')
echo "Found ${STORY_COUNT} stories"
echo "$STORIES_JSON" | jq -r '.[] | "  #\(.number): \(.title)"'
echo ""

if [ "$STORY_COUNT" -eq 0 ]; then
  echo "No stories found. Containerfile will only include the team repo."
fi

# Build pipe-separated story numbers for regex matching
STORY_NUMS=$(echo "$STORIES_JSON" | jq -r '.[].number' | paste -sd '|')

# ---------------------------------------------------------------------------
# Step 3: Find PRs linked to stories in each project repo
# ---------------------------------------------------------------------------
declare -A REPO_BRANCHES  # repo_name -> space-separated "branch|story|pr" entries
declare -A REPO_URLS      # repo_name -> org/repo

if [ -n "$STORY_NUMS" ]; then
  echo "Scanning project repos for linked PRs..."

  while IFS= read -r fork_url; do
    [ -z "$fork_url" ] && continue
    fork_url="${fork_url#"${fork_url%%[![:space:]]*}"}"  # trim leading whitespace
    repo_full="${fork_url#https://github.com/}"
    repo_name="${repo_full##*/}"
    REPO_URLS["$repo_name"]="$repo_full"

    PR_DATA=$(gh pr list --repo "$repo_full" --state all \
      --json number,headRefName,body,state --limit 100 2>/dev/null \
      | jq --arg pat "${REPO}#(${STORY_NUMS})" \
        '[.[] | select(.body != null) | select(.body | test($pat))]' 2>/dev/null \
      || echo "[]")

    PR_COUNT=$(echo "$PR_DATA" | jq 'length')
    [ "$PR_COUNT" -eq 0 ] && continue
    echo "  ${repo_name}: ${PR_COUNT} PR(s)"

    while IFS= read -r pr_line; do
      pr_num=$(echo "$pr_line" | jq -r '.number')
      pr_branch=$(echo "$pr_line" | jq -r '.headRefName')
      pr_body=$(echo "$pr_line" | jq -r '.body')

      matched_story="unknown"
      for snum in $(echo "$STORIES_JSON" | jq -r '.[].number'); do
        if echo "$pr_body" | grep -q "${REPO}#${snum}"; then
          matched_story="$snum"
          break
        fi
      done

      entry="${pr_branch}|${matched_story}|${pr_num}"
      if [ -n "${REPO_BRANCHES[$repo_name]+x}" ]; then
        REPO_BRANCHES["$repo_name"]+=" ${entry}"
      else
        REPO_BRANCHES["$repo_name"]="$entry"
      fi
    done < <(echo "$PR_DATA" | jq -c '.[]')
  done < <(grep 'fork_url:' "$BOTMINTER_YML" | sed 's/.*fork_url: *//')

  echo ""
  echo "Found PRs in ${#REPO_BRANCHES[@]} project repo(s)"
  echo ""
fi

# ---------------------------------------------------------------------------
# Step 4: Detect Go version from project repos
# ---------------------------------------------------------------------------
MAX_GO_VERSION=""

if [ ${#REPO_BRANCHES[@]} -gt 0 ]; then
  echo "Detecting Go versions from go.mod files..."
  for repo_name in $(echo "${!REPO_BRANCHES[@]}" | tr ' ' '\n' | sort); do
    repo_full="${REPO_URLS[$repo_name]}"
    entries="${REPO_BRANCHES[$repo_name]}"
    IFS=' ' read -ra entry_list <<< "$entries"
    IFS='|' read -r branch _ _ <<< "${entry_list[0]}"

    go_ver=$(gh api "repos/${repo_full}/contents/go.mod?ref=${branch}" \
      --jq '.content' 2>/dev/null \
      | base64 -d 2>/dev/null \
      | grep '^go ' | head -1 | awk '{print $2}')

    if [ -n "$go_ver" ]; then
      echo "  ${repo_name}: go ${go_ver}"
      if [ -z "$MAX_GO_VERSION" ] || [ "$(printf '%s\n%s' "$MAX_GO_VERSION" "$go_ver" | sort -V | tail -1)" != "$MAX_GO_VERSION" ]; then
        MAX_GO_VERSION="$go_ver"
      fi
    fi
  done

  if [ -n "$MAX_GO_VERSION" ]; then
    echo "  -> Installing Go ${MAX_GO_VERSION} (highest required)"
  fi
  echo ""
fi

# ---------------------------------------------------------------------------
# Step 5: Resolve VSCodium version
# ---------------------------------------------------------------------------
echo "Resolving VSCodium version..."
VSCODIUM_VERSION=$(gh api repos/VSCodium/vscodium/releases/latest --jq '.tag_name' 2>/dev/null || echo "")
if [ -n "$VSCODIUM_VERSION" ]; then
  echo "  VSCodium: ${VSCODIUM_VERSION}"
else
  echo "  Warning: Could not resolve VSCodium version from GitHub API"
  echo "  Falling back to 1.116.02821"
  VSCODIUM_VERSION="1.116.02821"
fi
echo ""

# ---------------------------------------------------------------------------
# Step 6: Detect epic branch in team repo
# ---------------------------------------------------------------------------
EPIC_BRANCH=""
if [ -d "${TEAM_ROOT}/.git" ]; then
  EPIC_BRANCH=$(git -C "$TEAM_ROOT" ls-remote --heads origin "epic/${EPIC_NUM}-*" 2>/dev/null \
    | head -1 | sed 's|.*refs/heads/||')
fi

if [ -n "$EPIC_BRANCH" ]; then
  echo "Team repo epic branch: ${EPIC_BRANCH}"
else
  echo "No epic branch found in team repo (will clone default branch)"
fi
echo ""

# ---------------------------------------------------------------------------
# Step 7: Generate Containerfile
# ---------------------------------------------------------------------------
GENERATED_DATE=$(date -u +%Y-%m-%dT%H:%M:%SZ)

generate_containerfile() {
  cat << EOF
# Epic #${EPIC_NUM}: ${EPIC_TITLE}
# Generated: ${GENERATED_DATE}
#
# Build:
#   podman build --build-arg GITHUB_TOKEN=\$(gh auth token) \\
#     -f ${OUTPUT_PATH##*/} -t epic-${EPIC_NUM}-debug .
#
# Run IDE (default):
#   podman run -p 8000:8000 epic-${EPIC_NUM}-debug
#   Open http://localhost:8000
#
# Run shell only:
#   podman run -it epic-${EPIC_NUM}-debug bash

FROM registry.access.redhat.com/ubi9/ubi-minimal

ARG GITHUB_TOKEN

LABEL io.botminter.epic="${EPIC_NUM}"
LABEL io.botminter.epic-title="${EPIC_TITLE}"
LABEL io.botminter.generated="${GENERATED_DATE}"
LABEL io.botminter.team="${TEAM_REPO}"

RUN microdnf install -y git tar gzip findutils make && microdnf clean all

RUN git config --global user.email "debug@botminter" && \\
    git config --global user.name "epic-debug"
EOF

  # Go installation
  if [ -n "$MAX_GO_VERSION" ]; then
    cat << EOF

# Go ${MAX_GO_VERSION} (highest version required across project repos)
RUN curl -fsSL https://go.dev/dl/go${MAX_GO_VERSION}.linux-amd64.tar.gz | tar -C /usr/local -xz

ENV PATH="/usr/local/go/bin:\${GOPATH}/bin:\${PATH}"
ENV GOPATH="/root/go"
EOF
  fi

  # VSCodium web server
  cat << EOF

# VSCodium web server (${VSCODIUM_VERSION})
RUN mkdir -p /opt/vscodium && \\
    curl -fsSL https://github.com/VSCodium/vscodium/releases/download/${VSCODIUM_VERSION}/vscodium-reh-web-linux-x64-${VSCODIUM_VERSION}.tar.gz \\
    | tar -C /opt/vscodium -xz && \\
    ln -s /opt/vscodium/bin/codium-server /usr/local/bin/codium-server

# Pre-install Go extension from Open VSX
RUN codium-server --install-extension golang.go \\
    --extensions-dir /opt/vscodium-extensions

ENV EXTENSIONS_DIR="/opt/vscodium-extensions"

EXPOSE 8000

WORKDIR /src
EOF

  # Team repo clone
  if [ -n "$EPIC_BRANCH" ]; then
    cat << EOF

# Team repo (epic branch: ${EPIC_BRANCH})
RUN git clone --single-branch --branch ${EPIC_BRANCH} \\
    https://x-access-token:\${GITHUB_TOKEN}@github.com/${TEAM_REPO}.git team
EOF
  else
    cat << EOF

# Team repo (default branch)
RUN git clone --single-branch \\
    https://x-access-token:\${GITHUB_TOKEN}@github.com/${TEAM_REPO}.git team
EOF
  fi

  # Project repo clones
  for repo_name in $(echo "${!REPO_BRANCHES[@]}" | tr ' ' '\n' | sort); do
    local entries="${REPO_BRANCHES[$repo_name]}"
    local repo_full="${REPO_URLS[$repo_name]}"
    local clone_url="https://x-access-token:\${GITHUB_TOKEN}@github.com/${repo_full}.git"

    IFS=' ' read -ra entry_list <<< "$entries"

    echo ""

    if [ ${#entry_list[@]} -eq 1 ]; then
      # Single PR: clone + checkout
      IFS='|' read -r branch story_num pr_num <<< "${entry_list[0]}"
      local story_title
      story_title=$(echo "$STORIES_JSON" | jq -r ".[] | select(.number == ${story_num}) | .title" 2>/dev/null || echo "")

      cat << EOF
# --- ${repo_name} ---
# Story #${story_num}: ${story_title} (PR #${pr_num})
RUN git clone ${clone_url} \\
    projects/${repo_name} && \\
    cd projects/${repo_name} && \\
    git fetch origin ${branch} && \\
    git checkout -b epic-debug FETCH_HEAD
EOF
    else
      # Multiple PRs: clone + merge each branch
      echo "# --- ${repo_name} ---"
      echo "# Multiple PRs — merging branches:"
      for entry in "${entry_list[@]}"; do
        IFS='|' read -r branch story_num pr_num <<< "$entry"
        local story_title
        story_title=$(echo "$STORIES_JSON" | jq -r ".[] | select(.number == ${story_num}) | .title" 2>/dev/null || echo "")
        echo "#   Story #${story_num}: ${story_title} (PR #${pr_num}, branch: ${branch})"
      done

      IFS='|' read -r first_branch first_story first_pr <<< "${entry_list[0]}"
      printf "RUN git clone %s \\\\\n" "$clone_url"
      printf "    projects/%s && \\\\\n" "$repo_name"
      printf "    cd projects/%s && \\\\\n" "$repo_name"
      printf "    git fetch origin %s && \\\\\n" "$first_branch"
      printf "    git checkout -b epic-debug FETCH_HEAD"

      for i in $(seq 1 $((${#entry_list[@]} - 1))); do
        IFS='|' read -r branch story_num pr_num <<< "${entry_list[$i]}"
        printf " && \\\\\n    git fetch origin %s && \\\\\n" "$branch"
        printf "    (git merge FETCH_HEAD --no-edit || echo 'WARN: merge conflict on %s (story #%s, PR #%s)')" \
          "$branch" "$story_num" "$pr_num"
      done
      echo ""
    fi
  done

  # Inline manifest
  echo ""
  echo "# Epic manifest for quick orientation"
  echo "RUN cat > /src/EPIC-MANIFEST.md << 'EPIC_MANIFEST'"
  generate_manifest
  echo "EPIC_MANIFEST"

  # Entrypoint: starts IDE by default, falls back to shell
  cat << 'EOF'

# Entrypoint: IDE by default, shell on override
RUN cat > /usr/local/bin/entrypoint.sh << 'ENTRY'
#!/bin/sh
if [ "$1" = "bash" ] || [ "$1" = "sh" ]; then
    exec "$@"
fi
exec codium-server \
    --host 0.0.0.0 \
    --port 8000 \
    --without-connection-token \
    --accept-server-license-terms \
    --extensions-dir "$EXTENSIONS_DIR" \
    --server-data-dir /root/.vscodium-server \
    "$@"
ENTRY
RUN chmod +x /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD []
EOF
}

generate_manifest() {
  echo "# Epic #${EPIC_NUM}: ${EPIC_TITLE}"
  echo ""
  echo "Generated: ${GENERATED_DATE}"
  echo "Team: ${TEAM_REPO}"
  echo ""

  if [ ${#REPO_BRANCHES[@]} -gt 0 ]; then
    echo "## Included Source"
    echo ""
    echo "| Project | Branch | Story | PR |"
    echo "|---------|--------|-------|----|"

    for repo_name in $(echo "${!REPO_BRANCHES[@]}" | tr ' ' '\n' | sort); do
      local entries="${REPO_BRANCHES[$repo_name]}"
      IFS=' ' read -ra entry_list <<< "$entries"
      for entry in "${entry_list[@]}"; do
        IFS='|' read -r branch story_num pr_num <<< "$entry"
        echo "| ${repo_name} | \`${branch}\` | #${story_num} | ${repo_name}#${pr_num} |"
      done
    done
    echo ""
  else
    echo "## No project PRs found"
    echo ""
    echo "No stories with linked PRs were found for this epic."
    echo "Only the team repo is included."
    echo ""
  fi

  echo "## Container Layout"
  echo ""
  echo '```'
  echo "/src/"
  if [ -n "$EPIC_BRANCH" ]; then
    echo "  team/                    # Team repo (${EPIC_BRANCH})"
  else
    echo "  team/                    # Team repo (default branch)"
  fi

  if [ ${#REPO_BRANCHES[@]} -gt 0 ]; then
    echo "  projects/"
    for repo_name in $(echo "${!REPO_BRANCHES[@]}" | tr ' ' '\n' | sort); do
      local entries="${REPO_BRANCHES[$repo_name]}"
      IFS=' ' read -ra entry_list <<< "$entries"
      local branches=""
      for entry in "${entry_list[@]}"; do
        IFS='|' read -r branch _ _ <<< "$entry"
        [ -n "$branches" ] && branches+=", "
        branches+="$branch"
      done
      printf "    %-25s # %s\n" "${repo_name}/" "$branches"
    done
  fi
  echo '```'
}

# ---------------------------------------------------------------------------
# Step 8: Output
# ---------------------------------------------------------------------------
if [ "$DRY_RUN" = true ]; then
  echo "=== Generated Containerfile ==="
  echo ""
  generate_containerfile
else
  mkdir -p "$(dirname "$OUTPUT_PATH")"
  generate_containerfile > "$OUTPUT_PATH"
  echo "Containerfile written to: ${OUTPUT_PATH}"
fi

echo ""
echo "=== Build & Run ==="
echo ""
echo "  # Build the debug container"
echo "  podman build --build-arg GITHUB_TOKEN=\$(gh auth token) \\"
echo "    -f ${OUTPUT_PATH} -t epic-${EPIC_NUM}-debug ."
echo ""
echo "  # Run with IDE (default) — opens VSCodium in browser"
echo "  podman run -p 8000:8000 epic-${EPIC_NUM}-debug"
echo "  # Then open http://localhost:8000"
echo ""
echo "  # Run shell only (skip IDE)"
echo "  podman run -it epic-${EPIC_NUM}-debug bash"
echo ""
echo "  # Inside the container:"
echo "  ls /src/projects/          # All project repos"
echo "  cat /src/EPIC-MANIFEST.md  # What's included"
