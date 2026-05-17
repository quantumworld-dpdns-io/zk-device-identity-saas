package vto

import "time"

type ComplianceResultResponse struct {
	DeviceID    string      `json:"device_id"`
	CheckType   string      `json:"check_type"`
	IsCompliant bool        `json:"is_compliant"`
	Score       float64     `json:"score,omitempty"`
	Details     interface{} `json:"details"`
	CheckedAt   time.Time   `json:"checked_at"`
}
