'use client'

import {
  ChartContainer,
  BarChart,
  Bar,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  ResponsiveContainer,
  CHART_COLORS,
  ChartTooltipContent,
} from '@/components/ui/chart'

interface AnomalyScoreChartProps {
  data: { device: string; score: number }[]
}

export function AnomalyScoreChart({ data }: AnomalyScoreChartProps) {
  return (
    <ChartContainer title="Anomaly Scores by Device" description="Devices with highest anomaly scores">
      <ResponsiveContainer width="100%" height="100%">
        <BarChart data={data} layout="vertical">
          <CartesianGrid strokeDasharray="3 3" className="stroke-muted" />
          <XAxis type="number" domain={[0, 1]} tick={{ fontSize: 12 }} className="text-muted-foreground" />
          <YAxis dataKey="device" type="category" tick={{ fontSize: 12 }} className="text-muted-foreground" />
          <Tooltip content={<ChartTooltipContent formatter={(v) => `${(v * 100).toFixed(1)}%`} />} />
          <Bar dataKey="score" fill={CHART_COLORS.danger} radius={[0, 4, 4, 0]} />
        </BarChart>
      </ResponsiveContainer>
    </ChartContainer>
  )
}
