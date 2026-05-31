FROM rust:1.96-alpine AS chef
RUN apk add --no-cache musl-dev pkgconfig openssl-dev
RUN cargo install cargo-chef --version 0.1.68
WORKDIR /app

FROM chef AS planner
COPY rust-proxy/ .
RUN cargo chef prepare --recipe-path recipe.json

FROM chef AS builder
COPY --from=planner /app/recipe.json recipe.json
RUN cargo chef cook --release --recipe-path recipe.json
COPY rust-proxy/ .
RUN cargo build --release --bin zk-identity-proxy

FROM alpine:3.19
RUN apk add --no-cache ca-certificates tzdata
RUN addgroup -S appgroup && adduser -S appuser -G appgroup
COPY --from=builder /app/target/release/zk-identity-proxy /server
RUN chown appuser:appgroup /server
EXPOSE 443 8081
USER appuser
HEALTHCHECK --interval=10s --timeout=3s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:8081/health || exit 1
CMD ["/server"]
