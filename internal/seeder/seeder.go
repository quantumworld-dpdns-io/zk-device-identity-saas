package seeder

import (
	"log/slog"

	"github.com/quantumworld-dpdns-io/zk-device-identity-saas/internal/config"
	"gorm.io/gorm"
)

func Run(db *gorm.DB, cfg *config.Config) {
	slog.Info("seeding database...")

	tenants := SeedTenants(db)
	slog.Info("seeded tenants", "count", len(tenants))

	users := SeedUsers(db, tenants)
	slog.Info("seeded users", "count", len(users))
	_ = users

	devices := SeedDevices(db, tenants)
	slog.Info("seeded devices", "count", len(devices))

	SeedCertificates(db, devices)
	slog.Info("seeded certificates")

	attestations := SeedAttestations(db, tenants, devices)
	slog.Info("seeded attestations", "count", len(attestations))

	slog.Info("database seeding complete")
}
