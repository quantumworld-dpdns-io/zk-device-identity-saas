package services

import (
	"context"
	"crypto/rand"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"log/slog"
	"time"

	"github.com/google/uuid"
	"github.com/redis/go-redis/v9"

	"github.com/quantumworld-dpdns-io/zk-device-identity-saas/internal/dto"
	"github.com/quantumworld-dpdns-io/zk-device-identity-saas/internal/models"
	"github.com/quantumworld-dpdns-io/zk-device-identity-saas/internal/repository"
)

type ProvisioningService struct {
	deviceRepo *repository.DeviceRepository
	redis      *redis.Client
}

func NewProvisioningService(deviceRepo *repository.DeviceRepository, redis *redis.Client) *ProvisioningService {
	return &ProvisioningService{
		deviceRepo: deviceRepo,
		redis:      redis,
	}
}

func (s *ProvisioningService) EnrollDevice(req *dto.EnrollRequest, tenantID uuid.UUID) (string, *models.Device, error) {
	if req.SerialNumber == "" || req.Manufacturer == "" || req.Model == "" || req.DeviceType == "" {
		return "", nil, fmt.Errorf("serial_number, manufacturer, model, and device_type are required")
	}

	existing, err := s.deviceRepo.SearchBySerialNumber(req.SerialNumber, tenantID)
	if err == nil && existing != nil {
		return "", nil, fmt.Errorf("device with serial number %s already exists", req.SerialNumber)
	}

	device := &models.Device{
		TenantID:     tenantID,
		SerialNumber: req.SerialNumber,
		Manufacturer: req.Manufacturer,
		Model:        req.Model,
		DeviceType:   req.DeviceType,
		PublicKey:    req.PublicKey,
		Status:       "enrolled",
	}

	if err := s.deviceRepo.Create(device); err != nil {
		return "", nil, fmt.Errorf("failed to enroll device: %w", err)
	}

	token, err := generateEnrollmentToken()
	if err != nil {
		return "", nil, fmt.Errorf("failed to generate enrollment token: %w", err)
	}

	challenge := make([]byte, 32)
	if _, err := rand.Read(challenge); err != nil {
		return "", nil, fmt.Errorf("failed to generate challenge: %w", err)
	}
	challengeHex := hex.EncodeToString(challenge)

	enrollmentData := map[string]interface{}{
		"device_id":      device.ID.String(),
		"tenant_id":      tenantID.String(),
		"serial_number":  req.SerialNumber,
		"challenge":      challengeHex,
		"token":          token,
		"status":         "pending",
		"created_at":     time.Now().UTC(),
	}

	dataJSON, _ := json.Marshal(enrollmentData)
	ctx := context.Background()
	if err := s.redis.Set(ctx, "enrollment:"+device.ID.String(), dataJSON, 30*time.Minute).Err(); err != nil {
		slog.Error("failed to store enrollment data in redis", "error", err)
	}

	slog.Info("device enrolled", "device_id", device.ID, "token", token)
	return token, device, nil
}

func (s *ProvisioningService) ProvisionSecureElement(req *dto.ProvisionRequest) (bool, error) {
	deviceID, err := uuid.Parse(req.DeviceID)
	if err != nil {
		return false, fmt.Errorf("invalid device_id: %w", err)
	}
	tenantID, err := uuid.Parse(req.TenantID)
	if err != nil {
		return false, fmt.Errorf("invalid tenant_id: %w", err)
	}

	ctx := context.Background()
	dataJSON, err := s.redis.Get(ctx, "enrollment:"+deviceID.String()).Bytes()
	if err != nil {
		return false, fmt.Errorf("no enrollment found or expired for device %s", deviceID)
	}

	var enrollmentData map[string]interface{}
	if err := json.Unmarshal(dataJSON, &enrollmentData); err != nil {
		return false, fmt.Errorf("failed to parse enrollment data: %w", err)
	}

	storedTenantID, _ := enrollmentData["tenant_id"].(string)
	if storedTenantID != tenantID.String() {
		return false, fmt.Errorf("tenant mismatch for enrollment")
	}

	storedChallenge, _ := enrollmentData["challenge"].(string)
	provisioningChallenge, ok := req.ProvisioningData["challenge_response"].(string)
	if !ok || provisioningChallenge == "" {
		return false, fmt.Errorf("missing challenge_response in provisioning data")
	}

	expectedResponse := hashChallenge(storedChallenge)
	if provisioningChallenge != expectedResponse {
		return false, fmt.Errorf("challenge response mismatch")
	}

	device, err := s.deviceRepo.GetByID(deviceID)
	if err != nil {
		return false, fmt.Errorf("device not found: %w", err)
	}

	device.Status = "provisioned"
	if err := s.deviceRepo.Update(device); err != nil {
		return false, fmt.Errorf("failed to update device status: %w", err)
	}

	s.redis.Del(ctx, "enrollment:"+deviceID.String())

	slog.Info("secure element provisioned", "device_id", deviceID)
	return true, nil
}

func (s *ProvisioningService) GetProvisioningStatus(deviceID uuid.UUID) (string, error) {
	ctx := context.Background()
	exists, err := s.redis.Exists(ctx, "enrollment:"+deviceID.String()).Result()
	if err == nil && exists > 0 {
		return "pending", nil
	}

	device, err := s.deviceRepo.GetByID(deviceID)
	if err != nil {
		return "", fmt.Errorf("device not found: %w", err)
	}

	return device.Status, nil
}

func generateEnrollmentToken() (string, error) {
	token := make([]byte, 32)
	if _, err := rand.Read(token); err != nil {
		return "", err
	}
	return "zkdev_enroll_" + hex.EncodeToString(token), nil
}

func hashChallenge(challenge string) string {
	hash := sha256.Sum256([]byte(challenge + ":provision"))
	return hex.EncodeToString(hash[:])
}
