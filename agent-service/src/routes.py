import json
import logging
import uuid
from typing import Any, Optional

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel

from src.backend_client import backend
from src.config import settings
from src.workflows.device_onboarding import DeviceOnboardingCrew
from src.workflows.proof_lifecycle import create_proof_graph, ProofState

logger = logging.getLogger(__name__)
router = APIRouter()

crew_store: dict[str, DeviceOnboardingCrew] = {}


class OnboardDeviceRequest(BaseModel):
    device_id: str
    vendor_id: str = "0000"
    product_id: str = "0000"
    certificate_chain: Optional[dict[str, Any]] = None
    public_key: Optional[str] = None


class OnboardDeviceResponse(BaseModel):
    workflow_id: str
    status: str
    message: str


class WorkflowStatusResponse(BaseModel):
    workflow_id: str
    status: str
    result: Optional[dict[str, Any]] = None
    error: Optional[str] = None


class ProofGenerationRequest(BaseModel):
    circuit_type: str
    public_inputs: dict[str, Any]
    private_inputs: dict[str, Any]


class ProofGenerationResponse(BaseModel):
    workflow_id: str
    status: str
    message: str


class AgentChatRequest(BaseModel):
    message: str
    context: Optional[dict[str, Any]] = None


class AgentChatResponse(BaseModel):
    response: str
    agent: str


class AgentStatusResponse(BaseModel):
    agents: list[dict[str, str]]
    overall: str


@router.post("/workflows/onboard-device", response_model=OnboardDeviceResponse)
async def onboard_device(request: OnboardDeviceRequest) -> OnboardDeviceResponse:
    workflow_id = f"onboard-{request.device_id}-{uuid.uuid4().hex[:8]}"
    device_data = request.model_dump()
    crew = DeviceOnboardingCrew()
    crew_store[workflow_id] = crew

    import asyncio
    asyncio.create_task(_run_onboarding(workflow_id, crew, device_data))

    return OnboardDeviceResponse(
        workflow_id=workflow_id,
        status="started",
        message=f"Device onboarding workflow started for {request.device_id}",
    )


async def _run_onboarding(workflow_id: str, crew: DeviceOnboardingCrew, device_data: dict[str, Any]) -> None:
    try:
        await crew.run(workflow_id, device_data)
    except Exception as e:
        logger.error("Onboarding workflow %s failed: %s", workflow_id, e)
    finally:
        crew_store.pop(workflow_id, None)


@router.get("/workflows/{workflow_id}", response_model=WorkflowStatusResponse)
async def get_workflow_status(workflow_id: str) -> WorkflowStatusResponse:
    import redis.asyncio as aioredis

    try:
        r = aioredis.from_url(settings.redis_url)
        raw = await r.get(f"workflow:{workflow_id}")
        await r.aclose()
    except Exception as e:
        logger.warning("Redis lookup failed for %s: %s", workflow_id, e)
        raw = None

    if raw:
        data = json.loads(raw)
        return WorkflowStatusResponse(
            workflow_id=workflow_id,
            status=data.get("status", "unknown"),
            result=data.get("result"),
            error=data.get("error"),
        )

    raise HTTPException(status_code=404, detail=f"Workflow {workflow_id} not found")


@router.post("/workflows/proof-generation", response_model=ProofGenerationResponse)
async def proof_generation(request: ProofGenerationRequest) -> ProofGenerationResponse:
    workflow_id = f"proof-{uuid.uuid4().hex}"

    initial_state: ProofState = {
        "request_id": workflow_id,
        "status": "initiated",
        "circuit_type": request.circuit_type,
        "public_inputs": request.public_inputs,
        "private_inputs": request.private_inputs,
        "proof_data": None,
        "verification_result": None,
        "error": None,
    }

    import asyncio

    async def run_graph() -> None:
        loop = asyncio.get_running_loop()
        try:
            graph = create_proof_graph()
            await loop.run_in_executor(None, lambda: graph.invoke(initial_state))
        except Exception as e:
            logger.error("Proof graph %s failed: %s", workflow_id, e)

    asyncio.create_task(run_graph())

    return ProofGenerationResponse(
        workflow_id=workflow_id,
        status="started",
        message=f"ZK proof generation workflow started: {request.circuit_type}",
    )


@router.post("/agents/chat", response_model=AgentChatResponse)
async def chat_with_agents(request: AgentChatRequest) -> AgentChatResponse:
    try:
        result = await backend.chat_agents(request.message, request.context)
        return AgentChatResponse(
            response=result.get("response", "No response from agent team"),
            agent=result.get("agent", "agent-team"),
        )
    except Exception as e:
        logger.error("Agent chat failed: %s", e)
        return AgentChatResponse(
            response=f"Agent team unavailable: {e}",
            agent="system",
        )


@router.get("/agents/status", response_model=AgentStatusResponse)
async def agent_status() -> AgentStatusResponse:
    agents = [
        {"name": "Certificate Validator", "status": "ready"},
        {"name": "Secure Element Provisioning Agent", "status": "ready"},
        {"name": "Matter Compliance Agent", "status": "ready"},
        {"name": "ZK Proof Manager", "status": "ready"},
    ]

    try:
        result = await backend.check_compliance("health-check")
        if result:
            agents.append({"name": "Go Backend", "status": "connected"})
    except Exception:
        agents.append({"name": "Go Backend", "status": "unreachable"})

    overall = "healthy" if all(a["status"] == "ready" or a["status"] == "connected" for a in agents) else "degraded"
    return AgentStatusResponse(agents=agents, overall=overall)
