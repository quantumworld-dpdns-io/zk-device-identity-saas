mod config;
mod proxy;
mod tls;
mod auth;
mod rate_limit;

use axum::{
    Router,
    routing::{get, post, any},
    middleware,
};
use std::net::SocketAddr;
use tracing_subscriber::EnvFilter;

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    dotenvy::dotenv().ok();
    tracing_subscriber::fmt()
        .with_env_filter(EnvFilter::from_default_env())
        .init();

    let cfg = config::Config::from_env()?;
    let redis_client = redis::Client::open(cfg.redis_url.as_str())?;

    let app = Router::new()
        .route("/health", get(health_handler))
        .route("/api/v1/auth/login", post(proxy::proxy_handler))
        .route("/api/v1/auth/register", post(proxy::proxy_handler))
        .route("/api/v1/*path", any(proxy::proxy_handler))
        .layer(middleware::from_fn_with_state(
            redis_client.clone(),
            rate_limit::rate_limit_middleware,
        ))
        .layer(middleware::from_fn_with_state(
            cfg.jwt_secret.clone(),
            auth::auth_middleware,
        ))
        .layer(
            tower_http::cors::CorsLayer::permissive()
                .allow_methods(tower_http::cors::Any)
                .allow_origin(tower_http::cors::Any),
        )
        .layer(tower_http::trace::TraceLayer::new_for_http())
        .with_state(cfg.clone());

    let addr = SocketAddr::from(([0, 0, 0, 0], cfg.proxy_port));
    tracing::info!("Starting proxy on {}", addr);

    if cfg.pqc_enabled {
        let tls_config = tls::build_tls_config(&cfg)?;
        let listener = tokio::net::TcpListener::bind(addr).await?;
        axum::serve(
            listener,
            app.into_make_service_with_connect_info::<SocketAddr>(),
        )
        .with_graceful_shutdown(shutdown_signal())
        .await?;
    } else {
        let listener = tokio::net::TcpListener::bind(addr).await?;
        axum::serve(listener, app.into_make_service())
            .with_graceful_shutdown(shutdown_signal())
            .await?;
    }

    Ok(())
}

async fn health_handler() -> axum::Json<serde_json::Value> {
    axum::Json(serde_json::json!({
        "status": "ok",
        "service": "zk-identity-proxy",
        "version": "0.1.0"
    }))
}

async fn shutdown_signal() {
    tokio::signal::ctrl_c()
        .await
        .expect("failed to install CTRL+C signal handler");
    tracing::info!("shutdown signal received");
}
