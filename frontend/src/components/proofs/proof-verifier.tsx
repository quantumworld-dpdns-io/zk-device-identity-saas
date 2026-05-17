'use client'

import { useState } from 'react'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { Badge } from '@/components/ui/badge'
import { Loader2, CheckCircle, XCircle } from 'lucide-react'

interface ProofVerifierProps {
  onVerify: (data: { proof_id: string; proof_data: string }) => Promise<{ verified: boolean }>
}

export function ProofVerifier({ onVerify }: ProofVerifierProps) {
  const [proofId, setProofId] = useState('')
  const [proofData, setProofData] = useState('')
  const [verifying, setVerifying] = useState(false)
  const [result, setResult] = useState<{ verified: boolean; error?: string } | null>(null)

  const handleVerify = async () => {
    if (!proofId || !proofData) return
    setVerifying(true)
    setResult(null)

    try {
      const res = await onVerify({ proof_id: proofId, proof_data: proofData })
      setResult({ verified: res.verified })
    } catch (err) {
      setResult({ verified: false, error: err instanceof Error ? err.message : 'Verification failed' })
    } finally {
      setVerifying(false)
    }
  }

  return (
    <Card>
      <CardHeader>
        <CardTitle>Verify Proof</CardTitle>
        <CardDescription>Paste a proof ID and data to verify its validity</CardDescription>
      </CardHeader>
      <CardContent className="space-y-4">
        <div className="space-y-2">
          <label htmlFor="proof-id" className="text-sm font-medium">Proof ID</label>
          <Input
            id="proof-id"
            value={proofId}
            onChange={(e) => setProofId(e.target.value)}
            placeholder="Enter proof ID"
          />
        </div>

        <div className="space-y-2">
          <label htmlFor="proof-data" className="text-sm font-medium">Proof Data</label>
          <textarea
            id="proof-data"
            className="flex min-h-[100px] w-full rounded-md border border-input bg-background px-3 py-2 text-sm font-mono ring-offset-background placeholder:text-muted-foreground focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2"
            value={proofData}
            onChange={(e) => setProofData(e.target.value)}
            placeholder="Paste proof data here..."
          />
        </div>

        <Button onClick={handleVerify} disabled={verifying || !proofId || !proofData}>
          {verifying ? (
            <>
              <Loader2 className="mr-2 h-4 w-4 animate-spin" />
              Verifying...
            </>
          ) : (
            'Verify Proof'
          )}
        </Button>

        {result && (
          <div className={`rounded-md border p-4 ${result.verified ? 'border-emerald-200 bg-emerald-50 dark:bg-emerald-900/20' : 'border-red-200 bg-red-50 dark:bg-red-900/20'}`}>
            <div className="flex items-center gap-2">
              {result.verified ? (
                <>
                  <CheckCircle className="h-5 w-5 text-emerald-600" />
                  <span className="font-medium text-emerald-700 dark:text-emerald-300">Proof Verified</span>
                </>
              ) : (
                <>
                  <XCircle className="h-5 w-5 text-red-600" />
                  <span className="font-medium text-red-700 dark:text-red-300">Verification Failed</span>
                </>
              )}
            </div>
            {result.error && (
              <p className="mt-1 text-sm text-red-600 dark:text-red-400">{result.error}</p>
            )}
          </div>
        )}
      </CardContent>
    </Card>
  )
}
