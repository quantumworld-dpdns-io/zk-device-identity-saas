import * as backend from './backend-client.js';

export const resources = [
  {
    uriTemplate: 'device://{id}',
    name: 'Device Details',
    description: 'Full device details including certificates, firmware, and metadata',
    mimeType: 'application/json',
    read: async (uri) => {
      const id = extractId(uri, 'device://');
      const data = await backend.getDevice(id);
      return {
        contents: [{
          uri,
          mimeType: 'application/json',
          text: JSON.stringify(data, null, 2),
        }],
      };
    },
  },
  {
    uriTemplate: 'devices://list?status={status}',
    name: 'Filtered Device List',
    description: 'Paginated list of devices, optionally filtered by status',
    mimeType: 'application/json',
    read: async (uri) => {
      const url = new URL(uri.replace('devices://', 'http://devices/'));
      const status = url.searchParams.get('status') || undefined;
      const tenantId = url.searchParams.get('tenant_id') || undefined;
      const page = parseInt(url.searchParams.get('page') || '1', 10);
      const pageSize = parseInt(url.searchParams.get('page_size') || '20', 10);
      const data = await backend.listDevices({ tenant_id: tenantId, status, page, page_size: pageSize });
      return {
        contents: [{
          uri,
          mimeType: 'application/json',
          text: JSON.stringify(data, null, 2),
        }],
      };
    },
  },
  {
    uriTemplate: 'attestation://{id}',
    name: 'Attestation Details',
    description: 'Attestation record details including DAC fingerprint and verification status',
    mimeType: 'application/json',
    read: async (uri) => {
      const id = extractId(uri, 'attestation://');
      const data = await backend.getAttestation(id);
      return {
        contents: [{
          uri,
          mimeType: 'application/json',
          text: JSON.stringify(data, null, 2),
        }],
      };
    },
  },
  {
    uriTemplate: 'proof://{id}',
    name: 'Proof Details',
    description: 'Zero-knowledge proof record details including circuit type, status, and verification data',
    mimeType: 'application/json',
    read: async (uri) => {
      const id = extractId(uri, 'proof://');
      const data = await backend.getProof(id);
      return {
        contents: [{
          uri,
          mimeType: 'application/json',
          text: JSON.stringify(data, null, 2),
        }],
      };
    },
  },
];

function extractId(uri, prefix) {
  const rest = uri.slice(prefix.length);
  const qIndex = rest.indexOf('?');
  return qIndex === -1 ? rest : rest.slice(0, qIndex);
}

export async function handleResourceRead(uri) {
  for (const resource of resources) {
    const template = resource.uriTemplate;
    const pattern = new RegExp('^' + template.replace(/\/\/\{(\w+)\}/g, '://([^/]+)').replace(/\?\{(\w+)\}/g, '\\?.*') + '$');
    if (pattern.test(uri)) {
      return resource.read(uri);
    }
  }
  throw new Error(`No resource matching URI: ${uri}`);
}

export function listResources() {
  return resources.map((r) => ({
    uri: r.uriTemplate,
    name: r.name,
    description: r.description,
    mimeType: r.mimeType,
  }));
}
