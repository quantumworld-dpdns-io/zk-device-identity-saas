package dto

type CreateDeviceRequest struct {
	SerialNumber    string `json:"serial_number"`
	Manufacturer    string `json:"manufacturer"`
	Model           string `json:"model"`
	FirmwareVersion string `json:"firmware_version"`
	DeviceType      string `json:"device_type"`
	PublicKey       string `json:"public_key"`
	TenantID        string `json:"tenant_id"`
}

type UpdateDeviceRequest struct {
	FirmwareVersion string                 `json:"firmware_version"`
	Status          string                 `json:"status"`
	Metadata        map[string]interface{} `json:"metadata"`
}

type RegisterDeviceRequest struct {
	SerialNumber    string `json:"serial_number"`
	Manufacturer    string `json:"manufacturer"`
	Model           string `json:"model"`
	FirmwareVersion string `json:"firmware_version"`
	DeviceType      string `json:"device_type"`
	PublicKey       string `json:"public_key"`
	CSRPEM          string `json:"csr_pem"`
}
