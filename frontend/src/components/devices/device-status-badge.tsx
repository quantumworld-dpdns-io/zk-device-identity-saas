import { Badge } from '@/components/ui/badge'
import { type DeviceStatus } from '@/types'

const statusConfig: Record<DeviceStatus, { variant: 'success' | 'warning' | 'destructive' | 'info' | 'secondary'; label: string }> = {
  active: { variant: 'success', label: 'Active' },
  inactive: { variant: 'secondary', label: 'Inactive' },
  revoked: { variant: 'destructive', label: 'Revoked' },
  compromised: { variant: 'destructive', label: 'Compromised' },
  pending: { variant: 'warning', label: 'Pending' },
}

interface DeviceStatusBadgeProps {
  status: DeviceStatus
}

export function DeviceStatusBadge({ status }: DeviceStatusBadgeProps) {
  const config = statusConfig[status] || statusConfig.pending
  return (
    <Badge variant={config.variant}>
      {config.label}
    </Badge>
  )
}
