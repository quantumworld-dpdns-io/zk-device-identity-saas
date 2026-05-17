package repository

import (
	"log/slog"

	"github.com/google/uuid"
	"github.com/quantumworld-dpdns-io/zk-device-identity-saas/internal/models"
	"gorm.io/gorm"
)

type AttestationRepository struct {
	db *gorm.DB
}

func NewAttestationRepository(db *gorm.DB) *AttestationRepository {
	return &AttestationRepository{db: db}
}

func (r *AttestationRepository) Create(attestation *models.AttestationRecord) error {
	if err := r.db.Create(attestation).Error; err != nil {
		slog.Error("failed to create attestation", "error", err)
		return err
	}
	return nil
}

func (r *AttestationRepository) GetByID(id uuid.UUID) (*models.AttestationRecord, error) {
	var att models.AttestationRecord
	if err := r.db.First(&att, "id = ?", id).Error; err != nil {
		slog.Error("failed to get attestation by id", "id", id, "error", err)
		return nil, err
	}
	return &att, nil
}

func (r *AttestationRepository) ListByDevice(deviceID uuid.UUID, page, pageSize int) ([]models.AttestationRecord, int64, error) {
	var attestations []models.AttestationRecord
	var total int64

	query := r.db.Model(&models.AttestationRecord{}).Where("device_id = ?", deviceID)
	if err := query.Count(&total).Error; err != nil {
		return nil, 0, err
	}

	offset := (page - 1) * pageSize
	if err := query.Offset(offset).Limit(pageSize).Order("created_at DESC").Find(&attestations).Error; err != nil {
		return nil, 0, err
	}
	return attestations, total, nil
}

func (r *AttestationRepository) ListByTenant(tenantID uuid.UUID, page, pageSize int) ([]models.AttestationRecord, int64, error) {
	var attestations []models.AttestationRecord
	var total int64

	query := r.db.Model(&models.AttestationRecord{}).Where("tenant_id = ?", tenantID)
	if err := query.Count(&total).Error; err != nil {
		return nil, 0, err
	}

	offset := (page - 1) * pageSize
	if err := query.Offset(offset).Limit(pageSize).Order("created_at DESC").Find(&attestations).Error; err != nil {
		return nil, 0, err
	}
	return attestations, total, nil
}

func (r *AttestationRepository) UpdateStatus(id uuid.UUID, status string) error {
	if err := r.db.Model(&models.AttestationRecord{}).Where("id = ?", id).Update("status", status).Error; err != nil {
		slog.Error("failed to update attestation status", "id", id, "status", status, "error", err)
		return err
	}
	return nil
}
