from crewai import Agent, Tool
from crewai.tools import BaseTool
from pydantic import BaseModel, Field
from typing import Type, Any

from src.backend_client import backend


class GenerateZKProofInput(BaseModel):
    circuit_type: str = Field(description="Type of ZK circuit to use (e.g. device_attestation, ownership_proof)")
    public_inputs: dict[str, Any] = Field(description="Public inputs for the ZK circuit")
    private_inputs: dict[str, Any] = Field(description="Private inputs for the ZK circuit (witness)")


class GenerateZKProofTool(BaseTool):
    name: str = "generate_zk_proof"
    description: str = "Generates a zero-knowledge proof using the specified Noir circuit"
    args_schema: Type[BaseModel] = GenerateZKProofInput

    def _run(self, circuit_type: str, public_inputs: dict[str, Any], private_inputs: dict[str, Any]) -> str:
        import asyncio

        witness = asyncio.run(backend.generate_witness(circuit_type, public_inputs, private_inputs))
        witness_id = witness.get("witness_id", "")
        proof = asyncio.run(backend.generate_proof(witness_id))
        return str(proof)


class VerifyZKProofInput(BaseModel):
    proof_data: dict[str, Any] = Field(description="Proof data to verify")


class VerifyZKProofTool(BaseTool):
    name: str = "verify_zk_proof"
    description: str = "Verifies a zero-knowledge proof against the public inputs"
    args_schema: Type[BaseModel] = VerifyZKProofInput

    def _run(self, proof_data: dict[str, Any]) -> str:
        import asyncio
        result = asyncio.run(backend.verify_proof(proof_data))
        return str(result)


zk_proof_agent = Agent(
    role="ZK Proof Manager",
    goal="Manage the lifecycle of zero-knowledge proofs from generation through verification and storage",
    backstory=(
        "You are a zero-knowledge cryptography engineer with expertise in Noir and RISC Zero. "
        "You have deployed production ZK systems for device attestation, identity verification, "
        "and private compliance auditing. You understand circuit compilation, witness generation, "
        "prover strategies, and on-chain/off-chain verification patterns. "
        "You ensure that every proof is correctly generated and verifiable before storage."
    ),
    tools=[
        GenerateZKProofTool(),
        VerifyZKProofTool(),
    ],
    verbose=True,
    allow_delegation=False,
)
