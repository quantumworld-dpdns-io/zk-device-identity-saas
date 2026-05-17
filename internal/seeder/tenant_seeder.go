package seeder

import (
	"github.com/quantumworld-dpdns-io/zk-device-identity-saas/internal/models"
	"gorm.io/gorm"
)

func SeedTenants(db *gorm.DB) []models.Tenant {
	entries := []struct {
		Name string
		Slug string
		Plan string
	}{
		{"Acme Devices", "acme-devices", "enterprise"},
		{"Beta IoT", "beta-iot", "pro"},
	}

	var tenants []models.Tenant
	for _, e := range entries {
		tenant := models.Tenant{Name: e.Name, Slug: e.Slug, Plan: e.Plan}
		db.Where("slug = ?", e.Slug).FirstOrCreate(&tenant)
		tenants = append(tenants, tenant)
	}
	return tenants
}
