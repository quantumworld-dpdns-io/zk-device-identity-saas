'use client'

import {
  LineChart,
  Line,
  BarChart,
  Bar,
  PieChart,
  Pie,
  Cell,
  AreaChart,
  Area,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  Legend,
  ResponsiveContainer,
  type TooltipProps,
} from 'recharts'
import { cn } from '@/lib/utils'

const CHART_COLORS = {
  primary: 'hsl(221.2, 83.2%, 53.3%)',
  secondary: 'hsl(210, 40%, 96.1%)',
  success: '#22c55e',
  warning: '#f59e0b',
  danger: '#ef4444',
  info: '#3b82f6',
}

const CHART_COLORS_ARRAY = [
  CHART_COLORS.primary,
  CHART_COLORS.success,
  CHART_COLORS.warning,
  CHART_COLORS.danger,
  CHART_COLORS.info,
  '#8b5cf6',
  '#ec4899',
  '#14b8a6',
]

interface ChartContainerProps {
  title?: string
  description?: string
  className?: string
  children: React.ReactNode
}

export function ChartContainer({ title, description, className, children }: ChartContainerProps) {
  return (
    <div className={cn('space-y-4', className)}>
      {(title || description) && (
        <div>
          {title && <h3 className="text-sm font-medium">{title}</h3>}
          {description && <p className="text-xs text-muted-foreground">{description}</p>}
        </div>
      )}
      <div className="h-[300px] w-full">{children}</div>
    </div>
  )
}

interface ChartTooltipContentProps extends TooltipProps<number, string> {
  label?: string
  formatter?: (value: number) => string
}

export function ChartTooltipContent({ active, payload, label, formatter }: ChartTooltipContentProps) {
  if (!active || !payload?.length) return null
  return (
    <div className="rounded-lg border bg-background p-2 shadow-sm">
      <p className="text-xs text-muted-foreground mb-1">{label}</p>
      {payload.map((entry, i) => (
        <p key={i} className="text-sm font-medium" style={{ color: entry.color }}>
          {entry.name}: {formatter ? formatter(entry.value as number) : entry.value}
        </p>
      ))}
    </div>
  )
}

export {
  LineChart,
  Line,
  BarChart,
  Bar,
  PieChart,
  Pie,
  Cell,
  AreaChart,
  Area,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  Legend,
  ResponsiveContainer,
  CHART_COLORS,
  CHART_COLORS_ARRAY,
}
