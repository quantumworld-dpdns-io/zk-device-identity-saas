'use client'

import { useState } from 'react'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { type Device } from '@/types'

interface DeviceFormProps {
  device?: Device
  onSubmit: (data: Partial<Device>) => Promise<void>
  onCancel: () => void
}

export function DeviceForm({ device, onSubmit, onCancel }: DeviceFormProps) {
  const [formData, setFormData] = useState({
    device_name: device?.device_name || '',
    serial_number: device?.serial_number || '',
    device_type: device?.device_type || '',
  })
  const [loading, setLoading] = useState(false)

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    setLoading(true)
    try {
      await onSubmit(formData)
    } finally {
      setLoading(false)
    }
  }

  return (
    <Card>
      <CardHeader>
        <CardTitle>{device ? 'Edit Device' : 'Register Device'}</CardTitle>
        <CardDescription>
          {device ? 'Update device information' : 'Add a new device to your tenant'}
        </CardDescription>
      </CardHeader>
      <CardContent>
        <form onSubmit={handleSubmit} className="space-y-4">
          <div className="space-y-2">
            <label htmlFor="device_name" className="text-sm font-medium">Device Name</label>
            <Input
              id="device_name"
              value={formData.device_name}
              onChange={(e) => setFormData({ ...formData, device_name: e.target.value })}
              placeholder="Living Room Sensor"
              required
            />
          </div>
          <div className="space-y-2">
            <label htmlFor="serial_number" className="text-sm font-medium">Serial Number</label>
            <Input
              id="serial_number"
              value={formData.serial_number}
              onChange={(e) => setFormData({ ...formData, serial_number: e.target.value })}
              placeholder="SN-2024-001"
              required
            />
          </div>
          <div className="space-y-2">
            <label htmlFor="device_type" className="text-sm font-medium">Device Type</label>
            <Input
              id="device_type"
              value={formData.device_type}
              onChange={(e) => setFormData({ ...formData, device_type: e.target.value })}
              placeholder="temperature-sensor"
            />
          </div>
          <div className="flex gap-3 pt-2">
            <Button type="submit" disabled={loading}>
              {loading ? 'Saving...' : device ? 'Update Device' : 'Register Device'}
            </Button>
            <Button type="button" variant="outline" onClick={onCancel}>
              Cancel
            </Button>
          </div>
        </form>
      </CardContent>
    </Card>
  )
}
