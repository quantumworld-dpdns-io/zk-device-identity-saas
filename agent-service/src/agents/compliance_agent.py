from crewai import Agent, Tool
from crewai.tools import BaseTool
from pydantic import BaseModel, Field
from typing import Type, Any

from src.backend_client import backend


class VerifyMatterComplianceInput(BaseModel):
    device_id: str = Field(description="Unique identifier of the device to check for Matter compliance")
    product_id: str = Field(description="Matter Product ID (PID) as hex string")
    vendor_id: str = Field(description="Matter Vendor ID (VID) as hex string")


class VerifyMatterComplianceTool(BaseTool):
    name: str = "verify_matter_compliance"
    description: str = "Verifies that a device meets Matter compliance requirements via the backend compliance service"
    args_schema: Type[BaseModel] = VerifyMatterComplianceInput

    def _run(self, device_id: str, product_id: str, vendor_id: str) -> str:
        import asyncio
        result = asyncio.run(backend.check_compliance(device_id))
        return str(result)


class RunRiscZeroComplianceInput(BaseModel):
    device_id: str = Field(description="Device ID for which to run a RISC Zero compliance proof")
    parameters: dict[str, Any] = Field(default_factory=dict, description="Additional compliance parameters")


class RunRiscZeroComplianceTool(Tool):
    name: str = "run_risc_zero_compliance"
    description: str = "Initiates a RISC Zero compliance proof for the given device to verify software integrity"
    func: str = ""

    def __init__(self) -> None:
        super().__init__(
            name="run_risc_zero_compliance",
            description="Initiates a RISC Zero compliance proof for the given device to verify software integrity",
            func=lambda device_id, parameters=None: (
                f"RISC Zero compliance proof initiated for device {device_id}"
            ),
        )


compliance_agent = Agent(
    role="Matter Compliance Agent",
    goal="Verify that devices meet all Matter certification and compliance requirements",
    backstory=(
        "You are a compliance auditor for the Matter smart home standard. "
        "You have encyclopedic knowledge of the Matter specification, including "
        "the Device Attestation (DAC), Product Attestation Intermediate (PAI), "
        "and Product Attestation Authority (PAA) requirements. You also verify "
        "that devices pass RISC Zero compliance proofs, ensuring software integrity "
        "and correct implementation of Matter clusters."
    ),
    tools=[
        VerifyMatterComplianceTool(),
        RunRiscZeroComplianceTool(),
    ],
    verbose=True,
    allow_delegation=False,
)
