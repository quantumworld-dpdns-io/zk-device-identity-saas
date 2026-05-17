'use client'

import { useState } from 'react'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Badge } from '@/components/ui/badge'
import { Table, TableHeader, TableBody, TableHead, TableRow, TableCell } from '@/components/ui/table'
import { ProofGenerator } from '@/components/proofs/proof-generator'
import { ProofVerifier } from '@/components/proofs/proof-verifier'
import { formatDateTime } from '@/lib/utils'
import type { Proof, GenerateProofRequest } from '@/types'

const MOCK_PROOFS: Proof[] = [
  { id: 'p1', device_id: '1', circuit_type: 'dac' as any, status: 'verified', public_inputs: { serial_number: 'SN-2024-001' }, proof_data: '0xabc123...', verified: true, created_at: '2026-05-17T10:30:00Z', updated_at: '2026-05-17T10:31:00Z' },
  { id: 'p2', device_id: '2', circuit_type: 'compliance' as any, status: 'completed', public_inputs: { batch: 'B3' }, proof_data: '0xdef456...', created_at: '2026-05-16T11:00:00Z', updated_at: '2026-05-16T11:02:00Z' },
  { id: 'p3', device_id: '1', circuit_type: 'anomaly' as any, status: 'failed', public_inputs: { device_id: '1', window: '24h' }, error_message: 'Circuit constraint violation', created_at: '2026-05-15T09:00:00Z', updated_at: '2026-05-15T09:01:00Z' },
  { id: 'p4', device_id: '3', circuit_type: 'pai' as any, status: 'generating', public_inputs: {}, created_at: '2026-05-17T12:00:00Z', updated_at: '2026-05-17T12:00:00Z' },
]

export default function ProofsPage() {
  const [proofs, setProofs] = useState(MOCK_PROOFS)
  const [selectedDevice, setSelectedDevice] = useState('')

  const handleGenerate = async (req: GenerateProofRequest): Promise<Proof> => {
    // Simulate API call
    await new Promise((r) => setTimeout(r, 2000))
    const newProof: Proof = {
      id: `p${Date.now()}`,
      device_id: req.device_id,
      circuit_type: req.circuit_type,
      status: 'completed',
      public_inputs: req.inputs,
      proof_data: '0x' + Math.random().toString(16).slice(2),
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
    }
    setProofs((prev) => [newProof, ...prev])
    return newProof
  }

  const handleVerify = async (data: { proof_id: string; proof_data: string }): Promise<{ verified: boolean }> => {
    // Simulate API call
    await new Promise((r) => setTimeout(r, 1500))
    if (data.proof_id.startsWith('p')) {
      return { verified: true }
    }
    return { verified: false }
  }

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold tracking-tight">ZK Proofs</h1>
        <p className="text-muted-foreground">Generate and verify zero-knowledge proofs for device attestation.</p>
      </div>

      <div className="grid gap-6 lg:grid-cols-2">
        <ProofGenerator deviceId={selectedDevice || undefined} onGenerate={handleGenerate} />
        <ProofVerifier onVerify={handleVerify} />

        {!selectedDevice && (
          <div className="lg:col-span-2">
            <Card>
              <CardHeader>
                <CardTitle className="text-base">Device Selection</CardTitle>
              </CardHeader>
              <CardContent>
                <p className="text-sm text-muted-foreground mb-4">Select a device to generate proofs for:</p>
                <div className="flex flex-wrap gap-2">
                  {['1', '2', '3'].map((id) => (
                    <Badge
                      key={id}
                      variant={selectedDevice === id ? 'default' : 'outline'}
                      className="cursor-pointer"
                      onClick={() => setSelectedDevice(id)}
                    >
                      Device {id}
                    </Badge>
                  ))}
                  {selectedDevice && (
                    <Badge variant="secondary" className="cursor-pointer" onClick={() => setSelectedDevice('')}>
                      Clear
                    </Badge>
                  )}
                </div>
              </CardContent>
            </Card>
          </div>
        )}
      </div>

      <Card>
        <CardHeader>
          <CardTitle className="text-base">Proof History</CardTitle>
        </CardHeader>
        <CardContent>
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead>ID</TableHead>
                <TableHead>Device</TableHead>
                <TableHead>Circuit</TableHead>
                <TableHead>Status</TableHead>
                <TableHead>Verified</TableHead>
                <TableHead>Date</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {proofs.length === 0 ? (
                <TableRow>
                  <TableCell colSpan={6} className="h-24 text-center text-muted-foreground">
                    No proofs generated yet.
                  </TableCell>
                </TableRow>
              ) : (
                proofs.map((proof) => (
                  <TableRow key={proof.id}>
                    <TableCell className="font-mono text-xs">{proof.id}</TableCell>
                    <TableCell className="font-mono text-xs">{proof.device_id}</TableCell>
                    <TableCell className="font-mono text-xs uppercase">{proof.circuit_type}</TableCell>
                    <TableCell>
                      <Badge
                        variant={
                          proof.status === 'completed' ? 'success' :
                          proof.status === 'verified' ? 'success' :
                          proof.status === 'generating' ? 'warning' :
                          'destructive'
                        }
                      >
                        {proof.status}
                      </Badge>
                    </TableCell>
                    <TableCell>
                      {proof.verified !== undefined ? (
                        <Badge variant={proof.verified ? 'success' : 'secondary'}>
                          {proof.verified ? 'Yes' : 'No'}
                        </Badge>
                      ) : (
                        <span className="text-sm text-muted-foreground">-</span>
                      )}
                    </TableCell>
                    <TableCell className="text-sm">{formatDateTime(proof.created_at)}</TableCell>
                  </TableRow>
                ))
              )}
            </TableBody>
          </Table>
        </CardContent>
      </Card>
    </div>
  )
}
