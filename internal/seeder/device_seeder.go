package seeder

import (
	"fmt"
	"time"

	"github.com/quantumworld-dpdns-io/zk-device-identity-saas/internal/models"
	"gorm.io/datatypes"
	"gorm.io/gorm"
)

func SeedDevices(db *gorm.DB, tenants []models.Tenant) []models.Device {
	manufacturers := []string{"MatterTech", "SecureLink", "IoTGuard"}
	modelsList := []string{"MT-100", "SL-200", "IG-300"}
	deviceTypes := []string{"sensor", "actuator", "gateway", "controller", "camera"}

	var devices []models.Device
	for i := 0; i < 10; i++ {
		device := models.Device{
			TenantID:        tenants[i%2].ID,
			SerialNumber:    fmt.Sprintf("SN-%08d", i+1),
			Manufacturer:    manufacturers[i%3],
			Model:           modelsList[i%3],
			FirmwareVersion: fmt.Sprintf("v1.%d.0", i),
			DeviceType:      deviceTypes[i%5],
			Status:          "active",
			PublicKey:       fmt.Sprintf("-----BEGIN PUBLIC KEY-----\nMOCK_KEY_%d\n-----END PUBLIC KEY-----", i+1),
			Metadata:        datatypes.JSON([]byte(`{"provisioned":true,"region":"us-east-1"}`)),
			CreatedAt:       time.Now(),
			UpdatedAt:       time.Now(),
		}
		db.Where("serial_number = ?", device.SerialNumber).FirstOrCreate(&device)
		devices = append(devices, device)
	}
	return devices
}

func SeedAttestations(db *gorm.DB, tenants []models.Tenant, devices []models.Device) []models.AttestationRecord {
	var records []models.AttestationRecord
	for i := 0; i < 5; i++ {
		record := models.AttestationRecord{
			DeviceID: devices[i].ID,
			TenantID: tenants[i%2].ID,
			Status:   "verified",
			AttestationData: datatypes.JSON([]byte(
				fmt.Sprintf(`{"dac":"mock-dac-%d","pai":"mock-pai-%d"}`, i+1, i+1),
			)),
			Signature:  fmt.Sprintf("mock-signature-%d", i+1),
			VerifiedBy: "system",
			CreatedAt:  time.Now(),
		}
		db.Where("device_id = ?", devices[i].ID).FirstOrCreate(&record)
		records = append(records, record)
	}
	return records
}
