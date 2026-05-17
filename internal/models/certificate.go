package models

import (
	"time"

	"github.com/google/uuid"
)

type Certificate struct {
	ID             uuid.UUID  `gorm:"type:uuid;primaryKey;default:gen_random_uuid()"`
	DeviceID       uuid.UUID  `gorm:"type:uuid;not null;index"`
	CertType       string     `gorm:"type:varchar(10);not null"`
	CertificatePEM string     `gorm:"type:text;not null"`
	IssuerID       *uuid.UUID `gorm:"type:uuid"`
	SerialNumber   string     `gorm:"type:varchar(255)"`
	ValidFrom      time.Time  `gorm:"type:timestamptz"`
	ValidTo        time.Time  `gorm:"type:timestamptz"`
	Status         string     `gorm:"type:varchar(50);default:active"`
	CreatedAt      time.Time  `gorm:"autoCreateTime"`
}
