package services

import (
	"crypto"
	"crypto/ecdsa"
	"crypto/rsa"
	"crypto/sha256"
	"crypto/x509"
	"encoding/hex"
	"encoding/pem"
	"fmt"
	"log/slog"
	"time"

	"github.com/google/uuid"
	"github.com/quantumworld-dpdns-io/zk-device-identity-saas/internal/dto"
	"github.com/quantumworld-dpdns-io/zk-device-identity-saas/internal/models"
	"github.com/quantumworld-dpdns-io/zk-device-identity-saas/internal/repository"
)

type AttestationService struct {
	attestationRepo *repository.AttestationRepository
	deviceRepo      *repository.DeviceRepository
	certRepo        *repository.CertificateRepository
	certSvc         *CertificateService
	zkSvc           *ZKService
}

func NewAttestationService(
	attestationRepo *repository.AttestationRepository,
	deviceRepo *repository.DeviceRepository,
	certRepo *repository.CertificateRepository,
	certSvc *CertificateService,
	zkSvc *ZKService,
) *AttestationService {
	return &AttestationService{
		attestationRepo: attestationRepo,
		deviceRepo:      deviceRepo,
		certRepo:        certRepo,
		certSvc:         certSvc,
		zkSvc:           zkSvc,
	}
}

func (s *AttestationService) SubmitAttestation(req *dto.SubmitAttestationRequest) (*models.AttestationRecord, error) {
	deviceID, err := uuid.Parse(req.DeviceID)
	if err != nil {
		return nil, fmt.Errorf("invalid device_id: %w", err)
	}
	tenantID, err := uuid.Parse(req.TenantID)
	if err != nil {
		return nil, fmt.Errorf("invalid tenant_id: %w", err)
	}

	device, err := s.deviceRepo.GetByID(deviceID)
	if err != nil {
		return nil, fmt.Errorf("device not found: %w", err)
	}

	if req.DAC != "" {
		if _, err := s.certSvc.SubmitCertificate(deviceID, "DAC", req.DAC, nil); err != nil {
			slog.Warn("failed to submit DAC", "device_id", deviceID, "error", err)
		}
	}
	if req.PAI != "" {
		if _, err := s.certSvc.SubmitCertificate(deviceID, "PAI", req.PAI, nil); err != nil {
			slog.Warn("failed to submit PAI", "device_id", deviceID, "error", err)
		}
	}
	if req.PAA != "" {
		if _, err := s.certSvc.SubmitCertificate(deviceID, "PAA", req.PAA, nil); err != nil {
			slog.Warn("failed to submit PAA", "device_id", deviceID, "error", err)
		}
	}

	attestationData := map[string]interface{}{
		"dac":        req.DAC,
		"pai":        req.PAI,
		"paa":        req.PAA,
		"nonce":      req.Nonce,
	}

	record := &models.AttestationRecord{
		DeviceID:        deviceID,
		TenantID:        tenantID,
		Status:          "pending",
		AttestationData: attestationData,
		Signature:       req.Signature,
	}

	if err := s.attestationRepo.Create(record); err != nil {
		return nil, fmt.Errorf("failed to create attestation: %w", err)
	}

	go func() {
		if _, err := s.certSvc.ValidateCertificateChain(deviceID); err != nil {
			slog.Error("certificate chain validation failed", "device_id", deviceID, "error", err)
			if updateErr := s.attestationRepo.UpdateStatus(record.ID, "failed"); updateErr != nil {
				slog.Error("failed to update attestation status", "error", updateErr)
			}
			return
		}

		proofReq := &dto.GenerateProofRequest{
			CircuitType: "attestation",
			DeviceID:    deviceID.String(),
			TenantID:    tenantID.String(),
			PublicInputs: map[string]interface{}{
				"device_id": deviceID.String(),
				"nonce":     req.Nonce,
			},
			PrivateInputs: map[string]interface{}{
				"signature": req.Signature,
			},
		}

		if _, err := s.zkSvc.GenerateProof(proofReq); err != nil {
			slog.Error("ZK proof generation failed", "attestation_id", record.ID, "error", err)
		}

		if updateErr := s.attestationRepo.UpdateStatus(record.ID, "verified"); updateErr != nil {
			slog.Error("failed to update attestation status", "error", updateErr)
		}
	}()

	slog.Info("attestation submitted", "attestation_id", record.ID, "device_id", deviceID)
	_ = device
	return record, nil
}

func (s *AttestationService) VerifyAttestation(attestationID uuid.UUID, challenge string) (bool, error) {
	record, err := s.attestationRepo.GetByID(attestationID)
	if err != nil {
		return false, fmt.Errorf("attestation not found: %w", err)
	}

	if record.Signature == "" {
		return false, fmt.Errorf("attestation has no signature")
	}

	device, err := s.deviceRepo.GetByID(record.DeviceID)
	if err != nil {
		return false, fmt.Errorf("device not found: %w", err)
	}

	publicKey, err := parsePublicKey(device.PublicKey)
	if err != nil {
		return false, fmt.Errorf("failed to parse device public key: %w", err)
	}

	payload := append([]byte(record.DeviceID.String()), []byte(challenge)...)
	hash := sha256.Sum256(payload)
	sigBytes, err := hex.DecodeString(record.Signature)
	if err != nil {
		return false, fmt.Errorf("invalid signature encoding: %w", err)
	}

	switch key := publicKey.(type) {
	case *ecdsa.PublicKey:
		if !ecdsa.VerifyASN1(key, hash[:], sigBytes) {
			return false, fmt.Errorf("ECDSA signature verification failed")
		}
	case *rsa.PublicKey:
		if err := rsa.VerifyPKCS1v15(key, crypto.SHA256, hash[:], sigBytes); err != nil {
			return false, fmt.Errorf("RSA signature verification failed: %w", err)
		}
	default:
		return false, fmt.Errorf("unsupported public key type")
	}

	now := time.Now()
	record.Status = "verified"
	record.VerifiedBy = "attestation_service"
	record.VerifiedAt = &now

	slog.Info("attestation verified", "attestation_id", attestationID)
	return true, nil
}

func (s *AttestationService) GetAttestationStatus(id uuid.UUID) (*models.AttestationRecord, error) {
	return s.attestationRepo.GetByID(id)
}

func (s *AttestationService) ListAttestations(tenantID uuid.UUID, page, pageSize int, status string) ([]models.AttestationRecord, int64, error) {
	var attestations []models.AttestationRecord
	var total int64
	var err error

	if status != "" {
		attestations, total, err = s.attestationRepo.ListByTenant(tenantID, page, pageSize)
		if err == nil {
			filtered := make([]models.AttestationRecord, 0, len(attestations))
			for _, a := range attestations {
				if a.Status == status {
					filtered = append(filtered, a)
				}
			}
			attestations = filtered
			total = int64(len(filtered))
		}
	} else {
		attestations, total, err = s.attestationRepo.ListByTenant(tenantID, page, pageSize)
	}

	if err != nil {
		return nil, 0, fmt.Errorf("failed to list attestations: %w", err)
	}
	return attestations, total, nil
}

func parsePublicKey(pemStr string) (crypto.PublicKey, error) {
	block, _ := pem.Decode([]byte(pemStr))
	if block == nil {
		return nil, fmt.Errorf("failed to decode PEM block")
	}

	switch block.Type {
	case "PUBLIC KEY":
		return x509.ParsePKIXPublicKey(block.Bytes)
	case "RSA PUBLIC KEY":
		return x509.ParsePKCS1PublicKey(block.Bytes)
	case "EC PUBLIC KEY":
		return x509.ParseECPrivateKey(block.Bytes)
	default:
		return x509.ParsePKIXPublicKey(block.Bytes)
	}
}
