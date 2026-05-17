'use client'

import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Badge } from '@/components/ui/badge'
import { AttestationTrend } from '@/components/charts/attestation-trend'
import { AnomalyScoreChart } from '@/components/charts/anomaly-score-chart'
import { Download } from 'lucide-react'

const attestationTrendData = [
  { date: 'May 11', count: 12 },
  { date: 'May 12', count: 18 },
  { date: 'May 13', count: 8 },
  { date: 'May 14', count: 25 },
  { date: 'May 15', count: 30 },
  { date: 'May 16', count: 22 },
  { date: 'May 17', count: 28 },
]

const anomalyData = [
  { device: 'Camera Hub H1', score: 0.87 },
  { device: 'Door Lock D3', score: 0.72 },
  { device: 'Temp Sensor A1', score: 0.45 },
  { device: 'Light Controller E7', score: 0.31 },
  { device: 'Motion Detector C1', score: 0.22 },
  { device: 'Humidity Sensor B2', score: 0.15 },
]

const anomalyResults = [
  { device: 'Camera Hub H1', score: 0.87, severity: 'high', details: 'Unusual network traffic pattern detected. 15x increase in attestation requests in last 24h.', detected: '2026-05-17T08:30:00Z' },
  { device: 'Door Lock D3', score: 0.72, severity: 'high', details: 'Repeated failed authentication attempts from unknown IP range.', detected: '2026-05-17T06:15:00Z' },
  { device: 'Temp Sensor A1', score: 0.45, severity: 'medium', details: 'Slight deviation in attestation timing pattern.', detected: '2026-05-16T22:00:00Z' },
]

export default function AnalyticsPage() {
  const handleExport = () => {
    // Create CSV and trigger download
    const headers = ['device', 'anomaly_score', 'severity', 'detected_at']
    const rows = anomalyResults.map((r) => [r.device, r.score, r.severity, r.detected])
    const csv = [headers.join(','), ...rows.map((r) => r.join(','))].join('\n')
    const blob = new Blob([csv], { type: 'text/csv' })
    const url = URL.createObjectURL(blob)
    const a = document.createElement('a')
    a.href = url
    a.download = 'anomaly-report.csv'
    a.click()
    URL.revokeObjectURL(url)
  }

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold tracking-tight">Analytics</h1>
          <p className="text-muted-foreground">Anomaly detection and compliance analytics.</p>
        </div>
        <Button onClick={handleExport}>
          <Download className="mr-2 h-4 w-4" />
          Export Data
        </Button>
      </div>

      <div className="grid gap-6 lg:grid-cols-2">
        <Card>
          <CardHeader>
            <CardTitle className="text-base">Attestation Trends</CardTitle>
            <CardDescription>Daily attestation volume over time</CardDescription>
          </CardHeader>
          <CardContent>
            <AttestationTrend data={attestationTrendData} />
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle className="text-base">Anomaly Scores by Device</CardTitle>
            <CardDescription>Devices ranked by anomalous behavior score</CardDescription>
          </CardHeader>
          <CardContent>
            <AnomalyScoreChart data={anomalyData} />
          </CardContent>
        </Card>
      </div>

      <Card>
        <CardHeader>
          <CardTitle className="text-base">Anomaly Detection Results</CardTitle>
          <CardDescription>Detected anomalies from Julia analysis engine</CardDescription>
        </CardHeader>
        <CardContent>
          <div className="space-y-4">
            {anomalyResults.map((result, i) => (
              <div key={i} className="rounded-lg border p-4">
                <div className="flex items-center justify-between mb-2">
                  <div className="flex items-center gap-2">
                    <span className="font-medium">{result.device}</span>
                    <Badge variant={result.severity === 'high' ? 'destructive' : 'warning'}>
                      {result.severity.toUpperCase()}
                    </Badge>
                  </div>
                  <span className="text-sm font-mono text-muted-foreground">
                    Score: {(result.score * 100).toFixed(0)}%
                  </span>
                </div>
                <p className="text-sm text-muted-foreground">{result.details}</p>
                <p className="text-xs text-muted-foreground mt-2">
                  Detected: {new Date(result.detected).toLocaleString()}
                </p>
              </div>
            ))}
          </div>
        </CardContent>
      </Card>
    </div>
  )
}
