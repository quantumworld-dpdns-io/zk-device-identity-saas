use axum::{
    body::Body,
    extract::{Request, State},
    http::{HeaderMap, HeaderValue, StatusCode, Uri},
    response::{IntoResponse, Response},
};
use bytes::Bytes;
use reqwest::Client;
use std::sync::Arc;

fn get_client(state: &crate::config::Config) -> Client {
    Client::builder()
        .no_proxy()
        .build()
        .expect("failed to build reqwest client")
}

fn build_backend_uri(cfg: &crate::config::Config, req: &Request<Body>) -> anyhow::Result<Uri> {
    let path = req.uri().path();
    let query = req.uri().query().map(|q| format!("?{}", q)).unwrap_or_default();
    let backend_url = cfg.go_backend_url.trim_end_matches('/').to_string();
    let full = format!("{}{}{}", backend_url, path, query);
    full.parse::<Uri>().map_err(|e| anyhow::anyhow!("invalid backend uri: {}", e))
}

fn copy_headers(src: &HeaderMap, dst: &mut HeaderMap) {
    for (key, value) in src.iter() {
        let key_str = key.as_str().to_lowercase();
        if key_str == "host" || key_str.starts_with("x-forwarded") {
            continue;
        }
        dst.insert(key.clone(), value.clone());
    }
}

pub async fn proxy_handler(
    State(cfg): State<crate::config::Config>,
    req: Request<Body>,
) -> Result<Response, StatusCode> {
    let client = get_client(&cfg);
    let backend_uri = build_backend_uri(&cfg, &req).map_err(|_| StatusCode::BAD_GATEWAY)?;

    let method = req.method().clone();
    let body_bytes = axum::body::to_bytes(req.into_body(), usize::MAX)
        .await
        .map_err(|_| StatusCode::BAD_REQUEST)?;

    let mut req_builder = match method {
        axum::http::Method::GET => client.get(backend_uri),
        axum::http::Method::POST => client.post(backend_uri),
        axum::http::Method::PUT => client.put(backend_uri),
        axum::http::Method::DELETE => client.delete(backend_uri),
        axum::http::Method::PATCH => client.patch(backend_uri),
        _ => client.request(reqwest::Method::from_bytes(method.as_str().as_bytes()).map_err(|_| StatusCode::BAD_REQUEST)?, backend_uri),
    };

    if !body_bytes.is_empty() {
        req_builder = req_builder.body(body_bytes);
    }

    let resp = req_builder.send().await.map_err(|_| StatusCode::BAD_GATEWAY)?;

    let status = resp.status();
    let resp_headers = resp.headers().clone();
    let resp_body = resp.bytes().await.map_err(|_| StatusCode::BAD_GATEWAY)?;

    let mut response = Response::builder()
        .status(status)
        .body(axum::body::Body::from(resp_body))
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    *response.status_mut() = status;
    for (key, value) in resp_headers.iter() {
        response.headers_mut().insert(key.clone(), value.clone());
    }

    Ok(response)
}
