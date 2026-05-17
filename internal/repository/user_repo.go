package repository

import (
	"log/slog"

	"github.com/google/uuid"
	"github.com/quantumworld-dpdns-io/zk-device-identity-saas/internal/models"
	"gorm.io/gorm"
)

type UserRepository struct {
	db *gorm.DB
}

func NewUserRepository(db *gorm.DB) *UserRepository {
	return &UserRepository{db: db}
}

func (r *UserRepository) Create(user *models.User) error {
	if err := r.db.Create(user).Error; err != nil {
		slog.Error("failed to create user", "error", err)
		return err
	}
	return nil
}

func (r *UserRepository) GetByID(id uuid.UUID) (*models.User, error) {
	var user models.User
	if err := r.db.First(&user, "id = ?", id).Error; err != nil {
		slog.Error("failed to get user by id", "id", id, "error", err)
		return nil, err
	}
	return &user, nil
}

func (r *UserRepository) GetByEmail(email string) (*models.User, error) {
	var user models.User
	if err := r.db.Where("email = ?", email).First(&user).Error; err != nil {
		slog.Error("failed to get user by email", "email", email, "error", err)
		return nil, err
	}
	return &user, nil
}

func (r *UserRepository) ListByTenant(tenantID uuid.UUID) ([]models.User, error) {
	var users []models.User
	if err := r.db.Where("tenant_id = ?", tenantID).Order("created_at DESC").Find(&users).Error; err != nil {
		slog.Error("failed to list users by tenant", "tenant_id", tenantID, "error", err)
		return nil, err
	}
	return users, nil
}

func (r *UserRepository) Update(user *models.User) error {
	if err := r.db.Save(user).Error; err != nil {
		slog.Error("failed to update user", "id", user.ID, "error", err)
		return err
	}
	return nil
}
