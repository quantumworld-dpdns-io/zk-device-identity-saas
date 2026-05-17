FROM python:3.12-slim AS builder
RUN apt-get update && apt-get install -y --no-install-recommends gcc && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY mcp-server/requirements.txt .
RUN pip install --user --no-cache-dir -r requirements.txt

FROM python:3.12-slim
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates && rm -rf /var/lib/apt/lists/*
RUN groupadd -r appgroup && useradd -r -g appgroup appuser
WORKDIR /app
COPY --from=builder /root/.local /root/.local
ENV PATH=/root/.local/bin:$PATH
COPY mcp-server/ .
RUN chown -R appuser:appgroup /app
EXPOSE 3003
USER appuser
HEALTHCHECK --interval=10s --timeout=3s --retries=3 \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:3003/health')" || exit 1
CMD ["uvicorn", "src.main:app", "--host", "0.0.0.0", "--port", "3003"]
