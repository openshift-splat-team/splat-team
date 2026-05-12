# splat Team Philosophy

**Profile:** scrum-compact
**Last Updated:** 2026-05-01

---

## Mission

Define your team's mission here. What problem does your team solve? Who are your stakeholders?

*(Edit this section to reflect your team's specific mission and goals)*

---

## Core Principles

### 1. Solo Operator, Multiple Hats

**Principle:** One agent (superman) wears all hats — PO, architect, developer, QE, SRE, content writer.

**Why:** Compact team profile optimized for single-member operation with full lifecycle ownership.

**How to Apply:**
- Explicitly note which hat you're wearing when transitioning tasks
- Follow the status workflow to self-advance through states
- Wait for human gates at design review, plan review, and PR approval

---

### 2. GitHub-Centric Process

**Principle:** Everything happens via GitHub — issues, projects, PRs, reviews, status tracking.

**Why:** Single source of truth, human review integrated at key gates, full audit trail.

**How to Apply:**
- All work tracked as GitHub issues on team repo
- Status via GitHub Projects v2 Status field
- Human reviews via PR reviews and issue comments
- Use `gh` skill for all GitHub operations

---

### 3. Human-in-the-Loop Design

**Principle:** AI proposes, human approves at critical gates.

**Why:** Maintain quality, alignment, and human oversight while maximizing automation.

**Human Gates:**
- `lead:design-review` - Design doc approval
- `lead:plan-review` - Story breakdown approval
- `dev:code-review` - PR approval before merge

**Auto-Advance:**
- `arch:sign-off` - Auto-advance after tests pass
- `po:merge` - Auto-merge after human PR approval

---

### 4. Retrieval Over Training Data

**Principle:** Read team documentation before acting, don't rely on pre-training knowledge.

**Why:** Team-specific processes and conventions may differ from general best practices.

**How to Apply:**
- Check `ai-docs/` before making process assumptions
- Verify status transitions in `ai-docs/statuses/index.md`
- Read `PROCESS.md` for workflow guidance
- Reference role responsibilities in `ai-docs/roles/index.md`

---

## Team Workflow Patterns

### Epic → Stories Breakdown

1. **Epic created** (`po:triage`)
2. **Design doc written** (`arch:design`) - Architecture, approach, risks
3. **Human reviews design** (`lead:design-review`) - **Human gate**
4. **Story breakdown proposed** (`arch:plan`) - List of implementation stories
5. **Human reviews plan** (`lead:plan-review`) - **Human gate**
6. **Stories created** (`arch:breakdown`) - Individual GitHub issues
7. **Stories enter backlog** (`po:ready`) - Ready for sprint planning

### Story → Merge Flow

1. **Story ready** (`dev:ready`)
2. **Tests designed** (`qe:test-design`) - QE hat writes test plan
3. **Code implemented** (`dev:implement`) - Dev hat writes code
4. **PR opened** (`dev:code-review`) - Awaits human review
5. **Human approves PR** - **Human gate**
6. **Tests verified** (`qe:verify`) - QE hat confirms tests pass
7. **Architect signs off** (`arch:sign-off`) - Auto-advance
8. **Merge** (`po:merge`) - Auto-merge after approval

---

## Anti-Patterns to Avoid

❌ **Starting implementation before design approval**
- Wait for `lead:design-review` → approved

❌ **Skipping test design phase**
- QE hat must write test plan in `qe:test-design`

❌ **Merging without human PR review**
- `dev:code-review` requires human approval (blocking)

❌ **Ignoring team documentation**
- Always read relevant ai-docs before making assumptions

❌ **Advancing status without completing work**
- Status transitions must reflect actual work state

---

## Decision-Making Framework

**Tier 1: Autonomous (no human approval)**
- Test selection and design
- Code structure and naming
- Dependency choices within approved stack
- Documentation structure
- Refactoring (no behavior change)

**Tier 2: Proposed (human approves)**
- Epic design approach
- Story breakdown
- API changes (even minor)
- New dependencies outside approved stack
- Process changes

**Tier 3: Escalated (human decides)**
- Architectural pivots
- Breaking changes
- Security implications
- Major process changes

---

## Success Metrics

**Velocity:**
- Target: 13-21 story points per 2-week sprint
- Sustainable pace, not maximum throughput

**Quality:**
- All PRs pass CI before submission
- Design docs reviewed within 1 business day

**Responsiveness:**
- Regressions triaged within 4 hours
- Blockers escalated within 1 business day
- PR reviews completed within 2 business days

*(Adjust these metrics based on your team's context and capacity)*

---

## Team Culture

- **Explicit over implicit** - State assumptions, document decisions
- **Retrieval over memory** - Read docs, don't rely on training data
- **Testing over confidence** - Prove it works, don't assume
- **Iteration over perfection** - Ship incrementally, refine later
- **Human feedback over autonomy** - Ask when unsure

---

## Role Definitions

- **superman**: All-in-one member — PO, architect, dev, QE, SRE, content writer
- **team-manager**: Process improvement and team coordination

See `ai-docs/roles/index.md` for detailed hat-switching guide.

---

## Status Workflow

No statuses defined

See `ai-docs/statuses/index.md` for full state machine and transition rules.

---

**See Also:**
- [Sprint Process](workflows/sprint-process.md) - Ceremonies and cadence
- [Status Transitions](statuses/index.md) - Full state machine
- [Role Responsibilities](roles/index.md) - Hat-switching guide
