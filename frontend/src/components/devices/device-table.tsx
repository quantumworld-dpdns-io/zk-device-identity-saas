'use client'

import { DataTable, type Column } from '@/components/ui/data-table'
import { DeviceStatusBadge } from './device-status-badge'
import { Button } from '@/components/ui/button'
import { MoreHorizontal, Eye, ShieldCheck, Fingerprint, Trash2 } from 'lucide-react'
import { DropdownMenu, DropdownMenuTrigger, DropdownMenuItem, DropdownMenuSeparator } from '@/components/ui/dropdown-menu'
import { type Device } from '@/types'
import { formatDate } from '@/lib/utils'

interface DeviceTableProps {
  devices: Device[]
  onView: (device: Device) => void
  onAttest: (device: Device) => void
  onProve: (device: Device) => void
  onDelete: (device: Device) => void
}

export function DeviceTable({ devices, onView, onAttest, onProve, onDelete }: DeviceTableProps) {
  const columns: Column<Device>[] = [
    {
      key: 'device_name',
      header: 'Name',
      sortable: true,
      filterable: true,
      cell: (device) => <span className="font-medium">{device.device_name}</span>,
    },
    {
      key: 'serial_number',
      header: 'Serial Number',
      sortable: true,
      filterable: true,
      cell: (device) => <span className="font-mono text-xs">{device.serial_number}</span>,
    },
    {
      key: 'device_type',
      header: 'Type',
      sortable: true,
      cell: (device) => device.device_type || '-',
    },
    {
      key: 'status',
      header: 'Status',
      sortable: true,
      cell: (device) => <DeviceStatusBadge status={device.status} />,
    },
    {
      key: 'last_seen',
      header: 'Last Seen',
      sortable: true,
      cell: (device) => (device.last_seen ? formatDate(device.last_seen) : 'Never'),
    },
    {
      key: 'created_at',
      header: 'Created',
      sortable: true,
      cell: (device) => formatDate(device.created_at),
    },
    {
      key: 'actions',
      header: '',
      cell: (device) => (
        <DropdownMenu>
          <DropdownMenuTrigger>
            <Button variant="ghost" size="icon" className="h-8 w-8">
              <MoreHorizontal className="h-4 w-4" />
            </Button>
          </DropdownMenuTrigger>
          <DropdownMenuTrigger>
            <div>
              <DropdownMenuItem onClick={() => onView(device)}>
                <Eye className="mr-2 h-4 w-4" />
                View Details
              </DropdownMenuItem>
              <DropdownMenuItem onClick={() => onAttest(device)}>
                <ShieldCheck className="mr-2 h-4 w-4" />
                Create Attestation
              </DropdownMenuItem>
              <DropdownMenuItem onClick={() => onProve(device)}>
                <Fingerprint className="mr-2 h-4 w-4" />
                Generate Proof
              </DropdownMenuItem>
              <DropdownMenuSeparator />
              <DropdownMenuItem onClick={() => onDelete(device)}>
                <Trash2 className="mr-2 h-4 w-4 text-destructive" />
                <span className="text-destructive">Delete</span>
              </DropdownMenuItem>
            </div>
          </DropdownMenuTrigger>
        </DropdownMenu>
      ),
    },
  ]

  return (
    <DataTable
      columns={columns}
      data={devices}
      searchKeys={['device_name', 'serial_number', 'device_type']}
    />
  )
}
