# Human Review Guide for BotMinter SPLAT Team

## Current State: No PRs Created Automatically

**Problem**: Superman completes stories but does NOT create Pull Requests. Code lives in branches with no way for humans to review via GitHub UI.

**Stories marked "done"** have:
- ✅ Commits in branches (in project forks: `openshift-splat-team/<project>`)
- ✅ Comments on issues (in team repo: `openshift-splat-team/splat-team`)
- ❌ **NO Pull Requests** (neither in forks nor upstream)
- ❌ **NO way to review code in GitHub**

## Two-Stage PR Workflow

1. **Staging PRs** (in forks): `openshift-splat-team/<project>` - for human review
2. **Upstream PRs** (to OpenShift): `openshift/<project>` - created by human when ready

This ensures atomic PRs: **one story = one branch = one PR per project**

## Solution: Create PRs for Review

### Option 1: Retroactive PR Creation (For Completed Stories)

Use the script to create **staging PRs** in the fork repos:

```bash
cd /home/splat/.botminter/workspaces/splat/team

# Auto-detect project and branch
./scripts/create-pr-for-story.sh 24

# Or specify project explicitly
./scripts/create-pr-for-story.sh 24 cloud-credential-operator

# Or specify everything
./scripts/create-pr-for-story.sh 24 cloud-credential-operator story-24-migration-path
```

**The script will:**
1. Find the branch in the project repo (auto-detects if not specified)
2. Push branch to `openshift-splat-team/<project>` fork
3. Create **staging PR** in the fork (for human review)
4. Link PR back to the story issue in team repo

**Example:**
```bash
./scripts/create-pr-for-story.sh 24
# ✓ Found branch in project: cloud-credential-operator
# ✓ PR created: https://github.com/openshift-splat-team/cloud-credential-operator/pull/123
# ✓ Linked to story: openshift-splat-team/splat-team#24
```

This creates an **atomic PR**: one story, one branch, one PR in the project fork.

### Option 2: Create Upstream PR (After Staging Review)

Once the **staging PR** in the fork is reviewed and approved:

```bash
# 1. Navigate to project
cd /home/splat/.botminter/workspaces/splat/superman-atlas/projects/cloud-credential-operator

# 2. Ensure branch is pushed
git checkout story-24-migration-path
git push -u origin story-24-migration-path

# 3. Create PR from fork → upstream OpenShift repo
gh pr create \
  --repo openshift/cloud-credential-operator \
  --base master \
  --head openshift-splat-team:story-24-migration-path \
  --title "Story #24: Migration Path for Existing Clusters" \
  --body "$(cat <<EOF
## Description
Migration path for existing clusters to adopt per-component credentials.

## Related
- SPLAT Story: openshift-splat-team/splat-team#24
- Staging PR: openshift-splat-team/cloud-credential-operator#123

## Testing
- Tested in staging fork
- QE verification complete
- All acceptance criteria met
EOF
)"

# 4. Open upstream PR in browser
gh pr view --web --repo openshift/cloud-credential-operator
```

**Important**: Only create upstream PRs after staging PR is approved!

### Option 3: Enable Automatic PR Creation (Future Stories)

Update superman's workflow to automatically create PRs after code review approval.

**Status**: Documentation added to `members/superman-atlas/hats/dev_code_reviewer/knowledge/pr-creation.md`

**To activate**: Superman will need to follow the PR creation workflow on next code review approval.

## How to Review Stories

### Step 1: Find Stories Ready for Review

```bash
# List stories in po:design-review status
gh issue list --repo openshift-splat-team/splat-team \
  --label "kind/epic" \
  --search "project:5 status:po:design-review"

# List stories in po:accept status (completed, awaiting acceptance)
gh issue list --repo openshift-splat-team/splat-team \
  --label "kind/story" \
  --search "project:5 status:po:accept"
```

### Step 2: Review the Issue

```bash
# View story details
gh issue view 24 --repo openshift-splat-team/splat-team

# View story in browser
gh issue view 24 --web
```

**Look for**:
- Superman's comments with work summaries
- Test results
- Code review outcomes
- **PR link** (if created)

### Step 3: Review Code Changes

**If PR exists:**
```bash
# Find PR for story
gh pr list --repo openshift-splat-team/splat-team --search "24"

# View PR in browser
gh pr view 123 --web

# Review code in GitHub UI with inline comments
```

**If NO PR exists (current state):**

You need to create one first (see Option 1 or 2 above), then review.

### Step 4: Approve or Request Changes

**Via GitHub Issue Comment** (current workflow):

```bash
# Approve
gh issue comment 24 --repo openshift-splat-team/splat-team \
  --body "Approved - design looks good, proceed with implementation"

# Reject with feedback
gh issue comment 24 --repo openshift-splat-team/splat-team \
  --body "Rejected: Need to address X, Y, Z before proceeding"
```

**Via GitHub PR Review** (if PR exists):

```bash
# Open PR in browser and use GitHub review UI
gh pr view 123 --web

# Or via CLI
gh pr review 123 --approve
gh pr review 123 --request-changes --body "Please address X"
```

### Step 5: Activate Stories (for po:ready status)

Stories in `po:ready` status await human activation:

```bash
# Tell superman to start work
gh issue comment 14 --repo openshift-splat-team/splat-team \
  --body "start"

# Or more explicitly
gh issue comment 14 --repo openshift-splat-team/splat-team \
  --body "Approved - activate this epic"
```

Superman scans for keywords: `start`, `activate`, `approved`, `lgtm` (case-insensitive)

## Review Gates in Workflow

| Status | Human Action | How to Respond |
|--------|--------------|----------------|
| `po:triage` | Approve/reject new epic | Comment: `Approved` or `Rejected: <reason>` |
| `po:design-review` | Review design doc | Comment: `Approved` or `Rejected: <feedback>` |
| `po:plan-review` | Review story breakdown | Comment: `Approved` or `Rejected: <feedback>` |
| `po:ready` | Activate epic | Comment: `start` or `activate` |
| `po:accept` | Accept completed epic | Comment: `Approved` or `Rejected: <feedback>` |

**Note**: Code review (`dev:code-review`) is automated via CodeRabbit + superman's self-review. But you CAN review the PR if one is created!

## Common Tasks

### See All Open Stories

```bash
gh issue list --repo openshift-splat-team/splat-team \
  --label "kind/story" \
  --state open
```

### See All Completed Stories (Ready for Acceptance)

```bash
gh issue list --repo openshift-splat-team/splat-team \
  --label "kind/story" \
  --search "project:5 status:po:accept"
```

### Find PRs Created by Superman

```bash
gh pr list --repo openshift-splat-team/splat-team \
  --author "splat-sdlc-agent[bot]"
```

### Bulk Create PRs for Completed Stories

```bash
cd /home/splat/.botminter/workspaces/splat/team

# List all done stories
DONE_STORIES=$(gh issue list --repo openshift-splat-team/splat-team \
  --label "kind/story" \
  --search "project:5 status:done" \
  --json number --jq '.[].number')

# Create PRs for each (if branches exist)
for story in $DONE_STORIES; do
  echo "Processing story #${story}..."
  ./scripts/create-pr-for-story.sh "$story" || echo "Skipped story #${story}"
done
```

## Next Steps

1. **Immediate**: Create PRs for completed stories using the script
2. **Short-term**: Review PRs in GitHub UI, provide feedback via PR comments
3. **Long-term**: Enable automatic PR creation in superman's workflow

## Troubleshooting

**"Branch not found"**:
- Superman may not have created a branch for that story
- Check if story was completed in a different repo/project
- Use `git branch -a | grep story-<num>` to search

**"PR already exists"**:
- Script will use existing PR
- Find it with `gh pr list --search "<story-num>"`

**"No changes to review"**:
- Story may be documentation-only
- Check the issue comments for deliverables

**"Cannot find team repo"**:
- Team repo is at `/home/splat/.botminter/workspaces/splat/team`
- Project repos are at `./superman-atlas/projects/<project>/`

## Resources

- **BotMinter SPLAT Team**: https://github.com/openshift-splat-team/splat-team
- **Project Board**: https://github.com/orgs/openshift-splat-team/projects/5
- **PR Creation Workflow**: `members/superman-atlas/hats/dev_code_reviewer/knowledge/pr-creation.md`
- **Create PR Script**: `scripts/create-pr-for-story.sh`
