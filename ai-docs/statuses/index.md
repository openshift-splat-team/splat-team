# splat Status Workflow

**Profile:** scrum-compact

---

## Overview

The splat team uses GitHub Projects v2 Status field to track work progression through defined states.

Statuses follow a prefix convention: `<role>:<state>`, indicating which role is responsible for the work.

---

## All Statuses

No statuses defined

---

## Status Categories

### Epic Statuses

**Lifecycle for `kind/epic` issues:**

```
po:triage → po:backlog → arch:design → lead:design-review →
arch:plan → lead:plan-review → arch:breakdown → po:ready →
arch:in-progress → po:accept → done
```

**Key gates:**
- **Human gates:** `lead:design-review`, `lead:plan-review`
- **Auto-advance:** After human approval

---

### Story Statuses

**Lifecycle for `kind/story` issues:**

```
dev:ready → qe:test-design → dev:implement → dev:code-review →
qe:verify → arch:sign-off → po:merge → done
```

**Key gates:**
- **Human gate:** `dev:code-review` (PR approval)
- **Auto-advance:** `arch:sign-off`, `po:merge`

---

### Specialist Statuses

**SRE workflow:**
```
sre:infra-setup → done
```

**Content Writer workflow:**
```
cw:write → cw:review → cw:merge-ready → done
```

**Team Manager workflow:**
```
mgr:todo → mgr:in-progress → mgr:done
```

---

## Status Transition Rules

### Epic Transitions

**po:triage** → New epic awaiting evaluation
- ✅ Can advance to: `po:backlog` (accepted), `done` (rejected)
- 👤 Who: PO hat
- 🎯 Action: Evaluate priority and scope

**po:backlog** → Accepted, prioritized, awaiting activation
- ✅ Can advance to: `arch:design`
- 👤 Who: PO hat activates when ready
- 🎯 Action: Move to active work

**arch:design** → Architect producing design doc
- ✅ Can advance to: `lead:design-review`
- 👤 Who: Architect hat
- 🎯 Action: Write design document in issue

**lead:design-review** → **HUMAN GATE** - Design doc awaiting lead review
- ✅ Can advance to: `arch:plan` (approved), `arch:design` (changes requested)
- 👤 Who: **Human reviewer**
- 🎯 Action: Review and approve/reject design

**arch:plan** → Architect proposing story breakdown
- ✅ Can advance to: `lead:plan-review`
- 👤 Who: Architect hat
- 🎯 Action: Propose list of stories with estimates

**lead:plan-review** → **HUMAN GATE** - Story breakdown awaiting lead review
- ✅ Can advance to: `arch:breakdown` (approved), `arch:plan` (changes requested)
- 👤 Who: **Human reviewer**
- 🎯 Action: Review and approve/reject breakdown

**arch:breakdown** → Architect creating story issues
- ✅ Can advance to: `po:ready`
- 👤 Who: Architect hat
- 🎯 Action: Create GitHub issues for each story

**po:ready** → Stories created, epic in ready backlog
- ✅ Can advance to: `arch:in-progress`
- 👤 Who: PO hat (when stories start)
- 🎯 Action: Monitor story progress

**arch:in-progress** → Architect monitoring story execution
- ✅ Can advance to: `po:accept`
- 👤 Who: Architect hat
- 🎯 Action: All stories completed

**po:accept** → **HUMAN GATE** - Epic awaiting human acceptance
- ✅ Can advance to: `done` (accepted)
- 👤 Who: **Human stakeholder**
- 🎯 Action: Validate epic completion

---

### Story Transitions

**dev:ready** → Story ready for development
- ✅ Can advance to: `qe:test-design`
- 👤 Who: Developer hat picks up work
- 🎯 Action: Understand story requirements

**qe:test-design** → QE designing tests
- ✅ Can advance to: `dev:implement`
- 👤 Who: QE hat
- 🎯 Action: Design test plan and criteria

**dev:implement** → Developer implementing
- ✅ Can advance to: `dev:code-review`
- 👤 Who: Developer hat
- 🎯 Action: Write code, tests, open PR

**dev:code-review** → **HUMAN GATE** - Code review
- ✅ Can advance to: `qe:verify` (approved), `dev:implement` (changes requested)
- 👤 Who: **Human reviewer**
- 🎯 Action: Review PR, approve or request changes

**qe:verify** → QE verifying implementation
- ✅ Can advance to: `arch:sign-off`
- 👤 Who: QE hat
- 🎯 Action: Verify tests pass, acceptance criteria met

**arch:sign-off** → Architect sign-off (auto-advance)
- ✅ Can advance to: `po:merge`
- 👤 Who: Architect hat
- 🎯 Action: Auto-advance if no concerns

**po:merge** → Merge gate (auto-advance)
- ✅ Can advance to: `done`
- 👤 Who: PO hat
- 🎯 Action: Merge PR, close story

---

## Special Statuses

**done** → Complete
- Final state for all work items
- No further transitions

**error** → Issue failed processing 3 times
- Requires human intervention
- Investigate processing failure

---

## Human Gates

**CRITICAL:** Never advance past these statuses without human approval:
- `lead:design-review` - Human must approve design
- `lead:plan-review` - Human must approve story breakdown
- `dev:code-review` - Human must approve PR

**These are blocking gates.** Work cannot proceed until human reviews and approves.

---

## Auto-Advance Statuses

These statuses can auto-advance after validation:
- `arch:sign-off` - After tests pass and verification complete
- `po:merge` - After human PR approval

---

## Status Workflow Best Practices

**1. Never skip statuses**
- Follow the defined workflow
- Each status represents required work

**2. Respect human gates**
- Wait for human approval at `lead:*` and `dev:code-review`
- Don't try to auto-advance

**3. Status reflects current work**
- Advance status when entering new phase
- Don't advance prematurely

**4. Use hat matching status prefix**
- `arch:*` → Architect hat
- `dev:*` → Developer hat
- `qe:*` → QE hat
- `po:*` → PO hat

**5. Comment when advancing status**
- Explain what was completed
- Note any concerns or blockers

---

## Common Status Questions

**What if I'm blocked in a status?**
- Add `blocked` label
- Comment with blocker details
- Don't advance status
- Escalate if blocker > 1 day

**What if human gate is delayed?**
- Escalate via direct message
- Work on other items
- Don't advance status without approval

**Can I go backwards in status?**
- Yes, if changes are requested
- Example: `lead:design-review` → `arch:design` (changes needed)

**What if tests fail?**
- Stay in `dev:implement` until fixed
- Don't advance to `dev:code-review` with failing tests

---

**See Also:**
- [Sprint Process](../workflows/sprint-process.md) - How status fits into sprints
- [Role Responsibilities](../roles/index.md) - Hat-switching details
- [Team Philosophy](../TEAM_PHILOSOPHY.md) - Core principles
