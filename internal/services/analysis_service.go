package services

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"log/slog"
	"net/http"
	"time"
)

type AnalysisService struct {
	client  *http.Client
	baseURL string
	apiKey  string
}

type anomalyResult struct {
	DeviceID    string                 `json:"device_id"`
	IsAnomaly   bool                   `json:"is_anomaly"`
	AnomalyScore float64               `json:"anomaly_score"`
	Features    map[string]interface{} `json:"features"`
	Details     map[string]interface{} `json:"details"`
}

type analysisStats struct {
	TotalAttestations int                    `json:"total_attestations"`
	VerifiedCount     int                    `json:"verified_count"`
	FailedCount       int                    `json:"failed_count"`
	AnomalyRate       float64                `json:"anomaly_rate"`
	Breakdown         map[string]interface{} `json:"breakdown"`
}

type similarityResult struct {
	DeviceID    string    `json:"device_id"`
	SimilarID   string    `json:"similar_id"`
	Score       float64   `json:"score"`
}

func NewAnalysisService(baseURL, apiKey string) *AnalysisService {
	return &AnalysisService{
		client: &http.Client{
			Timeout: 60 * time.Second,
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

func (s *AnalysisService) DetectAnomalies(deviceData map[string]interface{}) (*anomalyResult, error) {
	payloadBytes, err := json.Marshal(deviceData)
	if err != nil {
		return nil, fmt.Errorf("failed to marshal anomaly request: %w", err)
	}

	httpReq, err := http.NewRequest("POST", s.baseURL+"/api/v1/anomalies/detect", bytes.NewReader(payloadBytes))
	if err != nil {
		return nil, fmt.Errorf("failed to create anomaly detection request: %w", err)
	}
	httpReq.Header.Set("Content-Type", "application/json")
	httpReq.Header.Set("X-API-Key", s.apiKey)

	resp, err := s.client.Do(httpReq)
	if err != nil {
		return nil, fmt.Errorf("anomaly detection request failed: %w", err)
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("failed to read anomaly response: %w", err)
	}

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("analysis service returned error status %d: %s", resp.StatusCode, string(body))
	}

	var result anomalyResult
	if err := json.Unmarshal(body, &result); err != nil {
		return nil, fmt.Errorf("failed to parse anomaly response: %w", err)
	}

	slog.Info("anomaly detection completed", "device_id", result.DeviceID, "is_anomaly", result.IsAnomaly)
	return &result, nil
}

func (s *AnalysisService) GetAttestationAnalysis(deviceIDs []string) (*analysisStats, error) {
	payload := map[string]interface{}{
		"device_ids": deviceIDs,
	}
	payloadBytes, err := json.Marshal(payload)
	if err != nil {
		return nil, fmt.Errorf("failed to marshal analysis request: %w", err)
	}

	httpReq, err := http.NewRequest("POST", s.baseURL+"/api/v1/analysis/attestations", bytes.NewReader(payloadBytes))
	if err != nil {
		return nil, fmt.Errorf("failed to create analysis request: %w", err)
	}
	httpReq.Header.Set("Content-Type", "application/json")
	httpReq.Header.Set("X-API-Key", s.apiKey)

	resp, err := s.client.Do(httpReq)
	if err != nil {
		return nil, fmt.Errorf("analysis request failed: %w", err)
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("failed to read analysis response: %w", err)
	}

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("analysis service returned error status %d: %s", resp.StatusCode, string(body))
	}

	var stats analysisStats
	if err := json.Unmarshal(body, &stats); err != nil {
		return nil, fmt.Errorf("failed to parse analysis response: %w", err)
	}

	return &stats, nil
}

func (s *AnalysisService) FindSimilarDevices(fingerprint map[string]interface{}, limit int) ([]similarityResult, error) {
	payload := map[string]interface{}{
		"fingerprint": fingerprint,
		"limit":       limit,
	}
	payloadBytes, err := json.Marshal(payload)
	if err != nil {
		return nil, fmt.Errorf("failed to marshal similarity request: %w", err)
	}

	httpReq, err := http.NewRequest("POST", s.baseURL+"/api/v1/similarity/search", bytes.NewReader(payloadBytes))
	if err != nil {
		return nil, fmt.Errorf("failed to create similarity request: %w", err)
	}
	httpReq.Header.Set("Content-Type", "application/json")
	httpReq.Header.Set("X-API-Key", s.apiKey)

	resp, err := s.client.Do(httpReq)
	if err != nil {
		return nil, fmt.Errorf("similarity search request failed: %w", err)
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("failed to read similarity response: %w", err)
	}

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("similarity service returned error status %d: %s", resp.StatusCode, string(body))
	}

	var results []similarityResult
	if err := json.Unmarshal(body, &results); err != nil {
		return nil, fmt.Errorf("failed to parse similarity response: %w", err)
	}

	return results, nil
}
