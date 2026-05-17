package models

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/datatypes"
)

type AuditLog struct {
	ID         uuid.UUID      `gorm:"type:uuid;primaryKey;default:gen_random_uuid()"`
	TenantID   *uuid.UUID     `gorm:"type:uuid;index"`
	UserID     *uuid.UUID     `gorm:"type:uuid;index"`
	Action     string         `gorm:"type:varchar(100);not null"`
	Resource   string         `gorm:"type:varchar(100);not null"`
	ResourceID string         `gorm:"type:varchar(255)"`
	StatusCode int            `gorm:"default:0"`
	RequestIP  string         `gorm:"type:varchar(45)"`
	UserAgent  string         `gorm:"type:text"`
	Details    datatypes.JSON `gorm:"type:jsonb"`
	CreatedAt  time.Time      `gorm:"autoCreateTime"`
}
