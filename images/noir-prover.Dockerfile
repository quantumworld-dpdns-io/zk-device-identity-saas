FROM node:20-alpine AS builder
WORKDIR /app
RUN npm install -g @noir-lang/noirjs @noir-lang/backend_barretenberg

FROM node:20-alpine
RUN apk add --no-cache ca-certificates tzdata
RUN addgroup -S appgroup && adduser -S appuser -G appgroup
WORKDIR /app
COPY --from=builder /usr/local/lib/node_modules /usr/local/lib/node_modules
COPY --from=builder /usr/local/bin /usr/local/bin
COPY circuits/ ./circuits/
COPY scripts/noir-prover-server.js ./server.js
RUN mkdir -p /app/circuits/target && chown -R appuser:appgroup /app
EXPOSE 3001
USER appuser
HEALTHCHECK --interval=10s --timeout=3s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:3001/health || exit 1
CMD ["node", "server.js"]
