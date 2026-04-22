---
title: vsphere-multi-account-credential-management
authors:
  - "@rvanderp3"
reviewers:
  - TBD
approvers:
  - TBD
api-approvers:
  - None
creation-date: 2026-04-21
last-updated: 2026-04-21
status: provisional
tracking-link:
  - https://github.com/openshift-splat-team/splat-team/issues/14
  - https://redhat.atlassian.net/browse/OCPSTRAT-2933
---

# vSphere Multi-Account Credential Management

## Summary

Enable OpenShift on vSphere to support administrator-provisioned, component-specific credentials instead of relying on a single shared vCenter account for all operations. This enhancement provides privilege separation between provisioning (high privilege) and day-2 operations (restricted privilege), reducing blast radius and improving compliance with SOC2, PCI-DSS, and other enterprise security requirements.

## Motivation

### Current State and Problem

OpenShift currently uses a single vCenter credential across all components:
- **Installer**: Provisions infrastructure (VMs, networks, storage)
- **Machine API Operator**: Manages compute node lifecycle
- **CSI Driver**: Handles persistent storage operations
- **Cloud Controller Manager**: Discovers and manages node infrastructure
- **vSphere Problem Detector**: Validates vSphere configuration and monitors cluster health

This shared credential model creates critical security and compliance issues:

1. **Excessive privilege exposure**: Every component accesses all privileges regardless of actual needs
2. **Large blast radius**: Compromised credential grants full cluster and infrastructure access
3. **Poor auditability**: vCenter audit logs cannot distinguish which OpenShift component performed actions
4. **Compliance violations**: Architecture conflicts with SOC2 separation of duties and PCI-DSS least-privilege requirements
5. **Operational risk**: Rotating credentials requires cluster-wide coordination and potential downtime

### User Stories

**Story 1: Security-conscious enterprise**
> As a vSphere administrator in a regulated enterprise, I need to provide separate credentials for OpenShift installation versus runtime operations, so that I can meet SOC2 audit requirements for privilege separation and limit the blast radius of compromised credentials.

**Story 2: Multi-team environment**
> As a platform engineering team lead, I need installation-time credentials to be removed from the cluster after deployment completes, so that runtime operators cannot accidentally or maliciously provision new infrastructure without going through our change control process.

**Story 3: Compliance officer**
> As a compliance officer, I need vCenter audit logs to clearly distinguish between OpenShift installer actions and runtime operator actions, so that I can demonstrate separation of duties during security audits.

**Story 4: Operations team**
> As an operations engineer, I need to rotate vCenter credentials for runtime components without requiring cluster reinstallation, so that I can respond to security incidents and meet password rotation policies without downtime.

### Goals

1. **Privilege separation**: Enable distinct credentials for:
   - **Installer**: High-privilege provisioning operations (~50 privileges)
   - **Machine API Operator**: VM lifecycle management (35 privileges)
   - **CSI Driver**: Storage operations (10-15 privileges)
   - **Cloud Controller Manager**: Read-only node discovery (~10 privileges, requires verification)
   - **vSphere Problem Detector**: Configuration validation and health monitoring (~16 privileges: 11 vCenter-level for tagging/CNS/sessions, 1 datacenter for System.Read, 4 datastore for read-only checks)

2. **Migration path**: Support zero-downtime migration of existing single-credential clusters to multi-credential model

3. **Auditability**: Enable vCenter audit logs to distinguish installer vs in-cluster operator actions via credential-based attribution

4. **Multi-vCenter support**: Handle OpenShift deployments spanning multiple vCenter instances with independent credentials per vCenter

5. **Administrator control**: Respect enterprise account provisioning workflows (no automatic vCenter account creation by CCO)

6. **Operational flexibility**: Enable independent credential rotation per component without cluster-wide coordination

### Non-Goals

1. **Automatic credential minting**: CCO will NOT automatically create vCenter accounts (requires excessive CCO privileges and conflicts with enterprise IAM workflows)
2. **Dynamic privilege adjustment**: Privilege requirements are fixed per component (not runtime-configurable)
3. **Credential lifecycle management**: External credential rotation tooling is out of scope (administrators use existing vCenter IAM tools)
4. **Legacy vSphere version support**: Only vSphere 7.0+ supported (older versions lack required RBAC granularity)

## Proposal

### Workflow Description

#### Installation Workflow (New Cluster)

**Administrator perspective:**

1. **Prepare credentials** using provided tooling:
   ```bash
   # Create per-component vCenter roles using provided govc scripts
   ./create-vsphere-roles.sh --vcenter vcenter.example.com \
     --datacenter DC1 \
     --cluster Cluster1
   
   # Creates roles: openshift-installer, openshift-machine-api, 
   # openshift-storage, openshift-cloud-controller, openshift-diagnostics
   ```

2. **Configure install-config.yaml**:
   ```yaml
   platform:
     vsphere:
       vcenters:
       - server: vcenter.example.com
         datacenters:
         - DC1
       componentCredentials:
         installer:
           secretRef:
             name: vsphere-installer-creds
             namespace: kube-system
         machineAPI:
           secretRef:
             name: vsphere-machine-api-creds
             namespace: openshift-machine-api
         storage:
           secretRef:
             name: vsphere-storage-creds
             namespace: openshift-cluster-csi-drivers
         cloudController:
           secretRef:
             name: vsphere-cloud-controller-creds
             namespace: openshift-cloud-controller-manager
         diagnostics:
           secretRef:
             name: vsphere-diagnostics-creds
             namespace: openshift-config
   ```

3. **Create credential secrets**:
   ```bash
   # Installer validates secrets exist and contain credentials for all vCenters
   oc create secret generic vsphere-installer-creds \
     --from-literal=vcenter.example.com.username=installer@vsphere.local \
     --from-literal=vcenter.example.com.password='...'
   
   # Repeat for each component...
   ```

4. **Run installation**:
   ```bash
   openshift-install create cluster --dir ./install
   
   # Installer:
   # - Validates all credential secrets exist
   # - Validates privileges per component per vCenter
   # - Provisions infrastructure using installer credentials
   # - Creates component secrets in appropriate namespaces
   # - Does NOT persist installer credentials in cluster
   ```

**Component perspective (runtime):**

1. **Machine API Operator**:
   - Reads `vsphere-machine-api-creds` secret
   - Extracts credentials keyed by vCenter FQDN
   - Validates privileges before creating MachineSet
   - Uses restricted credentials for VM lifecycle operations

2. **CSI Driver**:
   - Reads `vsphere-storage-creds` secret
   - Uses storage-scoped credentials for volume operations
   - Reports privilege validation errors to cluster operator status

3. **Cloud Controller Manager**:
   - Reads `vsphere-cloud-controller-creds` secret
   - Uses read-only credentials for node discovery

#### Migration Workflow (Existing Cluster)

**Zero-downtime migration path:**

1. **Administrator creates new component credentials** in vCenter with restricted privileges

2. **Create new component secrets**:
   ```bash
   oc create secret generic vsphere-machine-api-creds \
     -n openshift-machine-api \
     --from-literal=vcenter.example.com.username=machine-api@vsphere.local \
     --from-literal=vcenter.example.com.password='...'
   ```

3. **Update Infrastructure CR**:
   ```yaml
   apiVersion: config.openshift.io/v1
   kind: Infrastructure
   metadata:
     name: cluster
   spec:
     platformSpec:
       type: VSphere
       vsphere:
         componentCredentials:
           machineAPI:
             secretRef:
               name: vsphere-machine-api-creds
               namespace: openshift-machine-api
           # ... other components
   ```

4. **Operators** detect component-specific credentials:
   - Operators check for component-specific credential secrets
   - Validate credentials and privileges per component
   - Update operator deployment environment to reference new secrets
   - Operators gracefully restart and adopt new credentials
   - Original shared credential remains available as fallback

5. **Verification**:
   ```bash
   # Check CCO status
   oc get credentialsrequest -A
   
   # Verify each component reports healthy with new credentials
   oc get co machine-api
   oc get co storage
   oc get co cloud-controller-manager
   ```

### API Extensions

#### Infrastructure API Changes

**New field in `Infrastructure.spec.platformSpec.vsphere`:**

```yaml
apiVersion: config.openshift.io/v1
kind: Infrastructure
metadata:
  name: cluster
spec:
  platformSpec:
    type: VSphere
    vsphere:
      # Existing fields...
      vcenters:
      - server: vcenter1.example.com
        datacenters: [DC1]
      - server: vcenter2.example.com
        datacenters: [DC2]
      
      # NEW: Component credential references
      componentCredentials:
        installer:
          secretRef:
            name: vsphere-installer-creds
            namespace: kube-system
        machineAPI:
          secretRef:
            name: vsphere-machine-api-creds
            namespace: openshift-machine-api
        storage:
          secretRef:
            name: vsphere-storage-creds
            namespace: openshift-cluster-csi-drivers
        cloudController:
          secretRef:
            name: vsphere-cloud-controller-creds
            namespace: openshift-cloud-controller-manager
        diagnostics:
          secretRef:
            name: vsphere-diagnostics-creds
            namespace: openshift-config
```

#### Secret Format

**Multi-vCenter credential secret structure:**

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: vsphere-machine-api-creds
  namespace: openshift-machine-api
type: Opaque
stringData:
  # Credentials keyed by vCenter FQDN
  vcenter1.example.com.username: "machine-api@vsphere.local"
  vcenter1.example.com.password: "password1"
  vcenter2.example.com.username: "machine-api@vc2.local"
  vcenter2.example.com.password: "password2"
```

**Key format rationale:**
- Supports multi-vCenter deployments
- Enables independent password rotation per vCenter
- Allows different identity providers per vCenter
- Backward compatible with single-vCenter deployments

#### Install-Config Schema

**New install-config.yaml platform section:**

```yaml
apiVersion: v1
baseDomain: example.com
metadata:
  name: vsphere-multivcenter
platform:
  vsphere:
    apiVIPs:
    - 192.168.1.10
    ingressVIPs:
    - 192.168.1.11
    
    # Multi-vCenter topology
    vcenters:
    - server: vcenter1.example.com
      port: 443
      datacenters:
      - DC1
    - server: vcenter2.example.com
      port: 443
      datacenters:
      - DC2
    
    # NEW: Credentials configuration
    componentCredentials:
      installer:
        username: "installer@vsphere.local"
        password: "..."
      machineAPI:
        username: "machine-api@vsphere.local"
        password: "..."
      storage:
        username: "storage@vsphere.local"
        password: "..."
      cloudController:
        username: "cloud-controller@vsphere.local"
        password: "..."
      diagnostics:
        username: "diagnostics@vsphere.local"
        password: "..."
```

**Alternative: Credentials file** (`~/.vsphere/credentials.yaml`):

```yaml
vcenters:
  vcenter1.example.com:
    installer:
      username: installer@vsphere.local
      password: ...
    machine_api:
      username: machine-api@vsphere.local
      password: ...
    storage:
      username: storage@vsphere.local
      password: ...
    cloud_controller:
      username: cloud-controller@vsphere.local
      password: ...
    diagnostics:
      username: diagnostics@vsphere.local
      password: ...
  
  vcenter2.example.com:
    installer:
      username: installer@vc2.local
      password: ...
    # ... additional components
```

### Topology Considerations

**Note**: Hypershift / Hosted Control Planes is not supported on vSphere platform.

#### Standalone Clusters

**Standard IPI deployment:**
- Full credential set required (installer + all runtime components)
- Installer credentials used during installation, not persisted in cluster
- Runtime credentials distributed to operator namespaces
- Migration path from single credential to per-component supported

**UPI deployment:**
- Administrator pre-provisions infrastructure
- Only runtime component credentials needed
- Installer credentials optional (no infrastructure provisioning)

#### Single-node Deployments or MicroShift

**SNO considerations:**
- Reduced component footprint (no Machine API on single-node)
- Required credentials: storage, cloud controller, diagnostics
- Machine API credentials optional (no compute scaling)

**MicroShift:**
- Out of scope (MicroShift does not support vSphere platform integration)

#### OpenShift Kubernetes Engine

**OKE deployment:**
- Same credential model as standalone clusters
- All component credentials required
- No special OKE-specific credential handling

### Implementation Details/Notes/Constraints

#### Component Privilege Requirements

**Installer (installation-time only):**
- Datacenter: Datastore.AllocateSpace, Network.Assign
- Cluster: Host.Config.Storage
- Folder: VirtualMachine.Inventory.Create, VirtualMachine.Inventory.Delete
- Resource Pool: VirtualMachine.Config.AddNewDisk, VirtualMachine.Interact.PowerOn
- Datastore: Datastore.AllocateSpace, Datastore.FileManagement
- Network: Network.Assign
- vApp: VApp.Import, VApp.Export

**Machine API Operator (~35 privileges):**
- VirtualMachine.Config.* (CPU, memory, disk, device management)
- VirtualMachine.Interact.* (power operations, console access)
- VirtualMachine.Inventory.* (create, delete, move)
- Resource.AssignVMToPool
- Datastore.AllocateSpace, Datastore.FileManagement
- Network.Assign

**CSI Driver (~10-15 privileges):**
- Datastore.AllocateSpace
- Datastore.FileManagement (low level file operations)
- VirtualMachine.Config.AddExistingDisk
- VirtualMachine.Config.AddNewDisk
- VirtualMachine.Config.RemoveDisk
- StoragePod.Config (for storage DRS)

**Cloud Controller Manager (~10 privileges - mostly read-only):**
- System.Anonymous (read access)
- System.Read (read vCenter inventory)
- System.View (view objects)
- VirtualMachine.Inventory.Create (for node providerID reconciliation)

**Diagnostics (~5 privileges - read-only):**
- System.Anonymous
- System.Read
- System.View
- Datastore.Browse (read logs from datastore)

#### Privilege Validation Logic

**Installer validation (pre-install):**

```go
// Pseudocode
func ValidateComponentCredentials(vcenters []VCenter, credentials ComponentCredentials) error {
    for _, vcenter := range vcenters {
        // Validate installer credentials
        installerClient := vcenter.NewClient(credentials.Installer)
        if err := installerClient.ValidatePrivileges(RequiredInstallerPrivileges); err != nil {
            return fmt.Errorf("installer credentials for %s: %w", vcenter.Server, err)
        }
        
        // Validate runtime component credentials
        machineAPIClient := vcenter.NewClient(credentials.MachineAPI)
        if err := machineAPIClient.ValidatePrivileges(RequiredMachineAPIPrivileges); err != nil {
            return fmt.Errorf("machine-api credentials for %s: %w", vcenter.Server, err)
        }
        
        // ... repeat for storage, cloudController, diagnostics
    }
    return nil
}
```

**CCO validation (runtime):**

```go
// CCO validates credentials before distributing to operators
func (r *ReconcileCredentialsRequest) validateVSphereCredentials(cr *minterv1.CredentialsRequest) error {
    infra := getInfrastructure()
    if infra.Spec.PlatformSpec.VSphere.CredentialsMode != "PerComponent" {
        return nil // Skip validation in passthrough mode
    }
    
    componentCreds := infra.Spec.PlatformSpec.VSphere.ComponentCredentials
    component := cr.Spec.ProviderSpec.Component // "machineAPI", "storage", etc.
    
    secretRef := componentCreds[component].SecretRef
    secret := getSecret(secretRef.Namespace, secretRef.Name)
    
    for _, vcenter := range infra.Spec.PlatformSpec.VSphere.VCenters {
        username := secret.Data[vcenter.Server + ".username"]
        password := secret.Data[vcenter.Server + ".password"]
        
        client := vcenter.NewClient(username, password)
        requiredPrivs := getRequiredPrivileges(component)
        
        if err := client.ValidatePrivileges(requiredPrivs); err != nil {
            return fmt.Errorf("insufficient privileges for %s on %s: %w", 
                component, vcenter.Server, err)
        }
    }
    
    return nil
}
```

#### Credential Distribution Flow

**Installation:**
1. Installer reads credentials from install-config.yaml or ~/.vsphere/credentials
2. Validates all component credentials against all vCenters
3. Provisions infrastructure using installer credentials
4. Creates component secrets in appropriate namespaces
5. Does NOT persist installer credentials in cluster

**Runtime:**
1. CCO reads Infrastructure CR to determine credentials mode
2. If PerComponent mode:
   - Reads component credential secret references
   - Validates credentials and privileges
   - Updates CredentialsRequest status with validation results
3. Operators read their respective credential secrets
4. Components connect to vCenter using their scoped credentials

#### Atomic Transition Design

**Requirement**: Installation must atomically transition from provisioning credentials to operational credentials.

**Implementation**:
1. Installer completes infrastructure provisioning using installer credentials
2. Installer creates all component credential secrets in cluster
3. Installer does NOT modify the Infrastructure CR `credentialsMode` field
4. Operators detect presence of component-specific credential secrets and adopt them
5. Operators restart and begin using component-specific credentials
6. **Only after all operators report healthy**: installer credentials removed from cluster state

**Failure handling**:
- If component credential validation fails → installation fails (no partial state)
- If operator fails to adopt new credentials → rollback to installer credentials
- Clear error messages indicating which component/vCenter combination failed

#### Multi-vCenter Considerations

**Scenario**: OpenShift cluster spanning two vCenters (vcenter1 and vcenter2)

**Credential architecture**:
```yaml
# Each component secret contains credentials for both vCenters
apiVersion: v1
kind: Secret
metadata:
  name: vsphere-machine-api-creds
stringData:
  vcenter1.example.com.username: "machine-api@vsphere.local"
  vcenter1.example.com.password: "password1"
  vcenter2.example.com.username: "machine-api@vc2.local"
  vcenter2.example.com.password: "password2"
```

**Lookup logic**:
```go
func (c *ComponentClient) GetCredentialsForVCenter(vcenterFQDN string) (string, string, error) {
    secret := c.getComponentSecret()
    
    usernameKey := vcenterFQDN + ".username"
    passwordKey := vcenterFQDN + ".password"
    
    username, ok := secret.Data[usernameKey]
    if !ok {
        return "", "", fmt.Errorf("missing username for vCenter %s", vcenterFQDN)
    }
    
    password, ok := secret.Data[passwordKey]
    if !ok {
        return "", "", fmt.Errorf("missing password for vCenter %s", vcenterFQDN)
    }
    
    return string(username), string(password), nil
}
```

#### Backward Compatibility

**Passthrough mode (default)**:
- Existing behavior preserved
- Single credential in `vsphere-cloud-credentials` secret
- All components use shared credential
- No privilege validation

**Migration path**:
1. Cluster starts in passthrough mode with shared credential
2. Administrator creates component credentials in vCenter
3. Administrator creates component secrets in cluster (without modifying Infrastructure CR)
4. Operators detect presence of component-specific credential secrets
5. Operators validate component credentials
6. Operators adopt new credentials and restart
7. Original shared credential can be removed after all operators report healthy

**Fallback**:
- If component secret missing → fall back to shared credential
- If privilege validation fails → block operation with clear error
- Operators log credential source (shared vs per-component) for debugging

### Risks and Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|-----------|------------|
| **Administrator misconfiguration** (incorrect privileges) | Installation fails or operators degraded | High | - Installer validates privileges before provisioning<br>- CCO validates before distributing credentials<br>- Clear error messages indicating missing privileges<br>- Provided privilege validation scripts |
| **Complex setup burden** | Adoption friction | Medium | - Automated govc/PowerCLI scripts for role creation<br>- Comprehensive documentation with examples<br>- Optional credentials file for interactive workflows |
| **Credential exposure** in install-config.yaml or credentials file | Credentials leaked in version control | Medium | - Enforce 0600 file permissions<br>- Install-config precedence over credentials file<br>- Documentation warnings about credential handling<br>- Consider external secret managers (future enhancement) |
| **Multi-vCenter inconsistency** | Some vCenters configured correctly, others not | Medium | - Provided scripts configure all vCenters uniformly<br>- Validation checks all vCenters before proceeding<br>- Detailed per-vCenter error reporting |
| **Privilege creep** (component requires new privilege in future release) | Existing credentials insufficient for upgrade | Low | - Document privilege requirements per OpenShift version<br>- CCO privilege validation before upgrade<br>- Release notes highlight privilege requirement changes |
| **CCO failure during credential distribution** | Operators cannot start | Low | - Fallback to shared credential if component secret missing<br>- CCO status reports validation errors per component<br>- Operators log credential source for debugging |
| **vCenter API rate limiting** with multiple credentials | Validation or operations throttled | Low | - Credential validation is one-time per install/update<br>- Runtime operations no different than current (same API call volume)<br>- Use connection pooling per credential |

### Drawbacks

1. **Increased operational complexity**: Administrators must manage 5 credentials instead of 1
   - **Counterpoint**: Enterprise environments already manage granular credentials via IAM systems; this aligns with existing workflows

2. **Migration effort for existing clusters**: Requires creating new vCenter roles and credentials
   - **Counterpoint**: Migration is optional (passthrough mode remains supported); provides zero-downtime migration path

3. **Documentation burden**: Must document exact privilege requirements per component
   - **Counterpoint**: Provided automation scripts reduce manual setup; documentation benefits security teams

4. **No automatic credential rotation**: Administrators must manually rotate credentials
   - **Counterpoint**: Enterprise credential rotation is policy-driven and integrated with IAM systems; automatic rotation would conflict with approval workflows

## Alternatives (Not Implemented)

### Alternative 1: CCO Mints vCenter Accounts

**Approach**: Cloud Credential Operator automatically creates vCenter service accounts with appropriate privileges.

**Why rejected**:
- Requires CCO to possess administrative vCenter privileges (excessive)
- Conflicts with enterprise IAM workflows (formal account provisioning with approvals)
- CCO would need access to identity management systems (Active Directory, LDAP)
- Violates separation of duties (OpenShift should not manage infrastructure IAM)

### Alternative 2: Single Credential with Role-Based Restrictions

**Approach**: Use single credential but restrict privileges via vCenter role, rely on OpenShift RBAC.

**Why rejected**:
- Does not achieve privilege separation (all components share same credential)
- No blast radius reduction (compromised credential = full access)
- Poor auditability (cannot distinguish component actions in vCenter logs)
- Does not meet compliance requirements (SOC2, PCI-DSS require distinct credentials)

### Alternative 3: External Secret Manager Integration (Vault, AWS Secrets Manager)

**Approach**: Store vSphere credentials in external secret manager, reference via ExternalSecret CRs.

**Why not implemented now**:
- Adds dependency on external systems (complicates air-gapped deployments)
- Requires external secret operator installation
- Can be layered on top of this enhancement (future work)
- Administrator-provided secrets sufficient for initial implementation

**Future consideration**: Document integration pattern with external secret managers as follow-up enhancement.

### Alternative 4: Certificate-Based Authentication

**Approach**: Use vSphere certificate authentication instead of username/password.

**Why not implemented now**:
- Requires vSphere 7.0 U2+ (later than target)
- Certificate lifecycle management complexity (issuance, renewal, revocation)
- Not all vSphere environments support certificate authentication
- Can be added as alternative auth method in future (complementary, not replacement)

## Open Questions

1. **Should installer credentials be optionally persisted for disaster recovery scenarios?**
   - **Current decision**: No, installer credentials should not persist in cluster
   - **Rationale**: Conflicts with privilege separation goal; administrators should maintain installer credentials externally
   - **Future consideration**: Document DR procedure using administrator-maintained credentials

2. **How should credentials be rotated during cluster operation?**
   - **Current approach**: Administrator updates secret, operator gracefully restarts
   - **Question**: Should CCO trigger operator restart automatically on secret change?
   - **Resolution needed**: Define restart behavior and document rotation procedure

3. **Should the enhancement support vSphere 6.7?**
   - **Current decision**: vSphere 7.0+ only (better RBAC granularity)
   - **Question**: Customer demand for 6.7 support?
   - **Future consideration**: Backport if significant demand, with privilege validation caveats

4. **Should diagnostics component have separate credentials?**
   - **Current decision**: Yes, for consistency and principle of least privilege
   - **Question**: Is read-only diagnostic access sufficient?
   - **Resolution needed**: Validate must-gather operations against minimal privilege set

## Test Plan

### Unit Tests

**Installer:**
- Credential parsing from install-config.yaml
- Credential parsing from ~/.vsphere/credentials file
- Privilege validation logic (mock vSphere API)
- Multi-vCenter credential lookup
- Error handling for missing credentials
- Error handling for malformed secret keys

**CCO:**
- Credentials mode detection
- Component credential secret validation
- Privilege requirement mapping per component
- CredentialsRequest reconciliation with per-component credentials
- Fallback to passthrough mode

**Machine API Operator:**
- Multi-vCenter credential lookup from secret
- Privilege validation before machine creation
- Graceful credential rotation handling

**CSI Driver:**
- Storage credential secret reading
- Privilege validation for volume operations
- Multi-vCenter volume attachment scenarios

**Cloud Controller Manager:**
- Cloud controller credential secret reading
- Read-only privilege validation
- Node reconciliation with restricted credentials

### Integration Tests

**govcsim-based tests:**
- Install cluster with per-component credentials
- Validate each component uses correct credential
- Simulate privilege validation failures
- Test credential rotation scenarios
- Multi-vCenter topology with different credentials per vCenter

### E2E Tests

**New cluster installation:**
- IPI installation with per-component credentials
- Verify installer credentials not persisted in cluster
- Verify each component secret created in correct namespace
- Verify all operators report healthy
- Verify machine creation works with scoped credentials
- Verify storage provisioning works with scoped credentials

**Existing cluster migration:**
- Deploy cluster in passthrough mode
- Create per-component credentials in vCenter
- Create component secrets in cluster
- Update Infrastructure CR to PerComponent mode
- Verify all operators gracefully adopt new credentials
- Verify no downtime during migration

**Credential rotation:**
- Rotate machine-api credential in vCenter
- Update machine-api secret in cluster
- Verify machine-api-operator detects change
- Verify machine-api-operator restarts with new credential
- Verify machine operations continue successfully

**Multi-vCenter:**
- Install cluster spanning two vCenters
- Verify credentials validated against both vCenters
- Create machine in each vCenter
- Provision storage in each vCenter
- Verify credential isolation (credentials for vcenter1 cannot access vcenter2)

**Failure scenarios:**
- Missing credential for one vCenter (should fail validation)
- Insufficient privileges for component (should fail with clear error)
- Malformed secret key (should fail with clear error)
- Component secret missing (should fall back to shared credential if available)

### Scale Testing

**Not applicable** (credential model does not affect scale limits)

### vSphere Version Testing

- vSphere 7.0 U3
- vSphere 8.0 U1
- ESXi 7.0 and 8.0

## Graduation Criteria

### Dev Preview -> Tech Preview

**Requirements:**
- ✅ Installer supports per-component credentials in install-config.yaml
- ✅ CCO validates and distributes component credentials
- ✅ Machine API Operator uses scoped credentials
- ✅ CSI Driver uses scoped credentials
- ✅ Cloud Controller Manager uses scoped credentials
- ✅ E2E tests passing for new installations
- ✅ Documentation includes installation instructions
- ✅ govc/PowerCLI privilege setup scripts available

### Tech Preview -> GA

**Requirements:**
- ✅ Migration path tested and documented for existing clusters
- ✅ Credential rotation tested and documented
- ✅ Multi-vCenter scenarios tested
- ✅ vSphere 7.0+ compatibility validated
- ✅ Privilege validation error messages clear and actionable
- ✅ Support procedures documented for common failure scenarios
- ✅ Performance impact measured (none expected)
- ✅ Security review completed
- ✅ Customer validation (at least 2 early adopters in production)

### Removing a deprecated feature

**Not applicable** (new feature, not deprecating existing functionality)

**Note**: Passthrough mode (shared credential) will remain supported indefinitely for backward compatibility.

## Upgrade / Downgrade Strategy

### Upgrade (Existing Cluster Adopts Per-Component Credentials)

**Zero-downtime upgrade path:**

1. **Pre-upgrade** (cluster running OpenShift N):
   - Cluster uses passthrough mode (shared credential)
   - Infrastructure CR has `credentialsMode: Passthrough` (or unset)

2. **Upgrade to OpenShift N+1** (supports per-component credentials):
   - No automatic credential changes during upgrade
   - Cluster continues using passthrough mode
   - New Infrastructure CR fields available but not populated

3. **Post-upgrade migration** (administrator-initiated):
   - Administrator creates per-component vCenter roles
   - Administrator creates component secrets in cluster
   - Operators detect component-specific credential secrets
   - Operators validate component credentials
   - Operators gracefully restart with new credentials
   - **No downtime** (operators restart one at a time)

4. **Rollback** (if migration fails):
   - Administrator removes component-specific credential secrets
   - Operators detect absence of component credentials and revert to shared credential
   - Component secrets can be deleted (optional)

**Validation requirements:**
- Upgrade must NOT require per-component credentials
- Passthrough mode must remain fully functional
- Migration to per-component mode is optional and administrator-controlled

### Downgrade (Cluster Reverts to Earlier OpenShift Version)

**Downgrade scenario:** OpenShift N+1 → OpenShift N

**If cluster is using passthrough mode:**
- No impact (passthrough mode supported in both versions)
- Downgrade proceeds normally

**If cluster is using per-component credentials:**
- **Before downgrade**: Administrator must revert to shared credential mode
  1. Ensure shared credential secret exists and is valid
  2. Remove component-specific credential secrets
  3. Verify operators detect shared credential and restart
  4. Verify all operators report healthy with shared credential
  5. Proceed with downgrade

- **If administrator downgrades without reverting:**
  - OpenShift N does not understand per-component credential fields
  - Operators will fail to find credentials
  - **Mitigation**: Pre-downgrade validation check warns if component-specific credentials are present

**Documentation requirements:**
- Downgrade documentation must include revert-to-passthrough procedure
- openshift-install validation should warn if downgrading from per-component mode

## Version Skew Strategy

### Control Plane vs Worker Node Skew

**Not applicable** (credential handling is control plane only; worker nodes do not access vSphere credentials)

### Operator Version Skew

**Scenario:** During upgrade, some operators are version N, others version N+1

**Handling:**
- **Passthrough mode**: No skew issues (all versions support shared credential)
- **Per-component mode**:
  - Older operators (version N) ignore per-component credential fields
  - Older operators fall back to shared credential if component secret missing
  - Newer operators (version N+1) use per-component credentials if available
  - **Safe skew**: Operators can run mixed versions during upgrade

**Validation:**
- E2E test upgrade scenario with rolling operator updates
- Verify no service disruption during operator version skew

### vSphere API Version Skew

**Scenario:** Cluster uses vSphere API version X, credentials created with API version Y

**Handling:**
- vSphere API backward compatible (newer API works with older vCenter)
- Privilege names stable across vSphere 7.0 and 8.0
- Credential validation uses lowest common denominator API calls

**Validation:**
- Test credentials created on vSphere 7.0 used on vSphere 8.0
- Test credentials created on vSphere 8.0 used on vSphere 7.0

## Operational Aspects of API Extensions

### Infrastructure CR Changes

**New fields:**
- `spec.platformSpec.vsphere.componentCredentials` (map of component → secret reference)

**Note**: The `credentialsMode` field is not used in this design. Operators detect component-specific credentials by checking for the presence of component-specific credential secrets, not by reading a mode field.

**Impact:**
- Operators check for component-specific credential secrets on every reconciliation loop
- Presence of component secrets triggers operator credential validation and restart
- Secrets must exist and be valid (invalid secrets block reconciliation)

**Performance:**
- Negligible (one-time read per CCO reconciliation, ~30s interval)
- Credential secret reads cached by CCO

### CredentialsRequest CR

**No API changes** (existing CR reused)

**Behavior change:**
- CCO populates credential content from component-specific secret instead of shared secret
- CredentialsRequest status includes per-vCenter validation results

### Failure Modes

**Component credential secret missing:**
- **Impact**: Operator degraded
- **Detection**: CCO sets CredentialsRequest status to "CredentialsNotFound"
- **Recovery**: Create missing secret, CCO automatically reconciles

**Insufficient privileges:**
- **Impact**: Operator degraded
- **Detection**: CCO validates privileges, sets CredentialsRequest status to "InsufficientPrivileges"
- **Recovery**: Grant missing privileges in vCenter, update secret if needed

**vCenter unreachable during validation:**
- **Impact**: CCO cannot validate credentials
- **Detection**: CCO sets CredentialsRequest status to "ValidationFailed"
- **Recovery**: Automatic retry when vCenter becomes reachable

## Support Procedures

### Diagnostic Commands

**Check for component-specific credentials:**
```bash
# Check if componentCredentials are configured in Infrastructure CR
oc get infrastructure cluster -o jsonpath='{.spec.platformSpec.vsphere.componentCredentials}' | jq .
```

**Check component credential secrets:**
```bash
# Machine API
oc get secret vsphere-machine-api-creds -n openshift-machine-api
oc get secret vsphere-machine-api-creds -n openshift-machine-api -o jsonpath='{.data}' | jq 'keys'

# Storage
oc get secret vsphere-storage-creds -n openshift-cluster-csi-drivers

# Cloud Controller
oc get secret vsphere-cloud-controller-creds -n openshift-cloud-controller-manager

# Diagnostics
oc get secret vsphere-diagnostics-creds -n openshift-config
```

**Check CCO validation status:**
```bash
oc get credentialsrequest -A
oc describe credentialsrequest <name> -n <namespace>
```

**Check operator health:**
```bash
oc get co machine-api
oc get co storage
oc get co cloud-controller-manager
```

**Check operator logs for credential issues:**
```bash
# Machine API
oc logs -n openshift-machine-api -l api=clusterapi -c machine-controller --tail=100

# Storage
oc logs -n openshift-cluster-csi-drivers -l app=vsphere-csi-driver --tail=100

# Cloud Controller
oc logs -n openshift-cloud-controller-manager -l app=cloud-controller-manager --tail=100
```

### Common Failure Scenarios

#### Scenario 1: Operator Degraded After Migration

**Symptoms:**
- Cluster operator status shows degraded
- Machines not creating
- Volumes not provisioning

**Diagnosis:**
```bash
# Check if component credentials are configured
oc get infrastructure cluster -o jsonpath='{.spec.platformSpec.vsphere.componentCredentials}' | jq .
# Output: {...} (component credentials are configured)

# Check if component secret exists
oc get secret vsphere-machine-api-creds -n openshift-machine-api
# Output: Error from server (NotFound)

# Check CCO status
oc describe credentialsrequest <name> -n openshift-machine-api
# Output: Status.Conditions: CredentialsNotFound
```

**Resolution:**
```bash
# Create missing secret with credentials for all vCenters
oc create secret generic vsphere-machine-api-creds \
  -n openshift-machine-api \
  --from-literal=vcenter1.example.com.username='machine-api@vsphere.local' \
  --from-literal=vcenter1.example.com.password='...'

# Verify operator recovers
oc get co machine-api
```

#### Scenario 2: Insufficient Privileges

**Symptoms:**
- Operator degraded
- Logs show vSphere API permission errors

**Diagnosis:**
```bash
# Check operator logs
oc logs -n openshift-machine-api -l api=clusterapi -c machine-controller --tail=50
# Output: "vim.fault.NoPermission: ... permission 'VirtualMachine.Inventory.Create' was required"

# Check CCO status
oc describe credentialsrequest <name> -n openshift-machine-api
# Output: Status.Conditions: InsufficientPrivileges, missing: VirtualMachine.Inventory.Create
```

**Resolution:**
```bash
# Grant missing privilege in vCenter (using govc example)
govc role.update openshift-machine-api VirtualMachine.Inventory.Create

# CCO will automatically re-validate and reconcile
```

#### Scenario 3: Credential Rotation Failure

**Symptoms:**
- Updated secret but operator still using old credential
- Operator logs show authentication failures

**Diagnosis:**
```bash
# Check secret was updated
oc get secret vsphere-machine-api-creds -n openshift-machine-api -o jsonpath='{.metadata.resourceVersion}'

# Check if operator pod restarted after secret update
oc get pods -n openshift-machine-api -l api=clusterapi
# Check pod age vs secret update time
```

**Resolution:**
```bash
# Manually restart operator to adopt new credentials
oc delete pod -n openshift-machine-api -l api=clusterapi

# Verify operator recovers with new credentials
oc logs -n openshift-machine-api -l api=clusterapi -c machine-controller --tail=20
```

#### Scenario 4: Multi-vCenter Credential Mismatch

**Symptoms:**
- Operations succeed on vcenter1 but fail on vcenter2
- Logs show credential missing for specific vCenter

**Diagnosis:**
```bash
# Check secret contents
oc get secret vsphere-machine-api-creds -n openshift-machine-api -o jsonpath='{.data}' | jq 'keys'
# Output: ["vcenter1.example.com.username", "vcenter1.example.com.password"]
# Missing: vcenter2 credentials

# Check Infrastructure CR for vCenter list
oc get infrastructure cluster -o jsonpath='{.spec.platformSpec.vsphere.vcenters[*].server}'
# Output: vcenter1.example.com vcenter2.example.com
```

**Resolution:**
```bash
# Add missing vcenter2 credentials
oc patch secret vsphere-machine-api-creds -n openshift-machine-api --type=json -p='[
  {"op":"add","path":"/stringData/vcenter2.example.com.username","value":"machine-api@vc2.local"},
  {"op":"add","path":"/stringData/vcenter2.example.com.password","value":"..."}
]'

# Verify operations succeed on both vCenters
```

### Must-Gather Integration

**Enhanced must-gather for credential issues:**

```bash
oc adm must-gather -- /usr/bin/gather_vsphere_credentials
```

**Collected data:**
- Infrastructure CR (credentials mode and component credential references)
- All component credential secret names (NOT contents for security)
- CredentialsRequest CRs and status
- CCO logs
- Operator logs (machine-api, storage, cloud-controller)
- vSphere connection test results (without exposing credentials)

**Privacy note:** Must-gather MUST NOT collect credential contents (passwords) for security.

## Infrastructure Needed

### Development Infrastructure

**vSphere test environment:**
- vSphere 7.0 U3 (minimum)
- vSphere 8.0 U1 (recommended)
- Two vCenter instances for multi-vCenter testing
- Sufficient compute (minimum 3 ESXi hosts per vCenter)
- Network: VLAN support for multi-network testing

### CI Infrastructure

**Existing OpenShift CI vSphere jobs:**
- Modify existing jobs to test both passthrough and per-component modes
- Add new job variant: `e2e-vsphere-per-component-credentials`

**New test job requirements:**
- Pre-provision vCenter roles with restricted privileges
- Create component credentials before cluster install
- Validate privilege validation logic

### govcsim Integration

**Enhanced govcsim for privilege validation testing:**
- Add privilege checking simulation
- Simulate multi-vCenter environments
- Simulate credential validation failures

**No additional hardware needed** (govcsim is software simulation)

## Security Considerations

### Threat Model

**Threat 1: Credential exposure in install-config.yaml**
- **Attack**: Attacker gains access to install-config.yaml in version control or backup
- **Mitigation**: 
  - Documentation warns against committing install-config.yaml
  - Installer deletes install-config.yaml after reading (existing behavior)
  - Support credentials file with enforced 0600 permissions

**Threat 2: Compromised component credential**
- **Attack**: Attacker compromises machine-api pod and extracts credentials
- **Mitigation**:
  - Blast radius limited to machine-api privileges (cannot access storage/diagnostics)
  - vCenter audit logs identify which credential performed actions
  - Other components continue operating with their isolated credentials

**Threat 3: Privilege escalation via credential**
- **Attack**: Attacker with low-privilege credential attempts operations beyond scope
- **Mitigation**:
  - vSphere enforces RBAC (credential cannot escalate privileges)
  - CCO validates privileges match requirements before use
  - Operators log credential validation failures

**Threat 4: Credential in cluster secret accessed by unauthorized pod**
- **Attack**: Attacker deploys pod in operator namespace to read credential secret
- **Mitigation**:
  - Kubernetes RBAC restricts secret access to operator service account
  - OpenShift security policies prevent arbitrary pod deployment in operator namespaces
  - Audit logs track secret access

### Security Best Practices

**Credential handling:**
- Install-config.yaml deleted after reading (existing installer behavior)
- Credentials file enforced 0600 permissions
- Secrets stored in appropriate namespaces with RBAC restrictions
- Installer credentials never persisted in cluster

**Privilege minimization:**
- Each component receives minimum required privileges
- Privilege requirements documented per component
- CCO validates privileges before distribution

**Auditability:**
- vCenter audit logs distinguish component actions by credential
- OpenShift audit logs track credential secret access
- CredentialsRequest status records validation results

**Compliance:**
- SOC2: Separation of duties via distinct credentials
- PCI-DSS: Least privilege via component-scoped credentials
- HIPAA: Audit trail via credential-based vCenter logging

## Given-When-Then Acceptance Criteria

### AC1: New cluster installation with per-component credentials

**Given** an administrator has pre-provisioned vCenter roles with appropriate privileges for each component  
**And** the administrator has created install-config.yaml with component-specific credentials provided  
**And** the administrator has provided credentials for installer, machine-api, storage, cloud-controller, and diagnostics components  
**When** the administrator runs `openshift-install create cluster`  
**Then** the installer validates all component credentials against all vCenters  
**And** the installer provisions infrastructure using installer credentials  
**And** the installer creates component secrets in appropriate namespaces  
**And** the installer does NOT persist installer credentials in the cluster  
**And** operators detect component-specific credential secrets  
**And** all cluster operators report healthy using component-specific credentials  
**And** machine creation uses machine-api credentials  
**And** storage provisioning uses storage credentials  

### AC2: Existing cluster migration to per-component credentials

**Given** an existing OpenShift cluster using passthrough mode (shared credential)  
**When** an administrator creates per-component vCenter roles  
**And** the administrator creates component secrets in the cluster  
**Then** operators detect the presence of component-specific credential secrets  
**And** operators validate all component credentials  
**And** operators gracefully restart and adopt new credentials  
**And** no cluster downtime occurs during migration  
**And** all cluster operators report healthy  
**And** machine operations succeed with scoped credentials  

### AC3: Credential rotation without downtime

**Given** an OpenShift cluster using per-component credentials  
**When** an administrator rotates the machine-api credential in vCenter  
**And** the administrator updates the machine-api secret in the cluster  
**Then** CCO detects the secret change  
**And** machine-api-operator restarts with the new credential  
**And** machine operations continue successfully  
**And** no cluster downtime occurs  

### AC4: Multi-vCenter deployment

**Given** an OpenShift cluster spanning two vCenter instances (vcenter1 and vcenter2)  
**And** each component has credentials for both vCenter instances  
**When** the administrator installs the cluster with per-component credentials  
**Then** the installer validates credentials against both vCenters  
**And** machine-api can create machines in both vCenters  
**And** storage can provision volumes in both vCenters  
**And** credentials for vcenter1 cannot access vcenter2 resources  

### AC5: Insufficient privilege detection

**Given** an administrator has created machine-api credentials with incomplete privileges  
**When** the administrator installs a cluster with these credentials  
**Then** the installer detects missing privileges during validation  
**And** the installer fails with a clear error message indicating which privilege is missing for which vCenter  
**And** no partial cluster state is created  

### AC6: Component credential secret missing

**Given** an OpenShift cluster configured for per-component credentials  
**When** the machine-api credential secret is accidentally deleted  
**Then** machine-api-operator reports degraded status  
**And** CCO sets CredentialsRequest status to "CredentialsNotFound"  
**When** the administrator recreates the credential secret  
**Then** CCO automatically reconciles  
**And** machine-api-operator recovers and reports healthy  

### AC7: Documentation and tooling

**Given** an administrator wants to deploy OpenShift with per-component credentials  
**When** the administrator reads the installation documentation  
**Then** the documentation includes:  
- Privilege requirements per component  
- govc scripts for automated role creation  
- PowerCLI templates for Windows environments  
- Example install-config.yaml with per-component credentials  
- Example credentials file format  
- Migration procedure from passthrough to per-component mode  
- Credential rotation procedure  
- Troubleshooting guide for common failures  

## References

- **Enhancement source**: https://github.com/rvanderp3/enhancements/blob/9e5c28ffd653e2b75f95ab58f76bb6edddcd5247/enhancements/installer/vsphere-multi-account-credentials-enhancement.md
- **JIRA feature**: https://redhat.atlassian.net/browse/OCPSTRAT-2933
- **vSphere installation docs**: https://docs.redhat.com/en/documentation/openshift_container_platform/4.21/html-single/installing_on_vmware_vsphere/index
- **Cloud Credential Operator**: https://github.com/openshift/cloud-credential-operator
- **Installer**: https://github.com/openshift/installer
- **Machine API Operator**: https://github.com/openshift/machine-api-operator
- **vSphere CSI Driver**: https://github.com/kubernetes-sigs/vsphere-csi-driver
- **vSphere Cloud Controller**: https://github.com/kubernetes/cloud-provider-vsphere
