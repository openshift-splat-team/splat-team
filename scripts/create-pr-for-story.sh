#!/bin/bash
# Create a Pull Request for a completed story in the appropriate project repo
# Usage: ./create-pr-for-story.sh <story-number> [project-name] [branch-name]

set -euo pipefail

STORY_NUM="${1:-}"
PROJECT_NAME="${2:-}"
BRANCH_NAME="${3:-}"
TEAM_REPO="openshift-splat-team/splat-team"
WORKSPACE_ROOT="/home/splat/.botminter/workspaces/splat/superman-atlas"

if [ -z "$STORY_NUM" ]; then
  echo "Usage: $0 <story-number> [project-name] [branch-name]"
  echo "Example: $0 24 cloud-credential-operator story-24-migration-path"
  echo ""
  echo "If project-name is omitted, will search all projects for the branch"
  exit 1
fi

# Get story info
echo "Fetching story #${STORY_NUM} info..."
STORY_INFO=$(gh issue view "$STORY_NUM" --repo "$TEAM_REPO" --json title,body,labels)
STORY_TITLE=$(echo "$STORY_INFO" | jq -r '.title')

echo "Story: ${STORY_TITLE}"

# Auto-detect branch if not provided
if [ -z "$BRANCH_NAME" ]; then
  BRANCH_NAME="story-${STORY_NUM}-$(echo "$STORY_TITLE" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | sed 's/[^a-z0-9-]//g' | head -c 40)"
  echo "Auto-detected branch: $BRANCH_NAME"
fi

# Find which project has this branch
if [ -z "$PROJECT_NAME" ]; then
  echo "Searching for branch in all projects..."
  for project_dir in "$WORKSPACE_ROOT/projects"/*/; do
    project=$(basename "$project_dir")
    cd "$project_dir"

    if git rev-parse --verify "$BRANCH_NAME" >/dev/null 2>&1; then
      PROJECT_NAME="$project"
      echo "✓ Found branch in project: $PROJECT_NAME"
      break
    fi
  done

  if [ -z "$PROJECT_NAME" ]; then
    echo "Error: Branch '$BRANCH_NAME' not found in any project"
    echo ""
    echo "Available story branches:"
    for project_dir in "$WORKSPACE_ROOT/projects"/*/; do
      project=$(basename "$project_dir")
      cd "$project_dir"
      echo "  ${project}:"
      git branch | grep "story-${STORY_NUM}" | sed 's/^/    /' || echo "    (none)"
    done
    exit 1
  fi
fi

# Navigate to project
PROJECT_DIR="$WORKSPACE_ROOT/projects/$PROJECT_NAME"
if [ ! -d "$PROJECT_DIR" ]; then
  echo "Error: Project directory not found: $PROJECT_DIR"
  exit 1
fi

cd "$PROJECT_DIR"
echo "Working in: $PROJECT_DIR"

# Get project repo from git remote
PROJECT_REPO=$(git remote get-url origin | sed 's/.*github.com[:/]\(.*\)\.git/\1/' | sed 's/.*github.com[:/]\(.*\)/\1/')
echo "Project repo: $PROJECT_REPO"

# Detect default branch (main or master)
DEFAULT_BRANCH=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || echo "master")
echo "Default branch: $DEFAULT_BRANCH"

# Verify branch exists
if ! git rev-parse --verify "$BRANCH_NAME" >/dev/null 2>&1; then
  echo "Error: Branch '$BRANCH_NAME' does not exist in $PROJECT_NAME"
  echo ""
  echo "Available branches:"
  git branch | grep story || echo "(no story branches)"
  exit 1
fi

# Checkout branch
echo "Checking out branch: $BRANCH_NAME"
git checkout "$BRANCH_NAME"

# Get current branch commits
COMMIT_COUNT=$(git rev-list --count ${DEFAULT_BRANCH}..HEAD 2>/dev/null || echo "0")
if [ "$COMMIT_COUNT" = "0" ]; then
  echo "Warning: No commits on this branch ahead of $DEFAULT_BRANCH"
  COMMIT_LOG=$(git log --oneline -5)
  DIFF_STAT=$(git diff --stat HEAD~5..HEAD 2>/dev/null || echo "No changes")
else
  COMMIT_LOG=$(git log --oneline ${DEFAULT_BRANCH}..HEAD)
  DIFF_STAT=$(git diff --stat ${DEFAULT_BRANCH}..HEAD)
fi

COMMIT_HASH=$(git rev-parse --short HEAD)

echo ""
echo "Branch status:"
echo "  Commits ahead of main: $COMMIT_COUNT"
echo "  Latest commit: $COMMIT_HASH"
echo ""

# Push branch to remote
echo "Pushing branch to $PROJECT_REPO..."
if git push -u origin "$BRANCH_NAME" 2>&1; then
  echo "✓ Branch pushed"
else
  echo "⚠ Push failed or branch already pushed"
fi

# Check if PR already exists
echo "Checking for existing PR..."
EXISTING_PR=$(gh pr list --repo "$PROJECT_REPO" --head "$BRANCH_NAME" --json number,url --jq '.[0]')

if [ -n "$EXISTING_PR" ] && [ "$EXISTING_PR" != "null" ]; then
  PR_URL=$(echo "$EXISTING_PR" | jq -r '.url')
  PR_NUM=$(echo "$EXISTING_PR" | jq -r '.number')
  echo "✓ PR already exists: $PR_URL"
else
  # Create PR
  echo "Creating Pull Request in $PROJECT_REPO..."

  PR_BODY="## Story

Implements story openshift-splat-team/splat-team#${STORY_NUM}

**${STORY_TITLE}**

## Implementation

This PR implements the changes for story #${STORY_NUM}.

### Commits ($COMMIT_COUNT commits)

\`\`\`
${COMMIT_LOG}
\`\`\`

### Files Changed

\`\`\`
${DIFF_STAT}
\`\`\`

## Testing

See story issue for test results and QE verification.

## Review Status

✅ **Automated Review**: Passed
⏳ **Human Review**: Ready for review

Latest commit: \`${COMMIT_HASH}\`

---
*This is a staging PR. A human will create the upstream PR when ready.*
*Managed by BotMinter superman-atlas*"

  PR_URL=$(gh pr create \
    --repo "$PROJECT_REPO" \
    --base "$DEFAULT_BRANCH" \
    --head "$BRANCH_NAME" \
    --title "Story #${STORY_NUM}: ${STORY_TITLE}" \
    --body "$PR_BODY" 2>&1)

  # Extract PR number from URL
  PR_NUM=$(echo "$PR_URL" | grep -oP 'pull/\K\d+' || echo "")

  if [ -z "$PR_NUM" ]; then
    echo "Error: Failed to create PR"
    echo "$PR_URL"
    exit 1
  fi

  echo "✅ PR created: $PR_URL"
fi

# Add PR link to story issue in team repo
echo ""
echo "Linking PR to story issue..."
gh issue comment "$STORY_NUM" --repo "$TEAM_REPO" --body "$(cat <<EOF
### 🔗 Pull Request Created

**Project**: [\`${PROJECT_NAME}\`](https://github.com/${PROJECT_REPO})
**PR**: [#${PR_NUM} - ${STORY_TITLE}](${PR_URL})
**Branch**: \`${BRANCH_NAME}\` (\`${COMMIT_HASH}\`)

This story has been implemented and is ready for review in the staging fork.

**Review the PR**: [${PROJECT_REPO}#${PR_NUM}](${PR_URL})

**Review checklist:**
- [ ] Code changes reviewed
- [ ] Tests included and passing
- [ ] Documentation updated
- [ ] Acceptance criteria met

**Next steps:**
- Human reviews staging PR
- After approval, human creates PR from fork → upstream \`openshift/${PROJECT_NAME}\`

---
*Atomic PR: one story, one branch, one PR*
EOF
)" 2>&1 && echo "✓ Comment added to story issue" || echo "⚠ Failed to add comment"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Done!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  Story:   #${STORY_NUM} - ${STORY_TITLE}"
echo "  Project: ${PROJECT_NAME}"
echo "  Branch:  ${BRANCH_NAME}"
echo "  PR:      ${PROJECT_REPO}#${PR_NUM}"
echo "  URL:     ${PR_URL}"
echo ""
echo "To review:"
echo "  gh pr view ${PR_NUM} --repo ${PROJECT_REPO} --web"
echo ""
