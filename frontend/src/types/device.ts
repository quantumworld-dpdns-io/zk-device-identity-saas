export interface DeviceFingerprint {
  id: string
  device_id: string
  serial_number: string
  manufacturer: string
  model: string
  firmware_version: string
  hardware_version: string
  public_key: string
  created_at: string
  updated_at: string
}

export interface Device {
  id: string
  tenant_id: string
  serial_number: string
  device_name: string
  status: DeviceStatus
  device_type: string
  fingerprint_id?: string
  fingerprint?: DeviceFingerprint
  last_seen?: string
  created_at: string
  updated_at: string
}

export type DeviceStatus = 'active' | 'inactive' | 'revoked' | 'compromised' | 'pending'

export interface DeviceStats {
  total: number
  active: number
  inactive: number
  revoked: number
  compromised: number
  pending: number
}
