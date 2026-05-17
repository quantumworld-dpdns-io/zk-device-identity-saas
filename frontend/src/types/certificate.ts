export enum CertType {
  DAC = 'dac',
  PAI = 'pai',
  PAA = 'paa',
}

export interface Certificate {
  id: string
  device_id: string
  cert_type: CertType
  certificate: string
  subject: string
  issuer: string
  serial_number: string
  not_before: string
  not_after: string
  is_valid: boolean
  created_at: string
}

export interface Attestation {
  id: string
  device_id: string
  certification_type: string
  status: AttestationStatus
  challenge: string
  signature: string
  nonce: string
  verification_result?: string
  verified_at?: string
  created_at: string
}

export type AttestationStatus = 'pending' | 'verified' | 'failed' | 'expired'

export interface AttestationStats {
  total: number
  pending: number
  verified: number
  failed: number
  expired: number
}
