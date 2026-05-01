# Status System

Status tracking and workflow state machine for the Splat Team.

---

## Contents

- **[transitions.md](transitions.md)** - Full status workflow and state machine

---

## Quick Reference

**Epic Flow:**
```
po:triage → po:backlog → arch:design → lead:design-review → 
arch:plan → lead:plan-review → arch:breakdown → po:ready → 
arch:in-progress → po:accept → done
```

**Story Flow:**
```
dev:ready → qe:test-design → dev:implement → dev:code-review → 
qe:verify → arch:sign-off → po:merge → done
```

**Human Gates (require human approval):**
- `lead:design-review` (< 1 business day SLA)
- `lead:plan-review` (< 1 business day SLA)
- `dev:code-review` (4-8 hours SLA)
- `po:accept` (< 2 business days SLA)

---

**Start Here:** Read [transitions.md](transitions.md) for full state machine and definitions.
