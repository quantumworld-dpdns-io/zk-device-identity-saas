package services

import (
	"fmt"
	"log/slog"

	"github.com/google/uuid"

	"github.com/quantumworld-dpdns-io/zk-device-identity-saas/internal/dto"
	"github.com/quantumworld-dpdns-io/zk-device-identity-saas/internal/models"
	"github.com/quantumworld-dpdns-io/zk-device-identity-saas/internal/vto"
)

type MCPService struct {
	deviceSvc   *DeviceService
	attestationSvc *AttestationService
	zkSvc       *ZKService
}

func NewMCPService(
	deviceSvc *DeviceService,
	attestationSvc *AttestationService,
	zkSvc *ZKService,
) *MCPService {
	return &MCPService{
		deviceSvc:      deviceSvc,
		attestationSvc: attestationSvc,
		zkSvc:          zkSvc,
	}
}

type MCPToolResult struct {
	Success bool        `json:"success"`
	Data    interface{} `json:"data,omitempty"`
	Error   string      `json:"error,omitempty"`
}

func (s *MCPService) ListDevices(tenantID uuid.UUID, page, pageSize int) *MCPToolResult {
	devices, total, err := s.deviceSvc.ListDevices(tenantID, page, pageSize, "", "", "")
	if err != nil {
		slog.Error("MCP ListDevices failed", "error", err)
		return &MCPToolResult{
			Success: false,
			Error:   fmt.Sprintf("failed to list devices: %s", err.Error()),
		}
	}

	deviceResponses := make([]vto.DeviceResponse, 0, len(devices))
	for _, d := range devices {
		deviceResponses = append(deviceResponses, vto.DeviceResponse{
			ID:              d.ID.String(),
			TenantID:        d.TenantID.String(),
			SerialNumber:    d.SerialNumber,
			Manufacturer:    d.Manufacturer,
			Model:           d.Model,
			FirmwareVersion: d.FirmwareVersion,
			DeviceType:      d.DeviceType,
			Status:          d.Status,
			CreatedAt:       d.CreatedAt,
			UpdatedAt:       d.UpdatedAt,
		})
	}

	return &MCPToolResult{
		Success: true,
		Data: map[string]interface{}{
			"devices": deviceResponses,
			"total":   total,
			"page":    page,
			"page_size": pageSize,
		},
	}
}

func (s *MCPService) GetDevice(deviceID uuid.UUID) *MCPToolResult {
	device, certs, err := s.deviceSvc.GetDevice(deviceID)
	if err != nil {
		slog.Error("MCP GetDevice failed", "device_id", deviceID, "error", err)
		return &MCPToolResult{
			Success: false,
			Error:   fmt.Sprintf("device not found: %s", err.Error()),
		}
	}

	certResponses := make([]map[string]interface{}, 0, len(certs))
	for _, c := range certs {
		certResponses = append(certResponses, map[string]interface{}{
			"id":        c.ID.String(),
			"cert_type": c.CertType,
			"status":    c.Status,
			"serial_number": c.SerialNumber,
			"valid_from":    c.ValidFrom,
			"valid_to":      c.ValidTo,
		})
	}

	return &MCPToolResult{
		Success: true,
		Data: map[string]interface{}{
			"device": map[string]interface{}{
				"id":               device.ID.String(),
				"tenant_id":        device.TenantID.String(),
				"serial_number":    device.SerialNumber,
				"manufacturer":     device.Manufacturer,
				"model":            device.Model,
				"firmware_version": device.FirmwareVersion,
				"device_type":      device.DeviceType,
				"status":           device.Status,
				"created_at":       device.CreatedAt,
				"updated_at":       device.UpdatedAt,
			},
			"certificates": certResponses,
		},
	}
}

func (s *MCPService) CreateAttestation(req *dto.SubmitAttestationRequest) *MCPToolResult {
	record, err := s.attestationSvc.SubmitAttestation(req)
	if err != nil {
		slog.Error("MCP CreateAttestation failed", "error", err)
		return &MCPToolResult{
			Success: false,
			Error:   fmt.Sprintf("failed to create attestation: %s", err.Error()),
		}
	}

	return &MCPToolResult{
		Success: true,
		Data: map[string]interface{}{
			"attestation_id": record.ID.String(),
			"device_id":      record.DeviceID.String(),
			"tenant_id":      record.TenantID.String(),
			"status":         record.Status,
			"created_at":     record.CreatedAt,
		},
	}
}

func (s *MCPService) VerifyProof(proofID uuid.UUID, proofData, publicInputs map[string]interface{}) *MCPToolResult {
	req := &dto.VerifyProofRequest{
		ProofID:      proofID.String(),
		ProofData:    proofData,
		PublicInputs: publicInputs,
	}

	valid, err := s.zkSvc.VerifyProof(req)
	if err != nil {
		slog.Error("MCP VerifyProof failed", "proof_id", proofID, "error", err)
		return &MCPToolResult{
			Success: false,
			Error:   fmt.Sprintf("proof verification failed: %s", err.Error()),
		}
	}

	return &MCPToolResult{
		Success: true,
		Data: map[string]interface{}{
			"proof_id": proofID.String(),
			"is_valid": valid,
		},
	}
}
