# Agent Operations Manual

## Project: zk-device-identity-saas

Polyglot ZK Device Identity SaaS for IoT/Matter manufacturers.

### Current Status (Monitor Agent Report)
- **Last Checked:** Sun May 17 2026
- **Latest Commit:** `1c587f0` — chore: initial scaffold for zk-device-identity-saas
- **Total Commits:** 1 (Initial scaffold)
- **README.md:** Updated with comprehensive documentation
- **AGENTS.md:** Updated with Monitor Agent section

### Monitor Agent
- Checks git log every 30 seconds for new commits
- Updates README.md to reflect current project progress
- Keeps AGENTS.md synchronized with new system configurations
- Next check: every 30s from last check

### Architecture

```
User/Frontend → Rust Axum Proxy → Go Chi Backend → Services
                                         ├── NoirJS (ZK proofs)
                                         ├── RISC Zero (compliance)
                                         ├── Julia (analysis)
                                         ├── PostgreSQL (DB)
                                         ├── Redis (cache)
                                         ├── Qdrant (vector DB)
                                         ├── MCP Server (agent protocol)
                                         └── Agent Service (LangGraph/CrewAI)
```

### Tech Stack
- **Proxy:** Rust (Axum, rustls, PQC hybrid TLS)
- **Backend:** Go (Chi, GORM, go-redis, qdrant-go, CIRCL PQC)
- **ZK:** Noir (DAC/PAI/PAA circuits), RISC Zero (compliance proofs)
- **Analysis:** Julia (DataFrames.jl, anomaly detection)
- **Frontend:** Next.js 14+ (App Router, shadcn/ui)
- **Agent:** Python (FastAPI, LangGraph, CrewAI)
- **Protocol:** MCP (Model Context Protocol)
- **Security:** Cilium Tetragon (eBPF runtime security)
- **DB:** PostgreSQL, Redis, Qdrant

### Project Structure
```
zk-device-identity-saas/
├── cmd/              # Go entrypoints
├── internal/         # Go packages (config, dto, vto, models, services, api)
├── rust-proxy/       # Rust Axum proxy gateway
├── circuits/         # Noir ZK circuits
├── risc-zero/        # RISC Zero compliance proofs
├── julia-analysis/   # Julia analysis engine
├── frontend/         # Next.js dashboard
├── tests/            # Robot Framework + unit tests
├── deploy/           # Docker Compose + K8s (Helm/Kustomize)
├── agent-service/    # LangGraph/CrewAI microservice
├── mcp-server/       # MCP protocol server
└── configs/          # Prometheus, Tetragon, Grafana configs
```

### Agent Workflow Commands

```bash
# Build & Test
make build-go        # Build Go backend
make build-rust      # Build Rust proxy
make test-all        # Run all tests
make test-robot      # Run Robot Framework tests

# Docker
make docker-up       # Start all services
make docker-down     # Stop all services

# Development
make seed            # Seed database
make swagger         # Generate Swagger docs
```

### Commit Rules
1. Commit every 1 minute during active development
2. Use conventional commits: feat, fix, chore, docs, test, refactor
3. Push to `dev` branch
4. Verify no secrets in commits (gitleaks check)
