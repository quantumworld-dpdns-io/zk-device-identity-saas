package vto

import "time"

type AttestationResponse struct {
	ID              string      `json:"id"`
	DeviceID        string      `json:"device_id"`
	TenantID        string      `json:"tenant_id"`
	Status          string      `json:"status"`
	AttestationData interface{} `json:"attestation_data,omitempty"`
	Signature       string      `json:"signature,omitempty"`
	VerifiedBy      string      `json:"verified_by,omitempty"`
	VerifiedAt      *time.Time  `json:"verified_at,omitempty"`
	CreatedAt       time.Time   `json:"created_at"`
}

type AttestationStatusResponse struct {
	AttestationID string `json:"attestation_id"`
	Status        string `json:"status"`
	IsVerified    bool   `json:"is_verified"`
}
