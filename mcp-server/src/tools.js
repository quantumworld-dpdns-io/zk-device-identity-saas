import { z } from 'zod';
import * as backend from './backend-client.js';

const ListDevicesInput = z.object({
  tenant_id: z.string().optional(),
  status: z.string().optional(),
  manufacturer: z.string().optional(),
  page: z.number().int().positive().optional(),
  page_size: z.number().int().positive().max(100).optional(),
});

const GetDeviceInput = z.object({
  device_id: z.string(),
});

const CreateAttestationInput = z.object({
  device_id: z.string(),
  dac_certificate: z.string(),
  pai_certificate: z.string().optional(),
  paa_certificate: z.string().optional(),
});

const VerifyProofInput = z.object({
  proof_data: z.record(z.unknown()),
  public_inputs: z.record(z.unknown()),
});

const CheckComplianceInput = z.object({
  device_id: z.string(),
  compliance_version: z.string().optional(),
});

const FindSimilarDevicesInput = z.object({
  device_id: z.string(),
  limit: z.number().int().positive().max(100).optional(),
});

export const tools = [
  {
    name: 'list_devices',
    description: 'List all registered devices with optional filters for status, manufacturer, and pagination',
    inputSchema: {
      type: 'object',
      properties: {
        tenant_id: { type: 'string', description: 'Optional tenant ID to filter by' },
        status: { type: 'string', description: 'Filter by device status (active, inactive, revoked, provisioned)' },
        manufacturer: { type: 'string', description: 'Filter by manufacturer name' },
        page: { type: 'integer', description: 'Page number for pagination (starts at 1)' },
        page_size: { type: 'integer', description: 'Number of results per page (max 100)' },
      },
    },
    handler: async (args) => {
      const parsed = ListDevicesInput.parse(args);
      const data = await backend.listDevices(parsed);
      return {
        content: [{ type: 'text', text: JSON.stringify(data, null, 2) }],
      };
    },
  },
  {
    name: 'get_device',
    description: 'Get detailed information about a specific device including certificates and metadata',
    inputSchema: {
      type: 'object',
      properties: {
        device_id: { type: 'string', description: 'The unique device ID (UUID)' },
      },
      required: ['device_id'],
    },
    handler: async (args) => {
      const parsed = GetDeviceInput.parse(args);
      const data = await backend.getDevice(parsed.device_id);
      return {
        content: [{ type: 'text', text: JSON.stringify(data, null, 2) }],
      };
    },
  },
  {
    name: 'create_attestation',
    description: 'Submit a new device attestation with DAC, PAI, and PAA certificates for Matter compliance verification',
    inputSchema: {
      type: 'object',
      properties: {
        device_id: { type: 'string', description: 'The device ID to attest' },
        dac_certificate: { type: 'string', description: 'Device Attestation Certificate (DAC) in PEM format' },
        pai_certificate: { type: 'string', description: 'Product Attestation Intermediate (PAI) certificate in PEM format' },
        paa_certificate: { type: 'string', description: 'Product Attestation Authority (PAA) certificate in PEM format' },
      },
      required: ['device_id', 'dac_certificate'],
    },
    handler: async (args) => {
      const parsed = CreateAttestationInput.parse(args);
      const data = await backend.createAttestation(parsed);
      return {
        content: [{ type: 'text', text: JSON.stringify(data, null, 2) }],
      };
    },
  },
  {
    name: 'verify_proof',
    description: 'Verify a zero-knowledge proof against its public inputs to validate device identity claims',
    inputSchema: {
      type: 'object',
      properties: {
        proof_data: { type: 'object', description: 'The ZK proof data as a JSON object' },
        public_inputs: { type: 'object', description: 'Public inputs used for verification' },
      },
      required: ['proof_data', 'public_inputs'],
    },
    handler: async (args) => {
      const parsed = VerifyProofInput.parse(args);
      const data = await backend.verifyProof(parsed);
      return {
        content: [{ type: 'text', text: JSON.stringify(data, null, 2) }],
      };
    },
  },
  {
    name: 'check_compliance',
    description: 'Check a device against Matter compliance requirements including firmware, attestation, and security posture',
    inputSchema: {
      type: 'object',
      properties: {
        device_id: { type: 'string', description: 'The device ID to check' },
        compliance_version: { type: 'string', description: 'Compliance version to check against (e.g. matter-1.3, matter-1.4)' },
      },
      required: ['device_id'],
    },
    handler: async (args) => {
      const parsed = CheckComplianceInput.parse(args);
      const data = await backend.checkCompliance(parsed);
      return {
        content: [{ type: 'text', text: JSON.stringify(data, null, 2) }],
      };
    },
  },
  {
    name: 'find_similar_devices',
    description: 'Find devices with similar fingerprints using vector similarity search for anomaly detection and device grouping',
    inputSchema: {
      type: 'object',
      properties: {
        device_id: { type: 'string', description: 'The source device ID to find similar devices for' },
        limit: { type: 'integer', description: 'Maximum number of similar devices to return (default 10, max 100)' },
      },
      required: ['device_id'],
    },
    handler: async (args) => {
      const parsed = FindSimilarDevicesInput.parse(args);
      const data = await backend.findSimilarDevices(parsed);
      return {
        content: [{ type: 'text', text: JSON.stringify(data, null, 2) }],
      };
    },
  },
];

export async function handleToolCall(name, args) {
  const tool = tools.find((t) => t.name === name);
  if (!tool) {
    throw new Error(`Unknown tool: ${name}`);
  }
  return tool.handler(args);
}
