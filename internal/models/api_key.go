package models

import (
	"time"

	"github.com/google/uuid"
)

type APIKey struct {
	ID        uuid.UUID  `gorm:"type:uuid;primaryKey;default:gen_random_uuid()"`
	TenantID  uuid.UUID  `gorm:"type:uuid;not null;index"`
	KeyHash   string     `gorm:"type:varchar(512);not null"`
	Name      string     `gorm:"type:varchar(255);not null"`
	Scopes    string     `gorm:"type:text"`
	ExpiresAt *time.Time `gorm:"type:timestamptz"`
	CreatedAt time.Time  `gorm:"autoCreateTime"`
}
