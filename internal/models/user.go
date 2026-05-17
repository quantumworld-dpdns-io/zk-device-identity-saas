package models

import (
	"time"

	"github.com/google/uuid"
)

type User struct {
	ID           uuid.UUID  `gorm:"type:uuid;primaryKey;default:gen_random_uuid()"`
	TenantID     *uuid.UUID `gorm:"type:uuid;index"`
	Email        string     `gorm:"type:varchar(255);not null;uniqueIndex"`
	PasswordHash string     `gorm:"type:varchar(512);not null"`
	Role         string     `gorm:"type:varchar(50);default:user"`
	MFAEnabled   bool       `gorm:"default:false"`
	CreatedAt    time.Time  `gorm:"autoCreateTime"`
	UpdatedAt    time.Time  `gorm:"autoUpdateTime"`
}
