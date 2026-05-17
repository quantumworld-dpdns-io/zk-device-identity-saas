use crate::config::Config;
use anyhow::Context;
use rustls::pki_types::{CertificateDer, PrivateKeyDer};
use std::fs;
use std::sync::Arc;

pub fn build_tls_config(cfg: &Config) -> anyhow::Result<Arc<rustls::ServerConfig>> {
    let cert_path = cfg
        .proxy_tls_cert_path
        .as_deref()
        .context("PROXY_TLS_CERT_PATH is required when PQC is enabled")?;
    let key_path = cfg
        .proxy_tls_key_path
        .as_deref()
        .context("PROXY_TLS_KEY_PATH is required when PQC is enabled")?;

    let cert_pem = fs::read_to_string(cert_path)
        .with_context(|| format!("failed to read TLS cert from {}", cert_path))?;
    let key_pem = fs::read_to_string(key_path)
        .with_context(|| format!("failed to read TLS key from {}", key_path))?;

    let certs: Vec<CertificateDer> = rustls_pemfile::certs(&mut cert_pem.as_bytes())
        .collect::<Result<Vec<_>, _>>()
        .context("failed to parse TLS certificates")?;

    if certs.is_empty() {
        anyhow::bail!("no certificates found in {}", cert_path);
    }

    let key = rustls_pemfile::private_key(&mut key_pem.as_bytes())
        .context("failed to parse TLS private key")?
        .ok_or_else(|| anyhow::anyhow!("no private key found in {}", key_path))?;

    let mut provider = rustls::crypto::aws_lc_rs::default_provider();

    if cfg.pqc_enabled {
        let mut kx_groups: Vec<&'static dyn rustls::crypto::SupportedKxGroup> = Vec::new();
        for group in rustls::crypto::aws_lc_rs::kx_groups::KX_GROUPS.iter() {
            let name = group.name();
            if name == "x25519_kyber768"
                || name == "x25519"
                || name == "secp384r1"
                || name == "secp256r1"
            {
                kx_groups.push(*group);
            }
        }
        if !kx_groups.is_empty() {
            provider.kx_groups = kx_groups;
        }
    }

    let config = rustls::ServerConfig::builder_with_provider(Arc::new(provider))
        .with_protocol_versions(&[&rustls::version::TLS13])
        .context("failed to set TLS protocol versions")?
        .with_no_client_auth()
        .with_single_cert(certs, key)
        .context("failed to configure TLS certificate")?;

    Ok(Arc::new(config))
}
