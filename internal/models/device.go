package models

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/datatypes"
	"gorm.io/gorm"
)

type Device struct {
	ID              uuid.UUID      `gorm:"type:uuid;primaryKey;default:gen_random_uuid()"`
	TenantID        uuid.UUID      `gorm:"type:uuid;not null;index"`
	SerialNumber    string         `gorm:"type:varchar(255);not null;uniqueIndex"`
	Manufacturer    string         `gorm:"type:varchar(255);not null"`
	Model           string         `gorm:"type:varchar(255);not null"`
	FirmwareVersion string         `gorm:"type:varchar(100)"`
	DeviceType      string         `gorm:"type:varchar(100);not null"`
	Status          string         `gorm:"type:varchar(50);default:active"`
	PublicKey       string         `gorm:"type:text"`
	Metadata        datatypes.JSON `gorm:"type:jsonb"`
	CreatedAt       time.Time      `gorm:"autoCreateTime"`
	UpdatedAt       time.Time      `gorm:"autoUpdateTime"`
	DeletedAt       gorm.DeletedAt `gorm:"index"`
}

type DeviceFingerprint struct {
	ID              uuid.UUID      `gorm:"type:uuid;primaryKey;default:gen_random_uuid()"`
	DeviceID        uuid.UUID      `gorm:"type:uuid;not null;index"`
	FingerprintHash string         `gorm:"type:varchar(512);not null"`
	Embedding       datatypes.JSON `gorm:"type:jsonb"`
	CreatedAt       time.Time      `gorm:"autoCreateTime"`
}
