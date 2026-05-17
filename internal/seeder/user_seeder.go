package seeder

import (
	"github.com/google/uuid"
	"github.com/quantumworld-dpdns-io/zk-device-identity-saas/internal/models"
	"golang.org/x/crypto/bcrypt"
	"gorm.io/gorm"
)

func SeedUsers(db *gorm.DB, tenants []models.Tenant) []models.User {
	hash, err := bcrypt.GenerateFromPassword([]byte("password123"), bcrypt.DefaultCost)
	if err != nil {
		panic("failed to hash password: " + err.Error())
	}
	hashStr := string(hash)

	entries := []struct {
		Email    string
		Password string
		Role     string
		TenantID *uuid.UUID
	}{
		{"admin@example.com", hashStr, "admin", &tenants[0].ID},
		{"user1@example.com", hashStr, "user", &tenants[0].ID},
		{"user2@example.com", hashStr, "user", &tenants[1].ID},
	}

	var users []models.User
	for _, e := range entries {
		user := models.User{
			Email:        e.Email,
			PasswordHash: e.Password,
			Role:         e.Role,
			TenantID:     e.TenantID,
		}
		db.Where("email = ?", e.Email).FirstOrCreate(&user)
		users = append(users, user)
	}
	return users
}
