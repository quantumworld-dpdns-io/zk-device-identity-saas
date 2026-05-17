from pydantic_settings import BaseSettings
from typing import Optional


class Settings(BaseSettings):
    app_name: str = "ZK Identity Agent Service"
    app_version: str = "0.1.0"
    debug: bool = False

    backend_base_url: str = "http://localhost:8080"
    backend_api_key: Optional[str] = None
    backend_timeout_seconds: int = 30

    redis_url: str = "redis://localhost:6379/0"
    redis_workflow_ttl: int = 86400

    log_level: str = "INFO"

    model_config = {"env_prefix": "AGENT_", "env_file": ".env", "extra": "ignore"}


settings = Settings()
