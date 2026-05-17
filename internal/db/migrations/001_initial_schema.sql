CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Tenants
CREATE TABLE tenants (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL,
    slug VARCHAR(255) NOT NULL UNIQUE,
    plan VARCHAR(50) DEFAULT 'free',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Users
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID REFERENCES tenants(id),
    email VARCHAR(255) NOT NULL UNIQUE,
    password_hash VARCHAR(512) NOT NULL,
    role VARCHAR(50) DEFAULT 'user',
    mfa_enabled BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX idx_users_tenant_id ON users(tenant_id);

-- Devices
CREATE TABLE devices (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES tenants(id),
    serial_number VARCHAR(255) NOT NULL,
    manufacturer VARCHAR(255) NOT NULL,
    model VARCHAR(255) NOT NULL,
    firmware_version VARCHAR(100),
    device_type VARCHAR(100) NOT NULL,
    status VARCHAR(50) DEFAULT 'active',
    public_key TEXT,
    metadata JSONB,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    deleted_at TIMESTAMPTZ,
    UNIQUE(serial_number)
);
CREATE INDEX idx_devices_tenant_id ON devices(tenant_id);
CREATE INDEX idx_devices_deleted_at ON devices(deleted_at);

-- Device Fingerprints
CREATE TABLE device_fingerprints (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    device_id UUID NOT NULL REFERENCES devices(id),
    fingerprint_hash VARCHAR(512) NOT NULL,
    embedding JSONB,
    created_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX idx_device_fingerprints_device_id ON device_fingerprints(device_id);

-- Certificates
CREATE TABLE certificates (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    device_id UUID NOT NULL REFERENCES devices(id),
    cert_type VARCHAR(10) NOT NULL,
    certificate_pem TEXT NOT NULL,
    issuer_id UUID REFERENCES certificates(id),
    serial_number VARCHAR(255),
    valid_from TIMESTAMPTZ,
    valid_to TIMESTAMPTZ,
    status VARCHAR(50) DEFAULT 'active',
    created_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX idx_certificates_device_id ON certificates(device_id);

-- Attestation Records
CREATE TABLE attestation_records (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    device_id UUID NOT NULL REFERENCES devices(id),
    tenant_id UUID NOT NULL REFERENCES tenants(id),
    status VARCHAR(50) DEFAULT 'pending',
    attestation_data JSONB,
    signature TEXT,
    verified_by VARCHAR(255),
    verified_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX idx_attestation_records_device_id ON attestation_records(device_id);
CREATE INDEX idx_attestation_records_tenant_id ON attestation_records(tenant_id);

-- Proof Records
CREATE TABLE proof_records (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES tenants(id),
    device_id UUID NOT NULL REFERENCES devices(id),
    circuit_type VARCHAR(100) NOT NULL,
    proof_data JSONB,
    public_inputs JSONB,
    private_inputs_hash VARCHAR(512),
    status VARCHAR(50) DEFAULT 'pending',
    created_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX idx_proof_records_tenant_id ON proof_records(tenant_id);
CREATE INDEX idx_proof_records_device_id ON proof_records(device_id);

-- API Keys
CREATE TABLE api_keys (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES tenants(id),
    key_hash VARCHAR(512) NOT NULL,
    name VARCHAR(255) NOT NULL,
    scopes TEXT,
    expires_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX idx_api_keys_tenant_id ON api_keys(tenant_id);

-- Audit Logs
CREATE TABLE audit_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID REFERENCES tenants(id),
    user_id UUID REFERENCES users(id),
    action VARCHAR(100) NOT NULL,
    resource VARCHAR(100) NOT NULL,
    resource_id VARCHAR(255),
    status_code INTEGER DEFAULT 0,
    request_ip VARCHAR(45),
    user_agent TEXT,
    details JSONB,
    created_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX idx_audit_logs_tenant_id ON audit_logs(tenant_id);
CREATE INDEX idx_audit_logs_user_id ON audit_logs(user_id);
CREATE INDEX idx_audit_logs_created_at ON audit_logs(created_at);
