package handlers

import (
	"encoding/json"
	"net/http"
	"time"

	"github.com/quantumworld-dpdns-io/zk-device-identity-saas/internal/config"
)

type HealthHandler struct {
	startTime time.Time
	version   string
}

func NewHealthHandler(cfg *config.Config) *HealthHandler {
	return &HealthHandler{
		startTime: time.Now(),
		version:   "1.0.0",
	}
}

func (h *HealthHandler) Health(w http.ResponseWriter, r *http.Request) {
	resp := map[string]interface{}{
		"status":    "healthy",
		"uptime":    time.Since(h.startTime).String(),
		"version":   h.version,
		"timestamp": time.Now().UTC(),
	}
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(resp)
}
