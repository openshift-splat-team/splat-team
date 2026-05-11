# Pull Request Creation Workflow

## Required: Create PR After Code Review Approval

When the code review is APPROVED, you MUST create a Pull Request before advancing the story.

### Step 1: Verify Branch and Commits

```bash
# Check current branch
CURRENT_BRANCH=$(git branch --show-current)

# Verify commits exist
git log --oneline main..HEAD

# Get latest commit hash
COMMIT_HASH=$(git rev-parse --short HEAD)
```

### Step 2: Push Branch to Remote

```bash
# Push branch if not already pushed
git push -u origin "$CURRENT_BRANCH"
```

### Step 3: Create Pull Request

```bash
# Get story number from branch name (e.g., story-24-migration-path → 24)
STORY_NUM=$(echo "$CURRENT_BRANCH" | grep -oP 'story-\K\d+')

# Read story title and body
STORY_INFO=$(gh issue view "$STORY_NUM" --repo "$TEAM_REPO" --json title,body)
STORY_TITLE=$(echo "$STORY_INFO" | jq -r '.title')

# Create PR with reference to story
PR_URL=$(gh pr create \
  --repo "$TEAM_REPO" \
  --base main \
  --head "$CURRENT_BRANCH" \
  --title "Story #${STORY_NUM}: ${STORY_TITLE}" \
  --body "$(cat <<EOF
## Story

Closes #${STORY_NUM}

## Implementation

This PR implements Story #${STORY_NUM}: ${STORY_TITLE}

### Changes

$(git log --oneline main..HEAD)

### Files Changed

$(git diff --stat main..HEAD)

## Review Status

✅ **Code Review**: Approved by dev_code_reviewer  
✅ **CodeRabbit**: All checks passed  
⏳ **QE Verification**: Ready for verification

## Commit

Latest: \`${COMMIT_HASH}\`

---
*PR created by superman-atlas (BotMinter)*
EOF
)")

echo "PR created: $PR_URL"
```

### Step 4: Link PR in Issue Comment

```bash
# Extract PR number from URL
PR_NUM=$(echo "$PR_URL" | grep -oP 'pull/\K\d+')

# Add PR link to story issue
gh issue comment "$STORY_NUM" --repo "$TEAM_REPO" --body "$(cat <<EOF
### 💻 dev — $(date -Iseconds)

**Pull Request Created**: #${PR_NUM}

Code review approved. PR is ready for QE verification.

**Review checklist:**
- ✅ CodeRabbit AI review passed
- ✅ All acceptance criteria addressed
- ✅ Tests included
- ✅ Code quality standards met

**Next steps:**
- QE verification in PR #${PR_NUM}
- Human review of PR (optional)
- Auto-merge after QE approval

[View Pull Request →](${PR_URL})
EOF
)"
```

### Step 5: Update Story Status

Only after PR is created, advance to QE verification:

```bash
# Set story to qe:verify status
gh issue edit "$STORY_NUM" --repo "$TEAM_REPO" --status "qe:verify"

# Publish event
ralph tools pubsub publish dev.approved "payload=PR #${PR_NUM} created for story ${STORY_NUM}"
```

## Integration Point

**When**: After `dev_code_reviewer` approves (status transition to `qe:verify`)  
**Before**: Advancing to QE verification  
**Required**: PR URL must be in issue comment

## Error Handling

If PR creation fails:

```bash
if ! PR_URL=$(gh pr create ...); then
  echo "PR creation failed - likely already exists"
  
  # Check for existing PR
  EXISTING_PR=$(gh pr list --repo "$TEAM_REPO" --head "$CURRENT_BRANCH" --json number,url --jq '.[0].url')
  
  if [ -n "$EXISTING_PR" ]; then
    echo "Using existing PR: $EXISTING_PR"
    PR_URL="$EXISTING_PR"
  else
    # Critical failure - cannot proceed
    gh issue comment "$STORY_NUM" --repo "$TEAM_REPO" --body "❌ Failed to create PR for story #${STORY_NUM}"
    ralph tools pubsub publish dev.code_review.failed "payload=PR creation failed"
    exit 1
  fi
fi
```

## Human Review Integration

With PRs created, humans can:

1. **Review code in GitHub UI** → `gh pr view #<pr-num> --web`
2. **See commits and diffs** → Native GitHub PR view
3. **Add review comments** → Inline code comments
4. **Approve/Request changes** → GitHub PR review
5. **Check CI status** → See test results in PR

## Benefits

✅ **Traceability**: Every story has a linked PR  
✅ **Code review**: Humans can review in GitHub UI  
✅ **Audit trail**: PR history shows all changes  
✅ **CI integration**: PR checks run automatically  
✅ **Merge control**: Humans can gate final merge  

## Migration Note

For stories completed without PRs (like #24), retroactively create PRs:

```bash
# Find the branch for completed story
git checkout story-24-migration-path

# Create PR
gh pr create --base main --head story-24-migration-path \
  --title "Story #24: Migration Path for Existing Clusters" \
  --body "Retroactive PR for completed story #24"
```
