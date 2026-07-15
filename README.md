# zk-Device-Identity-SaaS

> Zero-Knowledge Device Identity SaaS for IoT/Matter manufacturers — manages DAC/PAI/PAA certificate workflows, secure-element provisioning, and ZK compliance proofs.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![CI](https://github.com/quantumworld-dpdns-io/zk-device-identity-saas/actions/workflows/ci.yml/badge.svg)](https://github.com/quantumworld-dpdns-io/zk-device-identity-saas/actions/workflows/ci.yml)

---

## Architecture

```
                         ┌─────────────────────┐
                         │   Next.js Frontend   │
                         │ (Dashboard + Admin)  │
                         └─────────┬───────────┘
                                   │ HTTPS (PQC hybrid TLS)
                                   ▼
                      ┌─────────────────────┐
                      │   Rust Axum Proxy   │
                      │ (TLS termination,   │
                      │  rate limiting,     │
                      │  auth forwarding)   │
                      └─────────┬───────────┘
                                │ gRPC / HTTP
                                ▼
                      ┌─────────────────────┐
                      │   Go Chi Backend    │
                      │ (API server,        │
                      │  business logic,    │
                      │  orchestration)     │
                      └──┬────┬────┬────┬──┘
                         │    │    │    │
              ┌──────────┘    │    │    └──────────┐
              ▼               ▼    ▼                ▼
     ┌──────────────┐  ┌─────────┐ ┌─────────┐ ┌──────────┐
     │  Noir ZK     │  │ RISC    │ │ Julia   │ │ Agent    │
     │  Circuits    │  │ Zero    │ │ Analysis│ │ Service  │
     │ (DAC/PAI/PAA)│  │Compliance│ │Engine   │ │(LangGraph│
     └──────────────┘  └─────────┘ └─────────┘ │ /CrewAI) │
                                                └──────────┘
     ┌──────────┐  ┌─────────┐  ┌──────────┐  ┌──────────┐
     │PostgreSQL│  │  Redis  │  │  Qdrant  │  │   MCP    │
     │ (Primary │  │ (Cache) │  │ (Vector  │  │  Server  │
     │   DB)    │  │         │  │   DB)    │  │(Protocol)│
     └──────────┘  └─────────┘  └──────────┘  └──────────┘
```

## Tech Stack

| Layer | Technology | Purpose |
|-------|-----------|---------|
| **Proxy** | Rust (Axum, rustls, PQC hybrid TLS) | TLS termination, rate limiting, auth forwarding |
| **Backend** | Go (Chi, GORM, go-redis, qdrant-go, CIRCL PQC) | API server, business logic, orchestration |
| **ZK Circuits** | Noir (DAC/PAI/PAA) | Zero-knowledge proof generation |
| **Compliance** | RISC Zero | Compliance proof verification |
| **Analysis** | Julia (DataFrames.jl) | Anomaly detection, telemetry analysis |
| **Frontend** | Next.js 14+ (App Router, shadcn/ui) | Dashboard, admin panel |
| **Agent** | Python (FastAPI, LangGraph, CrewAI) | Automated workflows, AI agent orchestration |
| **Protocol** | MCP (Model Context Protocol) | Agent communication protocol |
| **Security** | Cilium Tetragon (eBPF) | Runtime security monitoring |
| **Database** | PostgreSQL | Primary data store |
| **Cache** | Redis | Session cache, rate limiting |
| **Vector DB** | Qdrant | Device fingerprint vectors |

## Quick Start

### Prerequisites

- Go 1.22+
- Rust 1.78+
- Node.js 20+
- Julia 1.10+
- Docker & Docker Compose
- Noir (nargo) 0.30+

### Setup

```bash
# Clone the repository
git clone https://github.com/quantumworld-dpdns-io/zk-device-identity-saas.git
cd zk-device-identity-saas

# Copy environment config
cp .env.example .env

# Start all services with Docker
make docker-up

# Seed the database
make seed
```

### Development

```bash
# Start dev environment (with hot-reload overrides)
make dev

# Build individual components
make build-go        # Go backend
make build-rust      # Rust proxy
make build-frontend  # Next.js frontend
make build-julia     # Julia analysis engine

# Run tests
make test-all        # All tests
make test-go         # Go backend tests
make test-rust       # Rust proxy tests
make test-noir       # Noir circuit tests
make test-robot      # Robot Framework integration tests
```

## Project Structure

```
zk-device-identity-saas/
├── cmd/                   # Go entrypoints
│   ├── server/            # API server main
│   └── migrate/           # Migration + seeder CLI
├── internal/              # Go packages
│   ├── api/               # HTTP handlers, middleware, router
│   ├── audit/             # Audit logging
│   ├── config/            # Configuration loading
│   ├── crypto/            # PQC cryptographic operations
│   ├── db/                # Database migrations & connection
│   ├── docs/              # Swagger documentation
│   ├── dto/               # Data transfer objects
│   ├── models/            # GORM models
│   ├── repository/        # Data access layer
│   ├── seeder/            # Database seeders
│   ├── services/          # Business logic layer
│   ├── vector/            # Qdrant vector DB integration
│   └── vto/               # View transfer objects
├── rust-proxy/            # Rust Axum proxy gateway
├── circuits/              # Noir ZK circuits (DAC/PAI/PAA)
├── risc-zero/             # RISC Zero compliance proofs
├── julia-analysis/        # Julia analysis engine
├── frontend/              # Next.js dashboard
│   ├── src/
│   │   ├── app/           # App Router pages
│   │   ├── components/    # shadcn/ui components
│   │   ├── lib/           # Utilities, API client
│   │   └── types/         # TypeScript types
│   ├── public/            # Static assets
│   └── package.json
├── agent-service/         # LangGraph/CrewAI microservice
├── mcp-server/            # MCP protocol server
├── tests/                 # Test suites
│   ├── go-unit/           # Go unit tests
│   ├── rust-unit/         # Rust unit tests
│   ├── robot-framework/   # Robot Framework integration tests
│   ├── noir-tests/        # Noir circuit tests
│   └── risc-zero-tests/   # RISC Zero tests
├── deploy/                # Deployment configurations
│   ├── docker-compose/    # Docker Compose files
│   ├── k8s/               # Kubernetes (Helm + Kustomize)
│   │   ├── base/          # Kustomize base
│   │   ├── helm/          # Helm charts
│   │   └── overlays/      # Environment overlays
│   └── scripts/           # Deployment scripts
├── configs/               # Service configurations
│   ├── grafana-dashboards/# Grafana dashboards
│   └── tetragon/          # Cilium Tetragon policies
├── docs/                  # Documentation
│   └── CONTRIBUTING.md
├── images/                # Architecture diagrams
├── scripts/               # Utility scripts
├── Makefile               # Build orchestration
├── .env.example           # Environment template
├── .github/workflows/     # CI/CD pipelines
└── .gitleaks.toml         # Secrets scanning config
```

## API Documentation

API documentation is auto-generated using Swagger/OpenAPI. Generate and view it locally:

```bash
make swagger
```

The generated docs are available at `/swagger/index.html` when the server is running.

### Core API Endpoints

| Method | Path | Description |
|--------|------|-------------|
| `POST` | `/api/v1/devices/register` | Register a new device identity |
| `GET` | `/api/v1/devices/{id}` | Get device identity details |
| `POST` | `/api/v1/devices/{id}/prove` | Generate ZK proof for device |
| `GET` | `/api/v1/devices/{id}/compliance` | Check device compliance status |
| `POST` | `/api/v1/certificates/dac` | Issue DAC certificate |
| `POST` | `/api/v1/certificates/pai` | Issue PAI certificate |
| `POST` | `/api/v1/certificates/paa` | Issue PAA certificate |
| `GET` | `/api/v1/analytics/anomalies` | Get anomaly detection results |
| `GET` | `/health` | Health check |

## Testing

```bash
# Run all tests
make test-all

# Component-specific tests
make test-go              # Go backend (race detection, coverage)
make test-rust            # Rust proxy
make test-noir            # Noir ZK circuits
make test-frontend        # Frontend unit tests

# Robot Framework integration tests
make test-robot           # All integration tests
make test-robot-api       # API integration tests
make test-robot-security  # Security integration tests
```

## Deployment

### Docker Compose

```bash
# Build and start all services
make docker-up

# View logs
make docker-logs

# Stop all services
make docker-down
```

### Kubernetes

Kubernetes manifests are available under `deploy/k8s/` with Helm charts and Kustomize overlays for staging and production environments.

```bash
# Deploy with Helm
helm install zk-identity ./deploy/k8s/helm

# Deploy with Kustomize
kubectl apply -k ./deploy/k8s/overlays/production
```

## Environment Variables

See [.env.example](.env.example) for a full list of configuration options. Key variables:

| Variable | Description | Default |
|----------|-------------|---------|
| `GO_PORT` | Backend API port | `8080` |
| `POSTGRES_*` | PostgreSQL connection | `localhost:5432` |
| `REDIS_*` | Redis connection | `localhost:6379` |
| `QDRANT_*` | Qdrant vector DB connection | `localhost:6334` |
| `RUST_PROXY_PORT` | Proxy TLS port | `443` |
| `JWT_SECRET` | JWT signing secret | *(required)* |
| `PQC_ENABLED` | Enable PQC cryptography | `true` |
| `TETRAGON_ENABLED` | Enable eBPF runtime security | `false` |

## Contributing

Please read [CONTRIBUTING.md](docs/CONTRIBUTING.md) before opening a pull request.

This project is part of the [quantumworld-dpdns-io](https://github.com/quantumworld-dpdns-io) Wild SaaS & Tech Development initiative.

## License

[MIT](LICENSE) © 2026 quantumworld-dpdns-io


---
Julia language: [#JuliaLang](https://julialang.org/) | [JuliaLang GitHub](https://github.com/JuliaLang/julia)
