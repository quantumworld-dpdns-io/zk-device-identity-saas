package handlers

import (
	"encoding/json"
	"net/http"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"
	"golang.org/x/crypto/bcrypt"
	"gorm.io/gorm"

	"github.com/quantumworld-dpdns-io/zk-device-identity-saas/internal/config"
	"github.com/quantumworld-dpdns-io/zk-device-identity-saas/internal/models"
)

type AuthHandler struct {
	db  *gorm.DB
	cfg *config.Config
}

func NewAuthHandler(db *gorm.DB, cfg *config.Config) *AuthHandler {
	return &AuthHandler{db: db, cfg: cfg}
}

type loginRequest struct {
	Email    string `json:"email"`
	Password string `json:"password"`
}

type registerRequest struct {
	Email    string `json:"email"`
	Password string `json:"password"`
	TenantID string `json:"tenant_id"`
	Role     string `json:"role"`
}

func (h *AuthHandler) Login(w http.ResponseWriter, r *http.Request) {
	var req loginRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid request body"})
		return
	}

	var user models.User
	if err := h.db.Where("email = ?", req.Email).First(&user).Error; err != nil {
		writeJSON(w, http.StatusUnauthorized, map[string]string{"error": "invalid credentials"})
		return
	}

	if err := bcrypt.CompareHashAndPassword([]byte(user.PasswordHash), []byte(req.Password)); err != nil {
		writeJSON(w, http.StatusUnauthorized, map[string]string{"error": "invalid credentials"})
		return
	}

	expiry := time.Now().Add(time.Duration(h.cfg.JWTExpiryHours) * time.Hour)
	claims := jwt.MapClaims{
		"sub":   user.ID.String(),
		"email": user.Email,
		"role":  user.Role,
		"exp":   expiry.Unix(),
		"iat":   time.Now().Unix(),
		"iss":   h.cfg.JWTIssuer,
	}
	if user.TenantID != nil {
		claims["tenant_id"] = user.TenantID.String()
	}

	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	tokenStr, err := token.SignedString([]byte(h.cfg.JWTSecret))
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, map[string]string{"error": "failed to generate token"})
		return
	}

	writeJSON(w, http.StatusOK, map[string]interface{}{
		"token":      tokenStr,
		"expires_at": expiry.Unix(),
	})
}

func (h *AuthHandler) Register(w http.ResponseWriter, r *http.Request) {
	var req registerRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid request body"})
		return
	}

	hash, err := bcrypt.GenerateFromPassword([]byte(req.Password), bcrypt.DefaultCost)
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, map[string]string{"error": "failed to hash password"})
		return
	}

	var tenantID *uuid.UUID
	if req.TenantID != "" {
		tid, err := uuid.Parse(req.TenantID)
		if err != nil {
			writeJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid tenant id"})
			return
		}
		tenantID = &tid
	}

	role := req.Role
	if role == "" {
		role = "user"
	}

	user := models.User{
		Email:        req.Email,
		PasswordHash: string(hash),
		TenantID:     tenantID,
		Role:         role,
	}

	if err := h.db.Create(&user).Error; err != nil {
		writeJSON(w, http.StatusInternalServerError, map[string]string{"error": "failed to create user"})
		return
	}

	writeJSON(w, http.StatusCreated, map[string]interface{}{
		"id":    user.ID.String(),
		"email": user.Email,
		"role":  user.Role,
	})
}

func writeJSON(w http.ResponseWriter, status int, data interface{}) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(data)
}
