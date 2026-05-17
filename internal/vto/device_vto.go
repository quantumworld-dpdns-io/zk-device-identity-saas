package vto

import "time"

type DeviceResponse struct {
	ID              string    `json:"id"`
	TenantID        string    `json:"tenant_id"`
	SerialNumber    string    `json:"serial_number"`
	Manufacturer    string    `json:"manufacturer"`
	Model           string    `json:"model"`
	FirmwareVersion string    `json:"firmware_version"`
	DeviceType      string    `json:"device_type"`
	Status          string    `json:"status"`
	CreatedAt       time.Time `json:"created_at"`
	UpdatedAt       time.Time `json:"updated_at"`
}

type DeviceDetailResponse struct {
	ID              string      `json:"id"`
	TenantID        string      `json:"tenant_id"`
	SerialNumber    string      `json:"serial_number"`
	Manufacturer    string      `json:"manufacturer"`
	Model           string      `json:"model"`
	FirmwareVersion string      `json:"firmware_version"`
	DeviceType      string      `json:"device_type"`
	Status          string      `json:"status"`
	PublicKey       string      `json:"public_key"`
	Metadata        interface{} `json:"metadata"`
	CreatedAt       time.Time   `json:"created_at"`
	UpdatedAt       time.Time   `json:"updated_at"`
}
