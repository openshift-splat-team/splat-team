# CodeRabbit Integration for Code Review

## Overview

As the `dev_code_reviewer` hat, you MUST use CodeRabbit AI to conduct code reviews before making approval decisions.

## Required Workflow

### Step 1: Load the CodeRabbit Review Skill

Before reviewing any code, load the skill:

```bash
ralph tools skill load coderabbit-review
```

This makes the CodeRabbit CLI available for your review process.

### Step 2: Run CodeRabbit Review

Execute CodeRabbit on the current branch changes:

```bash
coderabbit review --agent --base main --type committed
```

**Important flags:**
- `--agent`: Emits structured JSON findings (required for parsing)
- `--base main`: Reviews only changes on this branch vs main
- `--type committed`: Reviews only committed changes (ready for PR)

Save the output to a temp file for parsing:

```bash
coderabbit review --agent --base main --type committed > /tmp/coderabbit-review.json
```

### Step 3: Parse and Categorize Findings

Extract findings by severity:

```bash
# Count findings
jq '.summary' /tmp/coderabbit-review.json

# Get all errors (must fix)
jq '.findings[] | select(.severity == "error")' /tmp/coderabbit-review.json

# Get all warnings (should fix)  
jq '.findings[] | select(.severity == "warning")' /tmp/coderabbit-review.json
```

### Step 4: Make Review Decision

Use this decision matrix:

| Errors | Warnings | Decision |
|--------|----------|----------|
| > 0    | Any      | **REJECT** - Security/critical issues must be fixed |
| 0      | > 5      | **REJECT** - Too many quality issues |
| 0      | 1-5      | **APPROVE** with feedback - Minor issues acceptable |
| 0      | 0        | **APPROVE** - Clean code |

**Exception:** You can approve with 1-2 warnings if:
- They are low-impact (style/documentation)
- Code otherwise meets team standards
- Issue is documented in approval comment

### Step 5: Format Review Comment

Always structure your review comments like this:

```markdown
### 💻 dev — <ISO-timestamp>

**Code Review via CodeRabbit AI**

**Summary:** <X errors, Y warnings, Z info>

**🔴 Critical Issues (must fix):**
- `<file>:<line>` - <issue description>
  Suggestion: <fix recommendation>

**⚠️ Quality Issues:**
- `<file>:<line>` - <issue description>
  Suggestion: <fix recommendation>

**Decision:** <APPROVED | REJECTED>
**Reason:** <brief explanation>

---
*Review powered by CodeRabbit CLI*
```

### Step 6: Update Project Status

**On Approval:**
```bash
# Advance story to qe:verify status
gh issue edit <story-number> --repo "$TEAM_REPO" ...
```

**On Rejection:**
```bash
# Return story to dev:implement status with feedback
gh issue edit <story-number> --repo "$TEAM_REPO" ...
```

## Configuration Options

### Custom Review Standards

**Always use the team's CodeRabbit configuration:**

```bash
coderabbit review --agent --base main \
  --config team/coderabbit.yaml \
  --type committed
```

The team config at `team/coderabbit.yaml` includes:
- Security critical checks (SQL injection, secrets, etc.)
- Performance patterns (N+1 queries, inefficient loops)
- Team-specific conventions (OpenShift, vSphere best practices)
- Code quality thresholds (complexity, function size)
- Testing requirements

You can also add additional invariant files:

```bash
coderabbit review --agent --base main \
  --config team/coderabbit.yaml \
  --config team/invariants/golang-standards.md
```

This applies both team config and specific standards.

### Reviewing Specific Files

If the PR is large, review specific files:

```bash
# Only review changed Go files
git diff --name-only main | grep '\.go$' | xargs coderabbit review --agent --files
```

## Escalation Rules

**Always reject if CodeRabbit finds:**
- Security vulnerabilities (SQL injection, XSS, hardcoded secrets)
- Null pointer/panic risks
- Race conditions or concurrency issues
- Resource leaks (file handles, connections)

**Consider rejecting if CodeRabbit finds:**
- High cyclomatic complexity (>15)
- Poor test coverage for new code
- Violation of team invariants
- Breaking API changes without deprecation

**Acceptable warnings (can approve with feedback):**
- Minor style issues
- Documentation suggestions
- Performance micro-optimizations
- Overly broad error handling

## Error Handling

If CodeRabbit CLI fails:

```bash
# Check authentication
coderabbit auth status

# If auth fails, publish failure event
echo "CodeRabbit auth failed" >&2
ralph tools pubsub publish dev.code_review.failed \
  "payload=CodeRabbit authentication failed - cannot complete review"
```

If no changes to review (empty PR):

```bash
# Check for changes first
if git diff --quiet main..HEAD; then
  echo "No changes to review - approving empty PR"
  # Proceed with approval
fi
```

## Example Complete Review

```bash
#!/bin/bash
set -euo pipefail

STORY_NUM=25
TEAM_REPO="openshift-splat-team/splat-team"

# Load skill
ralph tools skill load coderabbit-review

# Run CodeRabbit review
echo "Running CodeRabbit review..."
coderabbit review --agent --base main --type committed > /tmp/cr-review.json

# Parse findings
ERRORS=$(jq -r '.summary.errors // 0' /tmp/cr-review.json)
WARNINGS=$(jq -r '.summary.warnings // 0' /tmp/cr-review.json)

# Make decision
if [ "$ERRORS" -gt 0 ]; then
  DECISION="REJECTED"
  REASON="CodeRabbit found $ERRORS critical issues that must be fixed"
  NEW_STATUS="dev:implement"
elif [ "$WARNINGS" -gt 5 ]; then
  DECISION="REJECTED"
  REASON="CodeRabbit found $WARNINGS quality issues - please address major concerns"
  NEW_STATUS="dev:implement"
else
  DECISION="APPROVED"
  REASON="Code meets quality standards"
  NEW_STATUS="qe:verify"
fi

# Format findings for comment
FINDINGS=$(jq -r '.findings[] | "- `\(.file):\(.line)` - \(.message)"' /tmp/cr-review.json)

# Post comment
gh issue comment "$STORY_NUM" --repo "$TEAM_REPO" --body "$(cat <<EOF
### 💻 dev — $(date -Iseconds)

**Code Review via CodeRabbit AI**

**Summary:** $ERRORS errors, $WARNINGS warnings

**Findings:**
$FINDINGS

**Decision:** $DECISION
**Reason:** $REASON

---
*Review powered by CodeRabbit CLI*
EOF
)"

# Update status
gh issue edit "$STORY_NUM" --repo "$TEAM_REPO" --status "$NEW_STATUS"

echo "Review complete: $DECISION"
```

## Important Notes

- **Never skip CodeRabbit review** - it's a required step in the review process
- **Always use `--agent` flag** for structured output
- **Document your decision** even if approving - explain why warnings are acceptable
- **Be consistent** with decision criteria - don't approve errors for one PR and reject for another
- **Trust CodeRabbit on security** - if it flags a security issue, investigate thoroughly before approving

## Skill Reference

For detailed CodeRabbit CLI usage, refer to:
```bash
ralph tools skill load coderabbit-review
cat team/coding-agent/skills/coderabbit-review/SKILL.md
```
