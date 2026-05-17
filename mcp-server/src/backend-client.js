import axios from 'axios';

const BACKEND_URL = process.env.GO_BACKEND_URL || 'http://localhost:8080';
const API_KEY = process.env.MCP_API_KEY || '';

const client = axios.create({
  baseURL: BACKEND_URL,
  headers: API_KEY ? { 'X-API-Key': API_KEY } : {},
  timeout: 30000,
});

export async function listDevices(params = {}) {
  const { tenant_id, status, manufacturer, page, page_size } = params;
  const query = {};
  if (page) query.page = page;
  if (page_size) query.page_size = page_size;
  if (status) query.status = status;
  if (manufacturer) query.manufacturer = manufacturer;
  const response = await client.get('/api/v1/devices', {
    params: query,
    headers: tenant_id ? { 'X-Tenant-ID': tenant_id } : {},
  });
  return response.data;
}

export async function getDevice(deviceId) {
  const response = await client.get(`/api/v1/devices/${deviceId}`);
  return response.data;
}

export async function createAttestation(params) {
  const { device_id, dac_certificate, pai_certificate, paa_certificate, tenant_id } = params;
  const response = await client.post('/api/v1/attestations', {
    device_id,
    dac: dac_certificate,
    pai: pai_certificate,
    paa: paa_certificate,
  }, {
    headers: tenant_id ? { 'X-Tenant-ID': tenant_id } : {},
  });
  return response.data;
}

export async function verifyProof(params) {
  const { proof_data, public_inputs } = params;
  const response = await client.post('/api/v1/proofs/verify', {
    proof_data,
    public_inputs,
  });
  return response.data;
}

export async function checkCompliance(params) {
  const { device_id, compliance_version } = params;
  const response = await client.post('/api/v1/compliance/check', {
    device_id,
    check_type: compliance_version || 'matter',
    parameters: {},
  });
  return response.data;
}

export async function findSimilarDevices(params) {
  const { device_id, limit } = params;
  const response = await client.get(`/api/v1/devices/${device_id}/similar`, {
    params: { limit: limit || 10 },
  });
  return response.data;
}

export async function getAttestation(attestationId) {
  const response = await client.get(`/api/v1/attestations/${attestationId}`);
  return response.data;
}

export async function getProof(proofId) {
  const response = await client.get(`/api/v1/proofs/${proofId}`);
  return response.data;
}
