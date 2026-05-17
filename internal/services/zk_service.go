package services

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"log/slog"
	"net/http"
	"time"

	"github.com/google/uuid"
	"github.com/quantumworld-dpdns-io/zk-device-identity-saas/internal/dto"
	"github.com/quantumworld-dpdns-io/zk-device-identity-saas/internal/models"
	"github.com/quantumworld-dpdns-io/zk-device-identity-saas/internal/repository"
)

type ZKService struct {
	client    *http.Client
	baseURL   string
	apiKey    string
	proofRepo *repository.ProofRepository
}

type noirProofResponse struct {
	ProofID     string                 `json:"proof_id"`
	ProofData   map[string]interface{} `json:"proof_data"`
	PublicInputs map[string]interface{} `json:"public_inputs"`
	Status      string                 `json:"status"`
}

type noirVerifyResponse struct {
	Valid     bool   `json:"valid"`
	CircuitID string `json:"circuit_id"`
}

type circuitInfo struct {
	ID          string   `json:"id"`
	Name        string   `json:"name"`
	Version     string   `json:"version"`
	InputTypes  []string `json:"input_types"`
	OutputTypes []string `json:"output_types"`
}

func NewZKService(baseURL, apiKey string, proofRepo *repository.ProofRepository) *ZKService {
	return &ZKService{
		client: &http.Client{
			Timeout: 60 * time.Second,
			Transport: &http.Transport{
				MaxIdleConns:        10,
				IdleConnTimeout:     30 * time.Second,
				DisableCompression:  false,
			},
		},
		baseURL:   baseURL,
		apiKey:    apiKey,
		proofRepo: proofRepo,
	}
}

func (s *ZKService) GenerateProof(req *dto.GenerateProofRequest) (*models.ProofRecord, error) {
	deviceID, err := uuid.Parse(req.DeviceID)
	if err != nil {
		return nil, fmt.Errorf("invalid device_id: %w", err)
	}
	tenantID, err := uuid.Parse(req.TenantID)
	if err != nil {
		return nil, fmt.Errorf("invalid tenant_id: %w", err)
	}

	proofPayload := map[string]interface{}{
		"circuit_type":  req.CircuitType,
		"public_inputs": req.PublicInputs,
		"private_inputs": req.PrivateInputs,
		"device_id":     req.DeviceID,
	}
	payloadBytes, err := json.Marshal(proofPayload)
	if err != nil {
		return nil, fmt.Errorf("failed to marshal proof request: %w", err)
	}

	httpReq, err := http.NewRequest("POST", s.baseURL+"/api/v1/prove", bytes.NewReader(payloadBytes))
	if err != nil {
		return nil, fmt.Errorf("failed to create proof request: %w", err)
	}
	httpReq.Header.Set("Content-Type", "application/json")
	httpReq.Header.Set("X-API-Key", s.apiKey)

	resp, err := s.client.Do(httpReq)
	if err != nil {
		return nil, fmt.Errorf("proof generation request failed: %w", err)
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("failed to read proof response: %w", err)
	}

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("proof service returned error status %d: %s", resp.StatusCode, string(body))
	}

	var noirResp noirProofResponse
	if err := json.Unmarshal(body, &noirResp); err != nil {
		return nil, fmt.Errorf("failed to parse proof response: %w", err)
	}

	proofRecord := &models.ProofRecord{
		TenantID:    tenantID,
		DeviceID:    deviceID,
		CircuitType: req.CircuitType,
		ProofData:   noirResp.ProofData,
		PublicInputs: req.PublicInputs,
		Status:      noirResp.Status,
	}
	if noirResp.Status == "" {
		proofRecord.Status = "generated"
	}

	if err := s.proofRepo.Create(proofRecord); err != nil {
		return nil, fmt.Errorf("failed to store proof record: %w", err)
	}

	slog.Info("ZK proof generated", "proof_id", proofRecord.ID, "circuit", req.CircuitType)
	return proofRecord, nil
}

func (s *ZKService) VerifyProof(req *dto.VerifyProofRequest) (bool, error) {
	proofID, err := uuid.Parse(req.ProofID)
	if err != nil {
		return false, fmt.Errorf("invalid proof_id: %w", err)
	}

	proofRecord, err := s.proofRepo.GetByID(proofID)
	if err != nil {
		return false, fmt.Errorf("proof not found: %w", err)
	}

	verifyPayload := map[string]interface{}{
		"proof_data":    req.ProofData,
		"public_inputs": req.PublicInputs,
		"circuit_type":  proofRecord.CircuitType,
	}
	payloadBytes, err := json.Marshal(verifyPayload)
	if err != nil {
		return false, fmt.Errorf("failed to marshal verify request: %w", err)
	}

	httpReq, err := http.NewRequest("POST", s.baseURL+"/api/v1/verify", bytes.NewReader(payloadBytes))
	if err != nil {
		return false, fmt.Errorf("failed to create verify request: %w", err)
	}
	httpReq.Header.Set("Content-Type", "application/json")
	httpReq.Header.Set("X-API-Key", s.apiKey)

	resp, err := s.client.Do(httpReq)
	if err != nil {
		return false, fmt.Errorf("proof verification request failed: %w", err)
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return false, fmt.Errorf("failed to read verify response: %w", err)
	}

	if resp.StatusCode != http.StatusOK {
		return false, fmt.Errorf("verify service returned error status %d: %s", resp.StatusCode, string(body))
	}

	var verifyResp noirVerifyResponse
	if err := json.Unmarshal(body, &verifyResp); err != nil {
		return false, fmt.Errorf("failed to parse verify response: %w", err)
	}

	status := "verified"
	if !verifyResp.Valid {
		status = "invalid"
	}
	if err := s.proofRepo.UpdateStatus(proofID, status); err != nil {
		slog.Error("failed to update proof status", "proof_id", proofID, "error", err)
	}

	slog.Info("ZK proof verified", "proof_id", proofID, "valid", verifyResp.Valid)
	return verifyResp.Valid, nil
}

func (s *ZKService) GetCircuitInfo() ([]map[string]interface{}, error) {
	httpReq, err := http.NewRequest("GET", s.baseURL+"/api/v1/circuits", nil)
	if err != nil {
		return nil, fmt.Errorf("failed to create circuits request: %w", err)
	}
	httpReq.Header.Set("X-API-Key", s.apiKey)

	resp, err := s.client.Do(httpReq)
	if err != nil {
		return nil, fmt.Errorf("circuits request failed: %w", err)
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("failed to read circuits response: %w", err)
	}

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("circuits service returned error status %d: %s", resp.StatusCode, string(body))
	}

	var circuits []map[string]interface{}
	if err := json.Unmarshal(body, &circuits); err != nil {
		return nil, fmt.Errorf("failed to parse circuits response: %w", err)
	}

	return circuits, nil
}
