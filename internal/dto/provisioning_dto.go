package dto

type EnrollRequest struct {
	SerialNumber string `json:"serial_number"`
	Manufacturer string `json:"manufacturer"`
	Model        string `json:"model"`
	DeviceType   string `json:"device_type"`
	PublicKey    string `json:"public_key"`
	TenantID     string `json:"tenant_id"`
}

type ProvisionRequest struct {
	DeviceID         string                 `json:"device_id"`
	TenantID         string                 `json:"tenant_id"`
	ProvisioningData map[string]interface{} `json:"provisioning_data"`
}
