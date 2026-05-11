# Objective

Advance all GitHub issues for the assigned project that are ready for action, and respond to human review feedback on any open pull requests associated with the project.

## Required Steps — Every Cycle

**These two steps are mandatory on every iteration, regardless of board state:**

### Step 1: Scan open PRs for human feedback (ALWAYS FIRST)

Before looking at the project board, scan all open PRs in `openshift-splat-team/*`
repos for unaddressed human review comments. Use the `monitor-active-prs` skill:

```bash
ralph tools skill load monitor-active-prs
scan_all_prs
```

- Check ALL open PRs — including those for stories already marked `done` on the board.
- If unaddressed human feedback is found, publish the appropriate feedback event
  (`dev.pr-feedback` or `arch.pr-feedback`) and skip Step 2 for this cycle.
- Do not skip this step even when the board has no actionable items.

### Step 2: Scan the project board and dispatch work

Follow the `board-scanner` skill to scan the GitHub Projects board and dispatch
exactly one event to the appropriate hat.

## Work Scope

Handle all phases of the issue lifecycle:
- Triage and backlog management
- Epic design, planning, and story breakdown
- Story test design and implementation
- Code review and quality verification
- Infrastructure setup
- Documentation
- **Responding to human PR review comments** (even on completed stories)

## Completion Condition

Done when no actionable issues remain and no open PRs have unaddressed human feedback.
An issue is actionable when:
- It belongs to the assigned project (identified by `project/<project-name>` label)
- Its current status indicates work that can be performed now
- It is not waiting on human review or approval
- It is not waiting on another team member

## Work Location

GitHub issues on the team repository, filtered by the assigned project's label.
Open PRs in `openshift-splat-team/*` repos associated with the project.
