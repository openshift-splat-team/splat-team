# splat Roles

**Profile:** scrum-compact

---

## Team Roles

- **superman**: All-in-one member — PO, architect, dev, QE, SRE, content writer
- **team-manager**: Process improvement and team coordination

---

## Role Descriptions

### Superman Role

**Purpose:** All-in-one team member wearing multiple hats

**Hats Worn:**
- **PO (Product Owner)**: Manages backlog, triages issues, accepts work
- **Architect**: Designs solutions, reviews technical approach
- **Developer**: Implements code, writes tests
- **QE (Quality Engineer)**: Designs tests, verifies implementations
- **SRE (Site Reliability Engineer)**: Infrastructure setup and monitoring (when applicable)
- **Content Writer**: Documentation and user guides (when applicable)

**When Active:** All work items (default role)

**Status Prefixes:**
- `po:*` - Product Owner hat
- `arch:*` - Architect hat
- `dev:*` - Developer hat
- `qe:*` - QE hat
- `sre:*` - SRE hat
- `cw:*` - Content Writer hat

---

### Team Manager Role

**Purpose:** Process improvement and team coordination

**Responsibilities:**
- Process improvement tasks
- Team coordination activities
- Methodology refinement
- Documentation maintenance

**When Active:** Only for process-related work items

**Status Prefixes:**
- `mgr:*` - Manager statuses

**Label:** `role/team-manager`

---

## Hat-Switching Guide

### Why Explicit Hat Switching?

The scrum-compact profile uses a solo operator model where one agent performs all roles. Explicit hat-switching provides clarity about:
- Current responsibility context
- Which perspective you're taking
- What work is being performed

### How to Switch Hats

**Announce the switch explicitly:**

```
Switching to QE hat: Designing test plan for story #123
```

```
Dev hat: Implementing feature X based on design
```

```
PO hat: Triaging new epic, evaluating priority
```

**Status transitions often trigger hat changes:**
- `arch:design` → **Architect hat**: Writing design doc
- `qe:test-design` → **QE hat**: Planning tests
- `dev:implement` → **Developer hat**: Writing code
- `po:triage` → **PO hat**: Evaluating new work

---

## Responsibilities by Hat

### Product Owner (PO) Hat

**Responsibilities:**
- Triage new issues (`po:triage`)
- Manage and prioritize backlog (`po:backlog`)
- Accept completed work (`po:accept`)
- Merge approved PRs (`po:merge`)

**Mindset:**
- Customer value focus
- Priority and scope decisions
- Stakeholder communication

---

### Architect Hat

**Responsibilities:**
- Design technical solutions (`arch:design`)
- Plan story breakdowns (`arch:plan`)
- Create story issues (`arch:breakdown`)
- Sign off on implementations (`arch:sign-off`)
- Monitor in-progress work (`arch:in-progress`)

**Mindset:**
- System architecture
- Technical approach
- Long-term maintainability
- Risk assessment

---

### Developer Hat

**Responsibilities:**
- Implement features (`dev:implement`)
- Write code and tests
- Create pull requests
- Address code review feedback (`dev:code-review`)

**Mindset:**
- Code quality
- Test coverage
- Clear implementation
- Best practices

---

### QE (Quality Engineer) Hat

**Responsibilities:**
- Design test plans (`qe:test-design`)
- Define test cases and criteria
- Verify implementations (`qe:verify`)
- Check for regressions

**Mindset:**
- Quality assurance
- Edge case thinking
- Test coverage
- Acceptance criteria validation

---

### Lead Hat (Human Gate)

**Responsibilities:**
- Review and approve design docs (`lead:design-review`)
- Review and approve story breakdowns (`lead:plan-review`)
- Review and approve code changes (`dev:code-review`)

**Note:** Lead gates are **human-performed** reviews, not AI-automated.

---

## Status → Hat Mapping

| Status | Hat | Responsibility |
|--------|-----|----------------|
| `po:triage` | PO | Evaluate new work |
| `po:backlog` | PO | Prioritize work |
| `arch:design` | Architect | Write design doc |
| `lead:design-review` | **Human** | Approve design |
| `arch:plan` | Architect | Propose story breakdown |
| `lead:plan-review` | **Human** | Approve breakdown |
| `arch:breakdown` | Architect | Create story issues |
| `po:ready` | PO | Ready for sprint |
| `dev:ready` | Developer | Ready to implement |
| `qe:test-design` | QE | Design test plan |
| `dev:implement` | Developer | Write code |
| `dev:code-review` | **Human** | Review PR |
| `qe:verify` | QE | Verify implementation |
| `arch:sign-off` | Architect | Technical approval |
| `po:merge` | PO | Merge and close |
| `po:accept` | PO | Accept epic |

---

## Best Practices

**1. Announce hat switches clearly**
- Don't switch silently mid-comment
- State which hat you're wearing

**2. Maintain perspective consistency**
- Stay in role while wearing a hat
- Don't mix PO and Dev thinking in same comment

**3. Respect human gates**
- Never advance past `lead:*` statuses without human approval
- Don't auto-approve your own design or code

**4. Use status prefixes to guide hat choice**
- Status name indicates which hat to wear
- Follow the workflow naturally

**5. Comment with hat context**
- Begin comments with hat indicator: "Dev hat: ..."
- Helps humans understand which perspective you're taking

---

**See Also:**
- [Team Philosophy](../TEAM_PHILOSOPHY.md) - Core principles
- [Sprint Process](../workflows/sprint-process.md) - Workflow details
- [Status Transitions](../statuses/index.md) - Status workflow
