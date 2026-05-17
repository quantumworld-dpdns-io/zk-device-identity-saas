package models

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/datatypes"
)

type ProofRecord struct {
	ID                uuid.UUID      `gorm:"type:uuid;primaryKey;default:gen_random_uuid()"`
	TenantID          uuid.UUID      `gorm:"type:uuid;not null;index"`
	DeviceID          uuid.UUID      `gorm:"type:uuid;not null;index"`
	CircuitType       string         `gorm:"type:varchar(100);not null"`
	ProofData         datatypes.JSON `gorm:"type:jsonb"`
	PublicInputs      datatypes.JSON `gorm:"type:jsonb"`
	PrivateInputsHash string         `gorm:"type:varchar(512)"`
	Status            string         `gorm:"type:varchar(50);default:pending"`
	CreatedAt         time.Time      `gorm:"autoCreateTime"`
}
