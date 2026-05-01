# Splat Team - Agent Navigation

**Profile:** scrum-compact  
**Repository:** https://github.com/openshift-splat-team/splat-team  
**Last Updated:** 2026-05-01

---

## CRITICAL: Retrieval Strategy

**IMPORTANT**: Prefer retrieval-led reasoning over pre-training-led reasoning.

When working on Splat Team:
- ✅ **DO**: Read relevant docs from `./ai-docs/` first
- ✅ **DO**: Check team workflows in `./ai-docs/workflows/`
- ✅ **DO**: Verify status transitions in `./ai-docs/statuses/`
- ✅ **DO**: Review project-specific context in `./projects/<project>/`
- ❌ **DON'T**: Rely solely on training data
- ❌ **DON'T**: Guess at team processes or status meanings

---

## AI Navigation: DON'T Read All Docs

**Read 4-5 docs per task, not everything.**

### Common Task Flows

**Starting new epic?**
→ `ai-docs/workflows/epic-breakdown.md` → `ai-docs/statuses/transitions.md` → `PROCESS.md`

**Implementing story?**
→ `ai-docs/workflows/sprint-process.md` → `ai-docs/practices/coding-standards.md` → `ai-docs/architecture/projects.md`

**Working on specific project (e.g., installer)?**
→ `projects/installer/CLAUDE.md` → `ai-docs/architecture/projects.md` → `ai-docs/practices/testing.md`

**Triaging issue or regression?**
→ `ai-docs/workflows/triage-process.md` → `coding-agent/skills/triage-regression/`

**Need role context?**
→ `ai-docs/roles/responsibilities.md`

---

## Quick Navigation by Task

| Task | Start Here | Then Read |
|------|-----------|-----------|
| **Epic breakdown** | `ai-docs/workflows/epic-breakdown.md` | `ai-docs/statuses/transitions.md` |
| **Story implementation** | `ai-docs/workflows/sprint-process.md` | `projects/<project>/CLAUDE.md` |
| **Code review** | `ai-docs/workflows/review-process.md` | `ai-docs/practices/coding-standards.md` |
| **Triage regression** | `ai-docs/workflows/triage-process.md` | `coding-agent/skills/triage-regression/` |
| **Process improvement** | `ai-docs/roles/team-manager.md` | `PROCESS.md` |

---

## Team Focus

**Mission:** OpenShift vSphere/VMware platform engineering and CI/CD

**Key Projects:**
- **vcf-migration-operator** - VMware Cloud Foundation migration tooling
- **installer** - OpenShift installer (vSphere provider support)
- **machine-api-operator** - vSphere machine provisioning
- **cluster-cloud-controller-manager-operator** - vSphere CCM integration
- **cloud-credential-operator** - vSphere credential management
- **vsphere-problem-detector** - Platform health diagnostics
- **opct** - OpenShift Provider Certification Tool

See `ai-docs/architecture/projects.md` for full project list and details.

---

## Technology Stack

**Primary Languages:** Go (OpenShift operators), Python (automation/skills)  
**Testing:** Go testing, pytest, Jest  
**CI/CD:** Prow, GitHub Actions  
**Documentation:** MkDocs

**See:** `ai-docs/architecture/tech-stack.md` for details

---

## Team Structure

### Roles

| Role | Description | When Active |
|------|-------------|-------------|
| **superman** | All-in-one member (PO, architect, dev, QE, SRE, content writer) | All tasks |
| **team-manager** | Process improvement and team coordination | Process tasks only |

See `ai-docs/roles/responsibilities.md` for detailed hat-switching guide.

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

See `ai-docs/statuses/transitions.md` for full state machine.

---

## Core Documentation

| Topic | File | Description |
|-------|------|-------------|
| **Team principles** | `ai-docs/TEAM_PHILOSOPHY.md` | Methodology and values |
| **Sprint process** | `ai-docs/workflows/sprint-process.md` | Ceremonies and cadence |
| **Epic breakdown** | `ai-docs/workflows/epic-breakdown.md` | Design → Stories flow |
| **Review process** | `ai-docs/workflows/review-process.md` | PR and acceptance criteria |
| **Triage process** | `ai-docs/workflows/triage-process.md` | Issue triage and regression handling |
| **Projects overview** | `ai-docs/architecture/projects.md` | Project descriptions and context |
| **Coding standards** | `ai-docs/practices/coding-standards.md` | Code conventions |
| **Testing guide** | `ai-docs/practices/testing.md` | Test strategy |
| **Custom skills** | `ai-docs/architecture/skills.md` | Team automation tools |

---

## Custom Skills

The team has specialized skills for OpenShift CI/CD:

| Skill | Purpose | Location |
|-------|---------|----------|
| **triage-regression** | Triage CI failures and regressions | `coding-agent/skills/triage-regression/` |
| **summarize-jiras** | Summarize related Jira issues | `coding-agent/skills/summarize-jiras/` |
| **suggest-reviewers** | Suggest PR reviewers via git blame | `coding-agent/skills/suggest-reviewers/` |
| **prow-job-analyze-resource** | Analyze Prow job resources | `coding-agent/skills/prow-job-analyze-resource/` |
| **prow-job-extract-must-gather** | Extract must-gather from Prow jobs | `coding-agent/skills/prow-job-extract-must-gather/` |

See `ai-docs/architecture/skills.md` for usage details.

---

## Documentation Structure

```
ai-docs/
├── TEAM_PHILOSOPHY.md        # Core principles
├── architecture/             # System structure
│   ├── index.md
│   ├── projects.md           # Project descriptions
│   ├── tech-stack.md         # Technologies used
│   └── skills.md             # Custom automation tools
├── workflows/                # Process guides
│   ├── index.md
│   ├── sprint-process.md     # Sprint ceremonies
│   ├── epic-breakdown.md     # Epic → Stories
│   ├── review-process.md     # PR review
│   └── triage-process.md     # Issue triage
├── roles/                    # Role definitions
│   ├── index.md
│   ├── responsibilities.md   # Hat-switching guide
│   └── team-manager.md       # Process coordination
├── statuses/                 # Status system
│   ├── index.md
│   └── transitions.md        # State machine
├── practices/                # Engineering practices
│   ├── index.md
│   ├── coding-standards.md   # Code conventions
│   ├── testing.md            # Test strategy
│   └── ci-cd.md              # Prow and GitHub Actions
├── decisions/                # Architectural Decision Records
│   ├── index.md
│   └── adr-template.md       # ADR template
└── references/               # Quick reference
    ├── index.md
    ├── glossary.md           # Team terminology
    └── shortcuts.md          # Common commands
```

---

## Project-Specific Context

Each forked project has its own context:

```
projects/<project>/
├── CLAUDE.md              # Project-specific agent guidance
├── .context.md            # Additional context (if present)
└── ...project files...
```

**Always read `projects/<project>/CLAUDE.md` before working on that project.**

---

**Navigation**: Start with `ai-docs/TEAM_PHILOSOPHY.md` for team context.

**Feedback**: Report issues via GitHub issues with `kind/docs` label.
