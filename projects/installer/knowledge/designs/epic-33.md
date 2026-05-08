# vSphere Multi-Account Credential Management

**Epic**: #33  
**Status**: Design  
**Last Updated**: 2026-05-06

## Overview

Enable OpenShift installer / vSphere integration to use distinct vCenter credentials for provisioning (high privilege) vs day-2 operations (restricted), reducing blast radius and improving compliance.

This enhancement addresses critical security and compliance requirements by enabling component-specific credential management rather than relying on a single shared vCenter account across all OpenShift components.

## Motivation

Current OpenShift deployments on vSphere utilize one vCenter account across all components, creating security and compliance challenges:

- **Privilege Overexposure**: All components access the full credential set regardless of actual needs
- **Audit Limitations**: vCenter logs cannot distinguish which OpenShift component performed actions
- **Compliance Gaps**: Single-account models conflict with SOC2 separation-of-duties requirements
- **Credential Rotation Friction**: Updating credentials requires simultaneous changes across all components

## Goals

1. **Privilege Separation**: Enable separate provisioning vs operational credentials for:
   - Machine API (including Cluster API)
   - Storage (CSI Driver)
   - Cloud Controller
   - Diagnostics (vSphere Problem Detector)

2. **Auditability**: Enable distinction between installer vs in-cluster operator actions in vCenter audit logs

3. **Compliance**: Achieve SOC2 separation of duties, PCI-DSS least privilege, and FedRAMP audit logging requirements

## Non-Goals

- Automatic vCenter account creation (mint mode) — conflicts with enterprise security practices
- External identity provider integration — valuable future enhancement but out of scope
- Cross-cluster credential sharing
- Migration from single-account to multi-account configuration for existing clusters

## Architecture

### Credential Management Flow

\`\`\`
Administrator → Scripts/Templates → vCenter Roles/Accounts
                                          ↓
                              install-config.yaml or ~/.vsphere/credentials
                                          ↓
                           Cloud Credential Operator (CCO)
                                          ↓
                    Privilege Validation (AuthorizationManager)
                                          ↓
               Component-Specific Secrets (machine-api, csi, cloud-controller, diagnostics)
                                          ↓
                           OpenShift Components (consume scoped credentials)
\`\`\`

### Components

#### 1. Credential Configuration

**Option A: install-config.yaml Integration**

\`\`\`yaml
platform:
  vsphere:
    vcenters:
      - server: vcenter1.example.com
        user: ocp-installer@vsphere.local
        password: <password>
        componentCredentials:
          machineAPI:
            user: ocp-machine-api@vsphere.local
            password: <password>
          csiDriver:
            user: ocp-csi@vsphere.local
            password: <password>
          cloudController:
            user: ocp-cloud-controller@vsphere.local
            password: <password>
          diagnostics:
            user: ocp-diagnostics@vsphere.local
            password: <password>
\`\`\`

**Option B: ~/.vsphere/credentials File**

YAML credentials file supporting per-vCenter, per-component configuration:

\`\`\`yaml
vcenters:
  vcenter1.example.com:
    user: admin@vsphere.local
    password: admin-password
    componentCredentials:
      machineAPI:
        user: ocp-machine-api@vsphere.local
        password: machine-api-password
      csiDriver:
        user: ocp-csi@vsphere.local
        password: csi-password
\`\`\`

**Security Constraints**:
- File permissions: 0600 (owner-only access) — installer validates and refuses overly permissive files
- Directory isolation: \`.vsphere/\` directory should have 0700 permissions
- Precedence: install-config.yaml credentials take priority over credentials file

#### 2. Cloud Credential Operator (CCO)

CCO validates credentials and distributes them to components:

**Validation Process**:
1. For each vCenter in cluster topology:
   - Extract component-specific credentials
   - Connect using provided credentials
   - Query \`AuthorizationManager.FetchUserPrivilegeOnEntities()\` on relevant objects
   - Compare returned privileges against required privilege set

2. **Success Path**: All required privileges present → provision credentials to component

3. **Failure Path**: Missing privileges → set \`CredentialsProvisionFailed\` condition with detailed logging identifying which privileges are missing and on which vCenter(s)

**Secret Distribution**:
- Each component gets a Kubernetes secret containing multi-vCenter credentials
- Secrets keyed by vCenter FQDN enable multi-vCenter support
- Graceful degradation: Falls back to shared credentials if per-component credentials not specified

#### 3. Component Privilege Requirements

Analysis across OpenShift repositories identified distinct privilege subsets:

| Component | Privilege Count | Scope | Examples |
|-----------|-----------------|-------|----------|
| Installer | 45 | Full operational set | All provisioning + operational privileges |
| Machine API | 19 | VM lifecycle | VirtualMachine.Config.*, VirtualMachine.Interact.* |
| CSI Driver | 6 | Storage operations | Datastore.*, VirtualMachine.Config.AddNewDisk |
| Cloud Controller | 3 | Discovery + LB provisioning | Read permissions + LB VM inventory |
| Diagnostics | 2 | Read-only monitoring | Sessions.ValidateSession, System.Read |

**Machine API Detailed Privileges** (19 required):
- Sessions.ValidateSession
- VirtualMachine.Config.AddNewDisk, AddRemoveDevice, AdvancedConfig, Annotation, CPUCount, Memory, Settings
- VirtualMachine.Interact.PowerOn, PowerOff, Reset
- VirtualMachine.Inventory.Create, Delete
- Resource.AssignVMToPool
- Datastore.AllocateSpace, FileManagement
- Network.Assign
- Task.Create, Update

**Storage (CSI) Detailed Privileges** (6 required):
- Sessions.ValidateSession
- VirtualMachine.Config.AddNewDisk, AddRemoveDevice
- Datastore.AllocateSpace, FileManagement
- System.Read

**Cloud Controller Detailed Privileges** (3 required):
- Sessions.ValidateSession
- System.Read
- VirtualMachine.Inventory.Create (for load balancer VMs)

**Diagnostics Detailed Privileges** (2 required):
- Sessions.ValidateSession
- System.Read

#### 4. Multi-vCenter Support

**Per-vCenter Credentials in Secrets**:

\`\`\`yaml
apiVersion: v1
kind: Secret
metadata:
  name: vsphere-creds-machine-api
  namespace: openshift-machine-api
type: Opaque
stringData:
  vcenter1.example.com.username: "ocp-machine-api@vsphere.local"
  vcenter1.example.com.password: "password-vc1"
  vcenter2.example.com.username: "ocp-machine-api@vsphere.local"
  vcenter2.example.com.password: "password-vc2"
\`\`\`

**Features**:
- Independent credentials per vCenter
- Separate validation on each vCenter
- Flexible key format enabling different identity sources per vCenter

### API Extensions

#### Infrastructure CR Enhancement

\`\`\`go
type VSpherePlatformSpec struct {
  CredentialsMode VSphereCredentialsMode
  ComponentCredentials *VSphereComponentCredentials
}

type VSphereCredentialsMode string
const (
  VSphereCredentialsModePassthrough = "Passthrough"    // Single shared credential (existing behavior)
  VSphereCredentialsModePerComponent = "PerComponent"  // Component-specific credentials
)

type VSphereComponentCredentials struct {
  MachineAPI *VSphereCredential
  CSIDriver *VSphereCredential
  CloudController *VSphereCredential
  Diagnostics *VSphereCredential
}
\`\`\`

### Data Models

**CredentialsRequest CRD** (existing, extended with vSphere privilege requirements):

\`\`\`yaml
apiVersion: cloudcredential.openshift.io/v1
kind: CredentialsRequest
metadata:
  name: openshift-machine-api-vsphere
  namespace: openshift-cloud-credential-operator
spec:
  providerSpec:
    apiVersion: cloudcredential.openshift.io/v1
    kind: VSphereProviderSpec
    requiredPrivileges:
      - Sessions.ValidateSession
      - VirtualMachine.Config.AddNewDisk
      # ... (full privilege list)
  secretRef:
    name: vsphere-cloud-credentials
    namespace: openshift-machine-api
\`\`\`

#### CredentialsRequest CR Annotation Mapping

Each vSphere component ships a `CredentialsRequest` CR that CCO uses to provision credentials. This enhancement adds a new annotation (`cloudcredential.openshift.io/vsphere-component`) to each CR, giving CCO an explicit hint for which per-component credential (from `install-config.yaml` or the credentials file) to provision into the component's secret.

| Component | Repository | CR Name | `capability.openshift.io/name` | Proposed Component Annotation | Secret Name | Secret Namespace |
|-----------|-----------|---------|--------------------------------|-------------------------------|-------------|-----------------|
| Machine API | `openshift/machine-api-operator` | `openshift-machine-api-vsphere` | `MachineAPI+CloudCredential` | `vsphere-component: machineAPI` | `vsphere-cloud-credentials` | `openshift-machine-api` |
| Cluster API | `openshift/cluster-capi-operator` | `openshift-cluster-api-vsphere` | `MachineAPI+CloudCredential` (feature-gated) | `vsphere-component: machineAPI` | `capv-manager-bootstrap-credentials` | `openshift-cluster-api` |
| CSI Driver | `openshift/cluster-storage-operator` | `openshift-vmware-vsphere-csi-driver-operator` | `Storage+CloudCredential` | `vsphere-component: csiDriver` | `vmware-vsphere-cloud-credentials` | `openshift-cluster-csi-drivers` |
| Cloud Controller | `openshift/cluster-cloud-controller-manager-operator` | `openshift-vsphere-cloud-controller-manager` | `CloudCredential+CloudControllerManager` | `vsphere-component: cloudController` | `vsphere-cloud-credentials` | `openshift-cloud-controller-manager` |
| Diagnostics | `openshift/cluster-storage-operator` | `openshift-vsphere-problem-detector` | `Storage+CloudCredential` | `vsphere-component: diagnostics` | `vsphere-cloud-credentials` | `openshift-cluster-storage-operator` |

The `cloudcredential.openshift.io/vsphere-component` annotation value aligns with the `componentCredentials` keys in `install-config.yaml` (`machineAPI`, `csiDriver`, `cloudController`, `diagnostics`). When CCO processes a CredentialsRequest with this annotation and per-component credentials are configured, it routes the matching credential to the component's secret. If the annotation is absent or the component key has no per-component credential, CCO falls back to the shared credential.

Multiple CRs may share the same component annotation value — for example, Machine API (`openshift-machine-api-vsphere`) and Cluster API (`openshift-cluster-api-vsphere`) both use `vsphere-component: machineAPI`, so CCO provisions the same per-component `machineAPI` credential to both their secrets. The Cluster API CR is feature-gated behind `ClusterAPIMachineManagement` and is only present when CAPI machine management is enabled.

> **Research finding — vSphere Problem Detector has a dedicated CredentialsRequest CR:**
> Research into `openshift/cluster-storage-operator` (manifests directory) confirms that the vSphere Problem Detector already ships its own dedicated CredentialsRequest CR (`openshift-vsphere-problem-detector`), separate and distinct from the CSI Driver CR (`openshift-vmware-vsphere-csi-driver-operator`). Both CRs are deployed by `cluster-storage-operator` but are independent manifests, each provisioning credentials into different secrets in different namespaces (`openshift-cluster-storage-operator` vs `openshift-cluster-csi-drivers`). This existing separation aligns with the design goal of per-component privilege isolation: the diagnostics credential scope (2 privileges: `Sessions.ValidateSession`, `System.Read`) is independent from the storage credential scope (6 privileges). The proposed `cloudcredential.openshift.io/vsphere-component: diagnostics` annotation is added to the **existing dedicated CR** (`openshift-vsphere-problem-detector`), not to the CSI Driver CR.

### Error Handling

**Validation Failure Scenarios**:

| Scenario | Error Message | Resolution |
|----------|---------------|------------|
| Missing privileges on vCenter | \`CredentialsProvisionFailed: Account 'ocp-machine-api@vsphere.local' on vCenter 'vcenter1.example.com' missing privileges: [VirtualMachine.Config.AddNewDisk, Datastore.AllocateSpace]\` | Grant missing privileges using provided scripts |
| Invalid credentials | \`CredentialsProvisionFailed: Authentication failed for 'ocp-csi@vsphere.local' on vCenter 'vcenter1.example.com'\` | Verify username/password, check account status |
| File permission violation | \`Error: Credentials file '/home/user/.vsphere/credentials' has insecure permissions (0644). Must be 0600.\` | \`chmod 600 ~/.vsphere/credentials\` |
| Partial configuration | \`Warning: Component 'cloudController' using fallback shared credentials (per-component credentials not provided)\` | Provide component-specific credentials or accept fallback behavior |

**Graceful Degradation**:
- If per-component credentials not provided for a component → fall back to shared credentials
- If validation fails for a component → block provisioning, report specific missing privileges
- If credentials file doesn't exist → use install-config.yaml credentials only

### Security Considerations

**Blast Radius Reduction**:
- **Before**: Single account compromise exposes all 45 admin-level privileges across all components
- **After**: Storage account compromise exposes only 6 storage-scoped privileges
- **Quantified benefit**: 87% privilege reduction in compromise scenario (45 → 6 for storage)

**Credential Storage**:
- Install-time credentials removed after bootstrap unless explicitly requested
- Cluster credentials stored in Kubernetes secrets (encrypted at rest if etcd encryption enabled)
- No plaintext credential persistence beyond installation phase

**Rotation Strategy**:
- Component credentials independently rotatable without affecting other components
- CCO re-validates on secret updates
- Zero-downtime rotation: create new account → update secret → decommission old account

**Privilege Escalation Prevention**:
- Validation enforces minimum required privileges (no "admin" role shortcuts)
- Each component limited to documented privilege subset
- vCenter RBAC enforces privilege boundaries

**Audit Trail**:
- vCenter audit logs show per-component service account actions
- Distinct user principals enable action attribution
- Compliance reporting can isolate component behavior

**Compliance Benefits**:
- **SOC2**: Achieves separation of duties requirement
- **PCI-DSS**: Satisfies least privilege principle (Requirement 7.1.2)
- **FedRAMP**: Enables audit logging per component (AC-2, AU-2)

## Acceptance Criteria

### AC1: New Cluster Installation with Per-Component Credentials

**Given**: Administrator has created vCenter roles and accounts per documentation  
**When**: Installing a new vSphere IPI cluster with componentCredentials specified in install-config.yaml  
**Then**:
- Installer validates each component's credentials possess required privileges
- Installation succeeds with component-specific secrets created in appropriate namespaces
- vCenter audit logs show distinct service accounts for installer, machine-api, csi, cloud-controller, diagnostics actions

### AC2: Validation Failure Reporting

**Given**: Administrator provides credentials missing required privileges  
**When**: CCO validates credentials during installation or secret update  
**Then**:
- CredentialsRequest condition shows CredentialsProvisionFailed status
- Error message specifies: account name, vCenter FQDN, and list of missing privileges
- Installation blocks until privileges are granted

### AC3: Multi-vCenter Credential Support

**Given**: Cluster spanning multiple vCenters (vcenter1.example.com, vcenter2.example.com)  
**When**: Per-component credentials provided for each vCenter  
**Then**:
- CCO validates credentials on each vCenter independently
- Component secrets contain separate credentials keyed by vCenter FQDN
- Components can perform operations on resources in both vCenters

### AC4: Graceful Degradation

**Given**: Administrator provides per-component credentials for machine-api and csi only  
**When**: CCO provisions credentials  
**Then**:
- machine-api and csi use per-component credentials
- cloud-controller and diagnostics fall back to shared credentials
- Warning logged for components using fallback

### AC5: Credential Rotation

**Given**: Cluster in PerComponent mode  
**When**: Administrator rotates machine-api credentials by updating secret  
**Then**:
- CCO re-validates new credentials
- Machine-api switches to new credentials
- Other components unaffected
- No cluster downtime during rotation

### AC6: Documentation and Tooling

**Given**: Administrator needs to configure per-component credentials  
**When**: Following official documentation  
**Then**:
- Scripts provided for vCenter role creation (govc and PowerCLI)
- Credentials file template generator available
- Privilege requirement documentation lists all required privileges per component
- Troubleshooting guide covers common validation failures

## Impact on Existing System

**Backward Compatibility**:
- Existing Passthrough mode clusters continue functioning unchanged
- No forced migration required
- API extensions purely additive

## References

- Source Feature: [OCPSTRAT-2933](https://redhat.atlassian.net/browse/OCPSTRAT-2933)
- Enhancement Proposal: https://github.com/rvanderp3/enhancements/blob/9e5c28ffd653e2b75f95ab58f76bb6edddcd5247/enhancements/installer/vsphere-multi-account-credentials-enhancement.md
- Installing on vSphere: https://docs.redhat.com/en/documentation/openshift_container_platform/4.21/html-single/installing_on_vmware_vsphere/index

## Success Metrics

- Successful deployment with per-component credentials on vSphere 8.0 Update 1+
- Audit logs showing per-component action attribution
- Independent credential rotation for individual components
- Zero compliance violations for SOC2/PCI-DSS separation of duties
- Graceful fallback to passthrough mode without operational disruption
