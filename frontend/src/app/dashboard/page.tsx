'use client'

import { useState, useEffect } from 'react'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { AttestationTrend } from '@/components/charts/attestation-trend'
import { DeviceStatusPie } from '@/components/charts/device-status-pie'
import { Badge } from '@/components/ui/badge'
import { Cpu, ShieldCheck, Fingerprint, AlertTriangle } from 'lucide-react'
import { formatDateTime } from '@/lib/utils'
import apiClient from '@/lib/api-client'
import { type DeviceStats, type AttestationStats, type ProofStats } from '@/types'

const chartData = [
  { date: 'May 11', count: 12 },
  { date: 'May 12', count: 18 },
  { date: 'May 13', count: 8 },
  { date: 'May 14', count: 25 },
  { date: 'May 15', count: 30 },
  { date: 'May 16', count: 22 },
  { date: 'May 17', count: 28 },
]

const pieData = [
  { name: 'Active', value: 145 },
  { name: 'Inactive', value: 23 },
  { name: 'Revoked', value: 7 },
  { name: 'Compromised', value: 2 },
  { name: 'Pending', value: 12 },
]

const recentActivity = [
  { action: 'Device registered', detail: 'Temperature Sensor #TS-2024-042', time: '2 minutes ago' },
  { action: 'Attestation verified', detail: 'Device: SN-2024-001', time: '15 minutes ago' },
  { action: 'ZK Proof generated', detail: 'Compliance proof for batch #B3', time: '1 hour ago' },
  { action: 'Anomaly detected', detail: 'Device: SN-2024-089 (score: 0.87)', time: '2 hours ago' },
  { action: 'Certificate revoked', detail: 'Device: SN-2024-012', time: '3 hours ago' },
  { action: 'Bulk attestation completed', detail: '12 devices verified', time: '5 hours ago' },
]

export default function DashboardPage() {
  const [deviceStats, setDeviceStats] = useState<DeviceStats | null>(null)
  const [attestationStats, setAttestationStats] = useState<AttestationStats | null>(null)
  const [proofStats, setProofStats] = useState<ProofStats | null>(null)

  useEffect(() => {
    const fetchStats = async () => {
      try {
        const [devicesRes, attestationsRes, proofsRes] = await Promise.all([
          apiClient.get('/api/v1/devices/stats'),
          apiClient.get('/api/v1/attestations/stats'),
          apiClient.get('/api/v1/proofs/stats'),
        ])
        setDeviceStats(devicesRes.data.data)
        setAttestationStats(attestationsRes.data.data)
        setProofStats(proofsRes.data.data)
      } catch {
        // Use default values if API is unavailable
        setDeviceStats({ total: 189, active: 145, inactive: 23, revoked: 7, compromised: 2, pending: 12 })
        setAttestationStats({ total: 1432, pending: 45, verified: 1340, failed: 32, expired: 15 })
        setProofStats({ total: 892, generating: 3, completed: 856, failed: 18, verified: 15 })
      }
    }
    fetchStats()
  }, [])

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold tracking-tight">Dashboard Overview</h1>
        <p className="text-muted-foreground">Welcome to your device identity management console.</p>
      </div>

      <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-4">
        <Card>
          <CardHeader className="flex flex-row items-center justify-between pb-2">
            <CardTitle className="text-sm font-medium">Total Devices</CardTitle>
            <Cpu className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{deviceStats?.total ?? '-'}</div>
            <p className="text-xs text-muted-foreground">
              {deviceStats?.active ?? 0} active
            </p>
          </CardContent>
        </Card>
        <Card>
          <CardHeader className="flex flex-row items-center justify-between pb-2">
            <CardTitle className="text-sm font-medium">Attestations</CardTitle>
            <ShieldCheck className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{attestationStats?.total ?? '-'}</div>
            <p className="text-xs text-muted-foreground">
              {attestationStats?.verified ?? 0} verified
            </p>
          </CardContent>
        </Card>
        <Card>
          <CardHeader className="flex flex-row items-center justify-between pb-2">
            <CardTitle className="text-sm font-medium">ZK Proofs</CardTitle>
            <Fingerprint className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{proofStats?.total ?? '-'}</div>
            <p className="text-xs text-muted-foreground">
              {proofStats?.completed ?? 0} completed
            </p>
          </CardContent>
        </Card>
        <Card>
          <CardHeader className="flex flex-row items-center justify-between pb-2">
            <CardTitle className="text-sm font-medium">Anomalies</CardTitle>
            <AlertTriangle className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">3</div>
            <p className="text-xs text-muted-foreground">2 high severity</p>
          </CardContent>
        </Card>
      </div>

      <div className="grid gap-6 lg:grid-cols-7">
        <div className="lg:col-span-4">
          <Card>
            <CardHeader>
              <CardTitle className="text-base">Attestation Trend</CardTitle>
            </CardHeader>
            <CardContent>
              <AttestationTrend data={chartData} />
            </CardContent>
          </Card>
        </div>

        <div className="lg:col-span-3">
          <Card>
            <CardHeader>
              <CardTitle className="text-base">Device Status</CardTitle>
            </CardHeader>
            <CardContent>
              <DeviceStatusPie data={pieData} />
            </CardContent>
          </Card>
        </div>
      </div>

      <Card>
        <CardHeader>
          <CardTitle className="text-base">Recent Activity</CardTitle>
        </CardHeader>
        <CardContent>
          <div className="space-y-4">
            {recentActivity.map((activity, i) => (
              <div key={i} className="flex items-center justify-between border-b pb-3 last:border-0 last:pb-0">
                <div>
                  <p className="text-sm font-medium">{activity.action}</p>
                  <p className="text-xs text-muted-foreground">{activity.detail}</p>
                </div>
                <Badge variant="secondary" className="shrink-0">{activity.time}</Badge>
              </div>
            ))}
          </div>
        </CardContent>
      </Card>
    </div>
  )
}
