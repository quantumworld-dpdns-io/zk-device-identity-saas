FROM julia:1.10-alpine
RUN apk add --no-cache ca-certificates tzdata
RUN addgroup -S appgroup && adduser -S appuser -G appgroup
WORKDIR /app
COPY julia-analysis/Project.toml /app/
RUN julia -e 'using Pkg; Pkg.activate("."); Pkg.instantiate()'
COPY julia-analysis/src/ /app/src/
RUN julia -e 'using Pkg; Pkg.activate("."); Pkg.precompile()'
EXPOSE 8090
USER appuser
HEALTHCHECK --interval=10s --timeout=3s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:8090/health || exit 1
CMD ["julia", "-e", "using Analysis; Analysis.run_server()"]
