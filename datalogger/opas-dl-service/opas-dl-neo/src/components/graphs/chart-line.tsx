import { useMemo } from "react"
import { CartesianGrid, Line, LineChart, XAxis, YAxis } from "recharts"
import { ChartContainer, ChartTooltip, ChartTooltipContent, type ChartConfig } from "@/components/ui/chart"

export interface ChartLineProps {
  data: Record<string, number | string | null>[]
  config: ChartConfig
  seriesIds: string[]
  // Smallest polling interval (ms) among the series currently plotted - the
  // finest real cadence any of them can produce. The x-axis tick step is
  // snapped to a multiple of this (see buildTicks), so grid lines never imply
  // a sampling rate no series on the chart can actually deliver.
  minPollingIntervalMs?: number
  className?: string
}

const MAX_TICKS = 40
// Step multipliers tried in order, in units of minPollingIntervalMs, before
// falling back to whole-day steps - keeps the tick count under MAX_TICKS
// while staying an exact multiple of the fastest series' own polling cadence.
const NICE_MULTIPLIERS = [1, 2, 5, 10, 15, 30, 60, 120, 300, 600, 1800, 3600, 7200, 21600, 43200]

function buildTicks(xs: number[], minPollingIntervalMs: number): { ticks: number[]; stepMs: number; domain: [number, number] | undefined } {
  if (xs.length === 0) return { ticks: [], stepMs: minPollingIntervalMs, domain: undefined }

  const min = Math.min(...xs)
  const max = Math.max(...xs)
  const span = Math.max(max - min, 1)

  let stepMs = minPollingIntervalMs
  for (const m of NICE_MULTIPLIERS) {
    stepMs = minPollingIntervalMs * m
    if (span / stepMs <= MAX_TICKS) break
  }
  if (span / stepMs > MAX_TICKS) {
    // Range spans well beyond what an hour-scale multiplier can cover (multi-day
    // window) - fall back to even day-sized steps instead of one giant step.
    const days = Math.ceil(span / (MAX_TICKS * 24 * 3600_000))
    stepMs = days * 24 * 3600_000
  }

  const ticks: number[] = []
  for (let t = Math.ceil(min / stepMs) * stepMs; t <= max; t += stepMs) ticks.push(t)
  return { ticks, stepMs, domain: [min, max] }
}

function formatTick(ms: number, stepMs: number): string {
  const d = new Date(ms)
  if (stepMs < 60_000) {
    return d.toLocaleTimeString('it-IT', { hour: '2-digit', minute: '2-digit', second: '2-digit' })
  }
  if (stepMs < 24 * 3600_000) {
    return d.toLocaleTimeString('it-IT', { hour: '2-digit', minute: '2-digit' })
  }
  return `${d.toLocaleDateString('it-IT')} ${d.toLocaleTimeString('it-IT', { hour: '2-digit', minute: '2-digit' })}`
}

// "yyyy-MM-ddTHH:mm:ss" -> "dd/MM/yyyy HH:mm:ss", plain string slicing (no
// Date parsing) so the tooltip always shows the exact wall-clock reading time,
// independent of the axis tick step / browser timezone interpretation.
function formatTooltipLabel(iso: string): string {
  const [datePart, timePart] = iso.split('T')
  const [y, m, d] = datePart.split('-')
  return `${d}/${m}/${y} ${timePart ?? ''}`
}

export function ChartLine({ data, config, seriesIds, minPollingIntervalMs = 60_000, className }: ChartLineProps) {
  const { ticks, stepMs, domain } = useMemo(() => {
    const xs = data.map(row => row.ts).filter((v): v is number => typeof v === 'number' && !Number.isNaN(v))
    return buildTicks(xs, minPollingIntervalMs)
  }, [data, minPollingIntervalMs])

  return (
    <ChartContainer config={config} className={className}>
      <LineChart data={data} margin={{ top: 12, right: 16, left: 4, bottom: 8 }}>
        <CartesianGrid vertical={false} />
        <XAxis
          dataKey="ts"
          type="number"
          domain={domain ?? ['dataMin', 'dataMax']}
          ticks={ticks.length > 0 ? ticks : undefined}
          tickLine={false}
          axisLine={false}
          tickMargin={8}
          minTickGap={32}
          tick={{ fontSize: 12, fill: "hsl(var(--muted-foreground))" }}
          tickFormatter={(v) => formatTick(v as number, stepMs)}
        />
        <YAxis
          tickLine={false}
          axisLine={false}
          width={44}
          tick={{ fontSize: 12, fill: "hsl(var(--muted-foreground))" }}
        />
        <ChartTooltip
          content={
            <ChartTooltipContent
              indicator="line"
              labelFormatter={(_, payload) => {
                const iso = payload?.[0]?.payload?.timestamp
                return typeof iso === 'string' ? formatTooltipLabel(iso) : ''
              }}
            />
          }
        />
        {seriesIds.map((id) => (
          <Line
            key={id}
            dataKey={id}
            type="linear"
            stroke={`var(--color-${id})`}
            strokeWidth={2}
            dot={false}
            connectNulls={false}
            isAnimationActive={false}
          />
        ))}
      </LineChart>
    </ChartContainer>
  )
}
