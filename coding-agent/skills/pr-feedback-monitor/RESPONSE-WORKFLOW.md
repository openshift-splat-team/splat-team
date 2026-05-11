# PR Feedback Response Workflow

## Golden Rule

**For EVERY feedback item, follow this 3-step pattern:**

1. **Comment: Acknowledge** - "Working on this"
2. **Action: Make changes** (if code changes needed)
3. **Comment: Report completion** - "Done, here's what changed"

## Decision Tree: Code Change vs Comment-Only

```
Feedback Received
    ↓
Is this a QUESTION/CLARIFICATION?
    ↓
YES → Comment-only response (no code changes)
 │
 └─→ Reply with explanation
     "Great question! Here's why..."
     DO NOT make code changes unless explicitly requested

NO → This is a CHANGE REQUEST
 ↓
Follow 3-step pattern:
 1. Comment: "Working on this now"
 2. Make code changes
 3. Comment: "Done! Here's the summary..."
```

## Response Templates

### Template 1: Question/Clarification (Comment-Only)

**Triggers:**
- "Why...?"
- "Can you explain...?"
- "Have you considered...?"
- "What about...?"
- "Is there a reason...?"

**Response:**
```bash
gh pr comment "$PR_NUM" --repo "$PROJECT_REPO" --body "$(cat <<EOF
@reviewer, great question!

**Q:** Why did we use approach X instead of Y?

**A:** We chose X because:
- Reason 1
- Reason 2
- Constraint that made Y unsuitable

Let me know if you'd like me to add this explanation as a code comment!

---
*Response by superman-atlas*
EOF
)"
```

**DO NOT make code changes** unless reviewer explicitly asks for them.

---

### Template 2: Code Change Request (3-Step)

**Triggers:**
- "Add..."
- "Fix..."
- "Change..."
- "Remove..."
- "Update..."
- "Improve..."

**Step 1: Acknowledge (immediate)**
```bash
gh pr comment "$PR_NUM" --repo "$PROJECT_REPO" --body "$(cat <<EOF
@reviewer, working on this now.

**Planned changes:**
- ${CHANGE_1}
- ${CHANGE_2}
- ${CHANGE_3}

ETA: ~15 minutes. I'll update when done.

---
*Working on it - superman-atlas*
EOF
)"
```

**Step 2: Make changes**
```bash
# Make the actual code changes
# ...

git add <changed-files>
git commit -m "${COMMIT_MESSAGE}

Reviewer: @${REVIEWER}"
git push
```

**Step 3: Report completion (required)**
```bash
gh pr comment "$PR_NUM" --repo "$PROJECT_REPO" --body "$(cat <<EOF
@reviewer, changes complete! ✅

**Summary:**
- ✅ ${CHANGE_1_COMPLETED}
- ✅ ${CHANGE_2_COMPLETED}
- ✅ ${CHANGE_3_COMPLETED}

**Commits:**
- \`$(git rev-parse --short HEAD)\` - ${COMMIT_SUBJECT}

**Files changed:**
$(git diff --stat HEAD~1..HEAD | head -10)

**Test results:**
$(run-tests-and-show-results)

Ready for re-review!

---
*Changes complete - superman-atlas*
EOF
)"
```

---

### Template 3: Security Issue (Urgent 3-Step)

**Triggers:**
- "Security vulnerability"
- "Hardcoded secret"
- "SQL injection"
- "XSS"
- Any security-related feedback

**Step 1: Immediate acknowledgment**
```bash
gh pr comment "$PR_NUM" --repo "$PROJECT_REPO" --body "🔒 @reviewer, addressing this security issue immediately. ETA: 15 minutes."
```

**Step 2: Fix immediately (highest priority)**
```bash
# Fix security issue
git add <files>
git commit -m "security: Fix ${VULNERABILITY}

${DETAILED_FIX_DESCRIPTION}

Reviewer: @${REVIEWER}
Security-Review: Required"
git push
```

**Step 3: Detailed report**
```bash
gh pr comment "$PR_NUM" --repo "$PROJECT_REPO" --body "$(cat <<EOF
🔒 @reviewer, security issue fixed! ✅

**Vulnerability:** ${VULN_NAME}
**Severity:** ${SEVERITY}

**Fix applied:**
- ✅ ${FIX_1}
- ✅ ${FIX_2}

**Security tests added:**
- ${TEST_1}
- ${TEST_2}

**Verification:**
\`\`\`
${SECURITY_TEST_RESULTS}
\`\`\`

**Commit:** \`$(git rev-parse --short HEAD)\`

This is a critical fix. Please prioritize re-review.

---
*Security fix complete - superman-atlas*
EOF
)"
```

---

### Template 4: Test Coverage Request (3-Step)

**Step 1: Acknowledge**
```bash
gh pr comment "$PR_NUM" --repo "$PROJECT_REPO" --body "$(cat <<EOF
@reviewer, adding test coverage for:
- ${SCENARIO_1}
- ${SCENARIO_2}

Writing tests now...

---
*Adding tests - superman-atlas*
EOF
)"
```

**Step 2: Add tests**
```bash
# Write tests
git add <test-files>
git commit -m "test: Add coverage for ${SCENARIOS}

Reviewer: @${REVIEWER}"
git push
```

**Step 3: Report with coverage stats**
```bash
gh pr comment "$PR_NUM" --repo "$PROJECT_REPO" --body "$(cat <<EOF
@reviewer, test coverage added! ✅

**New tests:**
- \`${TEST_1_NAME}\` - ${TEST_1_PURPOSE}
- \`${TEST_2_NAME}\` - ${TEST_2_PURPOSE}

**Coverage:**
- Before: ${OLD_COV}%
- After: ${NEW_COV}% (+${DELTA}%)

**Test results:**
\`\`\`
${TEST_OUTPUT}
\`\`\`

All tests passing! ✅

---
*Tests complete - superman-atlas*
EOF
)"
```

---

### Template 5: Documentation Request (3-Step)

**Step 1: Acknowledge**
```bash
gh pr comment "$PR_NUM" --repo "$PROJECT_REPO" --body "@reviewer, adding documentation now."
```

**Step 2: Add docs**
```bash
# Add/update documentation
git add <doc-files>
git commit -m "docs: ${DOC_CHANGES}

Reviewer: @${REVIEWER}"
git push
```

**Step 3: Report with examples**
```bash
gh pr comment "$PR_NUM" --repo "$PROJECT_REPO" --body "$(cat <<EOF
@reviewer, documentation added! ✅

**Updates:**
- ✅ ${DOC_UPDATE_1}
- ✅ ${DOC_UPDATE_2}

**Example:**
\`\`\`${LANGUAGE}
${CODE_EXAMPLE_WITH_DOCS}
\`\`\`

---
*Documentation complete - superman-atlas*
EOF
)"
```

---

## Key Principles

### 1. **Always Comment First**
Before making any code change, post a comment saying you're working on it.

### 2. **Always Comment Last**
After making code changes, post a summary of what was done.

### 3. **Question? Comment-Only**
If it's a question or clarification request, ONLY comment - do NOT make code changes unless explicitly requested.

### 4. **Change Request? 3-Step Pattern**
If it's a change request:
1. Comment: "Working on it"
2. Make changes
3. Comment: "Done! Here's what changed"

### 5. **Include Details in Summary**
The completion comment should always include:
- ✅ What was changed (checklist)
- Commit hash and message
- Files changed (diff stat)
- Test results (if applicable)

### 6. **Request Re-Review**
After completing changes, always end with "Ready for re-review!" and use `gh pr edit --add-reviewer` to request re-review.

## Example: Complete Response

**Reviewer comment:**
> "Add error handling for the nil credentials case. Also, can you explain why we're using a mutex here?"

**Superman response (recognizes 2 items: 1 change request + 1 question):**

**Comment 1: Acknowledge change request**
```
@reviewer, working on adding error handling for nil credentials now.

Planned change:
- Add validation at the start of ProcessCredentials()
- Return descriptive error if credentials are nil

ETA: 10 minutes.

---
Working on it - superman-atlas
```

**Comment 2: Answer question (separate comment)**
```
@reviewer, great question about the mutex!

Q: Why use a mutex here?

A: We use a mutex to protect the credentialCache map because:
- Multiple goroutines can call ProcessCredentials() concurrently
- Go maps are not safe for concurrent read/write
- Without the mutex, we'd have a race condition

The mutex ensures that only one goroutine can modify the cache at a time.

Let me know if you'd like me to add this explanation as a code comment!

---
Response by superman-atlas
```

**Action: Make code change**
```bash
git add pkg/credentials.go
git commit -m "fix: Add nil check for credentials

- Validate credentials are not nil at function entry
- Return descriptive error message
- Add test case for nil input

Reviewer: @human-reviewer"
git push
```

**Comment 3: Report completion**
```
@reviewer, nil check added! ✅

Summary:
- ✅ Added validation at start of ProcessCredentials()
- ✅ Returns error: "credentials cannot be nil"
- ✅ Added test: TestProcessCredentialsNil

Commits:
- `a1b2c3d` - fix: Add nil check for credentials

Files changed:
 pkg/credentials.go      | 4 ++++
 pkg/credentials_test.go | 8 ++++++++
 2 files changed, 12 insertions(+)

Test results:
PASS: TestProcessCredentialsNil (0.01s)

Ready for re-review!

---
Changes complete - superman-atlas
```

**Total: 3 comments**
1. Acknowledge change request
2. Answer clarification question (no code change)
3. Report completion

This provides full transparency and keeps the reviewer informed! ✅
