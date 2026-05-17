export enum CircuitType {
  DAC = 'dac',
  PAI = 'pai',
  PAA = 'paa',
  COMPLIANCE = 'compliance',
  ANOMALY = 'anomaly',
}

export type ProofStatus = 'generating' | 'completed' | 'failed' | 'verified'

export interface Proof {
  id: string
  device_id: string
  circuit_type: CircuitType
  status: ProofStatus
  public_inputs: Record<string, unknown>
  proof_data?: string
  verification_key?: string
  verified?: boolean
  error_message?: string
  created_at: string
  updated_at: string
}

export interface ProofStats {
  total: number
  generating: number
  completed: number
  failed: number
  verified: number
}

export interface GenerateProofRequest {
  device_id: string
  circuit_type: CircuitType
  inputs: Record<string, unknown>
}

export interface VerifyProofRequest {
  proof_id: string
  proof_data: string
  public_inputs: Record<string, unknown>
}
