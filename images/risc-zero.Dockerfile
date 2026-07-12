FROM rust:1.97 AS chef
RUN cargo install cargo-chef --version 0.1.68
WORKDIR /app

FROM chef AS planner
COPY risc-zero/ .
RUN cargo chef prepare --recipe-path recipe.json

FROM chef AS builder
COPY --from=planner /app/recipe.json recipe.json
RUN cargo chef cook --release --recipe-path recipe.json
COPY risc-zero/ .
RUN cargo build --release -p zk-identity-host

FROM ubuntu:22.04
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates libssl3 tzdata \
    && rm -rf /var/lib/apt/lists/*
RUN groupadd -r appgroup && useradd -r -g appgroup appuser
COPY --from=builder /app/target/release/zk-identity-host /server
COPY --from=builder /app/target/release/build /build-support
EXPOSE 3002
USER appuser
HEALTHCHECK --interval=10s --timeout=3s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:3002/health || exit 1
CMD ["/server"]
