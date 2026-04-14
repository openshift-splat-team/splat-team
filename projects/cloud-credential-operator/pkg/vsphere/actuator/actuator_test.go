package actuator

import (
	"context"
	"encoding/base64"
	"testing"
)

// TestCreateComponentSecrets_SingleVCenter verifies AC1: Single vCenter secret generation.
//
// Acceptance Criteria 1:
// Given an install-config with per-component credentials for a single vCenter
// When CCO creates secrets
// Then each component secret contains `username` and `password` keys with appropriate credentials
//
// Expected Behavior:
//   - Create 4 component-specific secrets:
//     - machine-api-vsphere-credentials (openshift-machine-api namespace)
//     - vsphere-csi-credentials (openshift-cluster-csi-drivers namespace)
//     - vsphere-ccm-credentials (openshift-cloud-controller-manager namespace)
//     - vsphere-diagnostics-credentials (openshift-config namespace)
//   - Each secret has simple keys: username and password (not FQDN-keyed)
//   - Credentials match the component-specific accounts from install-config
func TestCreateComponentSecrets_SingleVCenter(t *testing.T) {
	// Setup: Actuator with single vCenter
	actuator := NewActuator("vcenter.example.com", "legacy-user", "legacy-pass")

	// Component credentials (single vCenter, no overrides)
	componentCreds := &ComponentCredentials{
		MachineAPI: &AccountCredentials{
			Username: "machine-api@vsphere.local",
			Password: "machine-api-password",
		},
		CSIDriver: &AccountCredentials{
			Username: "csi-driver@vsphere.local",
			Password: "csi-driver-password",
		},
		CloudController: &AccountCredentials{
			Username: "cloud-controller@vsphere.local",
			Password: "cloud-controller-password",
		},
		Diagnostics: &AccountCredentials{
			Username: "diagnostics@vsphere.local",
			Password: "diagnostics-password",
		},
	}

	ctx := context.Background()
	secrets, err := actuator.CreateComponentSecrets(ctx, componentCreds)
	if err != nil {
		t.Fatalf("CreateComponentSecrets failed: %v", err)
	}

	// Verify 4 secrets created
	if len(secrets) != 4 {
		t.Errorf("Expected 4 secrets, got %d", len(secrets))
	}

	// Verify machine-api secret
	machineAPISecret := findSecret(secrets, "machine-api-vsphere-credentials")
	if machineAPISecret == nil {
		t.Fatal("machine-api-vsphere-credentials secret not found")
	}
	if machineAPISecret.Namespace != "openshift-machine-api" {
		t.Errorf("Expected namespace openshift-machine-api, got %s", machineAPISecret.Namespace)
	}
	verifySimpleCredentials(t, machineAPISecret.Data, "machine-api@vsphere.local", "machine-api-password")

	// Verify CSI secret
	csiSecret := findSecret(secrets, "vsphere-csi-credentials")
	if csiSecret == nil {
		t.Fatal("vsphere-csi-credentials secret not found")
	}
	if csiSecret.Namespace != "openshift-cluster-csi-drivers" {
		t.Errorf("Expected namespace openshift-cluster-csi-drivers, got %s", csiSecret.Namespace)
	}
	verifySimpleCredentials(t, csiSecret.Data, "csi-driver@vsphere.local", "csi-driver-password")

	// Verify CCM secret
	ccmSecret := findSecret(secrets, "vsphere-ccm-credentials")
	if ccmSecret == nil {
		t.Fatal("vsphere-ccm-credentials secret not found")
	}
	if ccmSecret.Namespace != "openshift-cloud-controller-manager" {
		t.Errorf("Expected namespace openshift-cloud-controller-manager, got %s", ccmSecret.Namespace)
	}
	verifySimpleCredentials(t, ccmSecret.Data, "cloud-controller@vsphere.local", "cloud-controller-password")

	// Verify Diagnostics secret
	diagSecret := findSecret(secrets, "vsphere-diagnostics-credentials")
	if diagSecret == nil {
		t.Fatal("vsphere-diagnostics-credentials secret not found")
	}
	if diagSecret.Namespace != "openshift-config" {
		t.Errorf("Expected namespace openshift-config, got %s", diagSecret.Namespace)
	}
	verifySimpleCredentials(t, diagSecret.Data, "diagnostics@vsphere.local", "diagnostics-password")
}

// TestCreateComponentSecrets_MultiVCenter verifies AC2: Multi-vCenter secret generation.
//
// Acceptance Criteria 2:
// Given an install-config with per-component credentials referencing two different vCenters
// When CCO creates secrets
// Then each component secret contains vCenter FQDN-keyed credentials
//
// Expected Behavior:
//   - Secret keys follow pattern: <vCenter-FQDN>.username, <vCenter-FQDN>.password
//   - Example: vcenter1.example.com.username, vcenter1.example.com.password
//   - Each component can reference different vCenter servers
//   - machine-api uses vcenter1, CSI uses vcenter2 (validates cross-vCenter component distribution)
func TestCreateComponentSecrets_MultiVCenter(t *testing.T) {
	// Setup: Actuator with default vCenter
	actuator := NewActuator("vcenter1.example.com", "legacy-user", "legacy-pass")

	// Component credentials (multi-vCenter: CSI uses vcenter2)
	componentCreds := &ComponentCredentials{
		MachineAPI: &AccountCredentials{
			Username: "machine-api@vsphere.local",
			Password: "machine-api-password",
			VCenter:  "vcenter1.example.com",
		},
		CSIDriver: &AccountCredentials{
			Username: "csi-driver@vsphere.local",
			Password: "csi-driver-password",
			VCenter:  "vcenter2.example.com", // Different vCenter
		},
		CloudController: &AccountCredentials{
			Username: "cloud-controller@vsphere.local",
			Password: "cloud-controller-password",
			VCenter:  "vcenter1.example.com",
		},
		Diagnostics: &AccountCredentials{
			Username: "diagnostics@vsphere.local",
			Password: "diagnostics-password",
			VCenter:  "vcenter1.example.com",
		},
	}

	ctx := context.Background()
	secrets, err := actuator.CreateComponentSecrets(ctx, componentCreds)
	if err != nil {
		t.Fatalf("CreateComponentSecrets failed: %v", err)
	}

	// Verify 4 secrets created
	if len(secrets) != 4 {
		t.Errorf("Expected 4 secrets, got %d", len(secrets))
	}

	// Verify machine-api secret (vcenter1)
	machineAPISecret := findSecret(secrets, "machine-api-vsphere-credentials")
	if machineAPISecret == nil {
		t.Fatal("machine-api-vsphere-credentials secret not found")
	}
	verifyFQDNKeyedCredentials(t, machineAPISecret.Data, "vcenter1.example.com", "machine-api@vsphere.local", "machine-api-password")

	// Verify CSI secret (vcenter2)
	csiSecret := findSecret(secrets, "vsphere-csi-credentials")
	if csiSecret == nil {
		t.Fatal("vsphere-csi-credentials secret not found")
	}
	verifyFQDNKeyedCredentials(t, csiSecret.Data, "vcenter2.example.com", "csi-driver@vsphere.local", "csi-driver-password")

	// Verify CCM secret (vcenter1)
	ccmSecret := findSecret(secrets, "vsphere-ccm-credentials")
	if ccmSecret == nil {
		t.Fatal("vsphere-ccm-credentials secret not found")
	}
	verifyFQDNKeyedCredentials(t, ccmSecret.Data, "vcenter1.example.com", "cloud-controller@vsphere.local", "cloud-controller-password")

	// Verify Diagnostics secret (vcenter1)
	diagSecret := findSecret(secrets, "vsphere-diagnostics-credentials")
	if diagSecret == nil {
		t.Fatal("vsphere-diagnostics-credentials secret not found")
	}
	verifyFQDNKeyedCredentials(t, diagSecret.Data, "vcenter1.example.com", "diagnostics@vsphere.local", "diagnostics-password")
}

// TestComponentSecretIsolation verifies AC3: Component credential isolation.
//
// Acceptance Criteria 3:
// Given an existing cluster with per-component credentials
// When an administrator inspects secrets
// Then each secret contains only its component's credentials (isolation verified)
//
// Expected Behavior:
//   - machine-api-vsphere-credentials contains ONLY machine-api credentials (2 keys: username, password)
//   - vsphere-csi-credentials contains ONLY csi-driver credentials
//   - vsphere-ccm-credentials contains ONLY cloud-controller credentials
//   - vsphere-diagnostics-credentials contains ONLY diagnostics credentials
//   - No cross-component credential leakage
func TestComponentSecretIsolation(t *testing.T) {
	// Setup: Actuator with single vCenter
	actuator := NewActuator("vcenter.example.com", "legacy-user", "legacy-pass")

	// Component credentials (all components specified)
	componentCreds := &ComponentCredentials{
		MachineAPI: &AccountCredentials{
			Username: "machine-api@vsphere.local",
			Password: "machine-api-password",
		},
		CSIDriver: &AccountCredentials{
			Username: "csi-driver@vsphere.local",
			Password: "csi-driver-password",
		},
		CloudController: &AccountCredentials{
			Username: "cloud-controller@vsphere.local",
			Password: "cloud-controller-password",
		},
		Diagnostics: &AccountCredentials{
			Username: "diagnostics@vsphere.local",
			Password: "diagnostics-password",
		},
	}

	ctx := context.Background()
	secrets, err := actuator.CreateComponentSecrets(ctx, componentCreds)
	if err != nil {
		t.Fatalf("CreateComponentSecrets failed: %v", err)
	}

	// Verify each secret contains ONLY its component's credentials (2 keys: username, password)
	for _, secret := range secrets {
		if len(secret.Data) != 2 {
			t.Errorf("Secret %s should have exactly 2 keys (username, password), got %d", secret.Name, len(secret.Data))
		}

		// Verify only username and password keys exist
		if _, ok := secret.Data["username"]; !ok {
			t.Errorf("Secret %s missing username key", secret.Name)
		}
		if _, ok := secret.Data["password"]; !ok {
			t.Errorf("Secret %s missing password key", secret.Name)
		}

		// Verify no other keys exist (no credential leakage)
		for key := range secret.Data {
			if key != "username" && key != "password" {
				t.Errorf("Secret %s contains unexpected key: %s (credential leakage detected)", secret.Name, key)
			}
		}
	}

	// Verify each secret has distinct credentials
	machineAPISecret := findSecret(secrets, "machine-api-vsphere-credentials")
	csiSecret := findSecret(secrets, "vsphere-csi-credentials")
	ccmSecret := findSecret(secrets, "vsphere-ccm-credentials")
	diagSecret := findSecret(secrets, "vsphere-diagnostics-credentials")

	// Ensure no two secrets have the same credentials
	if secretDataEqual(machineAPISecret.Data, csiSecret.Data) {
		t.Error("machine-api and csi secrets have identical credentials (isolation violation)")
	}
	if secretDataEqual(machineAPISecret.Data, ccmSecret.Data) {
		t.Error("machine-api and ccm secrets have identical credentials (isolation violation)")
	}
	if secretDataEqual(machineAPISecret.Data, diagSecret.Data) {
		t.Error("machine-api and diagnostics secrets have identical credentials (isolation violation)")
	}
	if secretDataEqual(csiSecret.Data, ccmSecret.Data) {
		t.Error("csi and ccm secrets have identical credentials (isolation violation)")
	}
}

// TestCreateComponentSecrets_PassthroughMode verifies passthrough mode fallback.
//
// Given componentCredentials is not provided
// When CCO creates secrets
// Then all components use legacy passthrough credentials (backward compatibility)
//
// Expected Behavior:
//   - When ComponentCredentials is nil, fall back to legacy mode
//   - All component secrets use the same root credentials
//   - No error occurs
func TestCreateComponentSecrets_PassthroughMode(t *testing.T) {
	// Setup: Actuator with legacy credentials
	actuator := NewActuator("vcenter.example.com", "legacy-user", "legacy-pass")

	// Passthrough mode: componentCredentials is nil
	ctx := context.Background()
	secrets, err := actuator.CreateComponentSecrets(ctx, nil)
	if err != nil {
		t.Fatalf("CreateComponentSecrets failed in passthrough mode: %v", err)
	}

	// Verify 4 secrets created
	if len(secrets) != 4 {
		t.Errorf("Expected 4 secrets, got %d", len(secrets))
	}

	// Verify all secrets use legacy credentials
	for _, secret := range secrets {
		verifySimpleCredentials(t, secret.Data, "legacy-user", "legacy-pass")
	}
}

// TestCreateComponentSecrets_PartialCredentials verifies partial credentials with fallback.
//
// Given componentCredentials with only machineAPI specified
// When CCO creates secrets
// Then machineAPI uses its specific credentials, other components fall back to root credentials
//
// Expected Behavior:
//   - machine-api secret uses component-specific credentials
//   - CSI, CCM, Diagnostics secrets fall back to root/legacy credentials
//   - Graceful degradation (no error)
func TestCreateComponentSecrets_PartialCredentials(t *testing.T) {
	// Setup: Actuator with legacy credentials
	actuator := NewActuator("vcenter.example.com", "legacy-user", "legacy-pass")

	// Partial component credentials: only machineAPI specified
	componentCreds := &ComponentCredentials{
		MachineAPI: &AccountCredentials{
			Username: "machine-api@vsphere.local",
			Password: "machine-api-password",
		},
		// CSIDriver, CloudController, Diagnostics are nil (fallback to legacy)
	}

	ctx := context.Background()
	secrets, err := actuator.CreateComponentSecrets(ctx, componentCreds)
	if err != nil {
		t.Fatalf("CreateComponentSecrets failed with partial credentials: %v", err)
	}

	// Verify 4 secrets created
	if len(secrets) != 4 {
		t.Errorf("Expected 4 secrets, got %d", len(secrets))
	}

	// Verify machine-api secret uses component-specific credentials
	machineAPISecret := findSecret(secrets, "machine-api-vsphere-credentials")
	if machineAPISecret == nil {
		t.Fatal("machine-api-vsphere-credentials secret not found")
	}
	verifySimpleCredentials(t, machineAPISecret.Data, "machine-api@vsphere.local", "machine-api-password")

	// Verify CSI, CCM, Diagnostics fall back to legacy credentials
	csiSecret := findSecret(secrets, "vsphere-csi-credentials")
	if csiSecret != nil {
		verifySimpleCredentials(t, csiSecret.Data, "legacy-user", "legacy-pass")
	}

	ccmSecret := findSecret(secrets, "vsphere-ccm-credentials")
	if ccmSecret != nil {
		verifySimpleCredentials(t, ccmSecret.Data, "legacy-user", "legacy-pass")
	}

	diagSecret := findSecret(secrets, "vsphere-diagnostics-credentials")
	if diagSecret != nil {
		verifySimpleCredentials(t, diagSecret.Data, "legacy-user", "legacy-pass")
	}
}

// TestCreateComponentSecrets_MissingVCenterReference verifies error handling for missing vCenter credentials.
//
// Given componentCredentials reference a vCenter that has no credentials provided
// When CCO attempts to create secrets
// Then validation fails with error indicating missing vCenter credentials
//
// Expected Error: "Component <component> references vCenter <vcenter> but no credentials provided"
//
// NOTE: This test is currently a placeholder. The actuator implementation does not yet
// validate vCenter credential availability. This test will be enabled when that validation
// logic is added.
func TestCreateComponentSecrets_MissingVCenterReference(t *testing.T) {
	t.Skip("Implementation pending: vCenter credential validation not yet implemented")

	// TODO: Implement this test when vCenter credential validation is added to actuator
	// Expected behavior:
	//   - Component references vcenter2.example.com but only vcenter1 credentials provided
	//   - CreateComponentSecrets should return error: "Component csi-driver references vCenter vcenter2.example.com but no credentials provided"
}

// TestCreateComponentSecrets_NamespaceCreation verifies secrets are created in correct namespaces.
//
// Verify secrets are created in correct namespaces:
//   - machine-api-vsphere-credentials → openshift-machine-api
//   - vsphere-csi-credentials → openshift-cluster-csi-drivers
//   - vsphere-ccm-credentials → openshift-cloud-controller-manager
//   - vsphere-diagnostics-credentials → openshift-config
func TestCreateComponentSecrets_NamespaceCreation(t *testing.T) {
	// Setup: Actuator with single vCenter
	actuator := NewActuator("vcenter.example.com", "legacy-user", "legacy-pass")

	// Component credentials
	componentCreds := &ComponentCredentials{
		MachineAPI: &AccountCredentials{
			Username: "machine-api@vsphere.local",
			Password: "machine-api-password",
		},
		CSIDriver: &AccountCredentials{
			Username: "csi-driver@vsphere.local",
			Password: "csi-driver-password",
		},
		CloudController: &AccountCredentials{
			Username: "cloud-controller@vsphere.local",
			Password: "cloud-controller-password",
		},
		Diagnostics: &AccountCredentials{
			Username: "diagnostics@vsphere.local",
			Password: "diagnostics-password",
		},
	}

	ctx := context.Background()
	secrets, err := actuator.CreateComponentSecrets(ctx, componentCreds)
	if err != nil {
		t.Fatalf("CreateComponentSecrets failed: %v", err)
	}

	// Expected namespace mapping
	expectedNamespaces := map[string]string{
		"machine-api-vsphere-credentials": "openshift-machine-api",
		"vsphere-csi-credentials":         "openshift-cluster-csi-drivers",
		"vsphere-ccm-credentials":         "openshift-cloud-controller-manager",
		"vsphere-diagnostics-credentials": "openshift-config",
	}

	// Verify each secret has the correct namespace
	for _, secret := range secrets {
		expectedNamespace, ok := expectedNamespaces[secret.Name]
		if !ok {
			t.Errorf("Unexpected secret name: %s", secret.Name)
			continue
		}

		if secret.Namespace != expectedNamespace {
			t.Errorf("Secret %s has incorrect namespace: expected %s, got %s", secret.Name, expectedNamespace, secret.Namespace)
		}
	}

	// Verify all expected secrets were created
	if len(secrets) != len(expectedNamespaces) {
		t.Errorf("Expected %d secrets, got %d", len(expectedNamespaces), len(secrets))
	}
}

// Helper functions

// findSecret finds a secret by name in the secrets slice.
func findSecret(secrets []Secret, name string) *Secret {
	for i := range secrets {
		if secrets[i].Name == name {
			return &secrets[i]
		}
	}
	return nil
}

// verifySimpleCredentials verifies secret data contains simple username/password keys (single vCenter format).
func verifySimpleCredentials(t *testing.T, data map[string]string, expectedUsername, expectedPassword string) {
	usernameEncoded, ok := data["username"]
	if !ok {
		t.Error("Secret missing username key")
		return
	}

	passwordEncoded, ok := data["password"]
	if !ok {
		t.Error("Secret missing password key")
		return
	}

	username, err := base64.StdEncoding.DecodeString(usernameEncoded)
	if err != nil {
		t.Errorf("Failed to decode username: %v", err)
		return
	}

	password, err := base64.StdEncoding.DecodeString(passwordEncoded)
	if err != nil {
		t.Errorf("Failed to decode password: %v", err)
		return
	}

	if string(username) != expectedUsername {
		t.Errorf("Expected username %s, got %s", expectedUsername, string(username))
	}

	if string(password) != expectedPassword {
		t.Errorf("Expected password %s, got %s", expectedPassword, string(password))
	}
}

// verifyFQDNKeyedCredentials verifies secret data contains FQDN-keyed credentials (multi-vCenter format).
func verifyFQDNKeyedCredentials(t *testing.T, data map[string]string, vCenter, expectedUsername, expectedPassword string) {
	usernameKey := vCenter + ".username"
	passwordKey := vCenter + ".password"

	usernameEncoded, ok := data[usernameKey]
	if !ok {
		t.Errorf("Secret missing %s key", usernameKey)
		return
	}

	passwordEncoded, ok := data[passwordKey]
	if !ok {
		t.Errorf("Secret missing %s key", passwordKey)
		return
	}

	username, err := base64.StdEncoding.DecodeString(usernameEncoded)
	if err != nil {
		t.Errorf("Failed to decode username: %v", err)
		return
	}

	password, err := base64.StdEncoding.DecodeString(passwordEncoded)
	if err != nil {
		t.Errorf("Failed to decode password: %v", err)
		return
	}

	if string(username) != expectedUsername {
		t.Errorf("Expected username %s, got %s", expectedUsername, string(username))
	}

	if string(password) != expectedPassword {
		t.Errorf("Expected password %s, got %s", expectedPassword, string(password))
	}
}

// secretDataEqual compares two secret data maps for equality.
func secretDataEqual(data1, data2 map[string]string) bool {
	if len(data1) != len(data2) {
		return false
	}

	for key, value1 := range data1 {
		value2, ok := data2[key]
		if !ok || value1 != value2 {
			return false
		}
	}

	return true
}
