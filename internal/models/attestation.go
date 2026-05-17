package models

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/datatypes"
)

type AttestationRecord struct {
	ID              uuid.UUID      `gorm:"type:uuid;primaryKey;default:gen_random_uuid()"`
	DeviceID        uuid.UUID      `gorm:"type:uuid;not null;index"`
	TenantID        uuid.UUID      `gorm:"type:uuid;not null;index"`
	Status          string         `gorm:"type:varchar(50);default:pending"`
	AttestationData datatypes.JSON `gorm:"type:jsonb"`
	Signature       string         `gorm:"type:text"`
	VerifiedBy      string         `gorm:"type:varchar(255)"`
	VerifiedAt      *time.Time     `gorm:"type:timestamptz"`
	CreatedAt       time.Time      `gorm:"autoCreateTime"`
}
