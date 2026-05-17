'use client'

import { useState } from 'react'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { Badge } from '@/components/ui/badge'
import { Table, TableHeader, TableBody, TableHead, TableRow, TableCell } from '@/components/ui/table'
import { formatDateTime } from '@/lib/utils'
import { ShieldCheck, Loader2, Plus } from 'lucide-react'
import type { Attestation, AttestationStatus } from '@/types'

const MOCK_ATTESTATIONS: Attestation[] = [
  { id: 'a1', device_id: '1', certification_type: 'dac', status: 'verified', challenge: '0xdeadbeef', signature: '0xabcd1234', nonce: '0x0001', verification_result: 'PASS', verified_at: '2026-05-17T10:30:00Z', created_at: '2026-05-17T10:28:00Z' },
  { id: 'a2', device_id: '2', certification_type: 'dac', status: 'verified', challenge: '0xcafebabe', signature: '0x5678efgh', nonce: '0x0002', verification_result: 'PASS', verified_at: '2026-05-16T09:00:00Z', created_at: '2026-05-16T08:55:00Z' },
  { id: 'a3', device_id: '1', certification_type: 'pai', status: 'failed', challenge: '0xbaadf00d', signature: '0x9012ijkl', nonce: '0x0003', verification_result: 'SIGNATURE_MISMATCH', verified_at: '2026-05-15T14:00:00Z', created_at: '2026-05-15T13:55:00Z' },
  { id: 'a4', device_id: '3', certification_type: 'dac', status: 'pending', challenge: '0xfeedface', signature: '', nonce: '0x0004', created_at: '2026-05-14T11:00:00Z' },
  { id: 'a5', device_id: '4', certification_type: 'dac', status: 'verified', challenge: '0xdecafcaf', signature: '0x3456mnop', nonce: '0x0005', verification_result: 'PASS', verified_at: '2026-05-13T16:45:00Z', created_at: '2026-05-13T16:40:00Z' },
]

const statusVariant: Record<AttestationStatus, 'success' | 'destructive' | 'warning' | 'secondary'> = {
  verified: 'success',
  failed: 'destructive',
  pending: 'warning',
  expired: 'secondary',
}

export default function AttestationsPage() {
  const [attestations] = useState(MOCK_ATTESTATIONS)
  const [deviceId, setDeviceId] = useState('')
  const [submitting, setSubmitting] = useState(false)

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!deviceId) return
    setSubmitting(true)
    // Simulate API call
    await new Promise((r) => setTimeout(r, 1500))
    setSubmitting(false)
    setDeviceId('')
  }

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold tracking-tight">Attestations</h1>
        <p className="text-muted-foreground">Submit and verify device attestations.</p>
      </div>

      <div className="grid gap-6 lg:grid-cols-3">
        <Card className="lg:col-span-1">
          <CardHeader>
            <CardTitle className="text-base">Submit Attestation</CardTitle>
            <CardDescription>Initiate a new device attestation</CardDescription>
          </CardHeader>
          <CardContent>
            <form onSubmit={handleSubmit} className="space-y-4">
              <div className="space-y-2">
                <label htmlFor="device-id" className="text-sm font-medium">Device ID</label>
                <Input
                  id="device-id"
                  value={deviceId}
                  onChange={(e) => setDeviceId(e.target.value)}
                  placeholder="Enter device ID"
                  required
                />
              </div>
              <Button type="submit" disabled={submitting} className="w-full">
                {submitting ? (
                  <>
                    <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                    Submitting...
                  </>
                ) : (
                  <>
                    <Plus className="mr-2 h-4 w-4" />
                    Submit Attestation
                  </>
                )}
              </Button>
            </form>
          </CardContent>
        </Card>

        <Card className="lg:col-span-2">
          <CardHeader>
            <CardTitle className="text-base">Attestation History</CardTitle>
            <CardDescription>Recent attestation requests and their status</CardDescription>
          </CardHeader>
          <CardContent>
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>ID</TableHead>
                  <TableHead>Device</TableHead>
                  <TableHead>Type</TableHead>
                  <TableHead>Status</TableHead>
                  <TableHead>Result</TableHead>
                  <TableHead>Date</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {attestations.length === 0 ? (
                  <TableRow>
                    <TableCell colSpan={6} className="h-24 text-center text-muted-foreground">
                      No attestations yet.
                    </TableCell>
                  </TableRow>
                ) : (
                  attestations.map((att) => (
                    <TableRow key={att.id}>
                      <TableCell className="font-mono text-xs">{att.id}</TableCell>
                      <TableCell className="font-mono text-xs">{att.device_id}</TableCell>
                      <TableCell className="font-mono text-xs uppercase">{att.certification_type}</TableCell>
                      <TableCell>
                        <Badge variant={statusVariant[att.status]}>{att.status}</Badge>
                      </TableCell>
                      <TableCell className="text-sm font-mono">{att.verification_result || '-'}</TableCell>
                      <TableCell className="text-sm">{formatDateTime(att.created_at)}</TableCell>
                    </TableRow>
                  ))
                )}
              </TableBody>
            </Table>
          </CardContent>
        </Card>
      </div>
    </div>
  )
}
