# Team Repository

**Control plane for a compact single-member agentic team.**

This is NOT a code repository. It defines team structure, process, knowledge, and work tracking. Code work happens in separate project repos.

## Overview

The compact team profile uses a single agent (`superman`) who wears all hats—Product Owner, architect, developer, QE, SRE, and content writer. The agent self-transitions through the entire issue lifecycle by switching between roles as work progresses.

**Key characteristics:**
- **GitHub-native**: Issues, milestones, and PRs live on this repo's GitHub
- **Supervised mode**: Human reviews and approves at design, planning, and final acceptance gates via GitHub issue comments
- **File-based coordination**: Knowledge, invariants, and process conventions propagate via git
- **Project-aware**: Team repo structure supports multiple projects with shared and project-specific knowledge

## Repository Structure

```
team/
├── CLAUDE.md              # Agent instructions and workspace model
├── PROCESS.md             # Workflow conventions, labels, statuses
├── botminter.yml          # Team formation definition
│
├── knowledge/             # Team-wide knowledge (all hats)
├── invariants/            # Team-wide constraints (all hats)
│
├── members/               # Member-specific configuration
│   └── superman-atlas/    # The single team member
│       ├── PROMPT.md      # Member-specific prompt
│       ├── context.md     # Member context
│       ├── hats/          # Hat-specific configurations
│       ├── knowledge/     # Member-specific knowledge
│       ├── invariants/    # Member-specific constraints
│       └── coding-agent/  # Skills, agents, settings
│
├── projects/              # Project-specific configurations
│   ├── <project>/
│   │   ├── knowledge/     # Project knowledge
│   │   ├── invariants/    # Project constraints
│   │   └── coding-agent/  # Project-specific skills/agents
│
├── coding-agent/          # Team-level skills and agents
│   ├── skills/            # Reusable skills (via Ralph)
│   └── agents/            # Sub-agents (via Claude Code)
│
├── bridges/               # Integration with external systems
├── formations/            # Team formation variants
└── ralph-prompts/         # Ralph coordination prompts
```

## How It Works

### Workspace Model

The agent operates in a **project repo clone** with this team repo cloned into `team/` inside it:

```
project-repo-superman/          # Agent's CWD (project codebase)
├── team/                       # This repo (on epic branch)
│   ├── knowledge/
│   ├── members/superman-atlas/
│   └── projects/<project>/
├── PROMPT.md → team/members/superman-atlas/PROMPT.md
├── context.md → team/members/superman-atlas/context.md
└── ralph.yml                   # Copied from member config
```

The agent has direct access to project code at `./` and team configuration at `team/`.

**Epic branch isolation:** The `team/` directory tracks an epic-specific branch (e.g., `epic/42-api-versioning`), not `main`. All team repo changes (designs, knowledge, invariants) are staged on the epic branch. When the epic completes, a PR merges the epic branch to `main`. This enables multiple agents to work on different epics without conflicts.

### Knowledge Resolution

Knowledge is resolved by specificity (all levels are additive):

1. **Team knowledge** — `knowledge/` (applies to all hats)
2. **Project knowledge** — `projects/<project>/knowledge/` (project-specific)
3. **Member knowledge** — `members/superman-atlas/knowledge/` (member-specific)
4. **Member+project** — `members/superman-atlas/projects/<project>/knowledge/`
5. **Hat knowledge** — `members/superman-atlas/hats/<hat>/knowledge/` (hat-specific)

Invariants follow the same pattern. All applicable invariants MUST be satisfied.

### Issue Lifecycle

Work is tracked through GitHub issues on this repo:

1. **Epic creation** — PO triages and prioritizes (`po:triage` → `po:backlog`)
2. **Branch creation** — When epic moves to `arch:design`, create epic branch (`epic/<number>-<slug>`)
3. **Design** — Architect creates design doc on epic branch (`arch:design`)
4. **Review** — Human reviews and approves design (`po:design-review`)
5. **Planning** — Architect breaks down into stories (`arch:plan`)
6. **Review** — Human reviews and approves plan (`po:plan-review`)
7. **Story creation** — Architect creates story issues (`arch:breakdown`)
8. **Execution** — Stories flow through TDD cycle:
   - `qe:test-design` → QE writes test stubs
   - `dev:implement` → Developer implements
   - `dev:code-review` → Code review
   - `qe:verify` → QE verifies
   - `po:merge` → Auto-advances to `done`
9. **Acceptance** — Human reviews completed epic (`po:accept`)
10. **Team repo PR** — Create PR from epic branch to `main`, merge after human approval

See [`PROCESS.md`](PROCESS.md) for complete status definitions, branch conventions, and comment formats.

### Detailed Workflow

#### Epic Lifecycle

**1. Triage & Backlog (`po:triage` → `po:backlog`)**
- PO evaluates new epic requests
- Prioritizes and adds to backlog
- Human decision: activate for design or keep in backlog

**2. Design Phase (`po:backlog` → `arch:design` → `lead:design-review` → `po:design-review`)**
- Agent creates epic branch: `git checkout -b epic/<number>-<slug>`
- Architect produces design document in `projects/<project>/knowledge/designs/epic-<number>.md`
- Design includes: problem statement, approach, architecture, dependencies
- Lead reviews (optional gate)
- **Human review gate**: Approve or reject with feedback
- If rejected: loops back to `arch:design` with feedback

**3. Planning Phase (`po:design-review` → `arch:plan` → `lead:plan-review` → `po:plan-review`)**
- Architect breaks epic into story-sized work items
- Creates story breakdown plan with acceptance criteria
- Lead reviews (optional gate)
- **Human review gate**: Approve or reject with feedback
- If rejected: loops back to `arch:plan` with feedback

**4. Story Creation (`po:plan-review` → `arch:breakdown` → `po:ready`)**
- Architect creates GitHub issues for each story
- Links stories to parent epic with `parent/<epic-number>` label
- Epic moves to `po:ready` (ready backlog)
- **Human decision**: When to activate epic

**5. Implementation (`po:ready` → `arch:in-progress`)**
- Stories flow through TDD cycle in parallel:
  - `qe:test-design` — QE writes test stubs and test plan
  - `dev:implement` — Developer implements feature
  - `dev:code-review` — Internal code review
  - `qe:verify` — QE verifies against acceptance criteria
  - `arch:sign-off` → `po:merge` → `done` (auto-advances)
- Architect monitors progress, epic stays in `arch:in-progress`
- When all stories complete, epic moves to `po:accept`

**6. Acceptance (`arch:in-progress` → `po:accept`)**
- **Human review gate**: Final acceptance review
- Verify all stories completed
- Approve or reject with feedback
- If rejected: loops back to `arch:in-progress` with issues to address

**7. Team Repo PR (`po:accept` → `done`)**
- Create PR from epic branch to `main`
- PR includes all design docs, knowledge, invariants added during epic
- Human reviews and merges PR
- Epic branch deleted after merge

#### Story Lifecycle

Stories follow a Test-Driven Development flow:

```
qe:test-design → dev:implement → dev:code-review → qe:verify → done
       ↑              ↓               ↓
       └──────────────┴───────────────┘
              (rejection loops)
```

**Rejection loops:**
- Code review can reject back to `dev:implement`
- QE verification can reject back to `dev:implement`
- Agent fixes issues and cycles through review again

### Updating Designs Mid-Implementation

**Problem:** You've approved a design, stories are in progress, but you realize the design needs changes.

**Options:**

#### Option 1: Reject at `po:accept` Gate (Minor Changes)
Wait until the epic reaches final acceptance, then reject:

```markdown
### 📝 human — 2026-04-16T12:00:00Z

**REJECT**

Implementation revealed design issues:
- [specific problem]
- Needs redesign to address [X]
```

This sends the epic back to `arch:in-progress`, but stories may need rework.

#### Option 2: Direct Design Update (Recommended for Most Cases)

Since design docs live on the epic branch, you can update them anytime:

1. **Edit the design directly** on the epic branch:
   ```bash
   cd team/
   git checkout epic/<number>-<slug>
   vim projects/<project>/knowledge/designs/epic-<number>.md
   git add projects/<project>/knowledge/designs/
   git commit -m "Design revision: address implementation findings"
   git push
   ```

2. **Comment on the epic** to notify the agent:
   ```markdown
   ### 📝 human — 2026-04-16T12:00:00Z
   
   **Design updated** based on implementation findings.
   
   Key changes:
   - [what changed and why]
   - Stories affected: #X, #Y
   ```

3. **Agent pulls the updated design** on next scan cycle and adjusts implementation

**Advantages:**
- Preserves git history of design evolution
- Agent sees changes immediately
- No workflow disruption

#### Option 3: Create Follow-up Epic (Major Redesigns)

For fundamental design pivots:

1. Create new epic with revised design
2. Close or park current epic with explanation
3. New epic goes through full design → plan → implement cycle

**When to use:**
- Design assumptions were fundamentally wrong
- Current implementation needs to be abandoned
- Scope grew significantly beyond original epic

**Workflow limitation:** The formal workflow lacks a path from `arch:in-progress` back to `arch:design`. The assumption is that design issues are caught at review gates. For mid-implementation changes, use direct git edits (Option 2) or a new epic (Option 3).

## Multi-Agent Collaboration

While the compact profile uses a single agent, the branching strategy supports multiple agents working on the same team repo:

**How it works:**
- Each agent works on a different epic in its own workspace
- Each workspace has `team/` checked out to a different epic branch
- Agents pull their epic branch before each scan cycle
- Changes stay isolated until the epic PR merges to `main`
- No coordination overhead — git handles conflicts naturally

**Example scenario:**
```
Agent A workspace:
  team/ → epic/42-api-versioning

Agent B workspace:
  team/ → epic/43-metrics-dashboard

Both agents can work simultaneously without conflicts
```

When an epic PR merges to `main`, other agents can rebase their epic branches to incorporate those changes.

## Getting Started

### Prerequisites

- GitHub CLI (`gh`) configured with access to this repo
- Ralph (agent orchestration tool)
- Claude Code CLI

### Initial Setup

1. Clone this repo into a project workspace:
   ```bash
   cd /path/to/project-repo
   git clone <team-repo-url> team
   ```

2. Checkout the epic branch (if working on an epic):
   ```bash
   cd team/
   git checkout epic/<epic-number>-<slug>
   cd ..
   ```
   
   Or create a new epic branch:
   ```bash
   cd team/
   git checkout -b epic/<epic-number>-<slug>
   git push -u origin epic/<epic-number>-<slug>
   cd ..
   ```

3. Set up member workspace files:
   ```bash
   ln -s team/members/superman-atlas/PROMPT.md PROMPT.md
   ln -s team/members/superman-atlas/context.md context.md
   cp team/members/superman-atlas/ralph.yml ralph.yml
   ```

4. Sync coding-agent configuration:
   ```bash
   # Copy settings and symlink agents
   cp team/members/superman-atlas/coding-agent/settings.local.json .claude/
   # (see member's setup script for full agent symlink process)
   ```

### Board Scanning

The agent periodically scans the GitHub project board using the `board-scanner` skill:

```bash
# Trigger a scan cycle
ralph run board-scanner
```

The scanner:
1. Pulls the epic branch in `team/` to get latest changes
2. Queries the project board for all issues via `gh project item-list`
3. Dispatches to the appropriate hat based on current status
4. The hat performs its work and commits changes to the epic branch
5. Logs activity to `poll-log.txt`

## Key Documentation

- **[CLAUDE.md](CLAUDE.md)** — Agent instructions, workspace model, scoping rules
- **[PROCESS.md](PROCESS.md)** — Workflow conventions, label scheme, status definitions
- **[knowledge/](knowledge/)** — Team-wide knowledge base
- **[members/superman-atlas/](members/superman-atlas/)** — Member configuration

## GitHub Integration

All GitHub operations use the `gh` skill (wraps GitHub CLI):

| Resource | Access Method |
|----------|--------------|
| Issues | `gh issue list/view/create/edit` |
| Project board | `gh project item-list/item-edit` |
| Milestones | `gh api repos/:owner/:repo/milestones` |
| Pull requests | `gh pr create/view/merge` |
| Comments | `gh issue comment` |

The team repo is auto-detected from `team/`'s git remote.

## Supervised Mode

Human approval is required at three gates via GitHub issue comments:

1. **Design review** (`po:design-review`) — Review design doc
2. **Plan review** (`po:plan-review`) — Review story breakdown
3. **Final acceptance** (`po:accept`) — Review completed epic

**To approve:** Comment `Approved` or `LGTM` on the issue  
**To reject:** Comment `Rejected: <feedback>`

All other transitions auto-advance without human interaction.

## Team Evolution

This repo evolves through multiple paths:

### Epic Workflow (primary mechanism)
1. Agent creates epic branch (`epic/<number>-<slug>`)
2. Agent commits all epic-related changes (designs, knowledge, invariants) to the epic branch
3. Agent creates PR from epic branch to `main` when epic completes
4. Human reviews and merges the PR
5. Epic branch is deleted

### Process Changes (formal path, preferred for significant changes)
1. Create a PR on a `process/<slug>` branch proposing the change
2. Review via lead hat
3. Merge to `main`

### Urgent Corrections (informal path)
1. Human requests change via issue comment
2. Agent edits files directly on `main`
3. Commit to team repo

## Project Support

Current projects:
- `cloud-credential-operator`
- `cluster-cloud-controller-manager-operator`
- `cluster-storage-operator`
- `installer`
- `machine-api-operator`
- `vcf-migration-operator`

Each project has its own knowledge base, invariants, and coding-agent extensions under `projects/<project>/`.

## License

This repository contains team coordination data and configuration. See individual project repositories for code licenses.
