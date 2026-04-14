package actuator

import (
	"context"
	"encoding/base64"
	"fmt"
)

// ComponentCredentials holds per-component vSphere credential configuration.
// Matches the schema defined in pkg/types/vsphere/platform.go (installer repo).
type ComponentCredentials struct {
	// Per-component account credentials
	Installer       *AccountCredentials `json:"installer,omitempty"`
	MachineAPI      *AccountCredentials `json:"machineAPI,omitempty"`
	CSIDriver       *AccountCredentials `json:"csiDriver,omitempty"`
	CloudController *AccountCredentials `json:"cloudController,omitempty"`
	Diagnostics     *AccountCredentials `json:"diagnostics,omitempty"`
}

// AccountCredentials represents a single vSphere account with optional vCenter override.
// Matches the schema defined in pkg/types/vsphere/platform.go (installer repo).
type AccountCredentials struct {
	Username string `json:"username"`
	Password string `json:"password"`
	VCenter  string `json:"vCenter,omitempty"` // Optional: override default vCenter for multi-vCenter topologies
}

// Secret represents a Kubernetes secret with component-specific credentials.
type Secret struct {
	Name      string
	Namespace string
	Data      map[string]string // Base64-encoded data
}

// Actuator manages vSphere component credential secret generation.
type Actuator struct {
	// defaultVCenter is the default vCenter server FQDN (from install-config.yaml platform.vsphere.vCenter)
	defaultVCenter string

	// legacyUsername is the legacy passthrough mode username (from install-config.yaml platform.vsphere.username)
	legacyUsername string

	// legacyPassword is the legacy passthrough mode password (from install-config.yaml platform.vsphere.password)
	legacyPassword string
}

// NewActuator creates a new vSphere credential actuator.
//
// Parameters:
//   - defaultVCenter: Default vCenter FQDN from install-config.yaml
//   - legacyUsername: Legacy passthrough mode username (used when ComponentCredentials not provided)
//   - legacyPassword: Legacy passthrough mode password (used when ComponentCredentials not provided)
func NewActuator(defaultVCenter, legacyUsername, legacyPassword string) *Actuator {
	return &Actuator{
		defaultVCenter: defaultVCenter,
		legacyUsername: legacyUsername,
		legacyPassword: legacyPassword,
	}
}

// CreateComponentSecrets generates component-specific secrets in appropriate namespaces.
//
// This method implements the per-component credential secret generation logic as defined
// in the vSphere Multi-Account Credentials design (epic-2.md).
//
// Behavior:
//   - If componentCreds is nil, falls back to passthrough mode (all components use legacy credentials)
//   - If componentCreds is provided but a specific component is nil, that component falls back to legacy credentials
//   - Supports single vCenter mode (simple username/password keys)
//   - Supports multi-vCenter mode (vCenter FQDN-keyed credentials)
//
// The generated secrets follow this naming convention:
//   - machine-api-vsphere-credentials (namespace: openshift-machine-api)
//   - vsphere-csi-credentials (namespace: openshift-cluster-csi-drivers)
//   - vsphere-ccm-credentials (namespace: openshift-cloud-controller-manager)
//   - vsphere-diagnostics-credentials (namespace: openshift-config)
//
// Single vCenter secret format:
//
//	data:
//	  username: <base64-encoded>
//	  password: <base64-encoded>
//
// Multi-vCenter secret format:
//
//	data:
//	  vcenter1.example.com.username: <base64-encoded>
//	  vcenter1.example.com.password: <base64-encoded>
//	  vcenter2.example.com.username: <base64-encoded>
//	  vcenter2.example.com.password: <base64-encoded>
//
// Parameters:
//   - ctx: Context for the operation
//   - componentCreds: Per-component credentials (nil for passthrough mode)
//
// Returns:
//   - []Secret: List of generated secrets ready for Kubernetes API creation
//   - error: Error if secret generation fails
func (a *Actuator) CreateComponentSecrets(ctx context.Context, componentCreds *ComponentCredentials) ([]Secret, error) {
	secrets := []Secret{}

	// Machine API secret
	machineAPISecret, err := a.createSecret(
		"machine-api-vsphere-credentials",
		"openshift-machine-api",
		componentCreds,
		func(cc *ComponentCredentials) *AccountCredentials { return cc.MachineAPI },
	)
	if err != nil {
		return nil, fmt.Errorf("failed to create machine-api secret: %w", err)
	}
	secrets = append(secrets, machineAPISecret)

	// CSI Driver secret
	csiSecret, err := a.createSecret(
		"vsphere-csi-credentials",
		"openshift-cluster-csi-drivers",
		componentCreds,
		func(cc *ComponentCredentials) *AccountCredentials { return cc.CSIDriver },
	)
	if err != nil {
		return nil, fmt.Errorf("failed to create csi-driver secret: %w", err)
	}
	secrets = append(secrets, csiSecret)

	// Cloud Controller Manager secret
	ccmSecret, err := a.createSecret(
		"vsphere-ccm-credentials",
		"openshift-cloud-controller-manager",
		componentCreds,
		func(cc *ComponentCredentials) *AccountCredentials { return cc.CloudController },
	)
	if err != nil {
		return nil, fmt.Errorf("failed to create cloud-controller secret: %w", err)
	}
	secrets = append(secrets, ccmSecret)

	// Diagnostics secret
	diagSecret, err := a.createSecret(
		"vsphere-diagnostics-credentials",
		"openshift-config",
		componentCreds,
		func(cc *ComponentCredentials) *AccountCredentials { return cc.Diagnostics },
	)
	if err != nil {
		return nil, fmt.Errorf("failed to create diagnostics secret: %w", err)
	}
	secrets = append(secrets, diagSecret)

	return secrets, nil
}

// createSecret generates a single component-specific secret.
//
// This helper method handles the logic for:
//   - Extracting component credentials from ComponentCredentials
//   - Falling back to legacy passthrough credentials when component creds not provided
//   - Detecting multi-vCenter mode (when vCenter overrides exist)
//   - Generating appropriate secret data format (single vs multi-vCenter)
//
// Parameters:
//   - secretName: Name of the secret (e.g., "machine-api-vsphere-credentials")
//   - namespace: Namespace for the secret (e.g., "openshift-machine-api")
//   - componentCreds: Per-component credentials (nil for passthrough mode)
//   - extractCred: Function to extract the specific component's credentials
//
// Returns:
//   - Secret: Generated secret ready for Kubernetes API creation
//   - error: Error if secret generation fails
func (a *Actuator) createSecret(
	secretName, namespace string,
	componentCreds *ComponentCredentials,
	extractCred func(*ComponentCredentials) *AccountCredentials,
) (Secret, error) {
	secret := Secret{
		Name:      secretName,
		Namespace: namespace,
		Data:      make(map[string]string),
	}

	// Determine component credentials (with fallback to legacy)
	var componentCred *AccountCredentials
	if componentCreds != nil {
		componentCred = extractCred(componentCreds)
	}

	// Passthrough mode: component credentials not provided, use legacy
	if componentCred == nil {
		// Single vCenter format with legacy credentials
		secret.Data["username"] = base64.StdEncoding.EncodeToString([]byte(a.legacyUsername))
		secret.Data["password"] = base64.StdEncoding.EncodeToString([]byte(a.legacyPassword))
		return secret, nil
	}

	// Determine vCenter server (component override or default)
	vCenter := a.defaultVCenter
	if componentCred.VCenter != "" {
		vCenter = componentCred.VCenter
	}

	// Check for multi-vCenter mode
	isMultiVCenter := a.isMultiVCenterMode(componentCreds)

	if isMultiVCenter {
		// Multi-vCenter format: FQDN-keyed credentials
		usernameKey := fmt.Sprintf("%s.username", vCenter)
		passwordKey := fmt.Sprintf("%s.password", vCenter)
		secret.Data[usernameKey] = base64.StdEncoding.EncodeToString([]byte(componentCred.Username))
		secret.Data[passwordKey] = base64.StdEncoding.EncodeToString([]byte(componentCred.Password))
	} else {
		// Single vCenter format: simple username/password keys
		secret.Data["username"] = base64.StdEncoding.EncodeToString([]byte(componentCred.Username))
		secret.Data["password"] = base64.StdEncoding.EncodeToString([]byte(componentCred.Password))
	}

	return secret, nil
}

// isMultiVCenterMode determines if the cluster is in multi-vCenter mode.
//
// Multi-vCenter mode is detected when any component specifies a vCenter override
// that differs from the default vCenter.
//
// Parameters:
//   - componentCreds: Per-component credentials
//
// Returns:
//   - bool: true if multi-vCenter mode detected, false otherwise
func (a *Actuator) isMultiVCenterMode(componentCreds *ComponentCredentials) bool {
	if componentCreds == nil {
		return false
	}

	// Check each component for vCenter override
	components := []*AccountCredentials{
		componentCreds.Installer,
		componentCreds.MachineAPI,
		componentCreds.CSIDriver,
		componentCreds.CloudController,
		componentCreds.Diagnostics,
	}

	for _, comp := range components {
		if comp != nil && comp.VCenter != "" && comp.VCenter != a.defaultVCenter {
			return true
		}
	}

	return false
}
