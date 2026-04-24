---
name: PR Feedback Monitor
description: Monitor staging PRs for review comments and respond with code changes
---

# PR Feedback Monitor

Monitor staging PRs in `openshift-splat-team/*` forks for human review comments and automatically respond by making appropriate code changes.

## When to Use This Skill

Use this skill to:
- Check for review comments on active PRs
- Parse feedback and categorize by urgency
- Make code changes in response to feedback
- Update PRs and notify reviewers
- Track feedback resolution status

## Prerequisites

1. **Active PR** exists for the story branch
2. **Project context** - know which project/PR to monitor
3. **Story number** - link feedback back to story issue

## Usage

### Basic: Check for Feedback on Current Branch

```bash
# Load the skill
ralph tools skill load pr-feedback-monitor

# Check current branch's PR for feedback
PROJECT_REPO=$(git remote get-url origin | sed 's/.*github.com[:/]\(.*\)\.git/\1/')
CURRENT_BRANCH=$(git branch --show-current)
PR_NUM=$(gh pr list --repo "$PROJECT_REPO" --head "$CURRENT_BRANCH" --json number --jq '.[0].number')

if [ -z "$PR_NUM" ]; then
  echo "No PR found for branch: $CURRENT_BRANCH"
  exit 0
fi

# Get unaddressed feedback
gh pr view "$PR_NUM" --repo "$PROJECT_REPO" --json reviews,comments
```

### Check Specific PR

```bash
# Check PR #3 in cloud-credential-operator
gh pr view 3 --repo openshift-splat-team/cloud-credential-operator --json reviews,comments --jq '
  {
    changesRequested: [.reviews[] | select(.state == "CHANGES_REQUESTED") | {
      author: .author.login,
      submittedAt: .submittedAt,
      body: .body
    }],
    comments: [.comments[] | select(.author.login != "splat-sdlc-agent[bot]") | {
      author: .author.login,
      createdAt: .createdAt,
      body: .body
    }]
  }
'
```

### Response Workflow

```bash
#!/bin/bash
# Full PR feedback response workflow

set -euo pipefail

PR_NUM="${1:-}"
PROJECT_REPO="${2:-}"
STORY_NUM="${3:-}"

if [ -z "$PR_NUM" ] || [ -z "$PROJECT_REPO" ]; then
  echo "Usage: $0 <pr-number> <project-repo> [story-number]"
  exit 1
fi

echo "Monitoring PR #${PR_NUM} in ${PROJECT_REPO}..."

# 1. Get latest changes requested review
LATEST_REVIEW=$(gh pr view "$PR_NUM" --repo "$PROJECT_REPO" --json reviews --jq '
  [.reviews[] | select(.state == "CHANGES_REQUESTED")] |
  sort_by(.submittedAt) |
  reverse |
  .[0]
')

if [ "$LATEST_REVIEW" = "null" ] || [ -z "$LATEST_REVIEW" ]; then
  echo "✓ No changes requested"
  exit 0
fi

REVIEWER=$(echo "$LATEST_REVIEW" | jq -r '.author.login')
FEEDBACK=$(echo "$LATEST_REVIEW" | jq -r '.body')
REVIEW_TIME=$(echo "$LATEST_REVIEW" | jq -r '.submittedAt')

echo "Review from @${REVIEWER} at ${REVIEW_TIME}"
echo "Feedback:"
echo "$FEEDBACK"

# 2. Check if already addressed
LAST_RESPONSE=$(gh pr view "$PR_NUM" --repo "$PROJECT_REPO" --json comments --jq '
  [.comments[] | 
   select(.author.login == "splat-sdlc-agent[bot]") |
   select(.body | contains("Feedback Addressed"))] |
  sort_by(.createdAt) |
  reverse |
  .[0].createdAt // empty
')

if [ -n "$LAST_RESPONSE" ] && [ "$REVIEW_TIME" \< "$LAST_RESPONSE" ]; then
  echo "✓ Already responded to this feedback"
  exit 0
fi

# 3. Analyze feedback and determine actions
echo ""
echo "📝 Feedback requires code changes"
echo ""

# TODO: Parse feedback and make appropriate changes
# This would involve:
# - Analyzing the feedback text
# - Identifying specific files/functions to change
# - Making the changes
# - Running tests
# - Committing and pushing

echo "⚠️  Manual implementation required for this feedback"
echo "    Add logic here to parse and respond to specific feedback types"

# 4. Example: Acknowledge feedback
gh pr comment "$PR_NUM" --repo "$PROJECT_REPO" --body "$(cat <<EOF
### 📝 Feedback Acknowledged

@${REVIEWER}, thank you for the review feedback.

I'm analyzing the requested changes:

$(echo "$FEEDBACK" | head -c 300)

**Status:** Working on implementation

I'll update this PR with the changes and notify you when ready for re-review.

---
*Automated by superman-atlas*
EOF
)"

echo "✓ Acknowledged feedback"
```

## Feedback Categories & Responses

### Category 1: Code Quality Issues

**Feedback patterns:**
- "Add error handling"
- "Function is too complex"
- "Missing input validation"
- "Improve naming"

**Response workflow:**

**Step 1: Acknowledge and plan**
```bash
gh pr comment "$PR_NUM" --repo "$PROJECT_REPO" --body "$(cat <<EOF
@reviewer, working on this now.

**Planned changes:**
- Add error handling for <case>
- Simplify <function> logic
- Validate <input> parameters

I'll update the PR shortly.

---
*Working on it - superman-atlas*
EOF
)"
```

**Step 2: Make code changes**
```bash
# Make code quality improvements
git add <files>
git commit -m "refactor: Improve <component> per review feedback

- Add error handling for <case>
- Simplify <function> logic
- Validate <input> parameters
- Rename <variable> for clarity

Reviewer: @<username>"
git push
```

**Step 3: Report completion**
```bash
gh pr comment "$PR_NUM" --repo "$PROJECT_REPO" --body "$(cat <<EOF
@reviewer, changes complete! ✅

**Summary of changes:**
- ✅ Added error handling for nil credentials in \`ProcessCredentials()\`
- ✅ Simplified \`ValidateConfig()\` by extracting helper function
- ✅ Added input validation for all public API functions
- ✅ Renamed \`data\` → \`credentialData\` for clarity

**Commits:**
- \`$(git rev-parse --short HEAD)\` - $(git log -1 --format=%s)

**Files changed:**
$(git diff --stat HEAD~1..HEAD)

Ready for re-review!

---
*Changes complete - superman-atlas*
EOF
)"
```

### Category 2: Missing Tests

**Feedback patterns:**
- "Need tests for X"
- "Test coverage is low"
- "Add edge case tests"
- "Missing error path tests"

**Response workflow:**

**Step 1: Acknowledge**
```bash
gh pr comment "$PR_NUM" --repo "$PROJECT_REPO" --body "@reviewer, adding test coverage for these scenarios now."
```

**Step 2: Add tests**
```bash
# Add requested tests
git add <test-files>
git commit -m "test: Add test coverage per review feedback

- Add tests for <scenario>
- Cover edge cases: <case1>, <case2>
- Test error paths for <function>
- Increase coverage to <percentage>%

Reviewer: @<username>"
git push
```

**Step 3: Report results**
```bash
gh pr comment "$PR_NUM" --repo "$PROJECT_REPO" --body "$(cat <<EOF
@reviewer, test coverage added! ✅

**New tests:**
- \`TestMultiVCenterValidation\` - validates multiple vCenter configurations
- \`TestCredentialRotation\` - tests edge cases during rotation
- \`TestErrorPaths\` - covers error scenarios in credential processing

**Coverage:**
- Before: 78%
- After: 91%

**Test results:**
\`\`\`
PASS: TestMultiVCenterValidation (0.23s)
PASS: TestCredentialRotation (0.15s)
PASS: TestErrorPaths (0.08s)
\`\`\`

All tests passing!

---
*Tests added - superman-atlas*
EOF
)"
```

### Category 3: Documentation

**Feedback patterns:**
- "Add docstring"
- "Update README"
- "Document parameters"
- "Explain algorithm"

**Response workflow:**

**Step 1: Acknowledge**
```bash
gh pr comment "$PR_NUM" --repo "$PROJECT_REPO" --body "@reviewer, adding documentation now."
```

**Step 2: Add documentation**
```bash
# Add/update documentation
git add <doc-files>
git commit -m "docs: Add documentation per review feedback

- Add docstring to <function>
- Document parameters and return values
- Explain <algorithm> implementation
- Update README with <section>

Reviewer: @<username>"
git push
```

**Step 3: Report completion**
```bash
gh pr comment "$PR_NUM" --repo "$PROJECT_REPO" --body "$(cat <<EOF
@reviewer, documentation added! ✅

**Updates:**
- ✅ Added docstrings to all public functions in \`actuator.go\`
- ✅ Documented parameters and return values
- ✅ Explained validation algorithm in inline comments
- ✅ Updated README with multi-vCenter configuration example

**Example:**
\`\`\`go
// ValidateVCenterConfig validates the provided vCenter configuration
// against required security constraints and connectivity requirements.
//
// Parameters:
//   - config: The vCenter configuration to validate
//   - ctx: Context for timeout and cancellation
//
// Returns error if validation fails, nil on success
func ValidateVCenterConfig(config *Config, ctx context.Context) error
\`\`\`

---
*Documentation complete - superman-atlas*
EOF
)"
```

### Category 4: Security/Compliance

**Feedback patterns:**
- "Security vulnerability"
- "Use constant-time comparison"
- "Validate input sanitization"
- "Remove hardcoded secret"

**Response workflow (HIGHEST PRIORITY):**

**Step 1: Acknowledge immediately**
```bash
gh pr comment "$PR_NUM" --repo "$PROJECT_REPO" --body "🔒 @reviewer, addressing this security issue immediately. ETA: 15 minutes."
```

**Step 2: Fix security issues**
```bash
# Fix security issues (HIGHEST PRIORITY)
git add <files>
git commit -m "security: Fix <vulnerability> per review feedback

- Use constant-time comparison for secrets
- Sanitize user input in <function>
- Move credentials to environment variable
- Add input validation for <parameter>

Reviewer: @<username>
Security-Review: Required"
git push
```

**Step 3: Report fix with details**
```bash
gh pr comment "$PR_NUM" --repo "$PROJECT_REPO" --body "$(cat <<EOF
🔒 @reviewer, security issue fixed! ✅

**Vulnerability:** ${VULN_DESCRIPTION}

**Fix applied:**
- ✅ Replaced string comparison with \`subtle.ConstantTimeCompare()\`
- ✅ All user input now sanitized via \`validateInput()\`
- ✅ Credentials moved from hardcoded string to \`os.Getenv("VCENTER_PASSWORD")\`
- ✅ Added input validation for all external parameters

**Security test:**
- Added \`TestConstantTimeComparison\` to verify timing-safe comparison
- Added \`TestInputSanitization\` to verify injection prevention

**Commit:** \`$(git rev-parse --short HEAD)\`

This is a critical fix. Please prioritize re-review.

---
*Security fix complete - superman-atlas*
EOF
)"
```

### Category 5: Questions/Clarifications

**Feedback patterns:**
- "Why was this approach chosen?"
- "Can you explain...?"
- "Have you considered...?"
- "What about...?"

**Response: Comment only (NO code changes)**

```bash
# IMPORTANT: Only respond with comment, do NOT make code changes
gh pr comment "$PR_NUM" --repo "$PROJECT_REPO" --body "$(cat <<EOF
@reviewer, great question!

**Q:** ${QUESTION}

**A:** ${ANSWER}

${ADDITIONAL_CONTEXT}

Let me know if you'd like me to add this explanation as a code comment or update the documentation.

---
*Response by superman-atlas*
EOF
)"
```

**Do NOT make code changes for clarification questions unless explicitly requested.**

## Output Format

The skill produces structured output for automation:

```json
{
  "prNumber": 3,
  "repository": "openshift-splat-team/cloud-credential-operator",
  "feedbackStatus": "changes-requested",
  "reviewers": ["human-reviewer"],
  "lastReviewDate": "2026-04-24T15:30:00Z",
  "lastResponseDate": "2026-04-24T14:00:00Z",
  "needsAction": true,
  "feedbackItems": [
    {
      "type": "code-quality",
      "priority": "medium",
      "description": "Add error handling for nil credentials",
      "file": "pkg/vsphere/actuator/actuator.go",
      "line": 42,
      "status": "pending"
    },
    {
      "type": "tests",
      "priority": "high",
      "description": "Add tests for multi-vCenter scenario",
      "status": "pending"
    }
  ],
  "actionRequired": "make-changes"
}
```

## Integration with Ralph Event Loop

This skill should be called periodically for active PRs:

```yaml
# In ralph event loop
every: 15min
trigger:
  - Check active PRs for stories in qe:verify or later
  - Load pr-feedback-monitor skill
  - Parse feedback
  - Make changes if needed
  - Publish dev.pr-feedback event if changes made
```

## Best Practices

1. **Respond quickly** - Acknowledge feedback within 30 minutes
2. **Commit granularly** - One commit per logical change
3. **Reference reviewers** - Always @mention in responses
4. **Test before pushing** - Run tests to verify changes
5. **Request re-review** - Explicitly ask for re-review after changes
6. **Track resolution** - Mark addressed items in comments

## Troubleshooting

**"No PR found"**
- Verify branch has been pushed: `git push -u origin <branch>`
- Check PR exists: `gh pr list --repo <repo>`

**"Cannot parse feedback"**
- Feedback may be too vague
- Ask reviewer for specific changes needed
- Tag issue for human attention

**"Changes failed tests"**
- Fix test failures before pushing
- Add new tests if needed
- Commit test fixes separately

**"Reviewer not responding to re-review request"**
- After 48 hours, add reminder comment
- Escalate to story issue if blocked

## Example: Complete Feedback Loop

```bash
#!/bin/bash
# Complete example: Respond to PR feedback

PR_NUM=3
PROJECT_REPO="openshift-splat-team/cloud-credential-operator"
STORY_NUM=25

# 1. Get feedback
FEEDBACK=$(gh pr view "$PR_NUM" --repo "$PROJECT_REPO" --json reviews --jq '
  [.reviews[] | select(.state == "CHANGES_REQUESTED")] | last
')

REVIEWER=$(echo "$FEEDBACK" | jq -r '.author.login')
REVIEW_BODY=$(echo "$FEEDBACK" | jq -r '.body')

echo "Review from: $REVIEWER"
echo "$REVIEW_BODY"

# 2. Make changes based on feedback
# (This would be specific to the feedback content)
echo "// Add nil check per review feedback" >> pkg/vsphere/actuator/actuator.go
echo "if creds == nil { return fmt.Errorf(\"credentials cannot be nil\") }" >> pkg/vsphere/actuator/actuator.go

# 3. Add tests
cat >> pkg/vsphere/actuator/actuator_test.go <<'EOF'
func TestNilCredentials(t *testing.T) {
    _, err := ProcessCredentials(nil)
    if err == nil {
        t.Error("Expected error for nil credentials")
    }
}
EOF

# 4. Commit changes
git add pkg/vsphere/actuator/actuator.go pkg/vsphere/actuator/actuator_test.go
git commit -m "fix: Add nil check for credentials per review feedback

- Add validation for nil credentials
- Add test coverage for nil case
- Return clear error message

Reviewer: @${REVIEWER}"

# 5. Push update
git push

# 6. Respond to review
gh pr comment "$PR_NUM" --repo "$PROJECT_REPO" --body "$(cat <<EOF
### Feedback Addressed ✅

@${REVIEWER}, thank you for catching that! I've added the nil check and test coverage.

**Changes:**
- ✅ Added nil validation for credentials
- ✅ Added \`TestNilCredentials\` test
- ✅ Returns clear error message

**Commit:** \`$(git rev-parse --short HEAD)\`

Ready for re-review!
EOF
)"

# 7. Request re-review
gh pr edit "$PR_NUM" --repo "$PROJECT_REPO" --add-reviewer "$REVIEWER"

echo "✅ Done! Re-review requested from @${REVIEWER}"
```

This skill enables superman to be responsive to human feedback and iterate on PRs efficiently! 🚀
