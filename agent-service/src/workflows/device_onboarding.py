import asyncio
import json
from typing import Any

from crewai import Crew, Process, Task

from src.agents.certificate_validator import certificate_validator
from src.agents.provisioning_agent import provisioning_agent
from src.agents.compliance_agent import compliance_agent
from src.backend_client import backend
from src.config import settings


validate_certificates_task = Task(
    description=(
        "Validate the device certificate chain for the device with ID {device_id}. "
        "The certificate chain contains DAC, PAI, and PAA certificates. "
        "Call verify_certificate_chain to submit to the backend for path validation. "
        "Then call check_certificate_revocation for each certificate in the chain. "
        "Report whether the chain is valid and trusted."
    ),
    expected_output=(
        "A JSON object with fields: device_id, chain_valid (bool), "
        "revocation_status (dict per certificate), and overall_verdict (str)."
    ),
    agent=certificate_validator,
)

provision_device_task = Task(
    description=(
        "Provision the secure element for device {device_id}. "
        "Generate a Certificate Signing Request (CSR) using the device's identity material, "
        "then use provision_secure_element to submit the CSR and public key to the backend. "
        "The backend will sign the CSR and return the device certificate."
    ),
    expected_output=(
        "A JSON object with fields: device_id, provisioning_status (str), "
        "device_certificate (str PEM), and error (str if any)."
    ),
    agent=provisioning_agent,
)

verify_compliance_task = Task(
    description=(
        "Verify Matter compliance for device {device_id} with "
        "vendor_id {vendor_id} and product_id {product_id}. "
        "Call verify_matter_compliance to check compliance requirements. "
        "Also call run_risc_zero_compliance to initiate a software integrity proof. "
        "Report the overall compliance status."
    ),
    expected_output=(
        "A JSON object with fields: device_id, compliance_status (str), "
        "risc_zero_status (str), and overall_verdict (str)."
    ),
    agent=compliance_agent,
)


class DeviceOnboardingCrew:
    def __init__(self) -> None:
        self.crew = Crew(
            agents=[certificate_validator, provisioning_agent, compliance_agent],
            tasks=[validate_certificates_task, provision_device_task, verify_compliance_task],
            process=Process.sequential,
            verbose=True,
        )

    async def run(self, workflow_id: str, device_data: dict[str, Any]) -> dict[str, Any]:
        inputs = {
            "device_id": device_data.get("device_id", "unknown"),
            "vendor_id": device_data.get("vendor_id", "0000"),
            "product_id": device_data.get("product_id", "0000"),
        }
        loop = asyncio.get_running_loop()
        result = await loop.run_in_executor(None, self.crew.kickoff, inputs)
        result_str = str(result) if not isinstance(result, str) else result

        import redis.asyncio as aioredis
        r = aioredis.from_url(settings.redis_url)
        await r.setex(
            f"workflow:{workflow_id}",
            settings.redis_workflow_ttl,
            json.dumps({"status": "completed", "result": result_str}),
        )
        await r.aclose()

        return {"status": "completed", "device_id": inputs["device_id"], "result": result_str}
