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
- Design doc lives on branch during review phases (lead:design-review, po:design-review)
- Operators review via GitHub PR interface (inline comments, suggestions, approval)
- Incorporate feedback via additional commits to the same branch
- Once approved, merge the PR and advance to arch:plan
- Comment on epic issue with PR link for traceability

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

## Merge Strategy

- **Design PRs:** Merge to main after human approval (po:design-review → arch:plan transition). Use "Merge commit" to preserve co-authorship. Architect can proceed with story planning once PR is merged.
- **Story PRs:** Merge via PR after code review and tests pass. Use "Merge commit" to preserve co-authorship.
- **Always:** Use merge commits (not squash or rebase) to preserve co-authorship and commit history
