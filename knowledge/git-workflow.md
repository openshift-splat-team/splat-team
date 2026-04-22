# Git Workflow Conventions

## Branch Strategy for Epic Work

**Context:** The team operates with BotMinter running as a daemon on a server. Operators review work via GitHub, not local file access.

### Design Phase Branching

When creating design documents for epics, **always create a feature branch and push immediately** so operators can review via GitHub.

**Branch naming:** `epic-<issue-number>-design`

**Example workflow:**

```bash
# In arch:design phase
git checkout -b epic-14-design
git add projects/installer/knowledge/designs/epic-14.md
git commit -m "Add <epic-title> design

Design doc for epic #<number>
- Key point 1
- Key point 2
- Key point 3

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
git push -u origin epic-14-design

# Create PR for review
gh pr create --head epic-14-design --base main \
  --title "Design: <epic-title> (Epic #<number>)" \
  --body "Design review for epic #<number>
  
Issue: https://github.com/<org>/<repo>/issues/<number>
Status: po:design-review

[Include design summary, key elements, acceptance criteria]

Please review and approve to advance to story planning."
```

**When to create PR:**
- Immediately after pushing the design branch (before moving to lead:design-review)
- Include link to epic issue in PR body
- Summarize key design elements for quick review

**Review workflow:**

Design PRs follow an iterative review cycle:

1. **Initial review:** Superman creates PR and waits in `lead:design-review` or `po:design-review` status
2. **Human feedback:** Operator leaves PR review comments (inline comments, review comments, or "Request changes")
3. **Superman addresses feedback:**
   - Monitors PR for new comments or review requests
   - Checks out the design branch
   - Updates design doc to address each comment
   - Commits changes with descriptive message
   - Pushes to same branch (updates PR automatically)
   - Replies to each PR comment indicating what was changed
4. **Iteration:** Repeat steps 2-3 until human approves
5. **Approval:** Once PR is approved, superman merges and advances epic to `arch:plan`

**How to provide feedback:**
- Add **inline comments** on specific lines for targeted feedback
- Use **review comments** for general feedback
- Click **"Request changes"** to formally request revisions
- Click **"Approve"** when design is ready to advance

**Superman monitors for:**
- New PR comments (inline or review-level)
- "Request changes" review status
- "Approved" review status

**No special commands needed** — just use GitHub's native PR review tools. Superman will automatically detect and address your feedback.

### Story Implementation Branching

For individual stories, follow standard feature branch workflow:

**Branch naming:** `story-<issue-number>-<short-description>`

**Example:**
```bash
git checkout -b story-42-installer-credential-validation
# ... implement changes ...
git push -u origin story-42-installer-credential-validation
# Create PR for review
```

### Rationale

**Why branch per epic design:**
- Operators cannot access local files on daemon servers
- GitHub provides better diff/review UX than comment threads
- Preserves design evolution history
- Enables concurrent epic design work without conflicts

**Why push immediately:**
- Design docs are ready for human review
- No value in keeping them local
- Reduces operator wait time
- Makes workflow transparent

## PR Monitoring for Design Reviews

When an epic is in `lead:design-review` or `po:design-review` status, actively monitor the associated design PR for feedback.

**Check for feedback:**
```bash
# Get PR number from epic issue or branch name
gh pr view <pr-number> --json reviews,comments

# Check for unresolved review comments
gh pr view <pr-number> --json reviewDecision
```

**If feedback exists:**
1. Read all PR comments and review feedback
2. Checkout the design branch: `git checkout epic-<number>-design`
3. Update the design document to address each comment
4. Commit with clear description of changes
5. Push to update the PR: `git push`
6. Reply to each PR comment explaining what changed
7. Request re-review if needed: `gh pr review <pr-number> --request-review`

**If PR is approved:**
1. Merge the PR: `gh pr merge <pr-number> --merge --delete-branch`
2. Update epic status from `po:design-review` to `arch:plan`
3. Comment on epic issue confirming design approval and next phase

**Example addressing feedback:**
```bash
git checkout epic-14-design
# ... update design doc based on PR comments ...
git add projects/installer/knowledge/designs/epic-14.md
git commit -m "Address PR feedback: clarify credential rotation workflow

- Expanded section on zero-downtime rotation
- Added sequence diagram for credential validation
- Clarified rollback procedure

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
git push

# Reply to each PR comment
gh pr comment <pr-number> --body "Updated design doc to address this feedback - see latest commit"
```

## Merge Strategy

- **Design PRs:** Merge to main after human approval (po:design-review → arch:plan transition). Use "Merge commit" to preserve co-authorship. Architect can proceed with story planning once PR is merged.
- **Story PRs:** Merge via PR after code review and tests pass. Use "Merge commit" to preserve co-authorship.
- **Always:** Use merge commits (not squash or rebase) to preserve co-authorship and commit history
