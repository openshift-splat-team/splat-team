---
name: CodeRabbit Code Review
description: AI-powered code review using CodeRabbit CLI for structured findings
---

# CodeRabbit Code Review

Use CodeRabbit AI to review code changes and provide structured feedback for code quality, security, performance, and best practices.

## When to Use This Skill

Use this skill when:
- Reviewing code changes before merging
- Conducting self-review as the `dev_code_reviewer` hat
- Checking for security vulnerabilities, bugs, or anti-patterns
- Validating code quality against team standards

## Prerequisites

1. **CodeRabbit CLI** must be installed and authenticated:
   ```bash
   coderabbit auth status
   ```

2. **Git repository** with changes to review (committed or uncommitted)

## Usage

### Basic Review (All Changes)

```bash
coderabbit review --agent
```

This reviews all local changes (committed and uncommitted) and outputs structured JSON findings suitable for agent processing.

### Review Specific Files

```bash
coderabbit review --agent --files src/api.go src/handlers.go
```

### Review Against Base Branch

```bash
coderabbit review --agent --base main
```

Reviews all changes on the current branch compared to `main`.

### Review Only Committed Changes

```bash
coderabbit review --agent --type committed
```

### Review with Custom Instructions

```bash
coderabbit review --agent --config team/invariants/code-standards.md
```

Provide additional context or standards for CodeRabbit to apply during review.

## Output Format

The `--agent` flag emits structured JSON with the following format:

```json
{
  "findings": [
    {
      "severity": "error",
      "category": "security",
      "file": "src/api.go",
      "line": 42,
      "message": "SQL injection vulnerability detected",
      "suggestion": "Use parameterized queries instead of string concatenation"
    },
    {
      "severity": "warning",
      "category": "performance",
      "file": "src/handlers.go",
      "line": 78,
      "message": "N+1 query detected in loop",
      "suggestion": "Use batch loading or eager loading to reduce database calls"
    }
  ],
  "summary": {
    "total_findings": 12,
    "errors": 2,
    "warnings": 7,
    "info": 3
  }
}
```

## Integration with dev_code_reviewer Hat

When wearing the `dev_code_reviewer` hat:

1. **Run CodeRabbit review** on the current branch/changes
   ```bash
   coderabbit review --agent --base main
   ```

2. **Parse the JSON output** and extract findings

3. **Categorize findings** by severity:
   - **Errors**: Must fix before approval (security, bugs, critical issues)
   - **Warnings**: Should fix (performance, code quality, maintainability)
   - **Info**: Nice to have (style, documentation, suggestions)

4. **Make review decision**:
   - **Approve** if no errors and warnings are acceptable
   - **Reject** if errors exist or warnings violate team standards
   - **Provide feedback** with specific file/line references from CodeRabbit findings

5. **Format feedback comment** referencing CodeRabbit findings:
   ```markdown
   ### 💻 dev — <timestamp>

   **Code review findings (via CodeRabbit AI)**

   **🔴 Errors (must fix):**
   - `src/api.go:42` - SQL injection vulnerability
   - `src/auth.go:156` - Unhandled error could cause panic

   **⚠️ Warnings (should address):**
   - `src/handlers.go:78` - N+1 query performance issue
   - `src/utils.go:23` - Function too complex (cyclomatic complexity 15)

   **Recommendation:** Rejected - fix security issues before re-review.
   ```

## Best Practices

- **Always use `--agent` flag** for structured output when used by automation
- **Review against base branch** (`--base main`) to see only changes introduced by the PR
- **Provide context** via `--config` when reviewing against specific team standards
- **Focus on actionable feedback** - prioritize errors and high-impact warnings
- **Combine with manual review** - CodeRabbit flags issues but human judgment is needed for approval decisions

## Example Workflow

```bash
# Step 1: Review current branch against main
coderabbit review --agent --base main > /tmp/review.json

# Step 2: Parse findings
cat /tmp/review.json | jq '.findings[] | select(.severity == "error")'

# Step 3: Make decision based on findings count
ERROR_COUNT=$(cat /tmp/review.json | jq '.summary.errors')
if [ "$ERROR_COUNT" -gt 0 ]; then
  echo "Rejecting: $ERROR_COUNT errors found"
else
  echo "Approving: No errors found"
fi
```

## Troubleshooting

- **"Not authenticated"**: Run `coderabbit auth login` and follow prompts
- **"No changes to review"**: Ensure you have uncommitted or committed changes
- **Rate limiting**: CodeRabbit may rate limit on large reviews - review specific files if needed
- **Slow reviews**: CodeRabbit AI takes time for large changesets - be patient

## Notes

- CodeRabbit requires network access (calls AI APIs)
- Reviews are not cached - each invocation makes fresh API calls
- CodeRabbit respects `.gitignore` and common ignore patterns
- For best results, review changes in small batches rather than large PRs
