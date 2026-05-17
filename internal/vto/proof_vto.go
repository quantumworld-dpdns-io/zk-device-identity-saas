package vto

import "time"

type ProofResponse struct {
	ID           string      `json:"id"`
	TenantID     string      `json:"tenant_id"`
	DeviceID     string      `json:"device_id"`
	CircuitType  string      `json:"circuit_type"`
	ProofData    interface{} `json:"proof_data,omitempty"`
	PublicInputs interface{} `json:"public_inputs,omitempty"`
	Status       string      `json:"status"`
	CreatedAt    time.Time   `json:"created_at"`
}

type VerificationResponse struct {
	ProofID    string    `json:"proof_id"`
	IsValid    bool      `json:"is_valid"`
	VerifiedBy string    `json:"verified_by"`
	VerifiedAt time.Time `json:"verified_at"`
}
