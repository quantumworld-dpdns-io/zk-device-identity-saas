package repository

import (
	"log/slog"

	"github.com/google/uuid"
	"github.com/quantumworld-dpdns-io/zk-device-identity-saas/internal/models"
	"gorm.io/gorm"
)

type CertificateRepository struct {
	db *gorm.DB
}

func NewCertificateRepository(db *gorm.DB) *CertificateRepository {
	return &CertificateRepository{db: db}
}

func (r *CertificateRepository) Create(cert *models.Certificate) error {
	if err := r.db.Create(cert).Error; err != nil {
		slog.Error("failed to create certificate", "error", err)
		return err
	}
	return nil
}

func (r *CertificateRepository) GetByID(id uuid.UUID) (*models.Certificate, error) {
	var cert models.Certificate
	if err := r.db.First(&cert, "id = ?", id).Error; err != nil {
		slog.Error("failed to get certificate by id", "id", id, "error", err)
		return nil, err
	}
	return &cert, nil
}

func (r *CertificateRepository) ListByDevice(deviceID uuid.UUID) ([]models.Certificate, error) {
	var certs []models.Certificate
	if err := r.db.Where("device_id = ?", deviceID).Order("created_at DESC").Find(&certs).Error; err != nil {
		slog.Error("failed to list certificates by device", "device_id", deviceID, "error", err)
		return nil, err
	}
	return certs, nil
}

func (r *CertificateRepository) ListByType(certType string) ([]models.Certificate, error) {
	var certs []models.Certificate
	if err := r.db.Where("cert_type = ?", certType).Order("created_at DESC").Find(&certs).Error; err != nil {
		slog.Error("failed to list certificates by type", "cert_type", certType, "error", err)
		return nil, err
	}
	return certs, nil
}

func (r *CertificateRepository) GetDACChain(deviceID uuid.UUID) (*models.Certificate, *models.Certificate, *models.Certificate, error) {
	certs, err := r.ListByDevice(deviceID)
	if err != nil {
		return nil, nil, nil, err
	}

	var dac, pai, paa *models.Certificate
	for i := range certs {
		switch certs[i].CertType {
		case "DAC":
			dac = &certs[i]
		case "PAI":
			pai = &certs[i]
		case "PAA":
			paa = &certs[i]
		}
	}
	return dac, pai, paa, nil
}

func (r *CertificateRepository) FindBySerialNumber(serialNumber string) (*models.Certificate, error) {
	var cert models.Certificate
	if err := r.db.Where("serial_number = ?", serialNumber).First(&cert).Error; err != nil {
		slog.Error("failed to find certificate by serial number", "serial_number", serialNumber, "error", err)
		return nil, err
	}
	return &cert, nil
}

func (r *CertificateRepository) Update(cert *models.Certificate) error {
	if err := r.db.Save(cert).Error; err != nil {
		slog.Error("failed to update certificate", "id", cert.ID, "error", err)
		return err
	}
	return nil
}
