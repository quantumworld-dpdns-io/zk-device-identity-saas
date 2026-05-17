from crewai import Agent, Tool
from crewai.tools import BaseTool
from pydantic import BaseModel, Field
from typing import Type, Any

from src.backend_client import backend


class ProvisionSecureElementInput(BaseModel):
    device_id: str = Field(description="Unique identifier of the device to provision")
    public_key: str = Field(description="Device public key in PEM format")
    csr: str = Field(description="Certificate Signing Request in PEM format")


class ProvisionSecureElementTool(BaseTool):
    name: str = "provision_secure_element"
    description: str = "Provisions a secure element by submitting device identity material to the backend"
    args_schema: Type[BaseModel] = ProvisionSecureElementInput

    def _run(self, device_id: str, public_key: str, csr: str) -> str:
        import asyncio
        result = asyncio.run(backend.provision_device({
            "device_id": device_id,
            "public_key": public_key,
            "csr": csr,
        }))
        return str(result)


class GenerateDeviceCSRInput(BaseModel):
    common_name: str = Field(description="Common Name (CN) for the certificate")
    organization: str = Field(description="Organization (O) for the certificate")
    vendor_id: str = Field(description="Matter Vendor ID (VID) as hex string")


class GenerateDeviceCSRTool(Tool):
    name: str = "generate_device_csr"
    description: str = "Generates a Certificate Signing Request for a Matter device with the given identity attributes"
    func: str = ""

    def __init__(self) -> None:
        super().__init__(
            name="generate_device_csr",
            description="Generates a Certificate Signing Request for a Matter device with the given identity attributes",
            func=lambda common_name, organization, vendor_id: (
                f"Simulated CSR for CN={common_name}, O={organization}, VID={vendor_id}"
            ),
        )


provisioning_agent = Agent(
    role="Secure Element Provisioning Agent",
    goal="Provision IoT secure elements with device identity material and establish root of trust",
    backstory=(
        "You are a hardware security expert specializing in secure element provisioning. "
        "You have worked with ECC608, SE050, and other secure element families. "
        "You understand the Matter certification process and know how to inject "
        "device attestation certificates, private keys, and vendor-specific data "
        "into secure storage. You ensure that every device leaves the factory floor "
        "with a unique, unclonable identity."
    ),
    tools=[
        ProvisionSecureElementTool(),
        GenerateDeviceCSRTool(),
    ],
    verbose=True,
    allow_delegation=False,
)
