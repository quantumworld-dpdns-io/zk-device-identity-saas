'use client'

import {
  ChartContainer,
  PieChart,
  Pie,
  Cell,
  Tooltip,
  ResponsiveContainer,
  CHART_COLORS_ARRAY,
  ChartTooltipContent,
} from '@/components/ui/chart'

interface DeviceStatusPieProps {
  data: { name: string; value: number }[]
}

export function DeviceStatusPie({ data }: DeviceStatusPieProps) {
  return (
    <ChartContainer title="Device Status Distribution" description="Current device status breakdown">
      <ResponsiveContainer width="100%" height="100%">
        <PieChart>
          <Pie
            data={data}
            cx="50%"
            cy="50%"
            innerRadius={60}
            outerRadius={100}
            paddingAngle={2}
            dataKey="value"
            label={({ name, percent }) => `${name} ${(percent * 100).toFixed(0)}%`}
          >
            {data.map((_, index) => (
              <Cell key={`cell-${index}`} fill={CHART_COLORS_ARRAY[index % CHART_COLORS_ARRAY.length]} />
            ))}
          </Pie>
          <Tooltip content={<ChartTooltipContent />} />
        </PieChart>
      </ResponsiveContainer>
    </ChartContainer>
  )
}
