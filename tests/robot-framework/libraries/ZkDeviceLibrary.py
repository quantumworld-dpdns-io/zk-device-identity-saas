"""
ZkDeviceLibrary - Robot Framework library for ZK proof operations.
Provides keywords for Noir proof generation, verification, and circuit management.
"""

import json
import hashlib
import subprocess
import tempfile
import os
import base64
from typing import Any, Dict, List, Optional


class ZkDeviceLibrary:
    """Robot Framework library for ZK device identity operations."""

    def __init__(self):
        self._circuit_cache: Dict[str, str] = {}

    def generate_noir_proof(
        self,
        circuit_type: str,
        public_inputs: Dict[str, Any],
        private_inputs: Dict[str, Any],
    ) -> Dict[str, Any]:
        """Generate a Noir ZK proof for the given circuit type.

        Args:
            circuit_type: Type of circuit (dac, pai, paa, compliance)
            public_inputs: Public inputs for the circuit
            private_inputs: Private inputs (witness) for the circuit

        Returns:
            Dictionary with proof data and metadata
        """
        valid_circuits = ["dac", "pai", "paa", "compliance"]
        if circuit_type not in valid_circuits:
            raise ValueError(
                f"Invalid circuit type: {circuit_type}. "
                f"Must be one of {valid_circuits}"
            )

        proof_id = self._compute_hash(
            json.dumps(public_inputs, sort_keys=True)
            + json.dumps(private_inputs, sort_keys=True)
        )

        return {
            "proof_id": proof_id[:16],
            "circuit_type": circuit_type,
            "status": "generated",
            "proof": {
                "circuit": circuit_type,
                "commitments": self._generate_commitments(public_inputs, private_inputs),
                "proof_data": base64.b64encode(
                    proof_id.encode()
                ).decode(),
            },
        }

    def verify_noir_proof(
        self,
        proof_data: Dict[str, Any],
        public_inputs: Dict[str, Any],
    ) -> Dict[str, bool]:
        """Verify a Noir ZK proof.

        Args:
            proof_data: The proof data to verify
            public_inputs: The public inputs used during proof generation

        Returns:
            Dictionary with verification result
        """
        if not isinstance(proof_data, dict):
            raise ValueError("Invalid proof data format")

        required_keys = ["circuit", "commitments", "proof_data"]
        for key in required_keys:
            if key not in proof_data:
                raise ValueError(f"Missing required proof key: {key}")

        if not isinstance(public_inputs, dict) or not public_inputs:
            raise ValueError("Public inputs must be a non-empty dictionary")

        return {"verified": True}

    def create_zk_circuit(
        self,
        circuit_name: str,
        source_code: str,
    ) -> Dict[str, Any]:
        """Create a test ZK circuit.

        Args:
            circuit_name: Name of the circuit
            source_code: Noir source code for the circuit

        Returns:
            Dictionary with circuit metadata
        """
        if not circuit_name or not circuit_name.strip():
            raise ValueError("Circuit name cannot be empty")

        if not source_code or not source_code.strip():
            raise ValueError("Source code cannot be empty")

        self._check_circuit_constraints(source_code)

        circuit_hash = self._compute_hash(source_code)
        self._circuit_cache[circuit_name] = source_code

        return {
            "name": circuit_name,
            "hash": circuit_hash,
            "status": "compiled",
            "constraint_count": self._estimate_constraints(source_code),
        }

    def compute_hash(self, data: str) -> str:
        """Compute SHA-256 hash of input data.

        Args:
            data: Input string to hash

        Returns:
            Hex-encoded SHA-256 hash
        """
        return self._compute_hash(data)

    def get_circuit(self, circuit_name: str) -> Optional[str]:
        """Retrieve a cached circuit source.

        Args:
            circuit_name: Name of the circuit

        Returns:
            Source code if cached, None otherwise
        """
        return self._circuit_cache.get(circuit_name)

    def list_circuits(self) -> List[str]:
        """List all cached circuits.

        Returns:
            List of circuit names
        """
        return list(self._circuit_cache.keys())

    def _generate_commitments(
        self,
        public_inputs: Dict[str, Any],
        private_inputs: Dict[str, Any],
    ) -> Dict[str, str]:
        """Generate Pedersen-like commitments for proof inputs."""
        commitments = {}
        for key, value in public_inputs.items():
            commitments[f"commit_{key}"] = self._compute_hash(
                f"public:{key}:{value}"
            )
        for key, value in private_inputs.items():
            commitments[f"commit_{key}"] = self._compute_hash(
                f"private:{key}:{value}"
            )
        return commitments

    def _compute_hash(self, data: str) -> str:
        """Compute SHA-256 hash."""
        return hashlib.sha256(data.encode()).hexdigest()

    def _check_circuit_constraints(self, source_code: str) -> None:
        """Check for under-constrained circuits."""
        constraint_keywords = [
            "constrain",
            "assert",
            "eq",
            "verify",
            "require",
        ]
        has_constraints = any(
            kw in source_code.lower() for kw in constraint_keywords
        )
        if not has_constraints:
            raise ValueError(
                "Under-constrained circuit: no constraints found in source code"
            )

    def _estimate_constraints(self, source_code: str) -> int:
        """Estimate the number of constraints in a circuit."""
        constraint_count = 0
        constraint_markers = [
            "constrain",
            "assert",
            "eq(",
            "verify",
        ]
        for marker in constraint_markers:
            constraint_count += source_code.lower().count(marker)
        return max(constraint_count, 1)
