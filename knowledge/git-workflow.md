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
```

**When to push:**
- Immediately after creating the design document (before moving to lead:design-review)
- After revisions (if design is rejected and revised)

**Review workflow:**
- Design doc lives on branch during review phases (lead:design-review, po:design-review)
- Operators review via GitHub web UI or by checking out the branch
- Once approved and stories are created, merge the branch to main

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

- **Design branches:** Merge to main after epic approval (po:design-review → arch:plan transition)
- **Story branches:** Merge via PR after code review and tests pass
- **Always:** Use merge commits (not squash) to preserve co-authorship
