package seeder

import (
	"fmt"
	"time"

	"github.com/quantumworld-dpdns-io/zk-device-identity-saas/internal/models"
	"gorm.io/gorm"
)

func SeedCertificates(db *gorm.DB, devices []models.Device) {
	for _, device := range devices {
		cert := models.Certificate{
			DeviceID:       device.ID,
			CertType:       "DAC",
			CertificatePEM: fmt.Sprintf("-----BEGIN CERTIFICATE-----\nMOCK_DAC_CERT_%s\n-----END CERTIFICATE-----", device.SerialNumber),
			SerialNumber:   device.SerialNumber,
			ValidFrom:      time.Now().Add(-24 * time.Hour),
			ValidTo:        time.Now().Add(365 * 24 * time.Hour),
			Status:         "active",
		}
		db.Where("device_id = ? AND cert_type = ?", device.ID, "DAC").FirstOrCreate(&cert)
	}
}
