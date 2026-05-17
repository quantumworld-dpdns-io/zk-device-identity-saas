import logging

from fastapi import FastAPI

from src.config import settings
from src.routes import router

logging.basicConfig(
    level=getattr(logging, settings.log_level.upper(), logging.INFO),
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
)

app = FastAPI(
    title=settings.app_name,
    version=settings.app_version,
    docs_url="/docs",
    redoc_url="/redoc",
)

app.include_router(router, prefix="/api/v1")


@app.on_event("startup")
async def startup() -> None:
    logging.info("Starting %s v%s", settings.app_name, settings.app_version)


@app.on_event("shutdown")
async def shutdown() -> None:
    from src.backend_client import backend
    await backend.close()


@app.get("/health")
async def health() -> dict[str, str]:
    return {"status": "ok", "service": "agent-service"}
