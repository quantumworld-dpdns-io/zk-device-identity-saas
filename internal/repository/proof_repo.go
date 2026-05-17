package repository

import (
	"log/slog"

	"github.com/google/uuid"
	"github.com/quantumworld-dpdns-io/zk-device-identity-saas/internal/models"
	"gorm.io/gorm"
)

type ProofRepository struct {
	db *gorm.DB
}

func NewProofRepository(db *gorm.DB) *ProofRepository {
	return &ProofRepository{db: db}
}

func (r *ProofRepository) Create(proof *models.ProofRecord) error {
	if err := r.db.Create(proof).Error; err != nil {
		slog.Error("failed to create proof", "error", err)
		return err
	}
	return nil
}

func (r *ProofRepository) GetByID(id uuid.UUID) (*models.ProofRecord, error) {
	var proof models.ProofRecord
	if err := r.db.First(&proof, "id = ?", id).Error; err != nil {
		slog.Error("failed to get proof by id", "id", id, "error", err)
		return nil, err
	}
	return &proof, nil
}

func (r *ProofRepository) ListByTenant(tenantID uuid.UUID, page, pageSize int) ([]models.ProofRecord, int64, error) {
	var proofs []models.ProofRecord
	var total int64

	query := r.db.Model(&models.ProofRecord{}).Where("tenant_id = ?", tenantID)
	if err := query.Count(&total).Error; err != nil {
		return nil, 0, err
	}

	offset := (page - 1) * pageSize
	if err := query.Offset(offset).Limit(pageSize).Order("created_at DESC").Find(&proofs).Error; err != nil {
		return nil, 0, err
	}
	return proofs, total, nil
}

func (r *ProofRepository) ListByDevice(deviceID uuid.UUID, page, pageSize int) ([]models.ProofRecord, int64, error) {
	var proofs []models.ProofRecord
	var total int64

	query := r.db.Model(&models.ProofRecord{}).Where("device_id = ?", deviceID)
	if err := query.Count(&total).Error; err != nil {
		return nil, 0, err
	}

	offset := (page - 1) * pageSize
	if err := query.Offset(offset).Limit(pageSize).Order("created_at DESC").Find(&proofs).Error; err != nil {
		return nil, 0, err
	}
	return proofs, total, nil
}

func (r *ProofRepository) UpdateStatus(id uuid.UUID, status string) error {
	if err := r.db.Model(&models.ProofRecord{}).Where("id = ?", id).Update("status", status).Error; err != nil {
		slog.Error("failed to update proof status", "id", id, "status", status, "error", err)
		return err
	}
	return nil
}
