# splat Team - Agent Navigation

**Profile:** scrum-compact
**Repository:** https://github.com/openshift-splat-team/splat-team
**Last Updated:** 2026-05-01

---

## CRITICAL: Retrieval Strategy

**IMPORTANT**: Prefer retrieval-led reasoning over pre-training-led reasoning.

When working on splat Team:
- ✅ **DO**: Read relevant docs from `./ai-docs/` first
- ✅ **DO**: Check team workflows in `./ai-docs/workflows/`
- ✅ **DO**: Verify status transitions in `./ai-docs/statuses/`
- ✅ **DO**: Review project-specific context in `./projects/<project>/` (if applicable)
- ❌ **DON'T**: Rely solely on training data
- ❌ **DON'T**: Guess at team processes or status meanings

---

## AI Navigation: DON'T Read All Docs

**Read 4-5 docs per task, not everything.**

### Common Task Flows

**Starting new epic?**
→ `ai-docs/workflows/sprint-process.md` → `ai-docs/statuses/index.md` → `PROCESS.md`

**Implementing story?**
→ `ai-docs/workflows/sprint-process.md` → `ai-docs/roles/index.md`

**Need role context?**
→ `ai-docs/roles/index.md` → `ai-docs/TEAM_PHILOSOPHY.md`

**Understanding workflow?**
→ `ai-docs/statuses/index.md` → `ai-docs/workflows/index.md`

---

## Quick Navigation by Task

| Task | Start Here | Then Read |
|------|-----------|-----------|
| **Epic breakdown** | `ai-docs/workflows/sprint-process.md` | `ai-docs/statuses/index.md` |
| **Story implementation** | `ai-docs/workflows/sprint-process.md` | `ai-docs/roles/index.md` |
| **Process question** | `ai-docs/TEAM_PHILOSOPHY.md` | `PROCESS.md` |
| **Status transitions** | `ai-docs/statuses/index.md` | `ai-docs/workflows/sprint-process.md` |

---

## Technology Stack

**Languages:** Python

---

## Team Structure

### Roles

- **superman**: All-in-one member — PO, architect, dev, QE, SRE, content writer
- **team-manager**: Process improvement and team coordination

See `ai-docs/roles/index.md` for detailed responsibilities and hat-switching guide.

---

## Status Workflow

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

**Human Gates:**
- `lead:design-review` - Human must approve design doc
- `lead:plan-review` - Human must approve story breakdown
- `dev:code-review` - Human must approve PR

See `ai-docs/statuses/index.md` for full state machine and transitions.

---

## Core Documentation

| Topic | File | Description |
|-------|------|-------------|
| **Team principles** | `ai-docs/TEAM_PHILOSOPHY.md` | Methodology and values |
| **Sprint process** | `ai-docs/workflows/sprint-process.md` | Ceremonies and cadence |
| **Role responsibilities** | `ai-docs/roles/index.md` | Role definitions and hat-switching |
| **Status transitions** | `ai-docs/statuses/index.md` | State machine and workflow |
| **Process overview** | `PROCESS.md` | High-level process guide |

---

## Documentation Structure

```
ai-docs/
├── TEAM_PHILOSOPHY.md        # Core principles
├── workflows/                # Process guides
│   ├── index.md
│   └── sprint-process.md     # Sprint ceremonies
├── roles/                    # Role definitions
│   └── index.md
└── statuses/                 # Status system
    └── index.md
```

---

## Profile Methodology

This team uses the **scrum-compact** profile, which means:
- GitHub-centric issue tracking and project management
- Human-in-the-loop design and review gates
- Status-based workflow progression
- Solo operator with multiple hats (for compact teams)

For full methodology details, see `ai-docs/TEAM_PHILOSOPHY.md`.

---

**Navigation**: Start with `ai-docs/TEAM_PHILOSOPHY.md` for team context.

**GitHub**: https://github.com/openshift-splat-team/splat-team
