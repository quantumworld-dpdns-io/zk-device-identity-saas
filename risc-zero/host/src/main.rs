mod methods;
mod prover;
mod types;

use std::sync::Arc;

use axum::{
    extract::State,
    http::StatusCode,
    routing::{get, post},
    Json, Router,
};
use serde_json::{json, Value};
use tracing_subscriber::EnvFilter;

use crate::prover::{ProverConfig, generate_proof, verify_receipt};
use crate::types::{ComplianceInput, GuestRequest};

/// Application-wide shared state.
#[derive(Clone)]
struct AppState {
    prover: Arc<ProverConfig>,
}

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    tracing_subscriber::fmt()
        .with_env_filter(
            EnvFilter::try_from_default_env()
                .or_else(|_| EnvFilter::try_new("info"))
                .unwrap(),
        )
        .init();

    let prover = ProverConfig::new(methods::ZK_IDENTITY_GUEST_ELF)?;
    tracing::info!(
        "Image ID: {:02x?}",
        prover.image_id.iter().map(|w| w.to_be_bytes()).flatten().collect::<Vec<_>>()
    );

    let state = AppState {
        prover: Arc::new(prover),
    };

    let app = Router::new()
        .route("/health", get(health_handler))
        .route("/prove", post(prove_handler))
        .route("/verify", post(verify_handler))
        .with_state(state);

    let addr = "0.0.0.0:3000";
    tracing::info!("starting RISC Zero prover HTTP server on {addr}");

    let listener = tokio::net::TcpListener::bind(addr).await?;
    axum::serve(listener, app).await?;

    Ok(())
}

/// GET /health — readiness probe.
async fn health_handler() -> Json<Value> {
    Json(json!({"status": "ok"}))
}

/// POST /prove — executes the compliance-check guest program inside the
/// RISC Zero zkVM and returns a cryptographic receipt.
///
/// The receipt can be stored or transmitted to a verifier. It contains
/// the public journal output and a zero-knowledge proof seal.
async fn prove_handler(
    State(state): State<AppState>,
    Json(input): Json<ComplianceInput>,
) -> Result<Json<Value>, (StatusCode, String)> {
    let request = GuestRequest::ComplianceCheck(input);

    let receipt = generate_proof(&state.prover, &request)
        .map_err(|e| {
            tracing::error!("proof generation failed: {e}");
            (
                StatusCode::INTERNAL_SERVER_ERROR,
                format!("proof generation failed: {e}"),
            )
        })?;

    let receipt_value = serde_json::to_value(&receipt).map_err(|e| {
        tracing::error!("receipt serialization failed: {e}");
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            format!("receipt serialization failed: {e}"),
        )
    })?;

    Ok(Json(json!({
        "receipt": receipt_value,
        "image_id": state.prover.image_id,
    })))
}

/// POST /verify — verifies a receipt against the known Image ID and
/// returns the decoded journal output.
///
/// The client sends a receipt previously obtained from `/prove`.
/// The server checks the cryptographic integrity of the proof and
/// reveals the public outputs.
async fn verify_handler(
    State(state): State<AppState>,
    Json(body): Json<Value>,
) -> Result<Json<Value>, (StatusCode, String)> {
    let receipt_value = body.get("receipt").ok_or_else(|| {
        (
            StatusCode::BAD_REQUEST,
            "missing 'receipt' field in request body".to_string(),
        )
    })?;

    let receipt: risc0_zkvm::Receipt = serde_json::from_value(receipt_value.clone()).map_err(|e| {
        (
            StatusCode::BAD_REQUEST,
            format!("invalid receipt JSON: {e}"),
        )
    })?;

    match verify_receipt(&receipt, &state.prover.image_id) {
        Ok(output) => {
            let output_value = serde_json::to_value(&output).map_err(|e| {
                (
                    StatusCode::INTERNAL_SERVER_ERROR,
                    format!("output serialization failed: {e}"),
                )
            })?;

            Ok(Json(json!({
                "verified": true,
                "output": output_value,
            })))
        }
        Err(e) => {
            tracing::warn!("receipt verification failed: {e}");
            Ok(Json(json!({
                "verified": false,
                "error": e.to_string(),
            })))
        }
    }
}
