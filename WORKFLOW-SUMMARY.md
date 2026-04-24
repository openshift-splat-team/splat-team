# Superman Workflow Summary

Complete end-to-end workflow for automated software development with human review gates.

## Workflow Stages

### 1. Epic Triage (`po:triage`)

**Hat:** `po_backlog`

**Actions:**
- Read epic issue
- Post triage request comment
- Wait for human response: `Approved` or `Rejected`

**Human Gate:** Approve/reject new epic

**Next:** `po:backlog` (if approved)

---

### 2. Backlog Management (`po:backlog`)

**Hat:** `po_backlog`

**Actions:**
- Post backlog report listing ready epics
- Wait for human activation: `start` or `activate`

**Human Gate:** Activate epic to start work

**Next:** `arch:design` (on activation)

---

### 3. Design (`arch:design`)

**Hat:** `arch_designer`

**Actions:**
- Read epic requirements
- Consult team/project knowledge
- Produce design doc at `team/projects/<project>/knowledge/designs/epic-<N>.md`
- Post comment linking design doc

**Next:** `lead:design-review` → `po:design-review`

**Human Gate:** Review design document, approve/reject

---

### 4. Story Planning (`arch:plan`)

**Hat:** `arch_planner`

**Actions:**
- Read approved design doc
- Decompose into stories with acceptance criteria
- Post story breakdown as comment

**Next:** `lead:plan-review` → `po:plan-review`

**Human Gate:** Review story breakdown, approve/reject

---

### 5. Story Creation (`arch:breakdown`)

**Hat:** `arch_breakdown`

**Actions:**
- Read approved story breakdown
- Create story issues in GitHub
- Add stories to project board
- Set initial status (`qe:test-design` or `cw:write`)

**Next:** `lead:breakdown-review` → `po:ready`

**Human Gate:** Review created stories, approve to activate

---

### 6. Test Design (`qe:test-design`)

**Hat:** `qe_test_designer`

**Actions:**
- Read story and parent epic design
- Write test plan
- Create test stubs/skeletons

**Next:** `dev:implement`

---

### 7. Implementation (`dev:implement`)

**Hat:** `dev_implementer`

**Actions:**
- Read story and test plan
- Implement code changes
- Run tests to verify
- Create branch and commits
- **Check for PR feedback** (if PR exists)

**Triggers:**
- Initial: `dev.implement`
- Rejection loop: `dev.rejected`, `qe.rejected`
- **PR feedback** (new!)

**Next:** `dev:code-review`

---

### 8. Code Review (`dev:code-review`)

**Hat:** `dev_code_reviewer`

**Actions:**
- **Run CodeRabbit AI review** (`coderabbit review --agent --config team/coderabbit.yaml`)
- Parse findings by severity
- **Create Pull Request** in staging fork (`openshift-splat-team/<project>`)
- Link PR to story issue
- Make approval decision:
  - Errors > 0: REJECT
  - Warnings > 5: REJECT
  - Otherwise: APPROVE

**Decision Matrix:**
| Errors | Warnings | Decision |
|--------|----------|----------|
| > 0 | Any | REJECT |
| 0 | > 5 | REJECT |
| 0 | 1-5 | APPROVE |
| 0 | 0 | APPROVE |

**Next:**
- If approved: `qe:verify` (+ PR created)
- If rejected: `dev:implement` (with feedback)

---

### 9. PR Feedback Loop (NEW!)

**Hat:** `dev_implementer`

**Actions:**
- **Monitor staging PR for human comments**
- Parse review feedback:
  - Changes requested
  - Questions/clarifications
  - Suggestions
- **Make code changes** based on feedback
- Commit and push updates
- **Reply to comments** confirming changes
- Request re-review

**Frequency:** Every 15 minutes while story is active

**Triggers:**
- After PR creation (during `qe:verify` status)
- On new review comments
- Until PR is approved or merged

**Skill:** `pr-feedback-monitor`

---

### 10. QE Verification (`qe:verify`)

**Hat:** `qe_verifier`

**Actions:**
- Read test plan and acceptance criteria
- Run tests and check coverage
- Verify implementation against criteria

**Next:**
- If pass: `arch:sign-off`
- If fail: `dev:implement` (with feedback)

---

### 11. Sign-Off (`arch:sign-off`)

**Auto-advance** → `po:merge`

---

### 12. Merge Review (`po:merge`)

**Auto-advance** → `done`

---

### 13. Epic Monitoring (`arch:in_progress`)

**Hat:** `arch_monitor`

**Actions:**
- Monitor child stories
- Check if all stories are done
- When complete, advance to `po:accept`

**Next:** `po:accept`

**Human Gate:** Final acceptance of completed epic

---

## Human Review Gates

| Stage | Status | Action | Response |
|-------|--------|--------|----------|
| **Epic Triage** | `po:triage` | Approve/reject new epic | `Approved` / `Rejected: <reason>` |
| **Backlog** | `po:ready` | Activate epic to start | `start` / `activate` |
| **Design Review** | `po:design-review` | Review design doc | `Approved` / `Rejected: <feedback>` |
| **Plan Review** | `po:plan-review` | Review story breakdown | `Approved` / `Rejected: <feedback>` |
| **Epic Acceptance** | `po:accept` | Accept completed work | `Approved` / `Rejected: <feedback>` |
| **PR Review** (NEW!) | After PR creation | Review code in staging PR | GitHub PR review (approve/request changes) |

## Pull Request Workflow (NEW!)

### Staging PRs (openshift-splat-team/* forks)

1. **PR Created** - After `dev:code-review` approval
   - One story = one branch = one PR (atomic)
   - Links to story issue with `Closes` keyword
   - Includes commits, diff stats, CodeRabbit results

2. **Human Reviews PR** - Via GitHub UI
   - Review code changes
   - Add inline comments
   - Request changes or approve

3. **Superman Monitors PR** - Every 15 minutes
   - Checks for review comments
   - Parses feedback by category
   - Makes code changes
   - Updates PR and replies to comments

4. **Iteration Loop** - Until approved
   - Human reviews → requests changes
   - Superman responds → makes changes
   - Loop continues until approval

5. **PR Approved** - Ready for upstream

### Upstream PRs (openshift/* repos)

After staging PR is approved, **human creates upstream PR**:

```bash
gh pr create \
  --repo openshift/<project> \
  --base master \
  --head openshift-splat-team:<branch> \
  --title "Story #N: <title>"
```

## Automated Tools

### CodeRabbit Integration
- **When:** During `dev:code-review`
- **Config:** `team/coderabbit.yaml`
- **Output:** Structured JSON with findings
- **Decision:** Auto-approve/reject based on error count

### PR Creation
- **When:** After code review approval
- **Script:** `scripts/create-pr-for-story.sh`
- **Target:** `openshift-splat-team/<project>` forks
- **Linking:** PRs linked to issues via `Closes` keyword

### PR Feedback Monitoring (NEW!)
- **When:** Every 15 minutes after PR creation
- **Skill:** `pr-feedback-monitor`
- **Actions:**
  - Parse review comments
  - Make code changes
  - Reply to reviewers
  - Request re-review

## Rejection Loops

Superman handles feedback at multiple stages:

1. **Design Rejected** → Return to `arch:design` with feedback
2. **Plan Rejected** → Return to `arch:plan` with feedback
3. **Code Review Rejected** → Return to `dev:implement` with feedback
4. **QE Verification Failed** → Return to `dev:implement` with feedback
5. **PR Changes Requested** (NEW!) → Update PR with changes, request re-review

## Event Flow

```
Epic Created
    ↓
po:triage → (human approve) → po:backlog → (human activate)
    ↓
arch:design → lead:design-review → po:design-review → (human approve)
    ↓
arch:plan → lead:plan-review → po:plan-review → (human approve)
    ↓
arch:breakdown → lead:breakdown-review → po:ready → (human activate)
    ↓
Stories Created
    ↓
qe:test-design → dev:implement → dev:code-review
    ↓                                   ↓
    ↓                            CodeRabbit Review
    ↓                                   ↓
    ↓                            Create Staging PR ← (NEW!)
    ↓                                   ↓
    ↓                            Monitor PR Feedback ← (NEW!)
    ↓                                   ↓
qe:verify → arch:sign-off → po:merge → done
```

## Skills Reference

| Skill | Purpose |
|-------|---------|
| `board-scanner` | Scan project board for actionable issues |
| `status-workflow` | Update issue project status |
| `coderabbit-review` | Run CodeRabbit AI code review |
| `pr-feedback-monitor` (NEW!) | Monitor and respond to PR comments |

## Configuration Files

- `team/coderabbit.yaml` - CodeRabbit review rules
- `team/invariants/` - Team-wide coding standards
- `team/projects/<project>/invariants/` - Project-specific rules
- `team/knowledge/` - Team knowledge base
- `team/projects/<project>/knowledge/` - Project knowledge
- `team/members/superman-atlas/hats/*/knowledge/` - Hat-specific guides

## Commands for Humans

### Review Design
```bash
gh issue view 14 --repo openshift-splat-team/splat-team --web
# Review design doc, then comment: "Approved"
```

### Activate Epic
```bash
gh issue comment 14 --repo openshift-splat-team/splat-team --body "activate"
```

### Review Staging PR
```bash
gh pr view 3 --repo openshift-splat-team/cloud-credential-operator --web
# Review code, add comments, approve or request changes
```

### Create Upstream PR
```bash
cd projects/cloud-credential-operator
gh pr create --repo openshift/cloud-credential-operator \
  --base master \
  --head openshift-splat-team:story-25-multi-vcenter-support
```

## Monitoring Superman

### Check Status
```bash
bm status -t splat
```

### View Recent Activity
```bash
tail -f ~/.botminter/workspaces/splat/superman-atlas/.ralph/events-*.jsonl
```

### Check PR Feedback Status
```bash
# List all active PRs
for project in cloud-credential-operator cluster-cloud-controller-manager-operator cluster-storage-operator installer machine-api-operator; do
  echo "=== $project ==="
  gh pr list --repo "openshift-splat-team/$project" --state open
done
```

## Summary

**Automated:**
- Epic design and planning
- Story creation
- Code implementation
- CodeRabbit reviews
- PR creation
- PR feedback responses (NEW!)
- Test execution
- Status transitions

**Human Gates:**
- Epic approval
- Design approval
- Story breakdown approval
- Epic activation
- Final acceptance
- PR review and approval (NEW!)
- Upstream PR creation

This creates a **collaborative workflow** where superman handles the heavy lifting while humans provide strategic guidance and final approval! 🚀
