package dto

type SubmitAttestationRequest struct {
	DeviceID  string `json:"device_id"`
	TenantID  string `json:"tenant_id"`
	DAC       string `json:"dac"`
	PAI       string `json:"pai"`
	PAA       string `json:"paa"`
	Signature string `json:"signature"`
	Nonce     string `json:"nonce"`
}

type VerifyAttestationRequest struct {
	AttestationID string `json:"attestation_id"`
	Challenge     string `json:"challenge"`
}
