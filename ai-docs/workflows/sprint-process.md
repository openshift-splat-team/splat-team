# splat Sprint Process

**Profile:** scrum-compact

---

## Overview

The splat team follows a lightweight sprint process adapted for the scrum-compact profile.

**Sprint Length:** 2 weeks
**Planning:** Start of sprint
**Review/Retro:** End of sprint

---

## Sprint Ceremonies

### Sprint Planning

**When:** First day of sprint
**Duration:** 1-2 hours
**Goal:** Commit to work for the sprint

**Process:**
1. Review sprint goal
2. Select stories from `po:ready` backlog
3. Move stories to `dev:ready`
4. Estimate story points
5. Commit to sprint scope (13-21 points target)

**Status Transitions:**
- Stories: `po:ready` → `dev:ready`

---

### Daily Standup (Async)

**When:** Daily
**Format:** GitHub issue comments or team channel

**Focus:**
- Progress since yesterday
- Plan for today
- Blockers or risks

**For Solo Teams:**
- Brief status update to stakeholders
- Note any blockers needing escalation

---

### Sprint Review

**When:** Last day of sprint
**Duration:** 1 hour
**Goal:** Demonstrate completed work

**Process:**
1. Demo completed stories
2. Show merged PRs
3. Highlight achievements
4. Collect feedback

**Acceptance:**
- Stories must be in `done` status
- All PRs merged
- Tests passing

---

### Sprint Retrospective

**When:** After sprint review
**Duration:** 30-60 minutes
**Goal:** Process improvement

**Format:**
- What went well?
- What could improve?
- Action items for next sprint

**For Solo Teams:**
- Self-reflection on process
- Identify process improvements
- Update team documentation

---

## Epic Breakdown Flow

### Phase 1: Design

**Status:** `arch:design`

1. Write design document in epic issue
2. Include:
   - Problem statement
   - Proposed approach
   - Architectural implications
   - Risks and mitigations
   - Success criteria

**Deliverable:** Design doc in epic description or linked document

---

### Phase 2: Design Review

**Status:** `lead:design-review`

**Human gate:** Awaiting human approval

**Review criteria:**
- Approach aligns with architecture
- Risks identified and mitigated
- Success criteria clear
- Stakeholder sign-off

**Outcomes:**
- ✅ Approved → `arch:plan`
- ⛔ Changes requested → back to `arch:design`

---

### Phase 3: Story Breakdown

**Status:** `arch:plan` → `lead:plan-review` → `arch:breakdown`

1. **Propose breakdown** (`arch:plan`)
   - List individual stories
   - Estimate story points
   - Define acceptance criteria per story

2. **Human reviews breakdown** (`lead:plan-review`)
   - Verify stories are appropriate size
   - Check acceptance criteria
   - Approve or request changes

3. **Create story issues** (`arch:breakdown`)
   - Create GitHub issues for each story
   - Link to parent epic
   - Add labels (`kind/story`, etc.)
   - Set acceptance criteria

**Deliverable:** Individual story issues in `po:ready` status

---

## Story Implementation Flow

### Phase 1: Test Design

**Status:** `qe:test-design`

**QE hat:**
1. Design test plan
2. Identify test cases (happy path, edge cases, errors)
3. Define test criteria
4. Document in issue comments

---

### Phase 2: Implementation

**Status:** `dev:implement`

**Dev hat:**
1. Create feature branch
2. Write code
3. Write tests (based on QE test plan)
4. Ensure tests pass locally
5. Push branch

---

### Phase 3: Code Review

**Status:** `dev:code-review`

**Human gate:** Awaiting PR approval

1. Open PR against main branch
2. Request human review
3. CI must pass
4. Address review feedback

**Outcomes:**
- ✅ Approved → `qe:verify`
- ⛔ Changes requested → stay in `dev:code-review`

---

### Phase 4: Verification

**Status:** `qe:verify` → `arch:sign-off` → `po:merge`

1. **QE verification** (`qe:verify`)
   - QE hat confirms tests pass
   - Verify acceptance criteria met
   - Check for regressions

2. **Architect sign-off** (`arch:sign-off`)
   - Auto-advance if tests pass
   - Verify no architectural concerns

3. **Merge** (`po:merge`)
   - Auto-merge after approval
   - Close story issue

**Deliverable:** Merged PR, story in `done` status

---

## Status Workflow Summary

### Epic States

No statuses defined

---

## Working with Multiple Hats

**When you switch hats, explicitly state it:**

> "Switching to QE hat: Designing test plan for story #123"

> "Dev hat: Implementing feature X"

> "PO hat: Triaging new epic"

**Why:** Clarity about current role and responsibilities

---

## Sprint Metrics

**Velocity:**
- Track story points completed per sprint
- Target: 13-21 points per 2-week sprint

**Quality:**
- PR approval time
- Test pass rate
- Regression rate

**Cycle Time:**
- Time from `dev:ready` to `done`
- Target: < 3 days for small stories

---

## Common Patterns

**Epic too large?**
- Break into multiple smaller epics
- Create epic parent-child relationships

**Story blocked?**
- Add `blocked` label
- Comment with blocker details
- Escalate if blocker > 1 day

**Human gate delayed?**
- Escalate via direct message
- Continue with other work
- Don't advance status prematurely

**Tests failing?**
- Stay in `dev:implement` until tests pass
- Don't open PR with failing tests

---

**See Also:**
- [Team Philosophy](../TEAM_PHILOSOPHY.md) - Core principles
- [Status Index](../statuses/index.md) - Full state machine
- [Role Responsibilities](../roles/index.md) - Hat-switching details
