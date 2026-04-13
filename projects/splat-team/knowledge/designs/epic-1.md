# Design: vSphere Multi-Account Credential Management (Component-Specific)

**Epic:** openshift-splat-team/splat-team#1 - feat: vSphere Multi-Account Credential Management  
**Status:** Revision 1 - Addresses PO Feedback  
**Author:** architect (superman)  
**Date:** 2026-04-13  
**Revision:** Incorporated component-specific credential requirements  
**Note:** Migrated from openshift-splat-team/vcf-ocp-migration#10

## Overview

This design enables the OpenShift Installer to utilize distinct VMware vCenter accounts for different components and phases of the cluster lifecycle. By separating high-privileged "Provisioning" credentials (used for infrastructure creation) from component-specific "Operational" credentials (used by individual in-cluster operators), we significantly reduce the security blast radius, enable fine-grained privilege management, and simplify compliance for enterprise environments.

The design introduces component-specific credential support in the install-config.yaml schema, automated secret provisioning per component, credential migration tooling, validation logic, and UI integration points while maintaining backward compatibility with existing single-credential installations.

**Key Enhancement (Based on PO Feedback):** Rather than a single operational credential set, this design supports independent credentials for:
- **Compute/Machine API** - VM lifecycle and machine management
- **Storage/CSI** - Volume provisioning and datastore operations
- **Cloud Controller Manager** - Cloud provider integration

## Architecture

### High-Level Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                    Install-config.yaml                           │
│  platform:                                                       │
│    vsphere:                                                      │
│      vcenters:                                                   │
│        - server: vcenter.example.com                             │
│          provisioningCredentials:                                │
│            user: admin@vsphere.local                             │
│            password: <high-privilege-password>                   │
│          componentCredentials:                                   │
│            machineAPI:                                           │
│              user: openshift-compute@vsphere.local               │
│              password: <compute-password>                        │
│            storage:                                              │
│              user: openshift-storage@vsphere.local               │
│              password: <storage-password>                        │
│            cloudController:                                      │
│              user: openshift-ccm@vsphere.local                   │
│              password: <ccm-password>                            │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    Installer (Bootstrap Phase)                   │
│  • Uses provisioningCredentials for:                             │
│    - Creating VMs (bootstrap, control plane, compute)            │
│    - Creating folders, resource pools                            │
│    - Network attachment                                          │
│    - Datastore provisioning                                      │
│  • Validates all credential sets (provisioning + components)     │
│  • Creates component-specific secrets:                           │
│    - vsphere-machine-api-credentials (kube-system)               │
│    - vsphere-storage-credentials (openshift-cluster-csi-drivers) │
│    - vsphere-cloud-credentials (openshift-cloud-controller-mgr)  │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    Running Cluster (Day 2)                       │
│  • Machine API Operator uses machineAPI credentials:             │
│    - VM lifecycle (create, delete, update)                       │
│    - Machine set scaling                                         │
│  • CSI Driver uses storage credentials:                          │
│    - Volume provisioning, attachment, deletion                   │
│    - Datastore operations                                        │
│  • Cloud Controller Manager uses cloudController credentials:    │
│    - Node metadata synchronization                               │
│    - Cloud provider integration                                  │
│  • Provisioning credentials never stored in cluster              │
└─────────────────────────────────────────────────────────────────┘
```

### Credential Separation Model

| Phase/Component | Credential Type | Required Permissions | Storage Location | Lifecycle |
|-----------------|-----------------|---------------------|------------------|-----------|
| **Bootstrap** | Provisioning | Full infrastructure creation (Folder.Create, ResourcePool.Create, VirtualMachine.Create, Network.Assign, Datastore.AllocateSpace) | Installer process memory only | Discarded after bootstrap |
| **Machine API** | Component (machineAPI) | VM lifecycle (VirtualMachine.Create, VirtualMachine.Delete, VirtualMachine.Config.*, VirtualMachine.Interact.*) | kube-system/vsphere-machine-api-credentials | Persists for cluster lifetime |
| **Storage/CSI** | Component (storage) | Datastore operations (Datastore.FileManagement, Datastore.AllocateSpace, VirtualMachine.Config.AddNewDisk, StorageProfile.View) | openshift-cluster-csi-drivers/vsphere-storage-credentials | Persists for cluster lifetime |
| **Cloud Controller** | Component (cloudController) | Node metadata (VirtualMachine.Read, VirtualMachine.GuestOperations, InventoryService.Tagging.*) | openshift-cloud-controller-manager/vsphere-cloud-credentials | Persists for cluster lifetime |

### Backward Compatibility

The design maintains full backward compatibility through multiple credential resolution modes:

1. **Legacy single-credential mode:** If only `user` and `password` are specified, all phases and components use the same credentials
2. **Dual-credential mode (deprecated):** If `operationalCredentials` is specified without component breakdown, all components use the same operational credentials
3. **Component-specific mode (new):** If `componentCredentials` with component-specific fields is specified, each component uses its dedicated credentials
4. **Hybrid mode:** Component-specific credentials can be partially specified; unspecified components fall back to `operationalCredentials` or legacy credentials

### Credential Resolution Priority

For each component, credentials are resolved in this priority order:

1. Component-specific credential (e.g., `componentCredentials.machineAPI`)
2. General operational credential (`operationalCredentials`)
3. Legacy single credential (`user`/`password`)

This allows gradual migration from single-credential to component-specific configurations.

## Components and Interfaces

### 1. Install-Config Schema Extension

**File:** `pkg/types/vsphere/platform.go`

```go
// VCenter struct extension
type VCenter struct {
    Server   string `json:"server"`
    Port     int32  `json:"port,omitempty"`
    
    // Legacy single-credential fields (deprecated but supported)
    Username string `json:"user,omitempty"`
    Password string `json:"password,omitempty"`
    
    // Dual-credential fields (transitional support)
    ProvisioningCredentials *Credentials `json:"provisioningCredentials,omitempty"`
    OperationalCredentials  *Credentials `json:"operationalCredentials,omitempty"`
    
    // Component-specific credentials (new, preferred)
    ComponentCredentials *ComponentCredentials `json:"componentCredentials,omitempty"`
    
    Datacenters []string `json:"datacenters"`
}

// Credentials represents a vCenter credential set
type Credentials struct {
    // Username is the vCenter username
    // +kubebuilder:validation:Required
    Username string `json:"user"`
    
    // Password is the vCenter password
    // +kubebuilder:validation:Required
    Password string `json:"password"`
}

// ComponentCredentials represents component-specific credential sets
type ComponentCredentials struct {
    // MachineAPI credentials for machine-api-operator (VM lifecycle)
    MachineAPI *Credentials `json:"machineAPI,omitempty"`
    
    // Storage credentials for CSI driver (volume and datastore operations)
    Storage *Credentials `json:"storage,omitempty"`
    
    // CloudController credentials for cloud-controller-manager (node metadata)
    CloudController *Credentials `json:"cloudController,omitempty"`
}
```

**Validation Rules:**
- If `componentCredentials` is specified, `user`/`password` should not be set (warning, not error)
- At least one credential mode must provide credentials for all required components
- Both credential sets must be valid and non-empty when specified
- Provisioning credentials required if not using legacy single-credential mode

### 2. Installer Credential Resolution Logic

**File:** `pkg/asset/installconfig/vsphere/client.go`

```go
// CredentialPhase identifies the lifecycle phase
type CredentialPhase string

const (
    ProvisioningPhase CredentialPhase = "provisioning"
)

// ComponentType identifies the in-cluster component
type ComponentType string

const (
    MachineAPIComponent      ComponentType = "machineAPI"
    StorageComponent         ComponentType = "storage"
    CloudControllerComponent ComponentType = "cloudController"
)

// GetProvisioningCredentials returns credentials for bootstrap phase
func (v *VCenter) GetProvisioningCredentials() (username, password string, err error) {
    // Explicit provisioning credentials (preferred)
    if v.ProvisioningCredentials != nil {
        return v.ProvisioningCredentials.Username, v.ProvisioningCredentials.Password, nil
    }
    
    // Fall back to legacy single-credential mode
    if v.Username != "" && v.Password != "" {
        return v.Username, v.Password, nil
    }
    
    return "", "", errors.New("no provisioning credentials configured")
}

// GetComponentCredentials returns credentials for a specific component
func (v *VCenter) GetComponentCredentials(component ComponentType) (username, password string, err error) {
    // Priority 1: Component-specific credentials
    if v.ComponentCredentials != nil {
        var creds *Credentials
        switch component {
        case MachineAPIComponent:
            creds = v.ComponentCredentials.MachineAPI
        case StorageComponent:
            creds = v.ComponentCredentials.Storage
        case CloudControllerComponent:
            creds = v.ComponentCredentials.CloudController
        }
        
        if creds != nil {
            return creds.Username, creds.Password, nil
        }
    }
    
    // Priority 2: General operational credentials
    if v.OperationalCredentials != nil {
        return v.OperationalCredentials.Username, v.OperationalCredentials.Password, nil
    }
    
    // Priority 3: Legacy single-credential mode
    if v.Username != "" && v.Password != "" {
        return v.Username, v.Password, nil
    }
    
    return "", "", fmt.Errorf("no credentials configured for component %s", component)
}
```

**Usage Points in Installer:**
- **Provisioning Phase:** All infrastructure creation operations during bootstrap use `GetProvisioningCredentials()`
- **Component Secrets:** Each component's secret generation calls `GetComponentCredentials(component)`

### 3. Secret Generation (Component-Specific)

**File:** `pkg/asset/manifests/vsphere/cloudproviderconfig.go`

The installer generates component-specific secrets in their respective namespaces:

```go
// SecretConfig defines where each component's secret is created
type SecretConfig struct {
    Name      string
    Namespace string
    Component ComponentType
}

var ComponentSecrets = []SecretConfig{
    {
        Name:      "vsphere-machine-api-credentials",
        Namespace: "kube-system",
        Component: MachineAPIComponent,
    },
    {
        Name:      "vsphere-storage-credentials",
        Namespace: "openshift-cluster-csi-drivers",
        Component: StorageComponent,
    },
    {
        Name:      "vsphere-cloud-credentials",
        Namespace: "openshift-cloud-controller-manager",
        Component: CloudControllerComponent,
    },
}

func GenerateComponentSecrets(vcenter *vsphere.VCenter) ([]*corev1.Secret, error) {
    secrets := make([]*corev1.Secret, 0, len(ComponentSecrets))
    
    for _, config := range ComponentSecrets {
        username, password, err := vcenter.GetComponentCredentials(config.Component)
        if err != nil {
            return nil, errors.Wrapf(err, "failed to get credentials for %s", config.Component)
        }
        
        secret := &corev1.Secret{
            TypeMeta: metav1.TypeMeta{
                APIVersion: "v1",
                Kind:       "Secret",
            },
            ObjectMeta: metav1.ObjectMeta{
                Name:      config.Name,
                Namespace: config.Namespace,
                Labels: map[string]string{
                    "vsphere.openshift.io/credential-component": string(config.Component),
                },
            },
            Type: corev1.SecretTypeOpaque,
            Data: map[string][]byte{
                "username": []byte(username),
                "password": []byte(password),
            },
        }
        
        secrets = append(secrets, secret)
    }
    
    return secrets, nil
}
```

**Security Considerations:**
- Provisioning credentials are NEVER written to cluster secrets
- Provisioning credentials exist only in installer process memory
- Each component secret contains only the credentials for that specific component
- Component secrets are labeled for identification and management
- Provisioning credentials are not logged (redacted in verbose output)

### 4. Permission Validation (Component-Specific)

**File:** `pkg/asset/installconfig/vsphere/permissions.go`

The installer validates that each credential set has the required permissions for its component:

```go
type PermissionValidator struct {
    client *vim25.Client
}

// ValidateProvisioningPermissions checks that the provisioning account has required permissions
func (v *PermissionValidator) ValidateProvisioningPermissions(ctx context.Context, username string) error {
    requiredPrivileges := []string{
        "Folder.Create",
        "Folder.Delete",
        "ResourcePool.Create",
        "ResourcePool.Delete",
        "VirtualMachine.Config.AddNewDisk",
        "VirtualMachine.Config.AddRemoveDevice",
        "VirtualMachine.Interact.PowerOn",
        "VirtualMachine.Interact.PowerOff",
        "VirtualMachine.Provisioning.Clone",
        "VirtualMachine.Provisioning.DeployTemplate",
        "Datastore.AllocateSpace",
        "Datastore.Browse",
        "Network.Assign",
    }
    
    return v.validatePrivileges(ctx, username, requiredPrivileges)
}

// ValidateMachineAPIPermissions checks machine-api-operator credential permissions
func (v *PermissionValidator) ValidateMachineAPIPermissions(ctx context.Context, username string) error {
    requiredPrivileges := []string{
        "VirtualMachine.Config.AddNewDisk",
        "VirtualMachine.Config.AddRemoveDevice",
        "VirtualMachine.Config.Settings",
        "VirtualMachine.Interact.PowerOn",
        "VirtualMachine.Interact.PowerOff",
        "VirtualMachine.Provisioning.Clone",
        "VirtualMachine.Provisioning.Customize",
        "VirtualMachine.Inventory.Create",
        "VirtualMachine.Inventory.Delete",
    }
    
    return v.validatePrivileges(ctx, username, requiredPrivileges)
}

// ValidateStoragePermissions checks CSI driver credential permissions
func (v *PermissionValidator) ValidateStoragePermissions(ctx context.Context, username string) error {
    requiredPrivileges := []string{
        "VirtualMachine.Config.AddNewDisk",
        "VirtualMachine.Config.AddRemoveDevice",
        "VirtualMachine.Config.RemoveDisk",
        "Datastore.FileManagement",
        "Datastore.Browse",
        "Datastore.AllocateSpace",
        "StorageProfile.View",
    }
    
    return v.validatePrivileges(ctx, username, requiredPrivileges)
}

// ValidateCloudControllerPermissions checks cloud-controller-manager credential permissions
func (v *PermissionValidator) ValidateCloudControllerPermissions(ctx context.Context, username string) error {
    requiredPrivileges := []string{
        "VirtualMachine.Read",
        "VirtualMachine.GuestOperations.Query",
        "InventoryService.Tagging.ObjectAttachable",
        "InventoryService.Tagging.ReadUsedTags",
    }
    
    return v.validatePrivileges(ctx, username, requiredPrivileges)
}

// ValidateAllCredentials validates all credential sets
func (v *PermissionValidator) ValidateAllCredentials(ctx context.Context, vcenter *vsphere.VCenter) error {
    // Validate provisioning credentials
    provUsername, _, err := vcenter.GetProvisioningCredentials()
    if err != nil {
        return errors.Wrap(err, "failed to get provisioning credentials")
    }
    
    if err := v.ValidateProvisioningPermissions(ctx, provUsername); err != nil {
        return errors.Wrapf(err, "provisioning credentials validation failed for %s", provUsername)
    }
    
    // Validate component credentials
    components := []struct {
        component ComponentType
        validator func(context.Context, string) error
    }{
        {MachineAPIComponent, v.ValidateMachineAPIPermissions},
        {StorageComponent, v.ValidateStoragePermissions},
        {CloudControllerComponent, v.ValidateCloudControllerPermissions},
    }
    
    for _, comp := range components {
        username, _, err := vcenter.GetComponentCredentials(comp.component)
        if err != nil {
            return errors.Wrapf(err, "failed to get credentials for %s", comp.component)
        }
        
        if err := comp.validator(ctx, username); err != nil {
            return errors.Wrapf(err, "%s credentials validation failed for %s", comp.component, username)
        }
    }
    
    return nil
}
```

**Validation Execution:**
- Runs during `openshift-install create cluster` validation phase
- Provides clear error messages indicating which permissions are missing and for which component
- Separate validation for each credential set
- Fails fast before infrastructure creation begins

### 5. Migration Tooling (Component-Specific)

**Implementation:** New subcommand `openshift-install vsphere migrate-credentials`

```bash
# Migrate all components to new credentials
openshift-install vsphere migrate-credentials \
  --kubeconfig=/path/to/kubeconfig \
  --config=/path/to/new-credentials.yaml

# Migrate specific component only
openshift-install vsphere migrate-credentials \
  --kubeconfig=/path/to/kubeconfig \
  --component=machineAPI \
  --username=openshift-compute@vsphere.local \
  --password-file=/path/to/password
```

**Migration Configuration YAML:**
```yaml
componentCredentials:
  machineAPI:
    user: openshift-compute@vsphere.local
    password: <password>
  storage:
    user: openshift-storage@vsphere.local
    password: <password>
  cloudController:
    user: openshift-ccm@vsphere.local
    password: <password>
```

**Workflow:**
1. Validates the new component credentials against the vCenter
2. Tests component-specific permissions for each credential
3. Updates the component-specific secrets atomically
4. Verifies that in-cluster components can authenticate with new credentials
5. Rolls back on failure (per-component or all)

**Atomicity Guarantee:**
- Uses Kubernetes strategic merge patch for secret updates
- Validates new credentials before applying
- Monitors component health after update (operator status, pod readiness)
- Automatic rollback if components fail to authenticate within 2 minutes
- Per-component rollback for partial migration scenarios

### 6. UI Integration Points

#### Assisted Installer

**Component:** Assisted Installer backend API

**API Extension:**
```json
{
  "platform": {
    "type": "vsphere",
    "vsphere": {
      "vcenters": [{
        "server": "vcenter.example.com",
        "provisioningCredentials": {
          "username": "admin@vsphere.local",
          "password": "<redacted>"
        },
        "componentCredentials": {
          "machineAPI": {
            "username": "openshift-compute@vsphere.local",
            "password": "<redacted>"
          },
          "storage": {
            "username": "openshift-storage@vsphere.local",
            "password": "<redacted>"
          },
          "cloudController": {
            "username": "openshift-ccm@vsphere.local",
            "password": "<redacted>"
          }
        }
      }]
    }
  }
}
```

**UI Changes:**
- "Infrastructure Provider" step gains a toggle: "Use component-specific credentials"
- When enabled, credential input sections appear:
  - "Provisioning Account" (required)
  - "Compute/Machine API Account" (optional, with "Use same as provisioning" checkbox)
  - "Storage Account" (optional, with "Use same as provisioning" checkbox)
  - "Cloud Controller Account" (optional, with "Use same as provisioning" checkbox)
- Validation button tests all credential sets against vCenter API
- Permission check shows per-component validation results
- Help text explains component-specific privilege separation model

**Progressive Disclosure:**
- Default mode: Single credential (backward compatible)
- Advanced mode: Component-specific credentials with granular control
- Fallback indicators show which components are using fallback credentials

#### OpenShift Console (Post-Install)

**Component:** Console cluster settings page

**Feature:** "Update vSphere Component Credentials" button
- Opens a modal dialog showing current credential configuration
- Allows updating individual component credentials or all at once
- Validates credentials against vCenter
- Shows component-specific permission validation
- Executes component-specific credential migration workflow
- Shows progress and status of migration per component
- Displays rollback status on failure

## Data Models

### Install-Config YAML Example (Component-Specific Mode - Full)

```yaml
apiVersion: v1
baseDomain: example.com
metadata:
  name: vsphere-cluster
platform:
  vsphere:
    apiVIPs:
      - 192.168.1.100
    ingressVIPs:
      - 192.168.1.101
    vcenters:
      - server: vcenter.example.com
        port: 443
        provisioningCredentials:
          user: admin@vsphere.local
          password: <high-privilege-password>
        componentCredentials:
          machineAPI:
            user: openshift-compute@vsphere.local
            password: <compute-password>
          storage:
            user: openshift-storage@vsphere.local
            password: <storage-password>
          cloudController:
            user: openshift-ccm@vsphere.local
            password: <ccm-password>
        datacenters:
          - DC1
    failureDomains:
      - name: fd-az1
        region: region-az1
        zone: zone-az1
        server: vcenter.example.com
        topology:
          datacenter: DC1
          computeCluster: /DC1/host/Cluster1
          networks:
            - VM Network
          datastore: /DC1/datastore/datastore1
```

### Install-Config YAML Example (Hybrid Mode - Partial Component Credentials)

```yaml
apiVersion: v1
baseDomain: example.com
metadata:
  name: vsphere-cluster
platform:
  vsphere:
    vcenters:
      - server: vcenter.example.com
        port: 443
        provisioningCredentials:
          user: admin@vsphere.local
          password: <high-privilege-password>
        # Operational credentials as fallback for unspecified components
        operationalCredentials:
          user: openshift-ops@vsphere.local
          password: <ops-password>
        # Only storage gets component-specific credentials
        componentCredentials:
          storage:
            user: openshift-storage@vsphere.local
            password: <storage-password>
          # machineAPI and cloudController fall back to operationalCredentials
        datacenters:
          - DC1
```

### Install-Config YAML Example (Backward-Compatible Single-Credential Mode)

```yaml
apiVersion: v1
baseDomain: example.com
metadata:
  name: vsphere-cluster
platform:
  vsphere:
    vcenters:
      - server: vcenter.example.com
        port: 443
        user: admin@vsphere.local
        password: <single-password>
        datacenters:
          - DC1
    # ... rest of config
```

### Component Secrets

#### Machine API Secret
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: vsphere-machine-api-credentials
  namespace: kube-system
  labels:
    vsphere.openshift.io/credential-component: machineAPI
type: Opaque
data:
  username: b3BlbnNoaWZ0LWNvbXB1dGVAdnNwaGVyZS5sb2NhbA==  # openshift-compute@vsphere.local
  password: PGNvbXB1dGUtcGFzc3dvcmQ+                      # <compute-password>
```

#### Storage Secret
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: vsphere-storage-credentials
  namespace: openshift-cluster-csi-drivers
  labels:
    vsphere.openshift.io/credential-component: storage
type: Opaque
data:
  username: b3BlbnNoaWZ0LXN0b3JhZ2VAdnNwaGVyZS5sb2NhbA==  # openshift-storage@vsphere.local
  password: PHN0b3JhZ2UtcGFzc3dvcmQ+                      # <storage-password>
```

#### Cloud Controller Secret
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: vsphere-cloud-credentials
  namespace: openshift-cloud-controller-manager
  labels:
    vsphere.openshift.io/credential-component: cloudController
type: Opaque
data:
  username: b3BlbnNoaWZ0LWNjbUB2c3BoZXJlLmxvY2Fs          # openshift-ccm@vsphere.local
  password: PGNjbS1wYXNzd29yZD4=                          # <ccm-password>
```

## Error Handling

### Validation Errors

| Error Condition | Error Message | Resolution |
|-----------------|---------------|------------|
| Mixed credential modes | "Cannot specify both legacy (user/password) and component-specific (componentCredentials) fields" | Remove one set of credentials |
| No credentials for component | "No credentials configured for component [component]. Specify componentCredentials.[component] or provide fallback via operationalCredentials or user/password" | Add credentials for component or provide fallback |
| Provisioning permissions insufficient | "Provisioning account [username] lacks required privileges: [list]. See documentation for required permissions" | Grant missing privileges or use different account |
| Component permissions insufficient | "Component [component] account [username] lacks required privileges: [list]. See documentation for required permissions" | Grant missing privileges or use different account |
| Credentials invalid | "Failed to authenticate to vCenter [server] with [username] for [component/phase]: [error]" | Verify credentials and vCenter connectivity |

### Runtime Errors

| Error Condition | Handling Strategy |
|-----------------|-------------------|
| Provisioning authentication fails during bootstrap | Fail installation with clear error message indicating credential issue |
| Component credential secret not created | Fail installation before completing bootstrap to prevent cluster with invalid credentials |
| Migration tool fails mid-update for a component | Automatic rollback of that component's secret, log failure details, continue or exit based on flag |
| In-cluster component fails after migration | Migration tool detects component degradation, rolls back that component's secret, reports failure |
| Partial component credential specification | Log warning about fallback usage, proceed with hybrid mode |

### Error Propagation

- All credential-related errors are logged to installer log with full context including component identification
- Sensitive information (passwords) is redacted in logs
- Error messages include actionable remediation steps and component context
- Failed installations leave diagnostic information in `.openshift_install_state.json`
- Migration tool provides detailed per-component status and rollback information

## Acceptance Criteria (Given-When-Then Format)

### AC1: Component-Specific Credential Installation

**Given** I have a vCenter environment with four accounts:
- `admin@vsphere.local` with full infrastructure creation privileges
- `openshift-compute@vsphere.local` with VM lifecycle privileges
- `openshift-storage@vsphere.local` with datastore operation privileges
- `openshift-ccm@vsphere.local` with node metadata read privileges

**When** I create an install-config.yaml specifying all accounts in the `provisioningCredentials` and `componentCredentials` fields

**And** I run `openshift-install create cluster`

**Then** the installer successfully bootstraps the cluster using the provisioning account

**And** the `kube-system/vsphere-machine-api-credentials` secret contains only the compute account credentials

**And** the `openshift-cluster-csi-drivers/vsphere-storage-credentials` secret contains only the storage account credentials

**And** the `openshift-cloud-controller-manager/vsphere-cloud-credentials` secret contains only the cloud controller account credentials

**And** machine-api-operator authenticates using the compute account

**And** CSI driver authenticates using the storage account

**And** cloud-controller-manager authenticates using the cloud controller account

**And** vCenter audit logs show infrastructure creation actions attributed to `admin@vsphere.local`

**And** vCenter audit logs show VM lifecycle actions attributed to `openshift-compute@vsphere.local`

**And** vCenter audit logs show storage operations attributed to `openshift-storage@vsphere.local`

**And** vCenter audit logs show node metadata operations attributed to `openshift-ccm@vsphere.local`

### AC2: Hybrid Credential Mode (Partial Component Specification)

**Given** I have a vCenter environment with three accounts:
- `admin@vsphere.local` with full infrastructure creation privileges
- `openshift-ops@vsphere.local` with general operational privileges
- `openshift-storage@vsphere.local` with specialized storage privileges

**When** I create an install-config.yaml specifying:
- `provisioningCredentials`: admin account
- `operationalCredentials`: ops account
- `componentCredentials.storage`: storage account (only storage specified)

**And** I run `openshift-install create cluster`

**Then** the installer successfully bootstraps the cluster using the provisioning account

**And** the storage component uses the storage-specific credentials

**And** the machine-api and cloud-controller components use the operational credentials (fallback)

**And** all components function correctly with their assigned credentials

### AC3: Component-Specific Permission Validation

**Given** I specify `componentCredentials.machineAPI` with insufficient permissions (missing `VirtualMachine.Inventory.Create`)

**When** I run `openshift-install create cluster`

**Then** the installer fails during validation phase before creating any infrastructure

**And** the error message clearly identifies the missing privilege, which component requires it, and which account lacks it

**And** the error message includes a link to documentation on component-specific required permissions

### AC4: Component-Specific Credential Migration

**Given** I have a running cluster installed with single-credential mode (all components use same account)

**When** I run `openshift-install vsphere migrate-credentials` with component-specific credentials configuration

**Then** the migration tool validates all new component credentials against vCenter

**And** the tool updates each component's secret atomically

**And** all in-cluster components continue to function without interruption

**And** subsequent component operations use the new component-specific credentials

**And** vCenter audit logs show component-segregated actions

**And** If the migration of one component fails, the tool automatically rolls back that component's credentials

### AC5: Per-Component Credential Migration

**Given** I have a running cluster with operational credentials for all components

**When** I run `openshift-install vsphere migrate-credentials --component=storage` with new storage credentials

**Then** the migration tool validates only the storage credentials against vCenter

**And** the tool updates only the storage secret

**And** machine-api and cloud-controller components continue using their existing credentials

**And** the storage component uses the new credentials

**And** If the storage migration fails, the tool automatically rolls back the storage credentials without affecting other components

### AC6: UI Integration (Assisted Installer)

**Given** I am using the Assisted Installer UI to configure a vSphere cluster

**When** I navigate to the "Infrastructure Provider" configuration step

**Then** I see a toggle option "Use component-specific credentials"

**When** I enable the toggle

**Then** I see credential input sections for:
- Provisioning Account
- Compute/Machine API Account (with "Use same as provisioning" checkbox)
- Storage Account (with "Use same as provisioning" checkbox)
- Cloud Controller Account (with "Use same as provisioning" checkbox)

**When** I specify different credentials for each component and click "Validate Credentials"

**Then** the UI tests all credential sets against the vCenter API

**And** displays success or error messages for each credential set independently with component-specific permission validation results

### AC7: Backward Compatibility

**Given** I have an existing install-config.yaml using the legacy `user` and `password` fields

**When** I run `openshift-install create cluster`

**Then** the installer successfully bootstraps the cluster using the single credential set

**And** all component secrets contain the same credentials as used for provisioning

**And** all cluster operations function identically to pre-enhancement behavior

## Impact on Existing System

### Installation Flow

**Modified Components:**
- `pkg/types/vsphere/platform.go` - Schema extension for component-specific credentials
- `pkg/asset/installconfig/vsphere/client.go` - Component-aware credential resolution logic
- `pkg/asset/installconfig/vsphere/validation.go` - Component-specific credential validation
- `pkg/asset/installconfig/vsphere/permissions.go` - Per-component permission validation
- `pkg/asset/manifests/vsphere/cloudproviderconfig.go` - Component-specific secret generation

**Unchanged Components:**
- Infrastructure creation logic (uses credentials via abstraction)
- Bootstrap machine creation
- Control plane machine creation
- Failure domain handling
- Network configuration

### Cluster Runtime

**Modified Components:**
- Cloud controller manager (no code changes, reads from new secret location)
- CSI driver (no code changes, reads from new secret location)
- Machine API operator (no code changes, reads from new secret location)

**Secret Location Changes:**
- Machine API: `kube-system/vsphere-machine-api-credentials` (new)
- Storage/CSI: `openshift-cluster-csi-drivers/vsphere-storage-credentials` (new)
- Cloud Controller: `openshift-cloud-controller-manager/vsphere-cloud-credentials` (location maintained, credential may differ)

**Unchanged Components:**
- All other operators and controllers
- Cluster authentication
- Cluster authorization
- Node bootstrap

### Component-Credential Mapping

| Component | Reads Secret From | Secret Name | Namespace |
|-----------|-------------------|-------------|-----------|
| machine-api-operator | Namespace-local | vsphere-machine-api-credentials | kube-system |
| vsphere-csi-driver | Namespace-local | vsphere-storage-credentials | openshift-cluster-csi-drivers |
| cloud-controller-manager | Namespace-local | vsphere-cloud-credentials | openshift-cloud-controller-manager |

### Migration Impact

**Risks:**
- **Component disruption:** If component-specific migration is not atomic, individual components might fail to authenticate during transition
- **Mitigation:** Use Kubernetes atomic secret update with per-component validation and rollback

**Compatibility:**
- Clusters installed with single-credential mode can migrate to component-specific mode (one-way or partial)
- Migration tool supports per-component migration for gradual transition
- Migration tool is non-destructive (can be re-run if needed)
- No cluster downtime required for migration

### Documentation Updates Required

| Document | Change |
|----------|--------|
| Installing on vSphere | Add section on component-specific credential configuration |
| Installing on vSphere | Add section on permission requirements for each component credential type |
| Installing on vSphere | Add section on hybrid credential mode and fallback resolution |
| Day 2 Operations | Add component-specific credential migration procedure |
| Day 2 Operations | Add per-component credential rotation procedure |
| Security Best Practices | Add guidance on component-specific privilege separation for vSphere credentials |
| Assisted Installer Guide | Update UI screenshots and component-specific credential input instructions |
| Troubleshooting Guide | Add component-specific credential-related error messages and resolutions |

## Security Considerations

### Threat Model

| Threat | Mitigation |
|--------|------------|
| **Cluster compromise leading to vCenter admin access** | Component-specific credentials stored in-cluster have minimal privileges for their respective functions. Provisioning credentials never stored in-cluster. |
| **Credential exposure in logs** | All credential output is redacted in installer logs and verbose output. |
| **Credential exposure in install-config.yaml** | Install-config.yaml should be stored securely and deleted after installation. Documentation emphasizes this. |
| **Man-in-the-middle credential interception** | vCenter communication uses TLS. Certificate validation enforced by default. |
| **Unauthorized credential migration** | Migration tool requires kubeconfig with admin privileges. RBAC controls access to secret modification. |
| **Component credential theft leading to broader access** | Each component credential set has minimal privileges for that component only. Cannot escalate to other components or infrastructure changes. |
| **Cross-component privilege escalation** | Component credentials are segregated with distinct permission sets. Compromise of one component's credentials does not grant access to other components' operations. |

### Privilege Escalation Prevention

**Provisioning Account Privileges:**
- Required for infrastructure creation only
- Not stored in cluster after bootstrap
- Cannot be accessed by compromised workloads
- Scope limited to vCenter infrastructure operations

**Component-Specific Operational Privileges:**
- **Machine API:** VM lifecycle only (create, delete, configure VMs). Cannot access datastores or modify cloud provider metadata.
- **Storage/CSI:** Datastore and volume operations only. Cannot create/delete VMs or access cloud provider metadata.
- **Cloud Controller:** Read-only node metadata and tagging. Cannot create/delete VMs or modify storage.

**Privilege Isolation:**
- Each component can only perform its designated operations
- No component credential has full vCenter administrative access
- Cross-component access is prevented through distinct permission sets

### Credential Storage Security

| Credential Set | Storage Location | Access Control | Lifecycle | Component Scope |
|----------------|------------------|----------------|-----------|-----------------|
| Provisioning | Installer process memory only | OS-level process isolation | Destroyed after bootstrap completion | N/A |
| Machine API | Kubernetes Secret (kube-system) | RBAC (cluster-admin only) | Persists for cluster lifetime | VM lifecycle |
| Storage/CSI | Kubernetes Secret (openshift-cluster-csi-drivers) | RBAC (cluster-admin only) | Persists for cluster lifetime | Volume/datastore ops |
| Cloud Controller | Kubernetes Secret (openshift-cloud-controller-manager) | RBAC (cluster-admin only) | Persists for cluster lifetime | Node metadata |
| Install-config | Local filesystem | Filesystem permissions | User responsible for deletion | All (before installation) |

### Compliance Benefits

This component-specific credential feature enables organizations to meet the following compliance requirements:
- **Principle of Least Privilege:** Each component has minimal permissions for its specific function
- **Segregation of Duties:** Different accounts for provisioning vs. operations, and different accounts for different operational components
- **Audit Trail:** vCenter logs clearly attribute actions to specific component accounts
- **Credential Rotation:** Component credentials can be rotated independently without affecting other components
- **Blast Radius Reduction:** Compromised cluster component cannot destroy infrastructure or access other components' operations
- **Fine-Grained Access Control:** Component-specific credential assignment enables compliance with security frameworks requiring operational segregation (e.g., PCI-DSS, NIST 800-53)

### Audit and Logging

**vCenter Audit Logs:**
- All provisioning actions attributed to provisioning account username
- All machine lifecycle operations attributed to machine-api account username
- All storage operations attributed to storage account username
- All cloud provider operations attributed to cloud-controller account username
- Clear component-level separation in audit trail for forensic analysis
- Easy identification of which OpenShift component performed which action

**OpenShift Audit Logs:**
- Secret access to component-specific credentials logged via Kubernetes audit
- Migration operations logged as administrative actions per component
- Failed authentication attempts logged with component identification

## Dependencies

### Internal Dependencies

| Component | Version | Requirement |
|-----------|---------|-------------|
| OpenShift Installer | 4.18+ | Schema validation, manifest generation, component-specific secret creation |
| Cloud Controller Manager | 4.18+ | Read credentials from new secret location (no code changes) |
| vSphere CSI Driver | 2.8+ | Read credentials from new secret location (no code changes) |
| Machine API Operator | 4.18+ | Read credentials from new secret location (no code changes) |

### External Dependencies

| Component | Version | Requirement |
|-----------|---------|-------------|
| VMware vCenter | 7.0+ | Permission validation API, audit logging, component-specific permission management |
| govmomi library | Latest | vCenter API client with permission checks |

### Testing Dependencies

| Component | Purpose |
|-----------|---------|
| vCenter test environment | Integration testing with real vCenter and component-specific credential scenarios |
| vCenter simulator (vcsim) | Unit testing component credential resolution and validation |
| Kubernetes test cluster | Migration tool testing for component-specific credential updates |

### Operator Integration

**Machine API Operator:**
- Reads from `kube-system/vsphere-machine-api-credentials`
- No code changes required (existing secret reading mechanism works)
- Credential resolution handled transparently

**vSphere CSI Driver:**
- Reads from `openshift-cluster-csi-drivers/vsphere-storage-credentials`
- No code changes required (configurable secret name)
- Credential resolution handled transparently

**Cloud Controller Manager:**
- Reads from `openshift-cloud-controller-manager/vsphere-cloud-credentials`
- No code changes required (existing secret location maintained)
- Credential resolution handled transparently

## Implementation Phases

### Phase 1: Core Schema and Validation
- Add ComponentCredentials type to platform.go
- Extend VCenter struct with component-specific credential fields
- Implement GetProvisioningCredentials() and GetComponentCredentials() methods
- Add validation for credential modes and fallback resolution
- Unit tests for component-specific credential resolution
- Hybrid mode testing

### Phase 2: Component-Specific Permission Validation
- Implement PermissionValidator with component-specific validators
- Add ValidateProvisioningPermissions()
- Add ValidateMachineAPIPermissions()
- Add ValidateStoragePermissions()
- Add ValidateCloudControllerPermissions()
- Integration tests with vcsim for each component

### Phase 3: Component-Specific Secret Generation
- Modify cloud credentials secret generation to support multiple secrets
- Implement GenerateComponentSecrets()
- Ensure component-specific credentials used for each secret
- Add namespace and secret name configuration per component
- Add tests for component secret content verification
- Add label-based secret identification

### Phase 4: Migration Tooling
- Implement `openshift-install vsphere migrate-credentials` subcommand
- Add component-specific credential validation
- Implement per-component atomic secret update
- Add per-component rollback logic
- Add all-component and single-component migration modes
- End-to-end migration tests for each component and combined scenarios

### Phase 5: UI Integration
- Assisted Installer API extension for component-specific credentials
- Assisted Installer UI changes (component credential input, progressive disclosure)
- Console component-specific credential update feature
- Per-component credential validation in UI
- UI/UX testing for component-specific flows

### Phase 6: Documentation and Release
- User documentation (component-specific credential configuration)
- Administrator documentation (component-specific credential management)
- Security guide updates (component privilege separation)
- Troubleshooting guide (component-specific error messages)
- Migration guide (single → component-specific credential transition)
- Release notes

## Open Questions

**Resolved (addressed in revision):**
- ✅ How should component-specific credentials be structured? → ComponentCredentials with machineAPI, storage, cloudController fields
- ✅ What fallback mechanism should be used for partial component specification? → Priority resolution: component-specific → operational → legacy
- ✅ How should migration handle component-specific updates? → Per-component migration support with independent rollback

**Remaining:**
None at this time. All requirements from the epic and PO feedback are addressed in this design.

## References

- Epic: [openshift-splat-team/splat-team#1](https://github.com/openshift-splat-team/splat-team/issues/1) - feat: vSphere Multi-Account Credential Management (migrated from vcf-ocp-migration#10)
- PO Feedback (2026-04-13): "The design should allow specific credentials to be assigned to specific components. These components are compute/machine API, storage, cloud controller manager."
- Enhancement Proposal: [vSphere Multi-Account Credentials](https://github.com/rvanderp3/enhancements/blob/9e5c28ffd653e2b75f95ab58f76bb6edddcd5247/enhancements/installer/vsphere-multi-account-credentials-enhancement.md)
- vSphere Documentation: [Installing OpenShift on vSphere](https://docs.redhat.com/en/documentation/openshift_container_platform/4.21/html-single/installing_on_vmware_vsphere/index)
- VMware vSphere Permission Reference: [vSphere Security Documentation](https://docs.vmware.com/en/VMware-vSphere/7.0/com.vmware.vsphere.security.doc/GUID-index.html)
