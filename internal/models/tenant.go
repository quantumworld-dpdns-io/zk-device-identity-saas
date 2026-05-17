package models

import (
	"time"

	"github.com/google/uuid"
)

type Tenant struct {
	ID        uuid.UUID `gorm:"type:uuid;primaryKey;default:gen_random_uuid()"`
	Name      string    `gorm:"type:varchar(255);not null"`
	Slug      string    `gorm:"type:varchar(255);not null;uniqueIndex"`
	Plan      string    `gorm:"type:varchar(50);default:free"`
	CreatedAt time.Time `gorm:"autoCreateTime"`
	UpdatedAt time.Time `gorm:"autoUpdateTime"`
}
