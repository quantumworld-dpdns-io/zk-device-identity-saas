import json
import logging
from typing import Any, Literal

from langgraph.graph import END, StateGraph
from typing_extensions import TypedDict

from src.backend_client import backend
from src.config import settings

logger = logging.getLogger(__name__)


class ProofState(TypedDict):
    request_id: str
    status: str
    circuit_type: str
    public_inputs: dict[str, Any]
    private_inputs: dict[str, Any]
    proof_data: dict[str, Any] | None
    verification_result: dict[str, Any] | None
    error: str | None


VALID_CIRCUITS = frozenset({"device_attestation", "ownership_proof", "compliance_proof"})


def validate_inputs_node(state: ProofState) -> ProofState:
    errors: list[str] = []

    if not state.get("request_id"):
        errors.append("Missing request_id")
    if not state.get("circuit_type"):
        errors.append("Missing circuit_type")
    elif state["circuit_type"] not in VALID_CIRCUITS:
        errors.append(f"Invalid circuit_type '{state['circuit_type']}'. Must be one of {sorted(VALID_CIRCUITS)}")
    if not state.get("public_inputs"):
        errors.append("Missing public_inputs")
    if not state.get("private_inputs"):
        errors.append("Missing private_inputs")

    if errors:
        state["status"] = "validation_failed"
        state["error"] = "; ".join(errors)
        return state

    state["status"] = "inputs_validated"
    return state


def decide_next(state: ProofState) -> Literal["generate_witness", "handle_error"]:
    if state.get("error"):
        return "handle_error"
    return "generate_witness"


def generate_witness_node(state: ProofState) -> ProofState:
    import asyncio

    try:
        loop = asyncio.new_event_loop()
        asyncio.set_event_loop(loop)
        result = loop.run_until_complete(
            backend.generate_witness(
                state["circuit_type"],
                state["public_inputs"],
                state["private_inputs"],
            )
        )
        loop.close()
    except Exception as e:
        loop.close()
        state["status"] = "witness_generation_failed"
        state["error"] = f"Witness generation failed: {e}"
        return state

    state["status"] = "witness_generated"
    state["proof_data"] = state.get("proof_data") or {}
    state["proof_data"]["witness_id"] = result.get("witness_id", "")
    state["proof_data"]["witness_data"] = result
    return state


def generate_proof_node(state: ProofState) -> ProofState:
    import asyncio

    witness_id = (state.get("proof_data") or {}).get("witness_id", "")
    if not witness_id:
        state["status"] = "proof_generation_failed"
        state["error"] = "No witness_id available"
        return state

    try:
        loop = asyncio.new_event_loop()
        asyncio.set_event_loop(loop)
        proof = loop.run_until_complete(backend.generate_proof(witness_id))
        loop.close()
    except Exception as e:
        loop.close()
        state["status"] = "proof_generation_failed"
        state["error"] = f"Proof generation failed: {e}"
        return state

    if "proof_data" not in state or state["proof_data"] is None:
        state["proof_data"] = {}
    state["proof_data"]["proof"] = proof.get("proof", {})
    state["proof_data"]["proof_id"] = proof.get("proof_id", "")
    state["status"] = "proof_generated"
    return state


def verify_proof_node(state: ProofState) -> ProofState:
    import asyncio

    proof_data = state.get("proof_data") or {}
    if not proof_data.get("proof"):
        state["status"] = "verification_failed"
        state["error"] = "No proof data available to verify"
        return state

    try:
        loop = asyncio.new_event_loop()
        asyncio.set_event_loop(loop)
        result = loop.run_until_complete(backend.verify_proof(proof_data))
        loop.close()
    except Exception as e:
        loop.close()
        state["status"] = "verification_failed"
        state["error"] = f"Verification failed: {e}"
        return state

    state["verification_result"] = result
    state["status"] = "proof_verified" if result.get("verified") else "proof_invalid"
    return state


def store_result_node(state: ProofState) -> ProofState:
    import asyncio

    proof_data = state.get("proof_data") or {}
    verification_result = state.get("verification_result") or {}

    try:
        loop = asyncio.new_event_loop()
        asyncio.set_event_loop(loop)
        loop.run_until_complete(
            backend.store_proof_result(state["request_id"], proof_data, verification_result)
        )
        loop.close()
    except Exception as e:
        loop.close()
        state["status"] = "storage_failed"
        state["error"] = f"Result storage failed: {e}"
        return state

    import redis.asyncio as aioredis

    try:
        loop2 = asyncio.new_event_loop()
        asyncio.set_event_loop(loop2)
        r = loop2.run_until_complete(aioredis.from_url(settings.redis_url))
        loop2.run_until_complete(
            r.setex(
                f"workflow:{state['request_id']}",
                settings.redis_workflow_ttl,
                json.dumps({
                    "status": state["status"],
                    "request_id": state["request_id"],
                    "circuit_type": state["circuit_type"],
                    "verification_result": verification_result,
                    "error": state.get("error"),
                }),
            )
        )
        loop2.run_until_complete(r.aclose())
        loop2.close()
    except Exception as e:
        logger.warning("Failed to write workflow status to Redis: %s", e)

    state["status"] = "completed"
    return state


def handle_error_node(state: ProofState) -> ProofState:
    logger.error(
        "Proof lifecycle error for request %s: %s",
        state.get("request_id", "unknown"),
        state.get("error"),
    )

    import redis.asyncio as aioredis
    try:
        loop = asyncio.new_event_loop()
        asyncio.set_event_loop(loop)
        r = loop.run_until_complete(aioredis.from_url(settings.redis_url))
        loop.run_until_complete(
            r.setex(
                f"workflow:{state['request_id']}",
                settings.redis_workflow_ttl,
                json.dumps({
                    "status": "failed",
                    "request_id": state["request_id"],
                    "circuit_type": state.get("circuit_type", ""),
                    "error": state.get("error"),
                }),
            )
        )
        loop.run_until_complete(r.aclose())
        loop.close()
    except Exception as e:
        logger.warning("Failed to persist error state to Redis: %s", e)

    return state


def create_proof_graph():
    workflow = StateGraph(ProofState)

    workflow.add_node("validate_inputs", validate_inputs_node)
    workflow.add_node("generate_witness", generate_witness_node)
    workflow.add_node("generate_proof", generate_proof_node)
    workflow.add_node("verify_proof", verify_proof_node)
    workflow.add_node("store_result", store_result_node)
    workflow.add_node("handle_error", handle_error_node)

    workflow.set_entry_point("validate_inputs")
    workflow.add_conditional_edges(
        "validate_inputs",
        decide_next,
        {"generate_witness": "generate_witness", "handle_error": "handle_error"},
    )
    workflow.add_edge("generate_witness", "generate_proof")
    workflow.add_edge("generate_proof", "verify_proof")
    workflow.add_edge("verify_proof", "store_result")
    workflow.add_edge("store_result", END)
    workflow.add_edge("handle_error", END)

    return workflow.compile()
