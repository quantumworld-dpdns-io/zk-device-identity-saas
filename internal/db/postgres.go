package db

import (
	"fmt"

	"github.com/quantumworld-dpdns-io/zk-device-identity-saas/internal/config"
	"github.com/quantumworld-dpdns-io/zk-device-identity-saas/internal/models"
	"gorm.io/driver/postgres"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"
)

func NewPostgresDB(cfg *config.Config) (*gorm.DB, error) {
	dsn := fmt.Sprintf(
		"host=%s port=%s user=%s password=%s dbname=%s sslmode=%s TimeZone=UTC",
		cfg.PostgresHost, cfg.PostgresPort, cfg.PostgresUser, cfg.PostgresPassword, cfg.PostgresDB, cfg.PostgresSSLMode,
	)

	logLevel := logger.Silent
	switch cfg.GoLogLevel {
	case "debug":
		logLevel = logger.Info
	case "info":
		logLevel = logger.Warn
	}

	db, err := gorm.Open(postgres.Open(dsn), &gorm.Config{
		Logger: logger.Default.LogMode(logLevel),
	})
	if err != nil {
		return nil, fmt.Errorf("failed to connect to postgres: %w", err)
	}

	if err := db.AutoMigrate(
		&models.Tenant{},
		&models.User{},
		&models.Device{},
		&models.DeviceFingerprint{},
		&models.Certificate{},
		&models.AttestationRecord{},
		&models.ProofRecord{},
		&models.APIKey{},
		&models.AuditLog{},
	); err != nil {
		return nil, fmt.Errorf("failed to auto-migrate: %w", err)
	}

	return db, nil
}
