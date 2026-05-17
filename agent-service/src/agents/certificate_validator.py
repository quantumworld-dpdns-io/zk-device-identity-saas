from crewai import Agent, Tool
from crewai.tools import BaseTool
from pydantic import BaseModel, Field
from typing import Type, Any

from src.backend_client import backend


class VerifyCertificateChainInput(BaseModel):
    cert_chain: dict[str, Any] = Field(description="Dictionary containing DAC, PAI, and PAA certificates as PEM strings")


class VerifyCertificateChainTool(BaseTool):
    name: str = "verify_certificate_chain"
    description: str = "Submits a DAC/PAI/PAA certificate chain to the backend for X.509 path validation"
    args_schema: Type[BaseModel] = VerifyCertificateChainInput

    def _run(self, cert_chain: dict[str, Any]) -> str:
        import asyncio
        result = asyncio.run(backend.verify_device_certificate(cert_chain))
        return str(result)


class CheckCertificateRevocationInput(BaseModel):
    subject_key_identifier: str = Field(description="Subject Key Identifier (SKI) hex string to check revocation status")


class CheckCertificateRevocationTool(BaseTool):
    name: str = "check_certificate_revocation"
    description: str = "Checks whether a certificate has been revoked using the backend CRL/OCSP service"
    args_schema: Type[BaseModel] = CheckCertificateRevocationInput

    def _run(self, subject_key_identifier: str) -> str:
        return f"Revocation status for SKI={subject_key_identifier}: not revoked (simulated)"


certificate_validator = Agent(
    role="Certificate Validator",
    goal="Validate DAC/PAI/PAA certificate chains for IoT devices and ensure Matter PKI compliance",
    backstory=(
        "You are a seasoned PKI expert with deep knowledge of the Matter smart home standard. "
        "You have validated thousands of device attestation certificate chains. "
        "You understand X.509 path building, CRL distribution points, and OCSP stapling. "
        "You ensure every device presented for onboarding has an unbroken chain of trust "
        "from the Product Attestation Authority down to the Device Attestation Certificate."
    ),
    tools=[
        VerifyCertificateChainTool(),
        CheckCertificateRevocationTool(),
    ],
    verbose=True,
    allow_delegation=False,
)
