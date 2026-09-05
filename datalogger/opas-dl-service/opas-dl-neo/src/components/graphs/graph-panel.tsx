import { forwardRef, useEffect, useImperativeHandle, useMemo, useRef, useState } from "react"
import { ToggleGroup, ToggleGroupItem } from "@/components/ui/toggle-group"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Button } from "@/components/ui/button"
import { IconX, IconTrash, IconFileTypeCsv, IconExternalLink } from "@tabler/icons-react"
import type { ChartConfig } from "@/components/ui/chart"
import { ChartLine } from "@/components/graphs/chart-line"
import { SeriesLegend } from "@/components/graphs/series-legend"
import type { SeriesDef, GraphPanelState } from "@/components/graphs/types"
import { getSeriesColor } from "@/lib/seriesColor"
import { mergeHistorySeries } from "@/lib/historySeries"

// "yyyy-MM-ddTHH:mm" - the exact format <input type="datetime-local"> uses,
// so state can be passed straight through without extra parsing.
function formatLocalDateTime(d: Date): string {
  const pad = (n: number) => String(n).padStart(2, '0')
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}T${pad(d.getHours())}:${pad(d.getMinutes())}`
}

function startOfTodayLocalDateTime(): string {
  const d = new Date()
  d.setHours(0, 0, 0, 0)
  return formatLocalDateTime(d)
}

function sanitizeFilenamePart(s: string): string {
  return s.replace(/[\\/:*?"<>|]/g, '_')
}

// Semicolon-separated, comma-decimal - matches the convention the station's
// own files_letture_csv/files_medie_csv already use, so the export opens
// correctly in Excel under an Italian locale.
function buildCsv(data: Record<string, number | string | null>[], seriesDefs: SeriesDef[]): string {
  const header = ['Timestamp', ...seriesDefs.map(s => `${s.instrumentName} · ${s.channelName}`)]
  const lines = [header.join(';')]
  for (const row of data) {
    const iso = String(row.timestamp ?? '')
    const [datePart, timePart] = iso.split('T')
    const [y, m, d] = (datePart ?? '').split('-')
    const ts = y && m && d ? `${d}/${m}/${y} ${timePart ?? ''}` : iso
    const values = seriesDefs.map(s => {
      const v = row[s.id]
      if (v === null || v === undefined) return ''
      return typeof v === 'number' ? String(v).replace('.', ',') : String(v)
    })
    lines.push([ts, ...values].join(';'))
  }
  return lines.join('\r\n')
}

const LIVE_REFRESH_MS = 10_000

export interface GraphPanelHandle {
  addSeries: (module: OpasModule, channel: OpasChannel) => void
  setKind: (kind: HistoryKind) => void
}

interface GraphPanelProps {
  title: string
  onRemove?: () => void
  // Seeds state on mount only (e.g. when this panel is the standalone
  // "detached" window for a graph opened via openGraphsWindow) - ignored on
  // later re-renders, same as any other React initial-state value.
  initialState?: GraphPanelState
}

export const GraphPanel = forwardRef<GraphPanelHandle, GraphPanelProps>(function GraphPanel(
  { title, onRemove, initialState },
  ref
) {
  const [seriesDefs, setSeriesDefs] = useState<SeriesDef[]>(initialState?.seriesDefs ?? [])
  const [kind, setKind] = useState<HistoryKind>(initialState?.kind ?? 'raw')
  const [fromDateTime, setFromDateTime] = useState(initialState?.fromDateTime ?? startOfTodayLocalDateTime())
  const [toDateTime, setToDateTime] = useState(initialState?.toDateTime ?? formatLocalDateTime(new Date()))
  const [live, setLive] = useState(initialState?.live ?? false)
  const [results, setResults] = useState<HistoryResult[]>([])
  // Starts past the highest "sN" id already present in initialState, so a
  // series added later can't collide with one carried over from detaching
  // (ids can have gaps if series were removed before detaching, so this
  // can't just be initialState.seriesDefs.length).
  const nextIdRef = useRef(1 + Math.max(-1, ...(initialState?.seriesDefs.map(s => Number(s.id.slice(1)) || 0) ?? [-1])))

  // Live mode: keeps "A" pinned to now, so the window grows to include new
  // readings as they come in. "Da" is left alone - the user can still narrow
  // where the window starts while it keeps advancing.
  useEffect(() => {
    if (!live) return
    const tick = () => setToDateTime(formatLocalDateTime(new Date()))
    tick()
    const interval = setInterval(tick, LIVE_REFRESH_MS)
    return () => clearInterval(interval)
  }, [live])

  const addSeries = (module: OpasModule, channel: OpasChannel) => {
    setSeriesDefs(prev => {
      if (prev.some(s => s.instrumentName === module.name && s.channelName === channel.name)) return prev
      const id = `s${nextIdRef.current++}`
      return [...prev, {
        id, instrumentName: module.name, channelName: channel.name, colorIndex: prev.length,
        pollingInterval: module.pollingInterval || 1,
      }]
    })
  }

  useImperativeHandle(ref, () => ({ addSeries, setKind }), [])

  const removeSeries = (id: string) => {
    setSeriesDefs(prev => prev.filter(s => s.id !== id))
  }

  const clearSeries = () => {
    setSeriesDefs([])
  }

  useEffect(() => {
    if (seriesDefs.length === 0) { setResults([]); return }
    let cancelled = false
    // Day-file selection only needs the date part - the exact from/to instant
    // is applied client-side below, after merging, so a range can span
    // multiple day-files while still narrowing to a precise time window.
    const fromDate = fromDateTime.slice(0, 10)
    const toDate = toDateTime.slice(0, 10)
    const requests: HistoryRequest[] = seriesDefs.map(s => ({
      seriesId: s.id, channelName: s.channelName, kind, fromDate, toDate,
    }))
    window.electron.getChannelHistory(requests).then(res => { if (!cancelled) setResults(res) })
    return () => { cancelled = true }
  }, [seriesDefs, kind, fromDateTime, toDateTime])

  const chartData = useMemo(() => {
    const merged = mergeHistorySeries(results)
    return merged
      .filter((row) => {
        const ts = (row.timestamp as string).slice(0, 16)
        return ts >= fromDateTime && ts <= toDateTime
      })
      // Numeric epoch-ms twin of the "timestamp" string, so ChartLine can plot
      // a real time-scaled x-axis (points spaced by actual elapsed time)
      // instead of Recharts' default categorical/by-index spacing.
      .map(row => ({ ...row, ts: new Date(row.timestamp as string).getTime() }))
  }, [results, fromDateTime, toDateTime])

  // Smallest polling interval among the series currently on this chart - the
  // finest cadence any of them can actually produce - used as the x-axis tick
  // step so grid lines reflect the fastest instrument's real sampling rate
  // (see ChartLine's tick-generation).
  const minPollingIntervalMs = useMemo(() => {
    if (seriesDefs.length === 0) return 60_000
    return Math.min(...seriesDefs.map(s => s.pollingInterval || 1)) * 1000
  }, [seriesDefs])

  const chartConfig = useMemo(() => {
    const config: ChartConfig = {}
    for (const s of seriesDefs) {
      const color = getSeriesColor(s.colorIndex)
      config[s.id] = { label: `${s.instrumentName} · ${s.channelName}`, theme: { light: color.light, dark: color.dark } }
    }
    return config
  }, [seriesDefs])

  const exportCsv = () => {
    const csv = buildCsv(chartData, seriesDefs)
    const rangeLabel = `${fromDateTime.replace(/[:T]/g, '-')}_${toDateTime.replace(/[:T]/g, '-')}`
    const defaultFilename = `${sanitizeFilenamePart(title)}_${rangeLabel}.csv`
    window.electron.exportCsv(defaultFilename, csv)
  }

  return (
    <div className="flex flex-col gap-4 rounded-xl border border-border bg-card p-4">
      <div className="flex items-center justify-between gap-2 flex-wrap">
        <h3 className="text-sm font-semibold text-muted-foreground">{title}</h3>
        <div className="flex items-center gap-2 flex-wrap">
          <ToggleGroup
            type="single"
            variant="outline"
            value={kind}
            onValueChange={(v) => v && setKind(v as HistoryKind)}
          >
            <ToggleGroupItem value="raw">Istantanei</ToggleGroupItem>
            <ToggleGroupItem value="hourly">Medie orarie</ToggleGroupItem>
          </ToggleGroup>
          <div className="flex items-center gap-1.5">
            <Label htmlFor={`graphs-from-${title}`} className="text-xs text-muted-foreground">Da</Label>
            <Input
              id={`graphs-from-${title}`}
              type="datetime-local"
              value={fromDateTime}
              onChange={(e) => setFromDateTime(e.target.value)}
              className="w-[190px]"
            />
          </div>
          <div className="flex items-center gap-1.5">
            <Label htmlFor={`graphs-to-${title}`} className="text-xs text-muted-foreground">A</Label>
            <Input
              id={`graphs-to-${title}`}
              type="datetime-local"
              value={toDateTime}
              onChange={(e) => setToDateTime(e.target.value)}
              disabled={live}
              className="w-[190px]"
            />
          </div>
          <Button
            type="button"
            variant={live ? "default" : "outline"}
            size="sm"
            onClick={() => setLive(v => !v)}
            className="gap-1.5"
            title={live ? "Ferma l'aggiornamento automatico" : "Aggiorna automaticamente fino ad adesso"}
          >
            <span className={`size-2 rounded-full ${live ? "bg-red-500 animate-pulse" : "bg-muted-foreground"}`} />
            Live
          </Button>
          <Button
            variant="ghost"
            size="icon"
            className="size-7 text-muted-foreground hover:text-primary"
            onClick={() => window.electron.openGraphsWindow({ seriesDefs, kind, fromDateTime, toDateTime, live })}
            title="Apri questo grafico in una nuova finestra"
          >
            <IconExternalLink size={16} />
          </Button>
          <Button
            variant="ghost"
            size="icon"
            className="size-7 text-muted-foreground hover:text-primary"
            onClick={exportCsv}
            disabled={chartData.length === 0}
            title="Esporta in CSV i dati visualizzati"
          >
            <IconFileTypeCsv size={16} />
          </Button>
          <Button
            variant="ghost"
            size="icon"
            className="size-7 text-muted-foreground hover:text-destructive"
            onClick={clearSeries}
            disabled={seriesDefs.length === 0}
            title="Svuota grafico (rimuovi tutti i parametri/diagnostici)"
          >
            <IconTrash size={16} />
          </Button>
          {onRemove && (
            <Button variant="ghost" size="icon" className="size-7 text-muted-foreground hover:text-destructive" onClick={onRemove} title="Rimuovi grafico">
              <IconX size={16} />
            </Button>
          )}
        </div>
      </div>

      {seriesDefs.length === 0 ? (
        <p className="text-sm text-muted-foreground py-16 text-center">
          Trascina un canale qui, oppure aggiungilo dall'elenco strumenti.
        </p>
      ) : (
        <ChartLine
          data={chartData}
          config={chartConfig}
          seriesIds={seriesDefs.map((s) => s.id)}
          minPollingIntervalMs={minPollingIntervalMs}
          className="h-[420px] w-full"
        />
      )}

      <SeriesLegend series={seriesDefs} onRemove={removeSeries} />
    </div>
  )
})
