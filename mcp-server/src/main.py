from fastapi import FastAPI
from pydantic import BaseModel

app = FastAPI(title="MCP Server", version="0.1.0")


class HealthResponse(BaseModel):
    status: str
    service: str
    version: str


@app.get("/health", response_model=HealthResponse)
async def health():
    return HealthResponse(status="ok", service="mcp-server", version="0.1.0")
