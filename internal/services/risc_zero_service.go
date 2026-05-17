package services

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"log/slog"
	"net/http"
	"time"

	"github.com/quantumworld-dpdns-io/zk-device-identity-saas/internal/dto"
)

type RiscZeroService struct {
	client  *http.Client
	baseURL string
	apiKey  string
}

type complianceCheckResponse struct {
	RequestID   string  `json:"request_id"`
	IsCompliant bool    `json:"is_compliant"`
	Score       float64 `json:"score"`
	Details     map[string]interface{} `json:"details"`
	Receipt     string  `json:"receipt"`
}

type receiptVerifyResponse struct {
	Valid   bool   `json:"valid"`
	ImageID string `json:"image_id"`
}

func NewRiscZeroService(baseURL, apiKey string) *RiscZeroService {
	return &RiscZeroService{
		client: &http.Client{
			Timeout: 120 * time.Second,
			Transport: &http.Transport{
				MaxIdleConns:        10,
				IdleConnTimeout:     30 * time.Second,
				DisableCompression:  false,
			},
		},
		baseURL: baseURL,
		apiKey:  apiKey,
	}
}

func (s *RiscZeroService) CheckCompliance(req *dto.ComplianceCheckRequest) (*complianceCheckResponse, error) {
	payloadBytes, err := json.Marshal(req)
	if err != nil {
		return nil, fmt.Errorf("failed to marshal compliance request: %w", err)
	}

	httpReq, err := http.NewRequest("POST", s.baseURL+"/api/v1/compliance/check", bytes.NewReader(payloadBytes))
	if err != nil {
		return nil, fmt.Errorf("failed to create compliance request: %w", err)
	}
	httpReq.Header.Set("Content-Type", "application/json")
	httpReq.Header.Set("X-API-Key", s.apiKey)

	resp, err := s.client.Do(httpReq)
	if err != nil {
		return nil, fmt.Errorf("compliance check request failed: %w", err)
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("failed to read compliance response: %w", err)
	}

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("compliance service returned error status %d: %s", resp.StatusCode, string(body))
	}

	var result complianceCheckResponse
	if err := json.Unmarshal(body, &result); err != nil {
		return nil, fmt.Errorf("failed to parse compliance response: %w", err)
	}

	slog.Info("compliance check completed", "request_id", result.RequestID, "compliant", result.IsCompliant)
	return &result, nil
}

func (s *RiscZeroService) VerifyReceipt(receipt string, imageID string) (bool, error) {
	verifyPayload := map[string]string{
		"receipt":  receipt,
		"image_id": imageID,
	}
	payloadBytes, err := json.Marshal(verifyPayload)
	if err != nil {
		return false, fmt.Errorf("failed to marshal receipt verify request: %w", err)
	}

	httpReq, err := http.NewRequest("POST", s.baseURL+"/api/v1/receipt/verify", bytes.NewReader(payloadBytes))
	if err != nil {
		return false, fmt.Errorf("failed to create receipt verify request: %w", err)
	}
	httpReq.Header.Set("Content-Type", "application/json")
	httpReq.Header.Set("X-API-Key", s.apiKey)

	resp, err := s.client.Do(httpReq)
	if err != nil {
		return false, fmt.Errorf("receipt verification request failed: %w", err)
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return false, fmt.Errorf("failed to read receipt verify response: %w", err)
	}

	if resp.StatusCode != http.StatusOK {
		return false, fmt.Errorf("receipt service returned error status %d: %s", resp.StatusCode, string(body))
	}

	var verifyResp receiptVerifyResponse
	if err := json.Unmarshal(body, &verifyResp); err != nil {
		return false, fmt.Errorf("failed to parse receipt verify response: %w", err)
	}

	slog.Info("receipt verified", "image_id", imageID, "valid", verifyResp.Valid)
	return verifyResp.Valid, nil
}
