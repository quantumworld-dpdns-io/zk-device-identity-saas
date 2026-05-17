package services

import (
	"crypto/x509"
	"encoding/pem"
	"fmt"
	"log/slog"
	"time"

	"github.com/google/uuid"
	"github.com/quantumworld-dpdns-io/zk-device-identity-saas/internal/models"
	"github.com/quantumworld-dpdns-io/zk-device-identity-saas/internal/repository"
)

type CertificateService struct {
	certRepo *repository.CertificateRepository
}

func NewCertificateService(certRepo *repository.CertificateRepository) *CertificateService {
	return &CertificateService{certRepo: certRepo}
}

func (s *CertificateService) SubmitCertificate(deviceID uuid.UUID, certType, certPEM string, issuerID *uuid.UUID) (*models.Certificate, error) {
	if certPEM == "" {
		return nil, fmt.Errorf("certificate PEM is required")
	}

	block, _ := pem.Decode([]byte(certPEM))
	if block == nil {
		return nil, fmt.Errorf("failed to parse certificate PEM")
	}

	cert, err := x509.ParseCertificate(block.Bytes)
	if err != nil {
		return nil, fmt.Errorf("invalid X.509 certificate: %w", err)
	}

	var validFrom, validTo time.Time
	if !cert.NotBefore.IsZero() {
		validFrom = cert.NotBefore
	}
	if !cert.NotAfter.IsZero() {
		validTo = cert.NotAfter
	}

	record := &models.Certificate{
		DeviceID:       deviceID,
		CertType:       certType,
		CertificatePEM: certPEM,
		IssuerID:       issuerID,
		SerialNumber:   cert.SerialNumber.String(),
		ValidFrom:      validFrom,
		ValidTo:        validTo,
		Status:         "active",
	}

	if err := s.certRepo.Create(record); err != nil {
		return nil, fmt.Errorf("failed to store certificate: %w", err)
	}

	slog.Info("certificate submitted", "cert_id", record.ID, "type", certType, "device_id", deviceID)
	return record, nil
}

func (s *CertificateService) ValidateCertificateChain(deviceID uuid.UUID) (bool, error) {
	dac, pai, paa, err := s.certRepo.GetDACChain(deviceID)
	if err != nil {
		return false, fmt.Errorf("failed to fetch certificate chain: %w", err)
	}

	if dac == nil || pai == nil || paa == nil {
		return false, fmt.Errorf("incomplete certificate chain: need DAC, PAI, and PAA")
	}

	dacCert, err := parseCert(dac.CertificatePEM)
	if err != nil {
		return false, fmt.Errorf("invalid DAC: %w", err)
	}
	paiCert, err := parseCert(pai.CertificatePEM)
	if err != nil {
		return false, fmt.Errorf("invalid PAI: %w", err)
	}
	paaCert, err := parseCert(paa.CertificatePEM)
	if err != nil {
		return false, fmt.Errorf("invalid PAA: %w", err)
	}

	now := time.Now()
	if now.Before(dacCert.NotBefore) || now.After(dacCert.NotAfter) {
		return false, fmt.Errorf("DAC certificate is expired or not yet valid")
	}
	if now.Before(paiCert.NotBefore) || now.After(paiCert.NotAfter) {
		return false, fmt.Errorf("PAI certificate is expired or not yet valid")
	}
	if now.Before(paaCert.NotBefore) || now.After(paaCert.NotAfter) {
		return false, fmt.Errorf("PAA certificate is expired or not yet valid")
	}

	dacPool := x509.NewCertPool()
	dacPool.AddCert(paiCert)
	verifyOpts := x509.VerifyOptions{
		Intermediates: dacPool,
		Roots:         x509.NewCertPool(),
		CurrentTime:   now,
	}
	verifyOpts.Roots.AddCert(paaCert)

	if _, err := dacCert.Verify(verifyOpts); err != nil {
		return false, fmt.Errorf("DAC chain verification failed: %w", err)
	}

	paiPool := x509.NewCertPool()
	paiPool.AddCert(paaCert)
	paiVerifyOpts := x509.VerifyOptions{
		Intermediates: paiPool,
		Roots:         x509.NewCertPool(),
		CurrentTime:   now,
	}
	paiVerifyOpts.Roots.AddCert(paaCert)

	if _, err := paiCert.Verify(paiVerifyOpts); err != nil {
		return false, fmt.Errorf("PAI chain verification failed: %w", err)
	}

	slog.Info("certificate chain validated", "device_id", deviceID)
	return true, nil
}

func (s *CertificateService) RevokeCertificate(id uuid.UUID) error {
	cert, err := s.certRepo.GetByID(id)
	if err != nil {
		return fmt.Errorf("certificate not found: %w", err)
	}

	cert.Status = "revoked"
	if err := s.certRepo.Update(cert); err != nil {
		return fmt.Errorf("failed to revoke certificate: %w", err)
	}

	slog.Info("certificate revoked", "cert_id", id)
	return nil
}

func parseCert(pemStr string) (*x509.Certificate, error) {
	block, _ := pem.Decode([]byte(pemStr))
	if block == nil {
		return nil, fmt.Errorf("failed to decode PEM block")
	}
	return x509.ParseCertificate(block.Bytes)
}
