'use client'

import { useState, useEffect } from 'react'
import { useRouter } from 'next/navigation'
import { Button } from '@/components/ui/button'
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogDescription } from '@/components/ui/dialog'
import { DeviceTable } from '@/components/devices/device-table'
import { DeviceForm } from '@/components/devices/device-form'
import type { Device } from '@/types'
import { Plus } from 'lucide-react'

const MOCK_DEVICES: Device[] = [
  { id: '1', tenant_id: 't1', serial_number: 'SN-2024-001', device_name: 'Temp Sensor A1', status: 'active', device_type: 'temperature-sensor', last_seen: '2026-05-17T10:30:00Z', created_at: '2026-01-15T08:00:00Z', updated_at: '2026-05-17T10:30:00Z' },
  { id: '2', tenant_id: 't1', serial_number: 'SN-2024-002', device_name: 'Humidity Sensor B2', status: 'active', device_type: 'humidity-sensor', last_seen: '2026-05-17T09:45:00Z', created_at: '2026-01-20T10:00:00Z', updated_at: '2026-05-17T09:45:00Z' },
  { id: '3', tenant_id: 't1', serial_number: 'SN-2024-003', device_name: 'Motion Detector C1', status: 'inactive', device_type: 'motion-sensor', created_at: '2026-02-10T12:00:00Z', updated_at: '2026-04-28T16:00:00Z' },
  { id: '4', tenant_id: 't1', serial_number: 'SN-2024-004', device_name: 'Door Lock D3', status: 'active', device_type: 'lock', last_seen: '2026-05-17T08:15:00Z', created_at: '2026-03-05T14:00:00Z', updated_at: '2026-05-17T08:15:00Z' },
  { id: '5', tenant_id: 't1', serial_number: 'SN-2024-005', device_name: 'Light Controller E7', status: 'revoked', device_type: 'lighting-controller', created_at: '2026-01-25T09:00:00Z', updated_at: '2026-05-10T11:00:00Z' },
  { id: '6', tenant_id: 't1', serial_number: 'SN-2024-006', device_name: 'Air Quality Monitor F2', status: 'pending', device_type: 'air-quality-sensor', created_at: '2026-05-16T07:00:00Z', updated_at: '2026-05-16T07:00:00Z' },
  { id: '7', tenant_id: 't1', serial_number: 'SN-2024-007', device_name: 'Pressure Sensor G4', status: 'active', device_type: 'pressure-sensor', last_seen: '2026-05-16T22:30:00Z', created_at: '2026-02-28T16:00:00Z', updated_at: '2026-05-16T22:30:00Z' },
  { id: '8', tenant_id: 't1', serial_number: 'SN-2024-008', device_name: 'Camera Hub H1', status: 'compromised', device_type: 'camera', last_seen: '2026-05-15T14:00:00Z', created_at: '2026-03-20T11:00:00Z', updated_at: '2026-05-15T14:00:00Z' },
]

export default function DevicesPage() {
  const router = useRouter()
  const [devices] = useState<Device[]>(MOCK_DEVICES)
  const [showForm, setShowForm] = useState(false)

  const handleView = (device: Device) => {
    router.push(`/dashboard/devices/${device.id}`)
  }

  const handleAttest = (device: Device) => {
    router.push(`/dashboard/attestations?device_id=${device.id}`)
  }

  const handleProve = (device: Device) => {
    router.push(`/dashboard/proofs?device_id=${device.id}`)
  }

  const handleDelete = async (device: Device) => {
    if (confirm(`Delete device "${device.device_name}"?`)) {
      // API call would go here
      console.log('Delete device:', device.id)
    }
  }

  const handleRegister = async (data: Partial<Device>) => {
    // API call would go here
    console.log('Register device:', data)
    setShowForm(false)
  }

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold tracking-tight">Devices</h1>
          <p className="text-muted-foreground">Manage your registered IoT devices.</p>
        </div>
        <Button onClick={() => setShowForm(true)}>
          <Plus className="mr-2 h-4 w-4" />
          Register Device
        </Button>
      </div>

      <DeviceTable
        devices={devices}
        onView={handleView}
        onAttest={handleAttest}
        onProve={handleProve}
        onDelete={handleDelete}
      />

      <Dialog open={showForm} onOpenChange={setShowForm}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Register New Device</DialogTitle>
            <DialogDescription>Add a new device to your tenant.</DialogDescription>
          </DialogHeader>
          <DeviceForm
            onSubmit={handleRegister}
            onCancel={() => setShowForm(false)}
          />
        </DialogContent>
      </Dialog>
    </div>
  )
}
