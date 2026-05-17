package repository

import (
	"log/slog"

	"github.com/google/uuid"
	"github.com/quantumworld-dpdns-io/zk-device-identity-saas/internal/models"
	"gorm.io/gorm"
)

type DeviceRepository struct {
	db *gorm.DB
}

func NewDeviceRepository(db *gorm.DB) *DeviceRepository {
	return &DeviceRepository{db: db}
}

func (r *DeviceRepository) Create(device *models.Device) error {
	if err := r.db.Create(device).Error; err != nil {
		slog.Error("failed to create device", "error", err)
		return err
	}
	return nil
}

func (r *DeviceRepository) GetByID(id uuid.UUID) (*models.Device, error) {
	var device models.Device
	if err := r.db.First(&device, "id = ?", id).Error; err != nil {
		slog.Error("failed to get device by id", "id", id, "error", err)
		return nil, err
	}
	return &device, nil
}

func (r *DeviceRepository) List(tenantID uuid.UUID, page, pageSize int) ([]models.Device, int64, error) {
	var devices []models.Device
	var total int64

	query := r.db.Model(&models.Device{}).Where("tenant_id = ?", tenantID)
	if err := query.Count(&total).Error; err != nil {
		slog.Error("failed to count devices", "error", err)
		return nil, 0, err
	}

	offset := (page - 1) * pageSize
	if err := query.Offset(offset).Limit(pageSize).Order("created_at DESC").Find(&devices).Error; err != nil {
		slog.Error("failed to list devices", "error", err)
		return nil, 0, err
	}
	return devices, total, nil
}

func (r *DeviceRepository) Update(device *models.Device) error {
	if err := r.db.Save(device).Error; err != nil {
		slog.Error("failed to update device", "id", device.ID, "error", err)
		return err
	}
	return nil
}

func (r *DeviceRepository) Delete(id uuid.UUID) error {
	if err := r.db.Delete(&models.Device{}, "id = ?", id).Error; err != nil {
		slog.Error("failed to delete device", "id", id, "error", err)
		return err
	}
	return nil
}

func (r *DeviceRepository) SearchBySerialNumber(serialNumber string, tenantID uuid.UUID) (*models.Device, error) {
	var device models.Device
	if err := r.db.Where("serial_number = ? AND tenant_id = ?", serialNumber, tenantID).First(&device).Error; err != nil {
		return nil, err
	}
	return &device, nil
}

func (r *DeviceRepository) SearchByManufacturer(manufacturer string, tenantID uuid.UUID, page, pageSize int) ([]models.Device, int64, error) {
	var devices []models.Device
	var total int64

	query := r.db.Model(&models.Device{}).Where("manufacturer ILIKE ? AND tenant_id = ?", "%"+manufacturer+"%", tenantID)
	if err := query.Count(&total).Error; err != nil {
		return nil, 0, err
	}

	offset := (page - 1) * pageSize
	if err := query.Offset(offset).Limit(pageSize).Order("created_at DESC").Find(&devices).Error; err != nil {
		return nil, 0, err
	}
	return devices, total, nil
}

func (r *DeviceRepository) SearchByStatus(status string, tenantID uuid.UUID, page, pageSize int) ([]models.Device, int64, error) {
	var devices []models.Device
	var total int64

	query := r.db.Model(&models.Device{}).Where("status = ? AND tenant_id = ?", status, tenantID)
	if err := query.Count(&total).Error; err != nil {
		return nil, 0, err
	}

	offset := (page - 1) * pageSize
	if err := query.Offset(offset).Limit(pageSize).Order("created_at DESC").Find(&devices).Error; err != nil {
		return nil, 0, err
	}
	return devices, total, nil
}

func (r *DeviceRepository) ListAll(tenantID uuid.UUID) ([]models.Device, error) {
	var devices []models.Device
	if err := r.db.Where("tenant_id = ?", tenantID).Order("created_at DESC").Find(&devices).Error; err != nil {
		return nil, err
	}
	return devices, nil
}
