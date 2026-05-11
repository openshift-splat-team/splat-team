# PR Feedback Loop - Responding to Human Comments

## Overview

After creating a staging PR, continuously monitor for human review comments and respond by making code changes.

## When to Monitor

Monitor PRs in these states:
- After `dev:code-review` approval (PR created)
- While story is in `qe:verify` status
- Before story reaches `done` status

## Workflow

### Step 1: Find Active PRs for Stories

```bash
# Get current story number from context
STORY_NUM=$(git branch --show-current | grep -oP 'story-\K\d+')

# Find PR for this story in current project
PROJECT_REPO=$(git remote get-url origin | sed 's/.*github.com[:/]\(.*\)\.git/\1/' | sed 's/.*github.com[:/]\(.*\)/\1/')

# Get PR number
PR_NUM=$(gh pr list --repo "$PROJECT_REPO" --head "$(git branch --show-current)" --json number --jq '.[0].number')

if [ -z "$PR_NUM" ]; then
  echo "No PR found for current branch"
  exit 0
fi

echo "Monitoring PR #${PR_NUM} in ${PROJECT_REPO}"
```

### Step 2: Check for Review Comments

```bash
# Get all review comments on the PR
COMMENTS=$(gh pr view "$PR_NUM" --repo "$PROJECT_REPO" --json reviews,comments --jq '
  [
    (.reviews[] | select(.state != "APPROVED") | {
      type: "review",
      author: .author.login,
      body: .body,
      state: .state,
      createdAt: .submittedAt
    }),
    (.comments[] | select(.author.login != "splat-sdlc-agent[bot]") | {
      type: "comment", 
      author: .author.login,
      body: .body,
      createdAt: .createdAt
    })
  ] | sort_by(.createdAt) | reverse
')

# Check if there are unaddressed comments
UNADDRESSED=$(echo "$COMMENTS" | jq -r '.[] | select(.body | contains("TODO") or contains("please") or contains("change") or contains("fix")) | .body')

if [ -z "$UNADDRESSED" ]; then
  echo "No feedback to address"
  exit 0
fi
```

### Step 3: Parse Feedback Categories

Review comments typically fall into these categories:

**Change Requests (MUST address):**
- Code changes requested via GitHub review
- Security or bug fixes
- Compliance with standards
- Test coverage requirements

**Questions (SHOULD answer):**
- Clarifications about implementation
- Rationale for design decisions
- Alternative approaches

**Suggestions (MAY consider):**
- Style improvements
- Optimization opportunities
- Documentation enhancements

### Step 4: Respond to Feedback

For each piece of feedback:

```bash
# Extract specific feedback items
gh pr view "$PR_NUM" --repo "$PROJECT_REPO" --json reviews --jq '
  .reviews[] | 
  select(.state == "CHANGES_REQUESTED") | 
  .body
' > /tmp/pr-feedback.txt

# Read and analyze feedback
cat /tmp/pr-feedback.txt

# Make code changes based on feedback
# (Implementation depends on specific feedback)

# Example: If feedback asks to add error handling
# 1. Read the current code
# 2. Add requested error handling
# 3. Commit the changes
git add <changed-files>
git commit -m "Address PR feedback: <summary of changes>

Responds to review comments:
- <specific change 1>
- <specific change 2>

Reviewer: @<reviewer-username>"

# Push updates to PR
git push
```

### Step 5: Reply to Comments

After making changes, respond to each comment:

```bash
# Reply to review comments
gh pr comment "$PR_NUM" --repo "$PROJECT_REPO" --body "$(cat <<EOF
### Feedback Addressed

Thank you for the review feedback. I've made the following changes:

**Changes made:**
- ✅ <Change 1 description>
- ✅ <Change 2 description>
- ✅ <Change 3 description>

**Commits:**
- \`$(git rev-parse --short HEAD~1)\` - <commit message 1>
- \`$(git rev-parse --short HEAD)\` - <commit message 2>

**Ready for re-review**

All requested changes have been implemented. Please review the updated code.

---
*Automated response by superman-atlas*
EOF
)"
```

### Step 6: Request Re-Review

If changes were made in response to "Changes Requested" review:

```bash
# Get reviewer usernames
REVIEWERS=$(gh pr view "$PR_NUM" --repo "$PROJECT_REPO" --json reviews --jq '
  [.reviews[] | select(.state == "CHANGES_REQUESTED") | .author.login] | unique | join(",")
')

# Request re-review
if [ -n "$REVIEWERS" ]; then
  gh pr edit "$PR_NUM" --repo "$PROJECT_REPO" --add-reviewer "$REVIEWERS"
  echo "Re-review requested from: $REVIEWERS"
fi
```

## Integration with Story Status

### When PR Feedback Loop Runs

**Trigger points:**
1. After PR creation (part of `qe:verify` status)
2. On periodic scan (every 15 minutes while story is active)
3. When PR receives new comments (if webhook available)

**Update story status:**
```bash
# If feedback requires code changes
if [ -n "$UNADDRESSED" ]; then
  # Add comment to story issue
  gh issue comment "$STORY_NUM" --repo "$TEAM_REPO" --body "$(cat <<EOF
### 📝 PR Feedback Received

PR #${PR_NUM} has review feedback that needs to be addressed.

**Project:** ${PROJECT_REPO}
**PR:** [#${PR_NUM}](https://github.com/${PROJECT_REPO}/pull/${PR_NUM})

**Feedback summary:**
$(echo "$UNADDRESSED" | head -c 200)...

**Status:** Addressing feedback and updating PR

---
*Automated by superman-atlas PR feedback loop*
EOF
  )"
fi
```

## Code Change Patterns

### Pattern 1: Add Missing Tests

```bash
# Feedback: "Need tests for error cases"
# Response:
cat > pkg/foo/foo_test.go <<'EOF'
func TestErrorHandling(t *testing.T) {
    // Test error cases based on feedback
}
EOF

git add pkg/foo/foo_test.go
git commit -m "Add error case tests per PR review feedback"
git push
```

### Pattern 2: Fix Security Issue

```bash
# Feedback: "Hardcoded credential should use secret"
# Response: Update code to use secret reference

# Make the change
sed -i 's/password := "hardcoded"/password := os.Getenv("PASSWORD")/' pkg/auth/auth.go

git add pkg/auth/auth.go
git commit -m "Fix: Use environment variable for password per security review"
git push
```

### Pattern 3: Improve Documentation

```bash
# Feedback: "Function needs docstring"
# Response: Add documentation

# Update file with docstring
cat > /tmp/update.go <<'EOF'
// ProcessCredentials validates and processes vCenter credentials
// for component-level authentication. Returns error if validation fails.
func ProcessCredentials(creds *Credentials) error {
EOF

# Apply changes and commit
git add pkg/credentials/processor.go
git commit -m "docs: Add docstring to ProcessCredentials per review feedback"
git push
```

## Idempotency

**Prevent duplicate responses:**
```bash
# Check if we've already responded to a review
EXISTING_RESPONSE=$(gh pr view "$PR_NUM" --repo "$PROJECT_REPO" --json comments --jq '
  .comments[] | 
  select(.author.login == "splat-sdlc-agent[bot]") |
  select(.body | contains("Feedback Addressed")) |
  .createdAt
' | tail -1)

LAST_REVIEW=$(gh pr view "$PR_NUM" --repo "$PROJECT_REPO" --json reviews --jq '
  [.reviews[] | select(.state == "CHANGES_REQUESTED")] | 
  sort_by(.submittedAt) | 
  reverse | 
  .[0].submittedAt
')

# Only respond if new feedback since last response
if [ -n "$EXISTING_RESPONSE" ] && [ "$LAST_REVIEW" \< "$EXISTING_RESPONSE" ]; then
  echo "Already responded to latest feedback"
  exit 0
fi
```

## Error Handling

**If unable to address feedback:**
```bash
gh pr comment "$PR_NUM" --repo "$PROJECT_REPO" --body "$(cat <<EOF
### ⚠️ Manual Review Needed

I've reviewed the feedback but need human assistance with:

$(cat /tmp/unclear-feedback.txt)

**Reason:** Feedback requires clarification or architectural decision

Please provide additional guidance or implement these changes manually.

---
*Automated response by superman-atlas*
EOF
)"

# Tag story issue for human attention
gh issue comment "$STORY_NUM" --repo "$TEAM_REPO" --body "🚨 Story #${STORY_NUM} PR needs human attention - see ${PROJECT_REPO}#${PR_NUM}"
```

## Best Practices

1. **Always acknowledge feedback** - Even if you can't immediately address it
2. **Commit granularly** - One commit per logical change requested
3. **Reference reviewer** - Mention @reviewer in commit messages
4. **Test changes** - Run tests before pushing updates
5. **Link commits to comments** - Reference specific review comments in commits
6. **Request re-review** - After addressing changes, explicitly request re-review

## Example Complete Flow

```bash
#!/bin/bash
set -euo pipefail

STORY_NUM=25
PROJECT_REPO="openshift-splat-team/cloud-credential-operator"
PR_NUM=3

# 1. Check for feedback
FEEDBACK=$(gh pr view "$PR_NUM" --repo "$PROJECT_REPO" --json reviews --jq '
  [.reviews[] | select(.state == "CHANGES_REQUESTED")] | last | .body
')

if [ -z "$FEEDBACK" ]; then
  echo "No changes requested"
  exit 0
fi

echo "Feedback to address:"
echo "$FEEDBACK"

# 2. Make changes (example: add validation)
cat >> pkg/vsphere/actuator/validation.go <<'EOF'

// ValidateVCenterConnection verifies connectivity per review feedback
func ValidateVCenterConnection(ctx context.Context, client *vim25.Client) error {
    // Implementation based on reviewer request
    return nil
}
EOF

# 3. Add tests for new validation
cat >> pkg/vsphere/actuator/validation_test.go <<'EOF'

func TestValidateVCenterConnection(t *testing.T) {
    // Test cases per reviewer request
}
EOF

# 4. Commit changes
git add pkg/vsphere/actuator/validation.go pkg/vsphere/actuator/validation_test.go
git commit -m "Add VCenter connection validation per PR review

Addresses review feedback requesting validation before operations.

- Add ValidateVCenterConnection function
- Add test coverage for validation
- Returns error on connection failure

Reviewer: @human-reviewer"

git push

# 5. Respond to review
gh pr comment "$PR_NUM" --repo "$PROJECT_REPO" --body "$(cat <<EOF
### Feedback Addressed ✅

Thank you for the review! I've added the requested vCenter connection validation.

**Changes:**
- ✅ Added \`ValidateVCenterConnection\` function
- ✅ Added test coverage
- ✅ Updated error handling

**Commit:** \`$(git rev-parse --short HEAD)\`

Ready for re-review!
EOF
)"

# 6. Request re-review
REVIEWER=$(gh pr view "$PR_NUM" --repo "$PROJECT_REPO" --json reviews --jq '
  [.reviews[] | select(.state == "CHANGES_REQUESTED")] | last | .author.login
')

gh pr edit "$PR_NUM" --repo "$PROJECT_REPO" --add-reviewer "$REVIEWER"

echo "✅ Feedback addressed and re-review requested"
```

## Monitoring Frequency

**Recommended schedule:**
- Check for PR comments every 15 minutes while story is in `qe:verify` or later
- Respond within 30 minutes of receiving feedback
- Continue monitoring until PR is merged or story is closed

This creates a responsive feedback loop that keeps PRs moving forward! 🚀
