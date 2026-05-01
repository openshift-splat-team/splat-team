# Glossary

**Team:** Splat Team  
**Last Updated:** 2026-05-01

---

## Team-Specific Terms

### Epic
A large body of work spanning multiple stories. Tracked as GitHub issue with `kind/epic` label. Goes through design → breakdown → implementation → acceptance workflow.

### Story
A single deliverable unit of work. Child of an epic. Tracked as GitHub issue with `kind/story` label and `parent/<epic-number>` label.

### Hat
A role persona that the superman agent wears while performing different responsibilities. Examples: PO hat, Architect hat, Dev hat, QE hat.

### Superman
The all-in-one team member role that wears all hats throughout the workflow.

### Team Manager
The role responsible for process improvement and team coordination. Handles retrospective action items.

### Human Gate
A status where human approval is required before proceeding. Examples: `lead:design-review`, `lead:plan-review`, `dev:code-review`, `po:accept`.

### Auto-Advance
A status that automatically transitions to the next status without human intervention. Examples: `arch:sign-off`, `po:merge`.

---

## vSphere Platform Terms

### vSphere
VMware's virtualization platform. OpenShift can run on vSphere infrastructure.

### vCenter
VMware's centralized management platform for vSphere environments.

### govmomi
Go library for interacting with VMware vSphere APIs. Used by all OpenShift vSphere operators.

### IPI (Installer-Provisioned Infrastructure)
OpenShift installation method where the installer provisions VMs on vSphere. Contrast with UPI (User-Provisioned Infrastructure).

### CCM (Cloud Controller Manager)
Kubernetes component that integrates with cloud providers. vSphere CCM manages node lifecycle and providerID.

### CSI (Container Storage Interface)
Kubernetes standard for storage plugins. vSphere CSI driver provisions persistent volumes from vSphere datastores.

### must-gather
OpenShift debugging tool that collects cluster diagnostics. vSphere-specific must-gather collects vCenter logs and configuration.

### VCF (VMware Cloud Foundation)
VMware's integrated cloud infrastructure platform. We're building migration tooling from VCF to OpenShift.

---

## OpenShift Terms

### Prow
OpenShift's CI/CD system based on Kubernetes. Runs e2e tests, presubmit checks, and periodic jobs.

### Presubmit
Prow job that runs on PR before merge. Must pass for PR to be mergeable.

### Periodic
Prow job that runs on a schedule (e.g., nightly). Used for long-running e2e tests.

### E2E Test
End-to-end test that validates full cluster functionality on real infrastructure. vSphere e2e tests run on actual vSphere clusters.

### Release Payload
OpenShift release artifact containing all operator images. Built from component repos.

### Operator
Kubernetes controller that manages custom resources. OpenShift is composed of many operators (installer, machine-api-operator, etc.).

### ClusterOperator
OpenShift custom resource that reports operator health status (Available, Progressing, Degraded).

### Machine API
OpenShift abstraction for provisioning nodes. machine-api-operator manages vSphere VMs as Kubernetes Machine resources.

---

## GitHub / Process Terms

### gh Skill
BotMinter skill that wraps GitHub CLI (`gh`). Used for all GitHub operations (issues, PRs, projects).

### Projects v2
GitHub's project management tool. Splat Team uses Projects v2 with custom Status field for tracking workflow states.

### Status Field
GitHub Projects v2 single-select field used to track issue state (e.g., `po:triage`, `dev:implement`, `done`).

### Kind Label
GitHub label indicating issue type. Values: `kind/epic`, `kind/story`, `kind/docs`, `kind/process-improvement`.

### Parent Label
GitHub label linking story to epic. Format: `parent/<epic-number>`.

### Sprint Milestone
GitHub milestone representing 2-week sprint. Stories are assigned to sprint milestones.

---

## Workflow States

See [Status Transitions](../statuses/transitions.md) for full definitions. Key states:

### po:triage
New epic awaiting PO evaluation.

### lead:design-review
Design doc awaiting human review (human gate).

### lead:plan-review
Story breakdown awaiting human review (human gate).

### dev:code-review
PR awaiting human review (human gate).

### po:accept
Completed epic awaiting human acceptance (human gate).

### arch:sign-off
Final architect verification (auto-advance).

### po:merge
Final merge gate (auto-advance after human PR approval).

---

## Common Abbreviations

| Abbreviation | Full Term |
|--------------|-----------|
| **PO** | Product Owner |
| **QE** | Quality Engineering |
| **SRE** | Site Reliability Engineering |
| **CW** | Content Writer |
| **PR** | Pull Request |
| **CI** | Continuous Integration |
| **CD** | Continuous Delivery |
| **E2E** | End-to-End |
| **API** | Application Programming Interface |
| **ADR** | Architectural Decision Record |
| **IPI** | Installer-Provisioned Infrastructure |
| **UPI** | User-Provisioned Infrastructure |
| **CCM** | Cloud Controller Manager |
| **CSI** | Container Storage Interface |
| **VCF** | VMware Cloud Foundation |
| **VM** | Virtual Machine |

---

## Tech Stack Terms

### Go
Primary programming language for OpenShift operators.

### Python
Scripting language used for BotMinter skills and automation.

### MkDocs
Documentation framework used for team docs (`docs/` directory).

### pytest
Python testing framework used in skills.

### Jest
JavaScript testing framework (used if any JS tooling present).

### YAML
Configuration file format used extensively (Prow jobs, Kubernetes manifests).

---

## Project-Specific Terms

### vcf-migration-operator
Operator for migrating VMs from VMware Cloud Foundation to OpenShift. New project with no upstream yet.

### installer
OpenShift installer. vSphere provider support lives here. Upstream: `openshift/installer`.

### machine-api-operator
Kubernetes Machine API implementation for vSphere. Upstream: `openshift/machine-api-operator`.

### cloud-credential-operator
Manages vSphere credentials for operators. Upstream: `openshift/cloud-credential-operator`.

### vsphere-problem-detector
Proactive health monitoring for vSphere platform. Upstream: `openshift/vsphere-problem-detector`.

---

## Anti-Patterns (Terms to Avoid)

❌ **"The agent"** - Be specific: which hat? (PO, Architect, Dev, QE)  
✅ **"[Architect Hat]"**

❌ **"Review the code"** - Ambiguous: QE verification or human PR review?  
✅ **"[QE Hat] verifying tests pass"** or **"Awaiting human code review"**

❌ **"VMware"** - Be specific: vSphere, vCenter, or VCF?  
✅ **"vSphere platform"**

❌ **"The project"** - Which project? 11 active repos  
✅ **"installer project"**

---

**See Also:**
- [Status Transitions](../statuses/transitions.md) - Full status definitions
- [Role Responsibilities](../roles/responsibilities.md) - Hat definitions
- [Projects](../architecture/projects.md) - Project descriptions
