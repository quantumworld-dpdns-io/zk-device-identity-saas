'use client'

import { useState } from 'react'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { Badge } from '@/components/ui/badge'
import { CircuitType, type Proof, type GenerateProofRequest } from '@/types'
import { Loader2 } from 'lucide-react'

interface ProofGeneratorProps {
  deviceId?: string
  onGenerate: (req: GenerateProofRequest) => Promise<Proof>
}

const circuitOptions = [
  { value: CircuitType.DAC, label: 'DAC Attestation' },
  { value: CircuitType.PAI, label: 'PAI Attestation' },
  { value: CircuitType.PAA, label: 'PAA Attestation' },
  { value: CircuitType.COMPLIANCE, label: 'Compliance' },
  { value: CircuitType.ANOMALY, label: 'Anomaly Detection' },
]

export function ProofGenerator({ deviceId, onGenerate }: ProofGeneratorProps) {
  const [circuit, setCircuit] = useState<CircuitType>(CircuitType.DAC)
  const [inputs, setInputs] = useState<string>('{}')
  const [generating, setGenerating] = useState(false)
  const [result, setResult] = useState<Proof | null>(null)
  const [error, setError] = useState('')

  const handleGenerate = async () => {
    if (!deviceId) return
    setError('')
    setGenerating(true)

    try {
      const parsed = JSON.parse(inputs)
      const proof = await onGenerate({
        device_id: deviceId,
        circuit_type: circuit,
        inputs: parsed,
      })
      setResult(proof)
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Generation failed')
    } finally {
      setGenerating(false)
    }
  }

  return (
    <Card>
      <CardHeader>
        <CardTitle>Generate ZK Proof</CardTitle>
        <CardDescription>Select a circuit and provide inputs to generate a zero-knowledge proof</CardDescription>
      </CardHeader>
      <CardContent className="space-y-4">
        {!deviceId && (
          <div className="rounded-md bg-amber-50 p-3 text-sm text-amber-800 dark:bg-amber-900/20 dark:text-amber-200">
            Select a device first to generate proofs.
          </div>
        )}

        <div className="space-y-2">
          <label className="text-sm font-medium">Circuit Type</label>
          <div className="grid grid-cols-2 gap-2">
            {circuitOptions.map((opt) => (
              <Button
                key={opt.value}
                type="button"
                variant={circuit === opt.value ? 'default' : 'outline'}
                size="sm"
                onClick={() => setCircuit(opt.value)}
              >
                {opt.label}
              </Button>
            ))}
          </div>
        </div>

        <div className="space-y-2">
          <label className="text-sm font-medium">Public Inputs (JSON)</label>
          <textarea
            className="flex min-h-[120px] w-full rounded-md border border-input bg-background px-3 py-2 text-sm font-mono ring-offset-background placeholder:text-muted-foreground focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 disabled:cursor-not-allowed disabled:opacity-50"
            value={inputs}
            onChange={(e) => setInputs(e.target.value)}
            placeholder='{"device_id": "..."}'
          />
        </div>

        <Button onClick={handleGenerate} disabled={generating || !deviceId}>
          {generating ? (
            <>
              <Loader2 className="mr-2 h-4 w-4 animate-spin" />
              Generating...
            </>
          ) : (
            'Generate Proof'
          )}
        </Button>

        {error && (
          <div className="rounded-md bg-destructive/10 p-3 text-sm text-destructive">
            {error}
          </div>
        )}

        {result && (
          <div className="rounded-md border p-3">
            <div className="flex items-center justify-between mb-2">
              <span className="text-sm font-medium">Proof Generated</span>
              <Badge variant={result.status === 'completed' ? 'success' : 'warning'}>
                {result.status}
              </Badge>
            </div>
            <p className="text-xs text-muted-foreground break-all font-mono">
              ID: {result.id}
            </p>
            {result.proof_data && (
              <p className="text-xs text-muted-foreground break-all font-mono mt-1">
                Proof: {result.proof_data.substring(0, 64)}...
              </p>
            )}
          </div>
        )}
      </CardContent>
    </Card>
  )
}
