'use client'

import { useState, useEffect } from 'react'
import { useParams, useRouter } from 'next/navigation'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { Badge } from '@/components/ui/badge'
import { Table, TableHeader, TableBody, TableHead, TableRow, TableCell } from '@/components/ui/table'
import { DeviceStatusBadge } from '@/components/devices/device-status-badge'
import { formatDateTime } from '@/lib/utils'
import { ArrowLeft, Fingerprint, ShieldCheck, Trash2 } from 'lucide-react'
import type { Device, Certificate, Attestation, Proof } from '@/types'
import { CertType } from '@/types'

const MOCK_DEVICE: Device = {
  id: '1', tenant_id: 't1', serial_number: 'SN-2024-001', device_name: 'Temp Sensor A1',
  status: 'active', device_type: 'temperature-sensor',
  last_seen: '2026-05-17T10:30:00Z', created_at: '2026-01-15T08:00:00Z', updated_at: '2026-05-17T10:30:00Z',
  fingerprint_id: 'fp-001',
  fingerprint: {
    id: 'fp-001', device_id: '1', serial_number: 'SN-2024-001', manufacturer: 'Acme Sensors Inc.',
    model: 'TS-2000', firmware_version: 'v2.1.4', hardware_version: 'rev-b', public_key: '0x04a1b2c3d4e5f6...',
    created_at: '2026-01-15T08:00:00Z', updated_at: '2026-05-17T10:30:00Z',
  },
}

const MOCK_CERTS: Certificate[] = [
  { id: 'c1', device_id: '1', cert_type: CertType.DAC, certificate: '-----BEGIN CERTIFICATE-----\nMIIB...', subject: 'CN=TS-2000,SN=SN-2024-001', issuer: 'CN=Acme PAI', serial_number: '0xABCD', not_before: '2026-01-15T00:00:00Z', not_after: '2031-01-15T00:00:00Z', is_valid: true, created_at: '2026-01-15T08:00:00Z' },
  { id: 'c2', device_id: '1', cert_type: CertType.PAI, certificate: '-----BEGIN CERTIFICATE-----\nMIIB...', subject: 'CN=Acme PAI', issuer: 'CN=Matter PAA', serial_number: '0x1234', not_before: '2025-06-01T00:00:00Z', not_after: '2030-06-01T00:00:00Z', is_valid: true, created_at: '2025-06-01T00:00:00Z' },
  { id: 'c3', device_id: '1', cert_type: CertType.PAA, certificate: '-----BEGIN CERTIFICATE-----\nMIIB...', subject: 'CN=Matter PAA', issuer: 'CN=Matter Root CA', serial_number: '0x5678', not_before: '2025-01-01T00:00:00Z', not_after: '2035-01-01T00:00:00Z', is_valid: true, created_at: '2025-01-01T00:00:00Z' },
]

const MOCK_ATTESTATIONS: Attestation[] = [
  { id: 'a1', device_id: '1', certification_type: 'dac', status: 'verified', challenge: '0xdeadbeef', signature: '0xabcd1234', nonce: '0x0001', verification_result: 'PASS', verified_at: '2026-05-17T10:30:00Z', created_at: '2026-05-17T10:28:00Z' },
  { id: 'a2', device_id: '1', certification_type: 'dac', status: 'verified', challenge: '0xcafebabe', signature: '0x5678efgh', nonce: '0x0002', verification_result: 'PASS', verified_at: '2026-05-16T09:00:00Z', created_at: '2026-05-16T08:55:00Z' },
  { id: 'a3', device_id: '1', certification_type: 'pai', status: 'failed', challenge: '0xbaadf00d', signature: '0x9012ijkl', nonce: '0x0003', verification_result: 'SIGNATURE_MISMATCH', verified_at: '2026-05-15T14:00:00Z', created_at: '2026-05-15T13:55:00Z' },
]

const MOCK_PROOFS: Proof[] = [
  { id: 'p1', device_id: '1', circuit_type: 'dac' as any, status: 'verified', public_inputs: { serial_number: 'SN-2024-001' }, proof_data: '0xabc123...', verified: true, created_at: '2026-05-17T10:30:00Z', updated_at: '2026-05-17T10:31:00Z' },
  { id: 'p2', device_id: '1', circuit_type: 'compliance' as any, status: 'completed', public_inputs: { batch: 'B3' }, proof_data: '0xdef456...', created_at: '2026-05-16T11:00:00Z', updated_at: '2026-05-16T11:02:00Z' },
]

export default function DeviceDetailPage() {
  const params = useParams()
  const router = useRouter()
  const [device, setDevice] = useState<Device | null>(null)

  useEffect(() => {
    // Simulate API call
    setDevice(MOCK_DEVICE)
  }, [params.id])

  if (!device) {
    return (
      <div className="flex items-center justify-center h-64">
        <p className="text-muted-foreground">Loading device...</p>
      </div>
    )
  }

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-4">
          <Button variant="ghost" size="icon" onClick={() => router.back()}>
            <ArrowLeft className="h-5 w-5" />
          </Button>
          <div>
            <h1 className="text-2xl font-bold tracking-tight">{device.device_name}</h1>
            <p className="text-sm text-muted-foreground font-mono">{device.serial_number}</p>
          </div>
          <DeviceStatusBadge status={device.status} />
        </div>
        <div className="flex gap-2">
          <Button variant="outline" size="sm">
            <ShieldCheck className="mr-2 h-4 w-4" />
            Attest
          </Button>
          <Button variant="outline" size="sm">
            <Fingerprint className="mr-2 h-4 w-4" />
            Generate Proof
          </Button>
          <Button variant="destructive" size="sm">
            <Trash2 className="mr-2 h-4 w-4" />
            Delete
          </Button>
        </div>
      </div>

      <div className="grid gap-6 lg:grid-cols-2">
        <Card>
          <CardHeader>
            <CardTitle className="text-base">Device Information</CardTitle>
          </CardHeader>
          <CardContent className="space-y-3">
            <div className="flex justify-between">
              <span className="text-sm text-muted-foreground">Type</span>
              <span className="text-sm font-medium">{device.device_type}</span>
            </div>
            <div className="flex justify-between">
              <span className="text-sm text-muted-foreground">Manufacturer</span>
              <span className="text-sm font-medium">{device.fingerprint?.manufacturer || '-'}</span>
            </div>
            <div className="flex justify-between">
              <span className="text-sm text-muted-foreground">Model</span>
              <span className="text-sm font-medium">{device.fingerprint?.model || '-'}</span>
            </div>
            <div className="flex justify-between">
              <span className="text-sm text-muted-foreground">Firmware</span>
              <span className="text-sm font-medium">{device.fingerprint?.firmware_version || '-'}</span>
            </div>
            <div className="flex justify-between">
              <span className="text-sm text-muted-foreground">Hardware</span>
              <span className="text-sm font-medium">{device.fingerprint?.hardware_version || '-'}</span>
            </div>
            <div className="flex justify-between">
              <span className="text-sm text-muted-foreground">Last Seen</span>
              <span className="text-sm font-medium">{device.last_seen ? formatDateTime(device.last_seen) : 'Never'}</span>
            </div>
            <div className="flex justify-between">
              <span className="text-sm text-muted-foreground">Created</span>
              <span className="text-sm font-medium">{formatDateTime(device.created_at)}</span>
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle className="text-base">Fingerprint Details</CardTitle>
          </CardHeader>
          <CardContent className="space-y-3">
            <div className="flex justify-between">
              <span className="text-sm text-muted-foreground">Fingerprint ID</span>
              <span className="text-sm font-mono">{device.fingerprint?.id || '-'}</span>
            </div>
            <div className="flex justify-between">
              <span className="text-sm text-muted-foreground">Serial Number</span>
              <span className="text-sm font-mono">{device.fingerprint?.serial_number || '-'}</span>
            </div>
            <div className="space-y-1">
              <span className="text-sm text-muted-foreground">Public Key</span>
              <p className="text-xs font-mono break-all bg-muted rounded p-2">{device.fingerprint?.public_key || 'N/A'}</p>
            </div>
          </CardContent>
        </Card>
      </div>

      <Card>
        <CardHeader>
          <CardTitle className="text-base">Certificate Chain</CardTitle>
          <CardDescription>DAC, PAI, PAA certificates for this device</CardDescription>
        </CardHeader>
        <CardContent>
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead>Type</TableHead>
                <TableHead>Subject</TableHead>
                <TableHead>Issuer</TableHead>
                <TableHead>Valid Until</TableHead>
                <TableHead>Status</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {MOCK_CERTS.map((cert) => (
                <TableRow key={cert.id}>
                  <TableCell>
                    <Badge variant={cert.cert_type === CertType.DAC ? 'default' : cert.cert_type === CertType.PAI ? 'secondary' : 'outline'}>
                      {cert.cert_type.toUpperCase()}
                    </Badge>
                  </TableCell>
                  <TableCell className="font-mono text-xs">{cert.subject}</TableCell>
                  <TableCell className="font-mono text-xs">{cert.issuer}</TableCell>
                  <TableCell className="text-sm">{formatDateTime(cert.not_after)}</TableCell>
                  <TableCell>
                    <Badge variant={cert.is_valid ? 'success' : 'destructive'}>
                      {cert.is_valid ? 'Valid' : 'Expired'}
                    </Badge>
                  </TableCell>
                </TableRow>
              ))}
            </TableBody>
          </Table>
        </CardContent>
      </Card>

      <div className="grid gap-6 lg:grid-cols-2">
        <Card>
          <CardHeader>
            <CardTitle className="text-base">Attestation History</CardTitle>
          </CardHeader>
          <CardContent>
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>Type</TableHead>
                  <TableHead>Status</TableHead>
                  <TableHead>Date</TableHead>
                  <TableHead>Result</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {MOCK_ATTESTATIONS.map((att) => (
                  <TableRow key={att.id}>
                    <TableCell className="font-mono text-xs">{att.certification_type.toUpperCase()}</TableCell>
                    <TableCell>
                      <Badge variant={att.status === 'verified' ? 'success' : att.status === 'failed' ? 'destructive' : 'warning'}>
                        {att.status}
                      </Badge>
                    </TableCell>
                    <TableCell className="text-sm">{formatDateTime(att.created_at)}</TableCell>
                    <TableCell className="text-sm font-mono">{att.verification_result || '-'}</TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle className="text-base">Proof History</CardTitle>
          </CardHeader>
          <CardContent>
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>Circuit</TableHead>
                  <TableHead>Status</TableHead>
                  <TableHead>Date</TableHead>
                  <TableHead>Verified</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {MOCK_PROOFS.map((proof) => (
                  <TableRow key={proof.id}>
                    <TableCell className="font-mono text-xs">{proof.circuit_type}</TableCell>
                    <TableCell>
                      <Badge variant={proof.status === 'verified' ? 'success' : proof.status === 'completed' ? 'info' : proof.status === 'generating' ? 'warning' : 'destructive'}>
                        {proof.status}
                      </Badge>
                    </TableCell>
                    <TableCell className="text-sm">{formatDateTime(proof.created_at)}</TableCell>
                    <TableCell>
                      {proof.verified !== undefined ? (
                        <Badge variant={proof.verified ? 'success' : 'destructive'}>
                          {proof.verified ? 'Yes' : 'No'}
                        </Badge>
                      ) : (
                        <span className="text-sm text-muted-foreground">-</span>
                      )}
                    </TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          </CardContent>
        </Card>
      </div>
    </div>
  )
}
