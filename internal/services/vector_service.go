package services

import (
	"fmt"
	"log/slog"

	"github.com/quantumworld-dpdns-io/zk-device-identity-saas/internal/vector"
)

type VectorService struct {
	qdrant *vector.QdrantClient
}

func NewVectorService(qdrant *vector.QdrantClient) *VectorService {
	return &VectorService{qdrant: qdrant}
}

func (s *VectorService) StoreFingerprint(deviceID string, embedding []float32) error {
	if err := s.qdrant.UpsertFingerprint(deviceID, embedding); err != nil {
		slog.Error("failed to store fingerprint", "device_id", deviceID, "error", err)
		return fmt.Errorf("failed to store fingerprint: %w", err)
	}
	slog.Info("fingerprint stored", "device_id", deviceID)
	return nil
}

func (s *VectorService) SearchSimilar(embedding []float32, limit int) ([]string, error) {
	results, err := s.qdrant.SearchSimilar(embedding, limit)
	if err != nil {
		slog.Error("failed to search similar devices", "error", err)
		return nil, fmt.Errorf("failed to search similar devices: %w", err)
	}
	return results, nil
}

func (s *VectorService) DeleteFingerprint(deviceID string) error {
	if err := s.qdrant.DeleteFingerprint(deviceID); err != nil {
		slog.Error("failed to delete fingerprint", "device_id", deviceID, "error", err)
		return fmt.Errorf("failed to delete fingerprint: %w", err)
	}
	slog.Info("fingerprint deleted", "device_id", deviceID)
	return nil
}
