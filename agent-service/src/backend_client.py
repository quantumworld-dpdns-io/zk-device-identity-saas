import httpx
from typing import Any, Optional
from src.config import settings


class BackendClient:
    def __init__(self) -> None:
        self.base_url = settings.backend_base_url.rstrip("/")
        headers: dict[str, str] = {
            "Content-Type": "application/json",
            "User-Agent": "zk-identity-agent-service/0.1.0",
        }
        if settings.backend_api_key:
            headers["X-API-Key"] = settings.backend_api_key
        self._client = httpx.AsyncClient(
            base_url=self.base_url,
            headers=headers,
            timeout=settings.backend_timeout_seconds,
        )

    async def _request(
        self,
        method: str,
        path: str,
        json_body: Optional[dict[str, Any]] = None,
    ) -> dict[str, Any]:
        resp = await self._client.request(method, path, json=json_body)
        resp.raise_for_status()
        return resp.json()

    async def verify_device_certificate(self, cert_chain: dict[str, Any]) -> dict[str, Any]:
        return await self._request("POST", "/api/v1/devices/verify-certificate", json_body=cert_chain)

    async def provision_device(self, device_data: dict[str, Any]) -> dict[str, Any]:
        return await self._request("POST", "/api/v1/devices/provision", json_body=device_data)

    async def check_compliance(self, device_id: str) -> dict[str, Any]:
        return await self._request("GET", f"/api/v1/compliance/{device_id}")

    async def generate_witness(self, circuit_type: str, public_inputs: dict[str, Any], private_inputs: dict[str, Any]) -> dict[str, Any]:
        return await self._request(
            "POST",
            "/api/v1/zk/witness",
            json_body={"circuit_type": circuit_type, "public_inputs": public_inputs, "private_inputs": private_inputs},
        )

    async def generate_proof(self, witness_id: str) -> dict[str, Any]:
        return await self._request("POST", "/api/v1/zk/proof", json_body={"witness_id": witness_id})

    async def verify_proof(self, proof_data: dict[str, Any]) -> dict[str, Any]:
        return await self._request("POST", "/api/v1/zk/verify", json_body=proof_data)

    async def store_proof_result(self, request_id: str, proof_data: dict[str, Any], verification_result: dict[str, Any]) -> dict[str, Any]:
        return await self._request(
            "POST",
            "/api/v1/zk/results",
            json_body={"request_id": request_id, "proof_data": proof_data, "verification_result": verification_result},
        )

    async def get_device(self, device_id: str) -> dict[str, Any]:
        return await self._request("GET", f"/api/v1/devices/{device_id}")

    async def chat_agents(self, message: str, context: Optional[dict[str, Any]] = None) -> dict[str, Any]:
        return await self._request("POST", "/api/v1/agents/chat", json_body={"message": message, "context": context or {}})

    async def close(self) -> None:
        await self._client.aclose()


backend = BackendClient()
