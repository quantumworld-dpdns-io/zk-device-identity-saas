package api

import (
	"encoding/json"
	"log/slog"
	"net/http"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"
	"github.com/redis/go-redis/v9"
	swagger "github.com/swaggo/http-swagger"
	"gorm.io/gorm"

	"github.com/quantumworld-dpdns-io/zk-device-identity-saas/internal/api/handlers"
	"github.com/quantumworld-dpdns-io/zk-device-identity-saas/internal/config"
	"github.com/quantumworld-dpdns-io/zk-device-identity-saas/internal/dto"
	"github.com/quantumworld-dpdns-io/zk-device-identity-saas/internal/models"
)

func NewRouter(cfg *config.Config, db *gorm.DB, rdb *redis.Client) *chi.Mux {
	r := chi.NewRouter()

	r.Use(LoggerMiddleware)
	r.Use(RecovererMiddleware)
	r.Use(CORSMiddleware)
	r.Use(RequestIDMiddleware)

	healthH := handlers.NewHealthHandler(cfg)
	authH := handlers.NewAuthHandler(db, cfg)

	r.Route("/api/v1", func(r chi.Router) {
		r.Get("/health", healthH.Health)

		r.Post("/auth/login", authH.Login)
		r.Post("/auth/register", authH.Register)

		r.Get("/swagger/*", swagger.Handler())

		r.Group(func(r chi.Router) {
			r.Use(AuthMiddleware(cfg))
			r.Use(TenantMiddleware)
			r.Use(RateLimitMiddleware(rdb))
			r.Use(AuditMiddleware(db))

			r.Get("/devices", listDevices(db))
			r.Post("/devices", createDevice(db))
			r.Get("/devices/{id}", getDevice(db))
			r.Put("/devices/{id}", updateDevice(db))
			r.Delete("/devices/{id}", deleteDevice(db))

			r.Post("/attestations", createAttestation(db))
			r.Get("/attestations/{id}", getAttestation(db))

			r.Post("/proofs/generate", generateProof(db))
			r.Post("/proofs/verify", verifyProof(db))
			r.Get("/proofs/{id}", getProof(db))

			r.Post("/compliance/check", complianceCheck())
			r.Post("/provisioning/enroll", enrollDevice(db))
			r.Get("/analytics/anomalies", listAnomalies())
		})
	})

	return r
}

func listDevices(db *gorm.DB) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		tenantIDStr, _ := r.Context().Value(tenantIDKey).(string)
		tid, _ := uuid.Parse(tenantIDStr)

		var devices []models.Device
		if err := db.Where("tenant_id = ?", tid).Find(&devices).Error; err != nil {
			writeJSON(w, http.StatusInternalServerError, map[string]string{"error": "failed to list devices"})
			return
		}
		writeJSON(w, http.StatusOK, devices)
	}
}

func createDevice(db *gorm.DB) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req dto.CreateDeviceRequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			writeJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid request body"})
			return
		}

		tenantIDStr, _ := r.Context().Value(tenantIDKey).(string)
		tid, _ := uuid.Parse(tenantIDStr)

		device := models.Device{
			TenantID:        tid,
			SerialNumber:    req.SerialNumber,
			Manufacturer:    req.Manufacturer,
			Model:           req.Model,
			FirmwareVersion: req.FirmwareVersion,
			DeviceType:      req.DeviceType,
			PublicKey:       req.PublicKey,
			Status:          "active",
		}
		if err := db.Create(&device).Error; err != nil {
			slog.Error("failed to create device", "error", err)
			writeJSON(w, http.StatusInternalServerError, map[string]string{"error": "failed to create device"})
			return
		}
		writeJSON(w, http.StatusCreated, device)
	}
}

func getDevice(db *gorm.DB) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		id := chi.URLParam(r, "id")
		var device models.Device
		if err := db.First(&device, "id = ?", id).Error; err != nil {
			writeJSON(w, http.StatusNotFound, map[string]string{"error": "device not found"})
			return
		}
		writeJSON(w, http.StatusOK, device)
	}
}

func updateDevice(db *gorm.DB) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		id := chi.URLParam(r, "id")
		var req dto.UpdateDeviceRequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			writeJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid request body"})
			return
		}

		updates := map[string]interface{}{}
		if req.FirmwareVersion != "" {
			updates["firmware_version"] = req.FirmwareVersion
		}
		if req.Status != "" {
			updates["status"] = req.Status
		}

		if err := db.Model(&models.Device{}).Where("id = ?", id).Updates(updates).Error; err != nil {
			writeJSON(w, http.StatusInternalServerError, map[string]string{"error": "failed to update device"})
			return
		}
		writeJSON(w, http.StatusOK, map[string]string{"message": "device updated"})
	}
}

func deleteDevice(db *gorm.DB) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		id := chi.URLParam(r, "id")
		if err := db.Delete(&models.Device{}, "id = ?", id).Error; err != nil {
			writeJSON(w, http.StatusInternalServerError, map[string]string{"error": "failed to delete device"})
			return
		}
		writeJSON(w, http.StatusOK, map[string]string{"message": "device deleted"})
	}
}

func createAttestation(db *gorm.DB) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req dto.SubmitAttestationRequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			writeJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid request body"})
			return
		}

		tenantIDStr, _ := r.Context().Value(tenantIDKey).(string)
		tid, _ := uuid.Parse(tenantIDStr)
		did, _ := uuid.Parse(req.DeviceID)

		record := models.AttestationRecord{
			DeviceID: did,
			TenantID: tid,
			Status:   "pending",
		}
		if err := db.Create(&record).Error; err != nil {
			writeJSON(w, http.StatusInternalServerError, map[string]string{"error": "failed to create attestation"})
			return
		}
		writeJSON(w, http.StatusCreated, record)
	}
}

func getAttestation(db *gorm.DB) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		id := chi.URLParam(r, "id")
		var record models.AttestationRecord
		if err := db.First(&record, "id = ?", id).Error; err != nil {
			writeJSON(w, http.StatusNotFound, map[string]string{"error": "attestation not found"})
			return
		}
		writeJSON(w, http.StatusOK, record)
	}
}

func generateProof(db *gorm.DB) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req dto.GenerateProofRequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			writeJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid request body"})
			return
		}

		tenantIDStr, _ := r.Context().Value(tenantIDKey).(string)
		tid, _ := uuid.Parse(tenantIDStr)
		did, _ := uuid.Parse(req.DeviceID)

		record := models.ProofRecord{
			TenantID:    tid,
			DeviceID:    did,
			CircuitType: req.CircuitType,
			Status:      "generated",
		}
		if err := db.Create(&record).Error; err != nil {
			writeJSON(w, http.StatusInternalServerError, map[string]string{"error": "failed to generate proof"})
			return
		}
		writeJSON(w, http.StatusCreated, record)
	}
}

func verifyProof(db *gorm.DB) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req dto.VerifyProofRequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			writeJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid request body"})
			return
		}

		var record models.ProofRecord
		if err := db.First(&record, "id = ?", req.ProofID).Error; err != nil {
			writeJSON(w, http.StatusNotFound, map[string]string{"error": "proof not found"})
			return
		}

		writeJSON(w, http.StatusOK, map[string]interface{}{
			"proof_id": record.ID.String(),
			"is_valid": true,
			"status":   record.Status,
		})
	}
}

func getProof(db *gorm.DB) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		id := chi.URLParam(r, "id")
		var record models.ProofRecord
		if err := db.First(&record, "id = ?", id).Error; err != nil {
			writeJSON(w, http.StatusNotFound, map[string]string{"error": "proof not found"})
			return
		}
		writeJSON(w, http.StatusOK, record)
	}
}

func complianceCheck() http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req dto.ComplianceCheckRequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			writeJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid request body"})
			return
		}

		writeJSON(w, http.StatusOK, map[string]interface{}{
			"device_id":    req.DeviceID,
			"check_type":   req.CheckType,
			"is_compliant": true,
			"score":        1.0,
			"details":      map[string]string{"status": "compliant"},
		})
	}
}

func enrollDevice(db *gorm.DB) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req dto.EnrollRequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			writeJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid request body"})
			return
		}

		tenantIDStr, _ := r.Context().Value(tenantIDKey).(string)
		tid, _ := uuid.Parse(tenantIDStr)

		device := models.Device{
			TenantID:     tid,
			SerialNumber: req.SerialNumber,
			Manufacturer: req.Manufacturer,
			Model:        req.Model,
			DeviceType:   req.DeviceType,
			PublicKey:    req.PublicKey,
			Status:       "provisioned",
		}
		if err := db.Create(&device).Error; err != nil {
			writeJSON(w, http.StatusInternalServerError, map[string]string{"error": "failed to enroll device"})
			return
		}
		writeJSON(w, http.StatusCreated, device)
	}
}

func listAnomalies() http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		writeJSON(w, http.StatusOK, map[string]interface{}{
			"anomalies": []interface{}{},
			"total":     0,
		})
	}
}
