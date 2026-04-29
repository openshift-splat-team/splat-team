# vSphere Multi-Account Credential Management

## Overview

The vSphere multi-account credential management feature enables OpenShift installations to use separate vCenter credentials for different operational phases and components. This provides privilege separation, reducing the security blast radius and improving compliance.

## Key Concepts

### Credential Types

**Provisioning Credentials**
- High-privilege account used during cluster installation
- Required permissions: VM creation, network configuration, storage provisioning
- Used only during the installation phase
- Not persisted in cluster configuration (unless explicitly requested)

**Operational Credentials**
- Restricted-privilege account for day-2 operations
- Minimal permissions required for ongoing cluster operations
- Persisted in the `vsphere-cloud-credentials` secret in `kube-system` namespace
- Used by in-cluster components after installation completes

### Component-Specific Credentials

Each component can be configured with its own vCenter credentials:

- **machine-api**: VM lifecycle management
- **storage**: Persistent volume operations
- **diagnostics**: Health checks and monitoring
- **cloud controller**: Cloud provider integration

## Configuration

### New Installation with Multi-Account Credentials

To install a new OpenShift IPI cluster on vSphere with separate provisioning and operational credentials:

```yaml
# install-config.yaml
apiVersion: v1
baseDomain: example.com
metadata:
  name: my-cluster
platform:
  vsphere:
    vcenters:
    - server: vcenter.example.com
      # Provisioning credentials (high privilege)
      provisioningCredentials:
        username: admin@vsphere.local
        password: <provisioning-password>
      # Operational credentials (restricted privilege)
      operationalCredentials:
        username: openshift-ops@vsphere.local
        password: <operational-password>
      datacenters:
      - datacenter1
```

#### Component-Specific Credential Override

To use different credentials for specific components:

```yaml
platform:
  vsphere:
    vcenters:
    - server: vcenter.example.com
      provisioningCredentials:
        username: admin@vsphere.local
        password: <provisioning-password>
      operationalCredentials:
        username: openshift-ops@vsphere.local
        password: <operational-password>
      # Component overrides
      componentCredentials:
        machineAPI:
          username: openshift-machine-api@vsphere.local
          password: <machine-api-password>
        storage:
          username: openshift-storage@vsphere.local
          password: <storage-password>
```

### Migration Path for Existing Clusters

Existing single-account clusters can be migrated to use operational credentials without downtime.

**Prerequisites:**
- Create the operational vCenter account with appropriate permissions
- Ensure the account has necessary access to existing cluster resources

**Migration Steps:**

1. Create a new vCenter account with operational-level permissions
2. Update the `vsphere-cloud-credentials` secret:

```bash
# Create new credentials secret
oc create secret generic vsphere-cloud-credentials \
  --from-literal=username=openshift-ops@vsphere.local \
  --from-literal=password=<operational-password> \
  -n kube-system \
  --dry-run=client -o yaml | oc apply -f -
```

3. Restart affected operators to pick up new credentials:

```bash
oc rollout restart deployment/cluster-storage-operator -n openshift-cluster-storage-operator
oc rollout restart deployment/machine-api-operator -n openshift-machine-api
```

4. Verify components are functioning with new credentials:

```bash
oc get co
```

## Permission Requirements

### Provisioning Account Permissions

Required during installation:

- Create and manage VMs
- Create and manage virtual disks
- Configure virtual machine networks
- Create resource pools
- Create folders
- Manage datastore allocation

### Operational Account Permissions

Required for day-2 operations:

- Read VM properties
- Modify VM settings (limited)
- Create/delete virtual disks (for storage operations)
- Monitor performance metrics
- Read resource pool information

### Component-Specific Permissions

**machine-api:**
- VM power operations
- VM creation/deletion
- Virtual disk management

**storage:**
- Virtual disk creation/deletion
- Datastore access

**diagnostics:**
- Read-only access to VM and cluster health

**cloud controller:**
- VM metadata access
- Network configuration read

## Security Best Practices

1. **Principle of Least Privilege**: Only grant operational accounts the minimum permissions required
2. **Credential Rotation**: Regularly rotate operational credentials
3. **Audit Logging**: Enable vCenter audit logging to track which account performs which actions
4. **Separate Accounts**: Use distinct accounts for each component when compliance requires attribution
5. **Secret Management**: Use external secret management systems (e.g., Vault) where possible

## Troubleshooting

### Credential Authentication Failures

**Symptom:** Cluster operators degraded with authentication errors

**Diagnosis:**
```bash
oc get co
oc logs -n openshift-machine-api deployment/machine-api-operator
```

**Resolution:**
1. Verify credentials in `vsphere-cloud-credentials` secret
2. Confirm vCenter account is not locked or expired
3. Check account permissions in vCenter

### Component-Specific Credential Issues

**Symptom:** Specific component (e.g., storage) failing while others work

**Diagnosis:**
```bash
oc get events -n openshift-cluster-storage-operator
oc describe secret vsphere-cloud-credentials-storage -n kube-system
```

**Resolution:**
1. Verify component-specific credential configuration
2. Check component account has required permissions
3. Confirm credential secret exists and is correctly formatted

### Credential Transition Failures

**Symptom:** Installation hangs during provisioning-to-operational credential transition

**Diagnosis:**
Check installer logs for credential transition errors

**Resolution:**
1. Ensure operational account has access to installer-provisioned resources
2. Verify operational account permissions are sufficient
3. Check network connectivity to vCenter

## Architecture

### Credential Flow

```
Installation Phase:
  Installer → Provisioning Credentials → vCenter
  ↓
  Creates cluster infrastructure
  ↓
  Transitions to operational credentials
  ↓
  Persists operational credentials in vsphere-cloud-credentials secret

Day-2 Operations:
  In-cluster Operators → vsphere-cloud-credentials secret → vCenter
```

### Secret Management

The `vsphere-cloud-credentials` secret in the `kube-system` namespace contains operational credentials:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: vsphere-cloud-credentials
  namespace: kube-system
type: Opaque
data:
  username: <base64-encoded-username>
  password: <base64-encoded-password>
```

Component-specific secrets follow the naming pattern:
- `vsphere-cloud-credentials-machineapi`
- `vsphere-cloud-credentials-storage`
- `vsphere-cloud-credentials-diagnostics`
- `vsphere-cloud-credentials-cloudcontroller`

## References

- **Enhancement Proposal**: [vsphere-multi-account-credentials-enhancement.md](https://github.com/rvanderp3/enhancements/blob/9e5c28ffd653e2b75f95ab58f76bb6edddcd5247/enhancements/installer/vsphere-multi-account-credentials-enhancement.md)
- **Upstream Documentation**: [Installing on vSphere](https://docs.redhat.com/en/documentation/openshift_container_platform/4.21/html-single/installing_on_vmware_vsphere/index)
- **JIRA Epic**: [OCPSTRAT-2933](https://redhat.atlassian.net/browse/OCPSTRAT-2933)
- **Implementation Issues**: See Epic [#14](https://github.com/openshift-splat-team/splat-team/issues/14)
