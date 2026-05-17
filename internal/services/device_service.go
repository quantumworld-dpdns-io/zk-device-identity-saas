package services

import (
	"crypto/rand"
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"log/slog"
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"

	"github.com/quantumworld-dpdns-io/zk-device-identity-saas/internal/dto"
	"github.com/quantumworld-dpdns-io/zk-device-identity-saas/internal/models"
	"github.com/quantumworld-dpdns-io/zk-device-identity-saas/internal/repository"
)

type DeviceService struct {
	deviceRepo  *repository.DeviceRepository
	certRepo    *repository.CertificateRepository
	vectorSvc   *VectorService
	cryptoKey   string
}

func NewDeviceService(
	deviceRepo *repository.DeviceRepository,
	certRepo *repository.CertificateRepository,
	vectorSvc *VectorService,
	cryptoKey string,
) *DeviceService {
	return &DeviceService{
		deviceRepo: deviceRepo,
		certRepo:   certRepo,
		vectorSvc:  vectorSvc,
		cryptoKey:  cryptoKey,
	}
}

func (s *DeviceService) RegisterDevice(req *dto.RegisterDeviceRequest, tenantID uuid.UUID) (*models.Device, string, error) {
	if req.SerialNumber == "" || req.Manufacturer == "" || req.Model == "" || req.DeviceType == "" {
		return nil, "", fmt.Errorf("serial_number, manufacturer, model, and device_type are required")
	}

	existing, err := s.deviceRepo.SearchBySerialNumber(req.SerialNumber, tenantID)
	if err == nil && existing != nil {
		return nil, "", fmt.Errorf("device with serial number %s already exists", req.SerialNumber)
	}

	device := &models.Device{
		TenantID:        tenantID,
		SerialNumber:    req.SerialNumber,
		Manufacturer:    req.Manufacturer,
		Model:           req.Model,
		FirmwareVersion: req.FirmwareVersion,
		DeviceType:      req.DeviceType,
		PublicKey:       req.PublicKey,
		Status:          "active",
	}

	if err := s.deviceRepo.Create(device); err != nil {
		slog.Error("failed to register device", "error", err)
		return nil, "", fmt.Errorf("failed to register device: %w", err)
	}

	apiKey, err := generateAPIKey(s.cryptoKey)
	if err != nil {
		slog.Error("failed to generate api key", "error", err)
		return nil, "", fmt.Errorf("failed to generate api key: %w", err)
	}

	hash := sha256.Sum256([]byte(apiKey))
	keyHash := hex.EncodeToString(hash[:])
	apiKeyModel := &models.APIKey{
		TenantID: tenantID,
		KeyHash:  keyHash,
		Name:     "device-" + device.SerialNumber,
		Scopes:   "device:attest device:read",
	}

	if err := s.deviceRepo.Create(apiKeyModel); err != nil {
		slog.Error("failed to store api key", "error", err)
		return device, apiKey, nil
	}

	slog.Info("device registered", "device_id", device.ID, "serial_number", device.SerialNumber)
	return device, apiKey, nil
}

func (s *DeviceService) GetDevice(id uuid.UUID) (*models.Device, []models.Certificate, error) {
	device, err := s.deviceRepo.GetByID(id)
	if err != nil {
		return nil, nil, fmt.Errorf("device not found: %w", err)
	}

	certs, err := s.certRepo.ListByDevice(id)
	if err != nil {
		slog.Warn("failed to fetch certificates for device", "device_id", id, "error", err)
		certs = []models.Certificate{}
	}

	return device, certs, nil
}

func (s *DeviceService) UpdateDevice(id uuid.UUID, req *dto.UpdateDeviceRequest) (*models.Device, error) {
	device, err := s.deviceRepo.GetByID(id)
	if err != nil {
		return nil, fmt.Errorf("device not found: %w", err)
	}

	if req.FirmwareVersion != "" {
		device.FirmwareVersion = req.FirmwareVersion
	}
	if req.Status != "" {
		device.Status = req.Status
	}
	if req.Metadata != nil {
		device.Metadata = req.Metadata
	}

	if err := s.deviceRepo.Update(device); err != nil {
		return nil, fmt.Errorf("failed to update device: %w", err)
	}

	slog.Info("device updated", "device_id", device.ID)
	return device, nil
}

func (s *DeviceService) ListDevices(tenantID uuid.UUID, page, pageSize int, serialNumber, manufacturer, status string) ([]models.Device, int64, error) {
	var devices []models.Device
	var total int64
	var err error

	switch {
	case serialNumber != "":
		var dev *models.Device
		dev, err = s.deviceRepo.SearchBySerialNumber(serialNumber, tenantID)
		if err == nil && dev != nil {
			devices = []models.Device{*dev}
			total = 1
		}
	case manufacturer != "":
		devices, total, err = s.deviceRepo.SearchByManufacturer(manufacturer, tenantID, page, pageSize)
	case status != "":
		devices, total, err = s.deviceRepo.SearchByStatus(status, tenantID, page, pageSize)
	default:
		devices, total, err = s.deviceRepo.List(tenantID, page, pageSize)
	}

	if err != nil {
		return nil, 0, fmt.Errorf("failed to list devices: %w", err)
	}
	return devices, total, nil
}

func (s *DeviceService) DeleteDevice(id uuid.UUID) error {
	if err := s.deviceRepo.Delete(id); err != nil {
		return fmt.Errorf("failed to delete device: %w", err)
	}

	if err := s.vectorSvc.DeleteFingerprint(id.String()); err != nil {
		slog.Warn("failed to delete device fingerprint from vector db", "device_id", id, "error", err)
	}

	slog.Info("device deleted", "device_id", id)
	return nil
}

func generateAPIKey(encryptionKey string) (string, error) {
	key := make([]byte, 32)
	if _, err := rand.Read(key); err != nil {
		return "", err
	}
	return "zkdev_" + hex.EncodeToString(key) + fmt.Sprintf("%d", time.Now().UnixNano()), nil
}
