# Role Responsibilities - Hat-Switching Guide

**Team:** Splat Team  
**Profile:** scrum-compact  
**Last Updated:** 2026-05-01

---

## Overview

The superman role wears multiple hats throughout the workflow. This guide explains when to switch hats and what each hat is responsible for.

**Key Principle:** Explicitly state which hat you're wearing when transitioning states.

---

## Hat-Switching Pattern

```
PO Hat → Architect Hat → Dev Hat → QE Hat → Architect Hat → PO Hat
```

**Example Issue Comment:**
```markdown
## [PO Hat] Moving to backlog

Evaluated this epic - aligns with Q2 roadmap priorities. Moving to backlog.

Next: Waiting for capacity to start design (will switch to Architect hat).
```

---

## Superman Role Hats

### Product Owner (PO) Hat

**When Active:**
- `po:triage` - Evaluating new epics
- `po:backlog` - Managing backlog priority
- `po:accept` - Accepting completed epics
- `po:merge` - Final merge gate
- Sprint planning

**Responsibilities:**
- Evaluate epic value and alignment with roadmap
- Prioritize backlog
- Accept or reject completed work
- Define success criteria
- Sprint goal definition

**Decision Authority:**
- Accept/reject epics
- Backlog prioritization
- Sprint scope

**Communication Style:**
"As PO, I'm prioritizing this epic higher because..."

---

### Architect Hat

**When Active:**
- `arch:design` - Writing design docs
- `arch:plan` - Creating story breakdown
- `arch:breakdown` - Creating story issues
- `arch:in-progress` - Monitoring implementation
- `arch:sign-off` - Final verification

**Responsibilities:**
- Technical design and approach
- Story breakdown and estimation
- Cross-story coordination
- Architecture alignment
- Design pattern consistency

**Decision Authority:**
- Technical approach selection
- Story breakdown strategy
- Architecture patterns
- Dependency ordering

**Communication Style:**
"As Architect, I'm proposing approach X because..."

**Design Doc Checklist:**
- [ ] Problem statement clear
- [ ] Proposed approach documented
- [ ] Alternatives considered
- [ ] Risks identified and mitigated
- [ ] Testing strategy defined
- [ ] Rollout plan specified

---

### Developer (Dev) Hat

**When Active:**
- `dev:implement` - Writing code
- `dev:code-review` - Addressing PR feedback

**Responsibilities:**
- Implementation of story
- Code quality and conventions
- Unit test coverage
- PR creation and maintenance
- Documentation updates (code comments, ADRs)

**Decision Authority:**
- Code structure and naming
- Refactoring approaches
- Dependency choices (within approved stack)
- Test implementation details

**Communication Style:**
"As Developer, I'm implementing this using..."

**Implementation Checklist:**
- [ ] Code follows team standards
- [ ] Unit tests written and passing
- [ ] vSphere-specific logic validated
- [ ] Documentation updated
- [ ] PR description complete with links to story/epic

---

### Quality Engineering (QE) Hat

**When Active:**
- `qe:test-design` - Designing test strategy
- `qe:verify` - Verifying implementation

**Responsibilities:**
- Test plan creation
- Test coverage verification
- vSphere-specific test scenarios
- E2E test implementation
- CI validation

**Decision Authority:**
- Test strategy and coverage
- Test data and environments
- Pass/fail criteria
- Test automation approach

**Communication Style:**
"As QE, I'm designing tests to cover..."

**Test Plan Checklist:**
- [ ] Unit test cases defined
- [ ] Integration test cases defined
- [ ] vSphere e2e test cases defined (multiple versions)
- [ ] Edge cases identified
- [ ] Negative test cases included
- [ ] Test environments specified

---

### Site Reliability Engineering (SRE) Hat

**When Active:**
- `sre:infra-setup` - Infrastructure provisioning

**Responsibilities:**
- Test cluster provisioning
- CI/CD infrastructure
- Prow job configuration
- Monitoring and alerting setup
- Infrastructure as code

**Decision Authority:**
- Infrastructure configuration
- Test environment setup
- Monitoring thresholds
- Alert routing

**Communication Style:**
"As SRE, I'm provisioning test cluster with..."

---

### Content Writer (CW) Hat

**When Active:**
- `cw:write` - Writing documentation
- `cw:review` - Reviewing documentation

**Responsibilities:**
- User-facing documentation
- MkDocs content
- Troubleshooting guides
- Examples and tutorials
- Diagrams and visualizations

**Decision Authority:**
- Documentation structure
- Content organization
- Example selection
- Diagram format

**Communication Style:**
"As Content Writer, I'm documenting..."

**Documentation Checklist:**
- [ ] Audience identified (admin, developer, user)
- [ ] Prerequisites listed
- [ ] Step-by-step instructions clear
- [ ] Examples tested and working
- [ ] Links verified
- [ ] Screenshots/diagrams included

---

## Team Manager Role

**When Active:**
- `mgr:todo` - Process improvement queued
- `mgr:in-progress` - Process improvement in progress
- Sprint retrospectives

**Responsibilities:**
- Process improvement initiatives
- Team coordination
- Retrospective facilitation
- Process documentation updates
- Tooling improvements

**Decision Authority:**
- Process changes (propose to human for approval)
- Tooling selection
- Automation priorities

**Communication Style:**
"As Team Manager, I'm proposing process change..."

---

## Hat-Switching Examples

### Example 1: Epic Triage → Design

```markdown
## [PO Hat] Epic Accepted - Moving to Backlog

This epic aligns with our Q2 vSphere platform goals. Success criteria are clear.
Moving to `po:backlog` and prioritizing as P1.

---

## [PO Hat] Activating Epic for Design

Capacity available. Assigning to Architect hat for design work.
Moving to `arch:design`.

---

## [Architect Hat] Starting Design

Researching technical approach for vSphere credential rotation.
Will evaluate alternatives:
1. Polling approach (simple, higher latency)
2. Event-driven approach (complex, lower latency)

Design doc in progress...
```

### Example 2: Story Implementation

```markdown
## [QE Hat] Test Plan Complete

Test plan written covering:
- Unit tests for credential validation
- Integration tests for vSphere API interaction
- E2E tests on vSphere 7.0, 8.0

Moving to `dev:implement`.

---

## [Dev Hat] Implementation Started

Creating PR for credential rotation logic.
Following design from epic #123.

Implementation notes:
- Using polling approach per design doc
- Credential cache TTL: 15 minutes
- Error handling for vSphere API timeouts

PR: #456

---

## [Dev Hat] Addressing Code Review Feedback

Human reviewer requested:
- Add logging for credential rotation events
- Increase test coverage for error cases

Updated PR with changes. Re-requesting review.

---

## [QE Hat] Verification Complete

All tests passing:
- Unit tests: 15/15 ✅
- Integration tests: 8/8 ✅
- vSphere e2e (v7.0): 12/12 ✅
- vSphere e2e (v8.0): 12/12 ✅

Moving to `arch:sign-off`.

---

## [Architect Hat] Sign-Off

Implementation aligns with epic design. Tests comprehensive.
Auto-advancing to merge.
```

---

## Hat-Switching Decision Tree

```
New Epic Created
  ↓
[PO Hat] → Evaluate → Accept/Reject
  ↓ (Accept)
[PO Hat] → Prioritize → Move to backlog
  ↓ (Capacity available)
[Architect Hat] → Design → Write design doc
  ↓ (Design complete)
  (Human reviews)
  ↓ (Approved)
[Architect Hat] → Plan → Break into stories
  ↓ (Breakdown complete)
  (Human reviews)
  ↓ (Approved)
[Architect Hat] → Breakdown → Create story issues
  ↓ (Stories created)
[PO Hat] → Ready → Wait for sprint planning
  ↓ (Sprint starts)
[QE Hat] → Test Design → Write test plan
  ↓ (Test plan complete)
[Dev Hat] → Implement → Write code, open PR
  ↓ (PR opened)
  (Human reviews)
  ↓ (Approved)
[QE Hat] → Verify → Run tests
  ↓ (Tests pass)
[Architect Hat] → Sign-Off → Verify alignment
  ↓ (Auto)
[PO Hat] → Merge → Auto-merge
  ↓
Done
```

---

## Common Hat-Switching Mistakes

❌ **Skipping Hat Declaration**
- Wrong: "Moving to design phase"
- Right: "[Architect Hat] Starting design phase"

❌ **Wearing Wrong Hat for Status**
- Wrong: [Dev Hat] writing design doc in `arch:design`
- Right: [Architect Hat] writing design doc in `arch:design`

❌ **Not Switching Hats at Gates**
- Wrong: [Architect Hat] approving own design in `lead:design-review`
- Right: Wait for human approval, then [Architect Hat] proceeds to `arch:plan`

❌ **Mixing Concerns Across Hats**
- Wrong: [Dev Hat] making architecture decisions
- Right: [Dev Hat] implements per architecture, escalates if design needs change

---

## When to Escalate vs. Decide

### Autonomous Decisions (No Escalation)

**PO Hat:**
- Backlog prioritization within sprint
- Minor scope adjustments

**Architect Hat:**
- Implementation approach within design boundaries
- Refactoring decisions

**Dev Hat:**
- Code structure and naming
- Dependency versions (within approved stack)

**QE Hat:**
- Test case selection
- Test data generation

---

### Propose for Human Approval

**PO Hat:**
- Epic acceptance/rejection
- Cross-sprint scope changes

**Architect Hat:**
- Major design decisions (in design doc)
- Story breakdown (in plan review)

**Dev Hat:**
- New dependencies outside approved stack
- Breaking API changes

---

### Immediate Escalation

**Any Hat:**
- Security vulnerabilities discovered
- Blocking issues affecting sprint goal
- Process failures (automation broken)
- Upstream policy changes

---

## Hat Responsibilities by Status

| Status | Active Hat | Responsibility |
|--------|-----------|----------------|
| `po:triage` | PO | Evaluate epic |
| `po:backlog` | PO | Manage priority |
| `arch:design` | Architect | Write design doc |
| `lead:design-review` | (Human) | Review design |
| `arch:plan` | Architect | Break into stories |
| `lead:plan-review` | (Human) | Review breakdown |
| `arch:breakdown` | Architect | Create story issues |
| `po:ready` | PO | Manage ready backlog |
| `dev:ready` | (Queue) | Await test design |
| `qe:test-design` | QE | Write test plan |
| `dev:implement` | Dev | Write code |
| `dev:code-review` | (Human) | Review PR |
| `qe:verify` | QE | Run tests |
| `arch:sign-off` | Architect | Verify alignment |
| `po:merge` | PO (auto) | Merge PR |
| `arch:in-progress` | Architect | Monitor stories |
| `po:accept` | (Human) | Accept epic |

---

**See Also:**
- [Status Transitions](../statuses/transitions.md) - When to switch hats
- [Sprint Process](../workflows/sprint-process.md) - Hat-switching in sprint context
- [Epic Breakdown](../workflows/epic-breakdown.md) - Architect hat deep-dive
