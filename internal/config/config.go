package config

import (
	"os"
	"strconv"
)

type Config struct {
	GoEnv     string
	GoPort    string
	GoLogLevel string

	PostgresHost     string
	PostgresPort     string
	PostgresUser     string
	PostgresPassword string
	PostgresDB       string
	PostgresSSLMode  string

	RedisHost     string
	RedisPort     string
	RedisPassword string

	QdrantHost       string
	QdrantPort       string
	QdrantAPIKey     string
	QdrantCollection string

	JWTSecret      string
	JWTIssuer      string
	JWTExpiryHours int

	APIKeyEncryptionKey string

	NoirProverURL    string
	NoirProverAPIKey string

	Risc0ProverURL    string
	Risc0ProverAPIKey string

	JuliaAnalysisURL    string
	JuliaAnalysisAPIKey string

	AgentServiceURL    string
	AgentServiceAPIKey string

	MCPServerPort string

	PQCEnabled    bool
	PQCHybridTLS  bool

	TetragonEnabled bool
}

func Load() *Config {
	return &Config{
		GoEnv:      getEnv("GO_ENV", "development"),
		GoPort:     getEnv("GO_PORT", "8080"),
		GoLogLevel: getEnv("GO_LOG_LEVEL", "debug"),

		PostgresHost:     getEnv("POSTGRES_HOST", "localhost"),
		PostgresPort:     getEnv("POSTGRES_PORT", "5432"),
		PostgresUser:     getEnv("POSTGRES_USER", "zkidentity"),
		PostgresPassword: getEnv("POSTGRES_PASSWORD", "changeme"),
		PostgresDB:       getEnv("POSTGRES_DB", "zk_device_identity"),
		PostgresSSLMode:  getEnv("POSTGRES_SSLMODE", "disable"),

		RedisHost:     getEnv("REDIS_HOST", "localhost"),
		RedisPort:     getEnv("REDIS_PORT", "6379"),
		RedisPassword: getEnv("REDIS_PASSWORD", ""),

		QdrantHost:       getEnv("QDRANT_HOST", "localhost"),
		QdrantPort:       getEnv("QDRANT_PORT", "6334"),
		QdrantAPIKey:     getEnv("QDRANT_API_KEY", ""),
		QdrantCollection: getEnv("QDRANT_COLLECTION", "device_fingerprints"),

		JWTSecret:      getEnv("JWT_SECRET", "change-me-in-production"),
		JWTIssuer:      getEnv("JWT_ISSUER", "zk-device-identity-saas"),
		JWTExpiryHours: getEnvInt("JWT_EXPIRY_HOURS", 24),

		APIKeyEncryptionKey: getEnv("API_KEY_ENCRYPTION_KEY", ""),

		NoirProverURL:    getEnv("NOIR_PROVER_URL", "http://localhost:3001"),
		NoirProverAPIKey: getEnv("NOIR_PROVER_API_KEY", ""),

		Risc0ProverURL:    getEnv("RISC0_PROVER_URL", "http://localhost:3002"),
		Risc0ProverAPIKey: getEnv("RISC0_PROVER_API_KEY", ""),

		JuliaAnalysisURL:    getEnv("JULIA_ANALYSIS_URL", "http://localhost:8090"),
		JuliaAnalysisAPIKey: getEnv("JULIA_ANALYSIS_API_KEY", ""),

		AgentServiceURL:    getEnv("AGENT_SERVICE_URL", "http://localhost:8000"),
		AgentServiceAPIKey: getEnv("AGENT_SERVICE_API_KEY", ""),

		MCPServerPort: getEnv("MCP_SERVER_PORT", "3003"),

		PQCEnabled:   getEnvBool("PQC_ENABLED", true),
		PQCHybridTLS: getEnvBool("PQC_HYBRID_TLS", true),

		TetragonEnabled: getEnvBool("TETRAGON_ENABLED", false),
	}
}

func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}

func getEnvInt(key string, defaultValue int) int {
	if value := os.Getenv(key); value != "" {
		if i, err := strconv.Atoi(value); err == nil {
			return i
		}
	}
	return defaultValue
}

func getEnvBool(key string, defaultValue bool) bool {
	if value := os.Getenv(key); value != "" {
		if b, err := strconv.ParseBool(value); err == nil {
			return b
		}
	}
	return defaultValue
}
