# Active Projects

**Team:** Splat Team  
**Last Updated:** 2026-05-01

---

## Overview

The Splat Team maintains forks of OpenShift components related to vSphere/VMware platform integration. All projects are forked under the `openshift-splat-team` GitHub organization.

**Fork Strategy:** Work in team forks, submit PRs to upstream when ready.

---

## Core Projects

### 1. vcf-migration-operator

**Fork:** https://github.com/openshift-splat-team/vcf-migration-operator  
**Upstream:** (new project, no upstream yet)  
**Language:** Go  
**Purpose:** Migrate workloads from VMware Cloud Foundation to OpenShift

**Key Responsibilities:**
- VM-to-container migration tooling
- VCF API integration
- Migration workflow orchestration

**Context:** `projects/vcf-migration-operator/CLAUDE.md`

---

### 2. installer

**Fork:** https://github.com/openshift-splat-team/installer  
**Upstream:** https://github.com/openshift/installer  
**Language:** Go  
**Purpose:** OpenShift cluster installation (vSphere provider support)

**Key Responsibilities:**
- vSphere platform provider implementation
- IPI (Installer-Provisioned Infrastructure) for vSphere
- Terraform provider integration for vSphere
- Pre-flight validation for vSphere environments

**Common Tasks:**
- Adding new vSphere configuration options
- Fixing installation failures on specific vSphere versions
- Updating terraform-provider-vsphere integration

**Context:** `projects/installer/CLAUDE.md`

---

### 3. machine-api-operator

**Fork:** https://github.com/openshift-splat-team/machine-api-operator  
**Upstream:** https://github.com/openshift/machine-api-operator  
**Language:** Go  
**Purpose:** Kubernetes-native machine provisioning for vSphere

**Key Responsibilities:**
- vSphere machine controller
- Machine health checks
- Auto-scaling integration
- Node provisioning and deprovisioning

**Common Tasks:**
- VM creation/deletion lifecycle
- Handling vSphere API errors gracefully
- Supporting new vSphere VM configurations

**Context:** `projects/machine-api-operator/CLAUDE.md`

---

### 4. cluster-cloud-controller-manager-operator

**Fork:** https://github.com/openshift-splat-team/cluster-cloud-controller-manager-operator  
**Upstream:** https://github.com/openshift/cluster-cloud-controller-manager-operator  
**Language:** Go  
**Purpose:** vSphere Cloud Controller Manager (CCM) integration

**Key Responsibilities:**
- Deploy and manage vSphere CCM
- Node initialization and tagging
- vSphere cloud provider integration
- Migration from in-tree to out-of-tree provider

**Common Tasks:**
- CCM version updates
- Node providerID management
- Cloud provider configuration

**Context:** `projects/cluster-cloud-controller-manager-operator/CLAUDE.md`

---

### 5. cloud-credential-operator

**Fork:** https://github.com/openshift-splat-team/cloud-credential-operator  
**Upstream:** https://github.com/openshift/cloud-credential-operator  
**Language:** Go  
**Purpose:** vSphere credential management

**Key Responsibilities:**
- vSphere credential provisioning for operators
- IAM-style permissions for vCenter
- Credential rotation and lifecycle
- Secure credential storage

**Common Tasks:**
- Adding new credential types
- Supporting different vSphere authentication methods
- Credential validation and pre-checks

**Context:** `projects/cloud-credential-operator/CLAUDE.md`

---

### 6. cluster-storage-operator

**Fork:** https://github.com/openshift-splat-team/cluster-storage-operator  
**Upstream:** https://github.com/openshift/cluster-storage-operator  
**Language:** Go  
**Purpose:** vSphere CSI driver deployment and management

**Key Responsibilities:**
- Deploy vSphere CSI driver
- StorageClass provisioning
- PersistentVolume lifecycle
- CSI driver version management

**Common Tasks:**
- CSI driver updates
- StorageClass configuration
- Volume provisioning troubleshooting

**Context:** `projects/cluster-storage-operator/CLAUDE.md`

---

### 7. vsphere-problem-detector

**Fork:** https://github.com/openshift-splat-team/vsphere-problem-detector  
**Upstream:** https://github.com/openshift/vsphere-problem-detector  
**Language:** Go  
**Purpose:** Proactive vSphere platform health monitoring

**Key Responsibilities:**
- Detect vSphere misconfigurations
- Validate vSphere prerequisites
- Alert on vSphere infrastructure issues
- Generate diagnostic reports

**Common Tasks:**
- Adding new health checks
- Improving diagnostic messages
- Supporting new vSphere versions

**Context:** `projects/vsphere-problem-detector/CLAUDE.md`

---

### 8. govmomi

**Fork:** https://github.com/openshift-splat-team/govmomi  
**Upstream:** https://github.com/vmware/govmomi  
**Language:** Go  
**Purpose:** VMware vSphere API Go client library

**Key Responsibilities:**
- vSphere API bindings for Go
- Used by all other vSphere-related projects
- API wrapper and utilities

**Note:** Upstream is VMware, not OpenShift. Submit PRs to vmware/govmomi.

**Context:** `projects/govmomi/CLAUDE.md`

---

### 9. provider-certification-plugins

**Fork:** https://github.com/openshift-splat-team/provider-certification-plugins  
**Upstream:** https://github.com/openshift/provider-certification-plugins  
**Language:** Go  
**Purpose:** vSphere provider certification tooling

**Key Responsibilities:**
- Certification test plugins for vSphere
- Platform validation checks
- Compliance verification

**Context:** `projects/provider-certification-plugins/CLAUDE.md`

---

### 10. opct

**Fork:** https://github.com/openshift-splat-team/opct  
**Upstream:** (new project)  
**Language:** Go  
**Purpose:** OpenShift Provider Certification Tool

**Key Responsibilities:**
- End-to-end provider certification workflow
- Test suite execution and reporting
- Certification artifact generation

**Context:** `projects/opct/CLAUDE.md`

---

### 11. release

**Fork:** https://github.com/openshift-splat-team/release  
**Upstream:** https://github.com/openshift/release  
**Language:** YAML, Go  
**Purpose:** OpenShift CI/CD configuration (Prow jobs)

**Key Responsibilities:**
- vSphere-specific Prow job definitions
- CI configuration for vSphere tests
- Test infrastructure as code

**Common Tasks:**
- Adding new vSphere e2e test jobs
- Updating vSphere test cluster configuration
- Debugging Prow job failures

**Context:** `projects/release/CLAUDE.md`

---

## Project Categories

### Installation & Provisioning
- `installer` - Cluster installation
- `machine-api-operator` - Node provisioning
- `cluster-cloud-controller-manager-operator` - Cloud provider integration

### Storage & Credentials
- `cluster-storage-operator` - CSI driver management
- `cloud-credential-operator` - Credential management

### Monitoring & Troubleshooting
- `vsphere-problem-detector` - Health checks
- `opct` - Certification testing

### Migration & Integration
- `vcf-migration-operator` - VCF migration
- `govmomi` - vSphere API client

### CI/CD
- `release` - Prow configuration
- `provider-certification-plugins` - Test plugins

---

## Cross-Project Dependencies

```
installer
  ├── depends on: govmomi, machine-api-operator
  └── used by: (entry point for cluster creation)

machine-api-operator
  ├── depends on: govmomi, cluster-cloud-controller-manager-operator
  └── used by: installer, cluster-autoscaler

cluster-cloud-controller-manager-operator
  ├── depends on: govmomi
  └── used by: machine-api-operator, other operators

cloud-credential-operator
  ├── depends on: govmomi
  └── used by: all operators needing vSphere credentials

cluster-storage-operator
  ├── depends on: cloud-credential-operator
  └── used by: workloads needing PersistentVolumes

vsphere-problem-detector
  ├── depends on: govmomi
  └── used by: cluster operators (health monitoring)

opct / provider-certification-plugins
  ├── depends on: all above operators
  └── used by: certification process
```

---

## Upstream Contribution Flow

1. **Work in fork** - `openshift-splat-team/<project>`
2. **Test in fork's Prow** - Use `release` repo config
3. **Create upstream PR** - From fork to `openshift/<project>`
4. **Upstream CI tests** - Must pass before merge
5. **Upstream review** - OpenShift maintainers approve
6. **Backport if needed** - Cherry-pick to release branches

---

## Project Selection Guide

| If you need to... | Work in... |
|-------------------|------------|
| Fix cluster installation on vSphere | `installer` |
| Fix node provisioning or scaling | `machine-api-operator` |
| Fix vSphere credential issues | `cloud-credential-operator` |
| Fix persistent volume provisioning | `cluster-storage-operator` |
| Add vSphere health check | `vsphere-problem-detector` |
| Fix vSphere API client bug | `govmomi` |
| Add vSphere e2e test | `release` |
| Migrate VMs from VCF | `vcf-migration-operator` |
| Fix cloud controller manager | `cluster-cloud-controller-manager-operator` |
| Add certification check | `opct` or `provider-certification-plugins` |

---

**See Also:**
- Individual project CLAUDE.md files in `projects/<project>/`
- [Tech Stack](tech-stack.md) - Common technologies across projects
- [Skills](skills.md) - Automation tools for project work
