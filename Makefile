.PHONY: all build-go build-rust build-frontend build-julia test-go test-rust \
        test-noir test-robot lint-go lint-rust lint-frontend \
        docker-up docker-down docker-build \
        seed migrate swagger dev clean

# ─── Go Backend ───
build-go:
	go build -o dist/go-server ./cmd/server

test-go:
	go test ./... -race -cover -count=1

lint-go:
	golangci-lint run ./...

seed:
	go run cmd/migrate/main.go seed

migrate:
	go run cmd/migrate/main.go migrate

swagger:
	swag init -g internal/docs/swagger.go -o internal/docs

# ─── Rust Proxy ───
build-rust:
	cargo build --release --manifest-path rust-proxy/Cargo.toml

test-rust:
	cargo test --manifest-path rust-proxy/Cargo.toml

lint-rust:
	cargo clippy --manifest-path rust-proxy/Cargo.toml

# ─── Frontend ───
build-frontend:
	cd frontend && npm run build

test-frontend:
	cd frontend && npm test

lint-frontend:
	cd frontend && npm run lint

dev-frontend:
	cd frontend && npm run dev

# ─── Noir Circuits ───
test-noir:
	cd circuits && nargo test

check-noir:
	cd circuits && nargo check

# ─── Robot Framework Tests ───
test-robot:
	cd tests/robot-framework && robot --outputdir output suites/

test-robot-security:
	cd tests/robot-framework && robot --outputdir output suites/security/

test-robot-api:
	cd tests/robot-framework && robot --outputdir output suites/api/

# ─── Julia ───
build-julia:
	cd julia-analysis && julia -e 'using Pkg; Pkg.precompile()'

# ─── Docker ───
docker-build:
	docker compose -f deploy/docker-compose/docker-compose.yml build

docker-up:
	docker compose -f deploy/docker-compose/docker-compose.yml up -d

docker-down:
	docker compose -f deploy/docker-compose/docker-compose.yml down

docker-logs:
	docker compose -f deploy/docker-compose/docker-compose.yml logs -f

# ─── Dev ───
dev:
	docker compose -f deploy/docker-compose/docker-compose.yml \
		-f deploy/docker-compose/docker-compose.override.yml up -d

setup:
	cp .env.example .env
	go mod init github.com/quantumworld-dpdns-io/zk-device-identity-saas/cmd/server
	go mod tidy

clean:
	rm -rf dist/ target/ .next/ out/
	rm -f circuits/target/*
	find . -name '*.pyc' -delete
	find . -name '__pycache__' -delete

# ─── All ───
all: build-go build-rust build-frontend

test-all: test-go test-rust test-noir test-frontend
