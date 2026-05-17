package dto

type GenerateProofRequest struct {
	CircuitType  string                 `json:"circuit_type"`
	PublicInputs map[string]interface{} `json:"public_inputs"`
	PrivateInputs map[string]interface{} `json:"private_inputs"`
	DeviceID     string                 `json:"device_id"`
	TenantID     string                 `json:"tenant_id"`
}

type VerifyProofRequest struct {
	ProofID      string                 `json:"proof_id"`
	ProofData    map[string]interface{} `json:"proof_data"`
	PublicInputs map[string]interface{} `json:"public_inputs"`
}
