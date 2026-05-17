package dto

type ComplianceCheckRequest struct {
	DeviceID   string                 `json:"device_id"`
	TenantID   string                 `json:"tenant_id"`
	CheckType  string                 `json:"check_type"`
	Parameters map[string]interface{} `json:"parameters"`
}
