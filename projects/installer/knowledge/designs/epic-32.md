---
title: vsphere-multi-account-credential-management
authors:
  - "@superman-atlas"
reviewers:
  - TBD
approvers:
  - TBD
api-approvers:
  - None
creation-date: 2026-05-05
last-updated: 2026-05-05
status: provisional
tracking-link:
  - https://github.com/openshift-splat-team/splat-team/issues/32
  - https://redhat.atlassian.net/browse/OCPSTRAT-2933
---

# vSphere Multi-Account Credential Management

## Overview

Enable OpenShift installer and vSphere integration to use distinct vCenter credentials for provisioning operations (high privilege) versus day-2 cluster operations (restricted privilege). This enhancement reduces blast radius from credential compromise, improves compliance posture with separation of duties, and enables better auditability of OpenShift component actions in vCenter audit logs.

The design supports two configuration methods: install-config.yaml for automation and ~/.vsphere/credentials file for interactive deployments. Both methods support multi-vCenter deployments with per-vCenter, per-component credential management.

## Motivation

### Current State and Problems

OpenShift on vSphere currently uses a single shared vCenter account across all components:
- **Installer**: Bootstrap and cluster provisioning
- **Machine API Operator**: VM lifecycle management
- **vSphere CSI Driver**: Storage operations
- **Cloud Controller Manager**: Node discovery and management
- **Diagnostics/Must-Gather**: System inspection

**Critical Issues:**
1. **Excessive privilege exposure**: Every component has access to all privileges regardless of actual operational needs
2. **Large blast radius**: Compromised credentials in any component grant comprehensive access to both cluster and infrastructure
3. **Poor auditability**: vCenter audit logs cannot distinguish which OpenShift component performed actions
4. **Compliance conflicts**: Single-account architecture violates SOC2 and PCI-DSS separation of duties requirements
5. **Complex credential rotation**: Updating credentials requires coordinated simultaneous changes across all components

### User Stories

**Story 1: Security-Conscious Administrator**
```
As a platform security administrator
I want to provide restricted operational credentials to OpenShift cluster components
So that a compromised container cannot provision new VMs or delete production infrastructure
```

**Story 2: Compliance Officer**
```
As a compliance officer
I need OpenShift deployments to separate provisioning from operational privileges
So that our vSphere environment meets SOC2 Type II separation of duties requirements
```

**Story 3: Operations Engineer**
```
As a vSphere operations engineer
I want vCenter audit logs to distinguish installer actions from machine-api actions
So that I can quickly identify which component caused infrastructure changes during incidents
```

### Goals

1. **Privilege separation**: Enable distinct credentials for:
   - Installer (provisioning)
   - Machine API Operator (VM lifecycle)
   - vSphere CSI Driver (storage)
   - Cloud Controller Manager (read-only node discovery)
   - Diagnostics (read-only inspection)

2. **Multi-vCenter support**: Allow different credentials per vCenter instance in multi-vCenter topologies

3. **Migration path**: Support transitioning existing single-credential clusters to multi-credential without downtime

4. **Backward compatibility**: Maintain support for single-credential deployments (passthrough mode)

5. **Auditability**: Enable vCenter audit logs to attribute actions to specific OpenShift components

### Non-Goals

1. **Automated account creation**: Cloud-credential-operator will NOT automatically create vCenter accounts. Account provisioning remains an infrastructure team responsibility through established workflows.

2. **Dynamic privilege escalation**: Components will not request additional privileges at runtime

3. **Multi-cluster credential sharing**: Credentials are cluster-scoped; sharing across clusters is out of scope

4. **vSphere permission automation beyond validation**: The installer validates provided credentials but does not modify vSphere permissions

## Proposal

### Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│ Installation Phase                                                  │
│                                                                     │
│  install-config.yaml OR ~/.vsphere/credentials                     │
│         │                                                           │
│         ▼                                                           │
│  ┌──────────────────┐                                              │
│  │  Installer       │  Uses: provisioning credentials              │
│  │  (openshift-     │  - ~45 privileges                            │
│  │   install)       │  - Creates VMs, networks, disks              │
│  └────────┬─────────┘  - Creates component secrets                 │
│           │                                                         │
│           │  Creates 5 component secrets in kube-system:           │
│           │  • vsphere-cloud-credentials (operational creds)       │
│           │  • machine-api-credentials                             │
│           │  • csi-driver-credentials                              │
│           │  • diagnostics-credentials                             │
│           │  • cloud-controller-credentials                        │
│           │                                                         │
│           ▼                                                         │
└─────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────┐
│ Day-2 Cluster Operations                                            │
│                                                                     │
│  ┌──────────────────┐   ┌──────────────────┐                       │
│  │  Machine API     │   │  CSI Driver      │                       │
│  │  Operator        │   │                  │                       │
│  │  • ~35 privs     │   │  • ~15 privs     │                       │
│  │  • VM lifecycle  │   │  • Storage ops   │                       │
│  └──────────────────┘   └──────────────────┘                       │
│                                                                     │
│  ┌──────────────────┐   ┌──────────────────┐                       │
│  │  Cloud           │   │  Diagnostics     │                       │
│  │  Controller Mgr  │   │  (must-gather)   │                       │
│  │  • ~10 privs     │   │  • ~5 privs      │                       │
│  │  • Read-only     │   │  • Read-only     │                       │
│  └──────────────────┘   └──────────────────┘                       │
│                                                                     │
│  Each component reads from its own secret with restricted creds    │
└─────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────┐
│ Multi-vCenter Secret Format                                         │
│                                                                     │
│  machine-api-credentials secret:                                    │
│    vcenter1.example.com.username: "machine-api@vsphere.local"      │
│    vcenter1.example.com.password: "pass1"                          │
│    vcenter2.example.com.username: "machine-api@domain"             │
│    vcenter2.example.com.password: "pass2"                          │
│                                                                     │
│  Components query credentials by vCenter FQDN                       │
└─────────────────────────────────────────────────────────────────────┘
```

### Components and Interfaces

#### 1. Installer (openshift-install)

**Responsibilities:**
- Parse component-specific credentials from install-config.yaml or ~/.vsphere/credentials
- Use provisioning credentials for bootstrap and cluster creation
- Create component-specific secrets in kube-system namespace
- Validate credential format and connectivity
- Persist installer credentials for day-2 operations if requested

**Interfaces:**
- **Input**: install-config.yaml platform.vsphere.componentCredentials OR ~/.vsphere/credentials file
- **Output**: 5 secrets in kube-system namespace (vsphere-cloud-credentials, machine-api-credentials, csi-driver-credentials, diagnostics-credentials, cloud-controller-credentials)

**Changes Required:**
- `pkg/types/vsphere/platform.go`: Add ComponentCredentials struct
- `pkg/asset/installconfig/vsphere/validation.go`: Add credential validation
- `pkg/asset/manifests/vspherecomponentsecrets.go`: New asset for component secrets
- `data/data/install.openshift.io_installconfigs.yaml`: Update CRD schema

#### 2. Cloud-Credential-Operator (CCO)

**Responsibilities:**
- Validate each component's credentials have required vSphere privileges
- Call vSphere AuthorizationManager.FetchUserPrivilegeOnEntities()
- Compare returned privileges against component requirements
- Report specific missing privileges if validation fails
- Refuse to provision clusters with incomplete credentials

**Interfaces:**
- **Input**: Component secrets in kube-system namespace
- **Output**: CredentialsRequest status with validation results

**Changes Required:**
- `pkg/vsphere/actuator.go`: Add privilege validation logic
- `pkg/vsphere/privileges.go`: Define required privileges per component
- `pkg/vsphere/client.go`: Add AuthorizationManager API calls

#### 3. Machine API Operator

**Responsibilities:**
- Use machine-api-credentials secret for VM operations
- Support multi-vCenter credential lookup by FQDN
- Maintain backward compatibility with single-credential passthrough

**Interfaces:**
- **Input**: machine-api-credentials secret with per-vCenter keys
- **vSphere API calls**: ~35 privileges for VM lifecycle

**Changes Required:**
- Update credential loading to check for per-vCenter keys first, fall back to legacy single credential

#### 4. vSphere CSI Driver

**Responsibilities:**
- Use csi-driver-credentials secret for storage operations
- Support multi-vCenter credential lookup

**Interfaces:**
- **Input**: csi-driver-credentials secret
- **vSphere API calls**: ~15 privileges for storage operations

**Changes Required:**
- Update credential loading for multi-vCenter support

#### 5. Cloud Controller Manager

**Responsibilities:**
- Use cloud-controller-credentials secret for node discovery
- Read-only operations (~10 privileges)

**Interfaces:**
- **Input**: cloud-controller-credentials secret
- **vSphere API calls**: Read-only node and infrastructure queries

#### 6. Diagnostics (must-gather)

**Responsibilities:**
- Use diagnostics-credentials secret for cluster inspection
- Read-only operations (~5 privileges)

**Interfaces:**
- **Input**: diagnostics-credentials secret
- **vSphere API calls**: Read-only diagnostics queries

### Implementation Details

#### Credential Input Methods

**Method 1: install-config.yaml**
```yaml
platform:
  vsphere:
    vcenters:
    - server: vcenter1.example.com
      username: installer@vsphere.local
      password: installer-password
      componentCredentials:
        machineAPI:
          username: machine-api@vsphere.local
          password: machine-api-password
        csiDriver:
          username: csi@vsphere.local
          password: csi-password
        cloudController:
          username: cloud-controller@vsphere.local
          password: cloud-controller-password
        diagnostics:
          username: diagnostics@vsphere.local
          password: diagnostics-password
```

**Method 2: ~/.vsphere/credentials**
```ini
[vcenter1.example.com]
user = installer@vsphere.local
password = installer-password
machine-api.user = machine-api@vsphere.local
machine-api.password = machine-api-password
csi-driver.user = csi@vsphere.local
csi-driver.password = csi-password
cloud-controller.user = cloud-controller@vsphere.local
cloud-controller.password = cloud-controller-password
diagnostics.user = diagnostics@vsphere.local
diagnostics.password = diagnostics-password

[vcenter2.example.com]
user = installer@vsphere.local
password = installer-password
# Component credentials...
```

**File permissions enforcement**: The installer MUST verify ~/.vsphere/credentials has mode 0600 and refuse to proceed if permissions are too open.

#### Secret Generation Logic

The installer creates component secrets with this structure:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: machine-api-credentials
  namespace: kube-system
type: Opaque
stringData:
  vcenter1.example.com.username: "machine-api@vsphere.local"
  vcenter1.example.com.password: "machine-api-password"
  vcenter2.example.com.username: "machine-api@domain"
  vcenter2.example.com.password: "machine-api-password"
```

**Atomic Transition**: All component secrets must be created before removing installer credentials from the cluster. The transition is atomic:
1. Create all 5 component secrets
2. Verify all secrets exist and are valid
3. Update vsphere-cloud-credentials to use operational credentials
4. Only then mark installation complete

#### Privilege Validation

CCO validates credentials by calling vSphere API:

```go
// AuthorizationManager.FetchUserPrivilegeOnEntities(entities, user)
privileges, err := authMgr.FetchUserPrivilegeOnEntities(
    ctx,
    []types.ManagedObjectReference{clusterRef, datacenterRef},
    "machine-api@vsphere.local",
)

// Compare with required privileges
required := []string{
    "VirtualMachine.Config.AddNewDisk",
    "VirtualMachine.Config.RemoveDisk",
    "VirtualMachine.Interact.PowerOn",
    // ... ~35 total for machine-api
}

missing := findMissingPrivileges(privileges, required)
if len(missing) > 0 {
    return fmt.Errorf("machine-api credentials missing privileges: %v", missing)
}
```

#### Backward Compatibility (Passthrough Mode)

If per-component credentials are not provided:
- Installer uses legacy single-credential behavior
- Creates vsphere-cloud-credentials with installer credentials
- Components fall back to vsphere-cloud-credentials secret
- No changes to existing cluster deployments

#### Migration Path for Existing Clusters

Existing single-credential clusters can migrate:
1. Create new component-specific vCenter accounts with restricted privileges
2. Create new component secrets in kube-system with restricted credentials
3. Update component operators to use new secrets (rolling update)
4. Components fall back to vsphere-cloud-credentials if component secret not found
5. Zero downtime during transition

### Risks and Mitigations

| Risk | Impact | Mitigation |
|------|--------|-----------|
| Increased setup complexity | Medium | Provide automation scripts (govc, PowerCLI) for account creation |
| Credential misconfiguration | High | CCO validates all credentials before cluster provisioning |
| Missing privileges cause runtime failures | High | Installer pre-validates privileges, refuses to proceed if incomplete |
| Credential rotation complexity | Medium | Document credential rotation procedures per component |
| Multi-vCenter credential mapping errors | Medium | Validate FQDN matching during installation |

### Drawbacks

1. **Setup overhead**: Administrators must create 4-5 vCenter accounts instead of 1
2. **Documentation burden**: More complex credential lifecycle documentation
3. **Troubleshooting complexity**: Credential issues may be component-specific
4. **Migration risk**: Existing clusters require careful migration planning

## Alternatives (Not Implemented)

### Alternative 1: CCO-Minted Accounts

**Approach**: Have cloud-credential-operator automatically create vCenter accounts with appropriate privileges.

**Why Rejected**: Conflicts with enterprise security models where infrastructure teams control account provisioning through established workflows (Active Directory, LDAP sync, approval processes). Requires installer credentials to have administrative privileges to create accounts, which contradicts the goal of privilege reduction.

### Alternative 2: Single Account with Least-Privilege Union

**Approach**: Use one account with the union of all component privileges (least privilege across all needs).

**Why Rejected**: Solves the excessive privilege problem but does not address:
- Blast radius (still one account to compromise)
- Auditability (cannot distinguish component actions in vCenter logs)
- Compliance separation of duties requirements

### Alternative 3: Runtime Privilege Escalation

**Approach**: Start with minimal privileges, request additional privileges when needed.

**Why Rejected**: vSphere does not support runtime privilege requests. Privileges must be assigned to accounts at provisioning time by vSphere administrators.

## Acceptance Criteria

### AC1: Install New Cluster with Component Credentials
```gherkin
Given an install-config.yaml with componentCredentials for all components
When the installer creates the vSphere cluster
Then the installer creates 5 component secrets in kube-system
And each secret contains per-vCenter credentials
And each component uses its respective secret for vSphere API calls
And installation completes successfully
```

### AC2: Multi-vCenter Credential Support
```gherkin
Given a multi-vCenter deployment with different credentials per vCenter
When components query vSphere APIs
Then each component correctly selects credentials by vCenter FQDN
And all vCenters are accessible with their respective credentials
```

### AC3: Credential Validation Prevents Incomplete Deployments
```gherkin
Given component credentials with missing required privileges
When the cloud-credential-operator validates credentials
Then CCO reports specific missing privileges
And installation is blocked until credentials are corrected
And error messages identify which component and which privilege is missing
```

### AC4: Backward Compatibility with Single Credential
```gherkin
Given an install-config.yaml without componentCredentials
When the installer creates the vSphere cluster
Then the installer uses legacy single-credential behavior
And vsphere-cloud-credentials secret is created with installer credentials
And all components fall back to vsphere-cloud-credentials
And installation completes successfully
```

### AC5: Migration from Single to Multi-Credential
```gherkin
Given an existing cluster with single-credential deployment
When administrator creates component secrets with restricted credentials
And components are updated to use component secrets
Then components transition to restricted credentials without downtime
And vsphere-cloud-credentials is updated to operational credentials
And all cluster operations continue normally
```

### AC6: Atomic Credential Transition
```gherkin
Given the installer is creating component secrets
When any secret creation fails
Then no secrets are created (atomic rollback)
And installation fails with clear error message
And cluster is not left in partially-configured state
```

### AC7: Auditability in vCenter Logs
```gherkin
Given a cluster with component-specific credentials
When machine-api creates a VM
And cloud-controller queries node information
Then vCenter audit logs show different users for each action
And administrators can attribute actions to specific OpenShift components
```

## Impact on Existing System

### Installer (openshift/installer)

**Changes:**
- New ComponentCredentials struct in vsphere platform types
- New validation logic for component credentials
- New manifest generation for component secrets
- Update install-config CRD schema

**Backward Compatibility**: All changes are additive. Existing install-config.yaml files without componentCredentials continue to work.

### Cloud-Credential-Operator

**Changes:**
- Add vSphere privilege validation logic
- Add AuthorizationManager API client
- Define required privileges per component

**Impact**: Additional validation step during cluster creation. No impact on existing passthrough-mode clusters.

### Machine API Operator

**Changes:**
- Update credential loading to check component secret first
- Add fallback to vsphere-cloud-credentials for backward compatibility

**Impact**: No breaking changes. Existing clusters continue using vsphere-cloud-credentials.

### vSphere CSI Driver, Cloud Controller Manager, Diagnostics

**Changes**: Similar to Machine API - component secret first, fallback to vsphere-cloud-credentials.

**Impact**: No breaking changes. Backward compatible.

### Documentation

**New Documentation Required:**
- Component privilege requirements reference
- Account creation procedures (govc and PowerCLI scripts)
- install-config.yaml examples with componentCredentials
- ~/.vsphere/credentials format and usage
- Migration guide for existing clusters
- Troubleshooting credential validation failures

### Testing

**New Test Coverage:**
- E2E test: Install with componentCredentials
- E2E test: Install without componentCredentials (backward compatibility)
- E2E test: Multi-vCenter deployment
- Unit test: Credential validation logic
- Unit test: Privilege comparison logic
- Integration test: Secret generation and component credential loading
- Upgrade test: Single-credential to multi-credential migration

## Security Considerations

### Threat Model

**Threat 1: Credential Exposure in install-config.yaml**
- **Risk**: install-config.yaml stored in version control exposes credentials
- **Mitigation**: Document credential handling best practices. Recommend ~/.vsphere/credentials for interactive deployments. Encourage secret management integration (Vault, etc.) for automation.

**Threat 2: Credential Exposure in ~/.vsphere/credentials**
- **Risk**: File permissions allow unauthorized access
- **Mitigation**: Installer enforces mode 0600 on ~/.vsphere/credentials and refuses to proceed if permissions are too open.

**Threat 3: Component Compromise**
- **Risk**: Compromised component container accesses credentials
- **Mitigation**: Each component has only its required privileges. Compromising diagnostics (read-only, ~5 privileges) does not enable VM creation or storage modification.

**Threat 4: Privilege Escalation**
- **Risk**: Component attempts to use credentials beyond assigned privileges
- **Mitigation**: vSphere enforces privilege restrictions. Components cannot escalate beyond assigned privileges.

**Threat 5: Missing Privilege Detection**
- **Risk**: Cluster deployed with incomplete privileges, fails at runtime
- **Mitigation**: CCO validates all credentials before cluster provisioning. Installation fails fast if privileges are missing.

### Credential Storage

**In-Cluster Storage**: Component credentials stored in Kubernetes secrets in kube-system namespace.
- Secrets encrypted at rest if etcd encryption is enabled
- RBAC restricts secret access to component service accounts
- Secrets are cluster-scoped, not namespace-scoped

**Installer Credentials**: Not persisted in cluster by default. If persistence is requested (for day-2 operations), stored in separate secret with RBAC restrictions.

### Audit and Compliance

**SOC2 Type II Separation of Duties**: Component-specific credentials enable separation between provisioning and operational activities.

**PCI-DSS Least Privilege**: Each component has minimum required privileges for its function.

**vCenter Audit Logs**: Component-specific usernames enable attribution of actions to specific OpenShift components.

## Test Plan

### Unit Tests
- Credential parsing from install-config.yaml
- Credential parsing from ~/.vsphere/credentials
- Secret generation with multi-vCenter keys
- Privilege validation logic
- Privilege comparison (required vs actual)
- Component credential loading with fallback

### Integration Tests
- CCO validates credentials against live vSphere
- Installer creates all component secrets
- Components load credentials from correct secret
- Multi-vCenter credential selection by FQDN

### E2E Tests
1. **Full multi-credential deployment**: Install with componentCredentials, verify all components use restricted credentials
2. **Backward compatibility**: Install without componentCredentials, verify passthrough mode
3. **Multi-vCenter deployment**: Install with 2+ vCenters, verify per-vCenter credential usage
4. **Privilege validation failure**: Provide incomplete credentials, verify installation blocked with clear error
5. **Migration test**: Deploy single-credential cluster, migrate to multi-credential, verify zero downtime

### Scale Tests
- Multi-vCenter deployment with 5+ vCenters
- Cluster with 100+ nodes using restricted machine-api credentials
- Credential rotation across all components

## Graduation Criteria

### Dev Preview → Tech Preview
- ✅ Core functionality implemented (credential parsing, secret generation, component usage)
- ✅ Basic validation (CCO privilege checking)
- ✅ Unit and integration tests passing
- ✅ Documentation for configuration methods
- ⚠️ Known limitations documented

### Tech Preview → GA
- ✅ Comprehensive E2E test coverage (all test plan scenarios)
- ✅ Scale testing with 5+ vCenters and 100+ nodes
- ✅ Migration guide and automation
- ✅ Account creation automation (govc and PowerCLI scripts)
- ✅ Production documentation (Red Hat Docs)
- ✅ Support procedures for credential troubleshooting
- ✅ No critical bugs in Tech Preview feedback
- ✅ Performance impact analysis (credential validation overhead)

### Removing a Deprecated Feature
Not applicable - this is a new feature with backward compatibility.

## Upgrade / Downgrade Strategy

### Upgrade (Single-Credential → Multi-Credential)

**Cluster Upgrade Path:**
1. Existing clusters on older OpenShift version continue using single credential
2. Upgrade to version with multi-credential support (no automatic migration)
3. Administrator manually creates component secrets if desired
4. Components detect component secrets and switch from vsphere-cloud-credentials
5. Administrator verifies all components operating normally
6. Administrator removes or restricts vsphere-cloud-credentials privileges

**Zero Downtime**: Component updates are rolling. Fallback to vsphere-cloud-credentials ensures continuous operation during migration.

### Downgrade (Multi-Credential → Single-Credential)

**Cluster Downgrade Path:**
1. Ensure vsphere-cloud-credentials exists with full privileges
2. Downgrade OpenShift version
3. Components revert to vsphere-cloud-credentials (component secrets ignored)
4. Administrator may delete component secrets if desired

**Risk**: If vsphere-cloud-credentials was removed after migration, downgrade requires recreating it with full privileges before downgrade.

**Mitigation**: Document retention of vsphere-cloud-credentials during migration window.

## Version Skew Strategy

### Installer vs Cluster Version Skew

**Scenario**: Newer installer with multi-credential support installs older cluster version without multi-credential support.

**Behavior**: Installer creates component secrets, but older components ignore them and use vsphere-cloud-credentials. No failures, just unused secrets.

**Recommendation**: Match installer version to cluster version.

### Component Version Skew During Upgrade

**Scenario**: Cluster upgrading from single-credential to multi-credential version.

**Behavior**: Components upgrade one-by-one. Older components use vsphere-cloud-credentials, newer components use component secrets. Mixed mode is safe because both secrets exist.

**Requirement**: vsphere-cloud-credentials MUST remain valid until all components upgraded.

## Operational Aspects of API Extensions

### install-config.yaml API Extension

**New field**: `platform.vsphere.vcenters[].componentCredentials`

**Type**: Object with fields:
- `machineAPI`: {username, password}
- `csiDriver`: {username, password}
- `cloudController`: {username, password}
- `diagnostics`: {username, password}

**Validation**: All fields optional. If provided, all sub-fields (username, password) must be present.

**Backward Compatibility**: Field is optional. Existing install-config.yaml without this field continues to work.

### Secrets API

No new API. Uses existing Kubernetes Secret resource with specific key naming convention:
- `{vcenter-fqdn}.username`
- `{vcenter-fqdn}.password`

## Support Procedures

### Diagnostic Procedure 1: Credential Validation Failure

**Symptom**: Installation fails with "missing privileges" error from CCO.

**Diagnosis Steps:**
1. Read CCO logs: `oc logs -n openshift-cloud-credential-operator`
2. Identify component and missing privileges from error message
3. Verify vCenter account exists: `govc about -u <component-user>@<vcenter>`
4. Check assigned privileges: `govc role.ls -u <component-user>@<vcenter>`

**Resolution:**
1. Grant missing privileges using provided scripts or manually
2. Delete CredentialsRequest: `oc delete credentialsrequest -n openshift-cloud-credential-operator <component>`
3. CCO will re-validate with updated credentials
4. Verify installation proceeds

### Diagnostic Procedure 2: Component Cannot Connect to vCenter

**Symptom**: Component logs show vSphere connection errors.

**Diagnosis Steps:**
1. Verify component secret exists: `oc get secret -n kube-system <component>-credentials`
2. Decode secret and verify credentials: `oc get secret -n kube-system <component>-credentials -o yaml`
3. Test credentials manually: `govc about -u <user>:<pass>@<vcenter>`
4. Check vCenter FQDN in secret matches component's vCenter configuration

**Resolution:**
1. If credentials incorrect: Update secret with correct credentials
2. If FQDN mismatch: Update secret keys to match vCenter FQDN
3. Restart component pods: `oc delete pod -n openshift-machine-api -l app=<component>`

### Diagnostic Procedure 3: Multi-vCenter Credential Mismatch

**Symptom**: Component operates on some vCenters but not others.

**Diagnosis Steps:**
1. List vCenters in cluster: `oc get infrastructure cluster -o yaml | grep vcenter`
2. Check component secret for all vCenter entries: `oc get secret -n kube-system <component>-credentials -o yaml`
3. Verify each vCenter FQDN has corresponding username/password keys

**Resolution:**
1. Add missing vCenter credentials to secret
2. Restart component pods
3. Verify all vCenters accessible

### Diagnostic Procedure 4: Migration from Single to Multi-Credential Fails

**Symptom**: Components fail after creating component secrets.

**Diagnosis Steps:**
1. Verify vsphere-cloud-credentials still exists and is valid
2. Check component secret format matches expected multi-vCenter format
3. Review component logs for credential loading errors
4. Verify component version supports multi-credential feature

**Resolution:**
1. If component secret malformed: Delete and recreate with correct format
2. If component version too old: Upgrade to version with multi-credential support
3. If vsphere-cloud-credentials invalid: Update fallback credentials
4. Roll back by deleting component secrets (components revert to vsphere-cloud-credentials)

## Infrastructure Needed

### Development Infrastructure
- vSphere test environment with multiple vCenters
- Ability to create and configure vCenter accounts with specific privilege sets
- OpenShift CI integration for E2E testing

### Production Infrastructure
No special infrastructure beyond standard vSphere deployment requirements.

### Documentation Infrastructure
- Update Red Hat OpenShift documentation portal
- Sample govc and PowerCLI scripts in openshift/installer repository
- Component privilege reference table in documentation

---

## Implementation Progress

Stories completed as of 2026-05-09:

| Story | Title | Status | PR |
|-------|-------|--------|----|
| #35 | vSphere ComponentCredentials API Types | ✅ Done | openshift-splat-team/installer#14 |
| #36 | openshift/api MachineProviderSpec ComponentCredentials | ✅ Done | openshift-splat-team/api#2 |
| #37 | CCO Per-Component Privilege Validation | ✅ Done | openshift-splat-team/cloud-credential-operator#7 |
| #38 | CCO Credential Distribution to Component Secrets | ✅ Done | openshift-splat-team/cloud-credential-operator#8 |
| #39 | Component Operator Credential Loading | ✅ Done | MAO#4, CSO#4, CCMO#4 |
| #40 | Installer Pre-flight Component Credential Validation | ✅ Done | openshift-splat-team/installer#15 |
| #41 | vCenter Role Creation Scripts for Per-Component Credentials | ✅ Done | openshift-splat-team/installer#16 |
| #42 | Per-Component Credential Privilege Documentation | ✅ Done | openshift-splat-team/installer#18 |
| #43 | E2E Test Suite for Per-Component Credential Installation | ✅ Done | openshift-splat-team/installer#17 |

## Implementation Notes

This design implements the vSphere multi-account credential management enhancement as specified in OCPSTRAT-2933. The implementation prioritizes security through privilege separation while maintaining backward compatibility with existing single-credential deployments.

**Key implementation repositories:**
- openshift/installer (credential parsing, secret generation, validation)
- openshift/cloud-credential-operator (privilege validation)
- openshift/machine-api-operator (credential loading)
- openshift/vsphere-csi-driver (credential loading)
- openshift/cloud-provider-vsphere (credential loading)

**Estimated implementation timeline:**
- Dev Preview: 1 sprint (credential parsing, basic secret generation)
- Tech Preview: 2 sprints (CCO validation, component integration, E2E tests)
- GA: 2 sprints (scale testing, documentation, support procedures)
