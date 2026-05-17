use anyhow::Context;

#[derive(Clone, Debug)]
pub struct Config {
    pub proxy_port: u16,
    pub proxy_tls_cert_path: Option<String>,
    pub proxy_tls_key_path: Option<String>,
    pub go_backend_url: String,
    pub jwt_secret: String,
    pub redis_url: String,
    pub rate_limit_rpm: u64,
    pub log_level: String,
    pub pqc_enabled: bool,
}

impl Config {
    pub fn from_env() -> anyhow::Result<Self> {
        let proxy_port = std::env::var("PROXY_PORT")
            .ok()
            .and_then(|v| v.parse().ok())
            .unwrap_or(443u16);

        let proxy_tls_cert_path = std::env::var("PROXY_TLS_CERT_PATH").ok();
        let proxy_tls_key_path = std::env::var("PROXY_TLS_KEY_PATH").ok();

        let go_backend_url = std::env::var("GO_BACKEND_URL")
            .unwrap_or_else(|_| "http://localhost:8080".to_string());

        let jwt_secret = std::env::var("JWT_SECRET")
            .context("JWT_SECRET must be set")?;

        let redis_url = std::env::var("REDIS_URL")
            .unwrap_or_else(|_| "redis://localhost:6379".to_string());

        let rate_limit_rpm = std::env::var("RATE_LIMIT_RPM")
            .ok()
            .and_then(|v| v.parse().ok())
            .unwrap_or(1000u64);

        let log_level = std::env::var("LOG_LEVEL")
            .unwrap_or_else(|_| "info".to_string());

        let pqc_enabled = std::env::var("PQC_ENABLED")
            .ok()
            .map(|v| v == "true" || v == "1")
            .unwrap_or(true);

        Ok(Self {
            proxy_port,
            proxy_tls_cert_path,
            proxy_tls_key_path,
            go_backend_url,
            jwt_secret,
            redis_url,
            rate_limit_rpm,
            log_level,
            pqc_enabled,
        })
    }
}
