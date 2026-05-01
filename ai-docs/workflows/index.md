# splat Workflows

**Profile:** scrum-compact

---

## Overview

This section documents the team's workflows and processes for managing work from idea to deployment.

The scrum-compact profile uses a GitHub-centric workflow with human-in-the-loop gates at critical decision points.

---

## Key Workflows

### Sprint Process
See [sprint-process.md](sprint-process.md) for details on:
- Sprint planning and ceremonies
- Status transitions during a sprint
- Epic breakdown and story implementation
- Review and acceptance criteria

---

## Workflow Principles

**1. Everything in GitHub**
- Issues for all work items (epics and stories)
- GitHub Projects v2 for tracking
- Status field for workflow state
- PRs for all code changes

**2. Human Gates at Critical Points**
- Design review (`lead:design-review`)
- Plan review (`lead:plan-review`)
- Code review (`dev:code-review`)

**3. Status-Driven Progression**
- Issues advance through defined states
- Status reflects current work phase
- Transitions documented in [../statuses/index.md](../statuses/index.md)

**4. Single Source of Truth**
- GitHub issues are authoritative
- Status field shows current state
- Comments capture decisions and feedback

---

## Process Documentation

- [Sprint Process](sprint-process.md) - Sprint ceremonies and cadence
- [Status Transitions](../statuses/index.md) - State machine and workflow
- [Role Responsibilities](../roles/index.md) - Who does what

---

## Getting Started

**For new epics:**
1. Create epic issue with `kind/epic` label
2. Triage (`po:triage`)
3. Write design doc (`arch:design`)
4. Submit for design review (`lead:design-review`)
5. Break down into stories (`arch:plan`, `arch:breakdown`)

**For new stories:**
1. Story enters backlog (`dev:ready`)
2. Design tests (`qe:test-design`)
3. Implement (`dev:implement`)
4. Open PR and request review (`dev:code-review`)
5. Verify and merge (`qe:verify`, `arch:sign-off`, `po:merge`)

---

**See Also:**
- [Team Philosophy](../TEAM_PHILOSOPHY.md) - Core principles
- [Status Index](../statuses/index.md) - Status definitions
