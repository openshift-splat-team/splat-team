# PR Review Monitoring for Design Reviews

## Context

When epics are in `lead:design-review` or `po:design-review` status, the associated design PR must be actively monitored for human feedback.

**Important:** The PR author may be the bot account (rvanderp3), so humans cannot use GitHub's "Request changes" feature. Therefore, **inline comments are the primary feedback mechanism.**

## What to Check

When checking a design PR for review feedback, check for **inline review comments first**, then formal review state.

### 1. Inline Review Comments (Primary Signal)

Check for inline comments on specific lines:

```bash
gh api repos/{owner}/{repo}/pulls/{pr_number}/comments
```

**If any inline comments exist from the PR author (human operator):**
- These are actionable feedback even without formal "Request changes" state
- Read all comments
- Address each comment by updating the design document
- Reply to each comment explaining what changed
- Push updates to the PR branch

### 2. Review State (Secondary Signal)

Check the PR's review decision:

```bash
gh pr view {pr_number} --json reviewDecision,reviews
```

States:
- `APPROVED` — Ready to merge and advance epic
- `CHANGES_REQUESTED` — Must address (only from non-author reviewers)
- Empty or `REVIEW_REQUIRED` — Check for inline comments

## Processing Inline Comments

**Treat inline comments as equivalent to "Request changes".**

When inline comments exist on a design PR:

1. **Recognize as actionable feedback** — Don't wait for formal review state
2. **Check out the design branch**
3. **Address each comment** in the design document
4. **Commit with clear description** of what changed
5. **Push to update the PR**
6. **Reply to each comment** explaining the changes made

**Example workflow:**

```bash
# Check for inline comments
COMMENTS=$(gh api repos/openshift-splat-team/splat-team/pulls/15/comments --jq '. | length')

if [ "$COMMENTS" -gt 0 ]; then
  echo "Found inline review comments - addressing feedback"
  
  # Get comment details
  gh api repos/openshift-splat-team/splat-team/pulls/15/comments --jq \
    '.[] | "Line \(.line) (\(.path)): \(.body)"'
  
  # Get PR branch
  BRANCH=$(gh pr view 15 --json headRefName -q .headRefName)
  
  # Check out branch
  git checkout "$BRANCH"
  
  # Update design doc to address each comment
  # (Read comments, make changes to design doc)
  
  # Commit and push
  git add projects/installer/knowledge/designs/*.md
  git commit -m "Address PR review feedback

- [Line X]: Addressed feedback about Y
- [Line Z]: Clarified A based on comment

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
  git push
  
  # Reply to each comment individually
  for comment_id in $(gh api repos/openshift-splat-team/splat-team/pulls/15/comments --jq '.[].id'); do
    gh api -X POST "repos/openshift-splat-team/splat-team/pulls/comments/$comment_id/replies" \
      -f body="Addressed in latest commit - see changes above"
  done
fi
```

## When to Consider Design Approved

A design PR is approved when:

1. **Formal approval exists** (`reviewDecision: APPROVED`), OR
2. **All inline comments have been addressed** AND human leaves a comment like:
   - "Approved" 
   - "LGTM"
   - "looks good"
   - "Ship it"

## Integration with Review Gates

When `po_reviewer` or `lead_reviewer` hats check design review gates:

1. Check epic issue for design PR link
2. **First, check for inline comments** (primary feedback mechanism)
   - If comments exist: Dispatch to `arch` hat to address them
   - Return to coordinator after addressing
3. **Then, check review decision**
   - If `APPROVED`: Merge PR and advance epic to `arch:plan`
   - If `CHANGES_REQUESTED`: Dispatch to `arch` to address
   - If neither: Check issue comments for text approval
4. If no feedback found anywhere: Return to coordinator (non-blocking gate)

## Rationale

**Why inline comments without formal review state?**

- PR author is the bot account (rvanderp3)
- Human operators cannot use "Request changes" on their own PRs
- Inline comments are the natural way for operators to provide feedback
- Waiting for formal state would block the workflow unnecessarily

**Why respond to each comment individually?**

- Shows which feedback was addressed
- Allows threaded discussion if needed
- Makes review iteration transparent
