package repository

import (
	"log/slog"

	"github.com/google/uuid"
	"github.com/quantumworld-dpdns-io/zk-device-identity-saas/internal/models"
	"gorm.io/gorm"
)

type TenantRepository struct {
	db *gorm.DB
}

func NewTenantRepository(db *gorm.DB) *TenantRepository {
	return &TenantRepository{db: db}
}

func (r *TenantRepository) Create(tenant *models.Tenant) error {
	if err := r.db.Create(tenant).Error; err != nil {
		slog.Error("failed to create tenant", "error", err)
		return err
	}
	return nil
}

func (r *TenantRepository) GetByID(id uuid.UUID) (*models.Tenant, error) {
	var tenant models.Tenant
	if err := r.db.First(&tenant, "id = ?", id).Error; err != nil {
		slog.Error("failed to get tenant by id", "id", id, "error", err)
		return nil, err
	}
	return &tenant, nil
}

func (r *TenantRepository) GetBySlug(slug string) (*models.Tenant, error) {
	var tenant models.Tenant
	if err := r.db.Where("slug = ?", slug).First(&tenant).Error; err != nil {
		slog.Error("failed to get tenant by slug", "slug", slug, "error", err)
		return nil, err
	}
	return &tenant, nil
}

func (r *TenantRepository) List() ([]models.Tenant, error) {
	var tenants []models.Tenant
	if err := r.db.Order("created_at DESC").Find(&tenants).Error; err != nil {
		slog.Error("failed to list tenants", "error", err)
		return nil, err
	}
	return tenants, nil
}

func (r *TenantRepository) Update(tenant *models.Tenant) error {
	if err := r.db.Save(tenant).Error; err != nil {
		slog.Error("failed to update tenant", "id", tenant.ID, "error", err)
		return err
	}
	return nil
}
