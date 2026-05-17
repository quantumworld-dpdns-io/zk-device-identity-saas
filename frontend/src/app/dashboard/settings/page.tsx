'use client'

import { useState } from 'react'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { Badge } from '@/components/ui/badge'
import { Copy, Key, Plus, Trash2, Eye, EyeOff } from 'lucide-react'

interface ApiKey {
  id: string
  name: string
  key: string
  created_at: string
  last_used: string | null
  active: boolean
}

const MOCK_API_KEYS: ApiKey[] = [
  { id: 'k1', name: 'Production', key: 'zk_sk_prod_abc123def456...', created_at: '2026-01-15T08:00:00Z', last_used: '2026-05-17T10:30:00Z', active: true },
  { id: 'k2', name: 'Development', key: 'zk_sk_dev_789012ghi345...', created_at: '2026-03-20T14:00:00Z', last_used: '2026-05-16T09:00:00Z', active: true },
  { id: 'k3', name: 'CI/CD Pipeline', key: 'zk_sk_ci_jkl456mno789...', created_at: '2026-04-10T11:00:00Z', last_used: null, active: false },
]

export default function SettingsPage() {
  const [apiKeys, setApiKeys] = useState(MOCK_API_KEYS)
  const [visibleKeys, setVisibleKeys] = useState<Record<string, boolean>>({})
  const [newKeyName, setNewKeyName] = useState('')
  const [showNewKeyForm, setShowNewKeyForm] = useState(false)
  const [mfaEnabled, setMfaEnabled] = useState(false)

  const toggleKeyVisibility = (id: string) => {
    setVisibleKeys((prev) => ({ ...prev, [id]: !prev[id] }))
  }

  const copyKey = (key: string) => {
    navigator.clipboard.writeText(key)
  }

  const revokeKey = (id: string) => {
    setApiKeys((prev) => prev.filter((k) => k.id !== id))
  }

  const generateKey = () => {
    if (!newKeyName) return
    const newKey: ApiKey = {
      id: `k${Date.now()}`,
      name: newKeyName,
      key: `zk_sk_${Math.random().toString(36).slice(2, 10)}${Math.random().toString(36).slice(2, 10)}`,
      created_at: new Date().toISOString(),
      last_used: null,
      active: true,
    }
    setApiKeys((prev) => [...prev, newKey])
    setNewKeyName('')
    setShowNewKeyForm(false)
  }

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold tracking-tight">Settings</h1>
        <p className="text-muted-foreground">Manage your tenant and account settings.</p>
      </div>

      <Card>
        <CardHeader>
          <CardTitle className="text-base">Tenant Profile</CardTitle>
          <CardDescription>Your organization details</CardDescription>
        </CardHeader>
        <CardContent className="space-y-4">
          <div className="grid gap-4 sm:grid-cols-2">
            <div className="space-y-2">
              <label className="text-sm font-medium">Company Name</label>
              <Input defaultValue="Acme Devices Inc." />
            </div>
            <div className="space-y-2">
              <label className="text-sm font-medium">Email</label>
              <Input defaultValue="admin@acme-devices.com" type="email" />
            </div>
          </div>
          <Button>Save Changes</Button>
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <div className="flex items-center justify-between">
            <div>
              <CardTitle className="text-base">API Keys</CardTitle>
              <CardDescription>Manage API keys for programmatic access</CardDescription>
            </div>
            <Button size="sm" onClick={() => setShowNewKeyForm(true)}>
              <Plus className="mr-2 h-4 w-4" />
              Generate Key
            </Button>
          </div>
        </CardHeader>
        <CardContent className="space-y-4">
          {showNewKeyForm && (
            <div className="flex gap-2">
              <Input
                value={newKeyName}
                onChange={(e) => setNewKeyName(e.target.value)}
                placeholder="Key name (e.g., Production)"
              />
              <Button onClick={generateKey} disabled={!newKeyName}>Create</Button>
              <Button variant="outline" onClick={() => setShowNewKeyForm(false)}>Cancel</Button>
            </div>
          )}

          {apiKeys.length === 0 ? (
            <p className="text-sm text-muted-foreground">No API keys generated yet.</p>
          ) : (
            <div className="space-y-3">
              {apiKeys.map((apiKey) => (
                <div key={apiKey.id} className="flex items-center justify-between rounded-lg border p-3">
                  <div className="flex-1">
                    <div className="flex items-center gap-2">
                      <Key className="h-4 w-4 text-muted-foreground" />
                      <span className="text-sm font-medium">{apiKey.name}</span>
                      <Badge variant={apiKey.active ? 'success' : 'secondary'}>
                        {apiKey.active ? 'Active' : 'Revoked'}
                      </Badge>
                    </div>
                    <div className="flex items-center gap-2 mt-1">
                      <code className="text-xs font-mono text-muted-foreground">
                        {visibleKeys[apiKey.id] ? apiKey.key : apiKey.key.slice(0, 20) + '...'}
                      </code>
                      <button onClick={() => toggleKeyVisibility(apiKey.id)} className="text-muted-foreground hover:text-foreground">
                        {visibleKeys[apiKey.id] ? <EyeOff className="h-3 w-3" /> : <Eye className="h-3 w-3" />}
                      </button>
                      <button onClick={() => copyKey(apiKey.key)} className="text-muted-foreground hover:text-foreground">
                        <Copy className="h-3 w-3" />
                      </button>
                    </div>
                    <p className="text-xs text-muted-foreground mt-1">
                      Created: {new Date(apiKey.created_at).toLocaleDateString()}
                      {apiKey.last_used && ` | Last used: ${new Date(apiKey.last_used).toLocaleDateString()}`}
                    </p>
                  </div>
                  <Button variant="ghost" size="icon" onClick={() => revokeKey(apiKey.id)}>
                    <Trash2 className="h-4 w-4 text-destructive" />
                  </Button>
                </div>
              ))}
            </div>
          )}
        </CardContent>
      </Card>

      <div className="grid gap-6 lg:grid-cols-2">
        <Card>
          <CardHeader>
            <CardTitle className="text-base">Notification Preferences</CardTitle>
            <CardDescription>Configure alert notifications</CardDescription>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-sm font-medium">Anomaly Alerts</p>
                <p className="text-xs text-muted-foreground">Receive notifications when anomalies are detected</p>
              </div>
              <label className="relative inline-flex cursor-pointer items-center">
                <input type="checkbox" className="peer sr-only" defaultChecked />
                <div className="h-6 w-11 rounded-full bg-muted after:absolute after:left-[2px] after:top-[2px] after:h-5 after:w-5 after:rounded-full after:border after:border-muted after:bg-background after:transition-all peer-checked:bg-primary peer-checked:after:translate-x-full" />
              </label>
            </div>
            <div className="flex items-center justify-between">
              <div>
                <p className="text-sm font-medium">Attestation Failures</p>
                <p className="text-xs text-muted-foreground">Get notified when attestations fail</p>
              </div>
              <label className="relative inline-flex cursor-pointer items-center">
                <input type="checkbox" className="peer sr-only" defaultChecked />
                <div className="h-6 w-11 rounded-full bg-muted after:absolute after:left-[2px] after:top-[2px] after:h-5 after:w-5 after:rounded-full after:border after:border-muted after:bg-background after:transition-all peer-checked:bg-primary peer-checked:after:translate-x-full" />
              </label>
            </div>
            <div className="flex items-center justify-between">
              <div>
                <p className="text-sm font-medium">Weekly Report</p>
                <p className="text-xs text-muted-foreground">Receive weekly compliance summary</p>
              </div>
              <label className="relative inline-flex cursor-pointer items-center">
                <input type="checkbox" className="peer sr-only" />
                <div className="h-6 w-11 rounded-full bg-muted after:absolute after:left-[2px] after:top-[2px] after:h-5 after:w-5 after:rounded-full after:border after:border-muted after:bg-background after:transition-all peer-checked:bg-primary peer-checked:after:translate-x-full" />
              </label>
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle className="text-base">Security Settings</CardTitle>
            <CardDescription>Manage security preferences</CardDescription>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-sm font-medium">Multi-Factor Authentication</p>
                <p className="text-xs text-muted-foreground">Add an extra layer of security to your account</p>
              </div>
              <label className="relative inline-flex cursor-pointer items-center">
                <input
                  type="checkbox"
                  className="peer sr-only"
                  checked={mfaEnabled}
                  onChange={() => setMfaEnabled(!mfaEnabled)}
                />
                <div className="h-6 w-11 rounded-full bg-muted after:absolute after:left-[2px] after:top-[2px] after:h-5 after:w-5 after:rounded-full after:border after:border-muted after:bg-background after:transition-all peer-checked:bg-primary peer-checked:after:translate-x-full" />
              </label>
            </div>
            {mfaEnabled && (
              <div className="rounded-md bg-muted p-3">
                <p className="text-sm text-muted-foreground">
                  MFA is enabled. Use an authenticator app to generate codes.
                </p>
              </div>
            )}
            <div className="flex items-center justify-between">
              <div>
                <p className="text-sm font-medium">Session Timeout</p>
                <p className="text-xs text-muted-foreground">Automatically log out after inactivity</p>
              </div>
              <select className="rounded-md border border-input bg-background px-3 py-1 text-sm">
                <option>30 minutes</option>
                <option>1 hour</option>
                <option>4 hours</option>
                <option>8 hours</option>
              </select>
            </div>
          </CardContent>
        </Card>
      </div>
    </div>
  )
}
