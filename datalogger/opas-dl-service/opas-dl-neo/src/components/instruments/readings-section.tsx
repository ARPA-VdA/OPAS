import { useEffect, useState } from "react"
import { Button } from "@/components/ui/button"
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table"
import { Tooltip, TooltipContent, TooltipTrigger } from "@/components/ui/tooltip"
import { IconLayoutGrid, IconTable, IconEye, IconEyeOff, IconChartLine, IconFileOff } from "@tabler/icons-react"
import { ChannelEditDialog } from "./channel-edit-dialog"
import { useNavigation } from "@/context/NavigationContext"

interface MergedChannel {
  config: OpasChannel
  value: number | null
  rawValue: number | null
  timestamp: string | null
}

export const DEFAULT_RAW_VALUE_MAX_DECIMALS = 3

export function formatValue(value: number | null, decimals: number): string {
  if (value === null || isNaN(value)) return '—'
  return value.toFixed(decimals)
}

// "Al massimo N decimali": arrotonda a maxDecimals ma non aggiunge zeri di
// riempimento se il valore ne ha naturalmente meno.
export function formatRawValue(value: number | null, maxDecimals: number): string {
  if (value === null || isNaN(value)) return '—'
  return Number(value.toFixed(maxDecimals)).toString()
}

// Canale di un modulo "Temporaneo": i dati vengono salvati solo nel CSV, non
// nei file .dat (vedi OpasModule.temporary).
function TemporaryBadge() {
  return (
    <Tooltip>
      <TooltipTrigger asChild>
        <span className="inline-flex text-muted-foreground shrink-0">
          <IconFileOff size={13} />
        </span>
      </TooltipTrigger>
      <TooltipContent>Canale temporaneo: salvato solo su CSV, non su file .dat</TooltipContent>
    </Tooltip>
  )
}

// ── Config summary inline ─────────────────────────────────────────────────────

function ChannelConfigInfo({ config }: { config: OpasChannel }) {
  const items: { label: string; value: string }[] = [
    { label: 'Formula', value: config.formule || '—' },
    { label: 'Dec.', value: String(config.decimals) },
    { label: 'Alg.', value: String(config.algorithm) },
    { label: 'Media', value: `${config.meanInterval / 60} min` },
  ]
  if (config.detectionLimit !== null) {
    items.push({ label: 'Lim. rilev.', value: String(config.detectionLimit) })
  }
  if (config.allowedMinValue !== null || config.allowedMaxValue !== null) {
    const min = config.allowedMinValue !== null ? String(config.allowedMinValue) : '—'
    const max = config.allowedMaxValue !== null ? String(config.allowedMaxValue) : '—'
    items.push({ label: 'Range', value: `${min} – ${max}` })
  }

  return (
    <div className="flex flex-wrap gap-x-2 gap-y-0.5 mt-1">
      {items.map(({ label, value }) => (
        <span key={label} className="text-xs text-muted-foreground">
          <span className="font-medium">{label}:</span> {value}
        </span>
      ))}
    </div>
  )
}

// ── Card singolo canale ───────────────────────────────────────────────────────

function ChannelCard({ ch, isTemporary, rawValueMaxDecimals, onSelect, onViewGraph }: { ch: MergedChannel; isTemporary: boolean; rawValueMaxDecimals: number; onSelect: () => void; onViewGraph: () => void }) {
  const { config, value, rawValue, timestamp } = ch
  const hasValue = value !== null && !isNaN(value)
  const valueEl = (
    <span className={`text-xl font-bold tabular-nums ${hasValue ? '' : 'text-muted-foreground'}`}>
      {formatValue(value, config.decimals)}
    </span>
  )

  return (
    <button
      className={`w-full text-left rounded-md border border-border bg-muted/20 px-3 py-2 hover:bg-muted/50 hover:border-primary/40 transition-all ${!config.active ? 'opacity-50' : ''}`}
      onClick={onSelect}
    >
      <div className="flex items-start justify-between gap-2">
        <div className="min-w-0 flex-1">
          <div className="flex items-center gap-1.5 flex-wrap">
            <span className="text-xs text-muted-foreground font-mono" title="ID database">{config.databaseId}</span>
            <span className="text-sm font-semibold">{config.name}</span>
            {isTemporary && <TemporaryBadge />}
            {config.unit && <span className="text-xs text-muted-foreground">{config.unit}</span>}
            <span
              role="button"
              tabIndex={0}
              onClick={(e) => { e.stopPropagation(); onViewGraph() }}
              className="text-muted-foreground hover:text-primary transition-colors"
              title="Vedi in Grafici"
            >
              <IconChartLine size={13} />
            </span>
          </div>
          <ChannelConfigInfo config={config} />
          <p className="text-[10px] text-muted-foreground mt-1">
            Raw: {formatRawValue(rawValue, rawValueMaxDecimals)}
            {timestamp && <span className="ml-2">{timestamp}</span>}
          </p>
        </div>
        <div className="flex items-baseline gap-1 shrink-0">
          {valueEl}
          {config.unit && <span className="text-xs text-muted-foreground">{config.unit}</span>}
        </div>
      </div>
    </button>
  )
}

// ── Intestazione di sezione ───────────────────────────────────────────────────

function SectionHeader({ label, visible, onToggle }: { label: string; visible: boolean; onToggle: () => void }) {
  return (
    <div className="flex items-center gap-2 pb-0.5">
      <span className="text-xs font-semibold text-muted-foreground uppercase tracking-wide">{label}</span>
      <div className="flex-1 h-px bg-border" />
      <button
        onClick={onToggle}
        className="text-muted-foreground hover:text-foreground transition-colors"
        title={visible ? `Nascondi ${label.toLowerCase()}` : `Mostra ${label.toLowerCase()}`}
      >
        {visible ? <IconEye size={14} /> : <IconEyeOff size={14} />}
      </button>
    </div>
  )
}

// ── Vista a griglia ───────────────────────────────────────────────────────────

function ChannelsCards({ params, diags, isTemporary, rawValueMaxDecimals, onSelect, onViewGraph, paramsVisible, diagsVisible, onToggleParams, onToggleDiags }: {
  params: MergedChannel[]
  diags: MergedChannel[]
  isTemporary: boolean
  rawValueMaxDecimals: number
  onSelect: (ch: MergedChannel) => void
  onViewGraph: (ch: MergedChannel) => void
  paramsVisible: boolean
  diagsVisible: boolean
  onToggleParams: () => void
  onToggleDiags: () => void
}) {
  return (
    <div className="space-y-2">
      {params.length > 0 && (
        <>
          <SectionHeader label="Parametri" visible={paramsVisible} onToggle={onToggleParams} />
          {paramsVisible && (
            <div className="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-4 gap-2">
              {params.map(ch => (
                <ChannelCard key={ch.config.id} ch={ch} isTemporary={isTemporary} rawValueMaxDecimals={rawValueMaxDecimals} onSelect={() => onSelect(ch)} onViewGraph={() => onViewGraph(ch)} />
              ))}
            </div>
          )}
        </>
      )}
      {diags.length > 0 && (
        <>
          <SectionHeader label="Diagnostici" visible={diagsVisible} onToggle={onToggleDiags} />
          {diagsVisible && (
            <div className="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-4 gap-2">
              {diags.map(ch => (
                <ChannelCard key={ch.config.id} ch={ch} isTemporary={isTemporary} rawValueMaxDecimals={rawValueMaxDecimals} onSelect={() => onSelect(ch)} onViewGraph={() => onViewGraph(ch)} />
              ))}
            </div>
          )}
        </>
      )}
    </div>
  )
}

// ── Vista a tabella ───────────────────────────────────────────────────────────

function ChannelsTable({ params, diags, isTemporary, rawValueMaxDecimals, onSelect, onViewGraph, paramsVisible, diagsVisible, onToggleParams, onToggleDiags }: {
  params: MergedChannel[]
  diags: MergedChannel[]
  isTemporary: boolean
  rawValueMaxDecimals: number
  onSelect: (ch: MergedChannel) => void
  onViewGraph: (ch: MergedChannel) => void
  paramsVisible: boolean
  diagsVisible: boolean
  onToggleParams: () => void
  onToggleDiags: () => void
}) {
  const renderRows = (channels: MergedChannel[]) =>
    channels.map(ch => {
      const valueEl = formatValue(ch.value, ch.config.decimals)
      return (
        <TableRow
          key={ch.config.id}
          className={`cursor-pointer hover:bg-muted/40 ${!ch.config.active ? 'opacity-50' : ''}`}
          onClick={() => onSelect(ch)}
        >
          <TableCell className="font-medium">
            <div className="flex items-center gap-1.5">
              {ch.config.name}
              {isTemporary && <TemporaryBadge />}
              <span
                role="button"
                tabIndex={0}
                onClick={(e) => { e.stopPropagation(); onViewGraph(ch) }}
                className="text-muted-foreground hover:text-primary transition-colors"
                title="Vedi in Grafici"
              >
                <IconChartLine size={13} />
              </span>
            </div>
          </TableCell>
          <TableCell className="text-muted-foreground">{ch.config.unit || '—'}</TableCell>
          <TableCell className="text-right font-mono tabular-nums">
            {valueEl}
          </TableCell>
          <TableCell className="text-right font-mono tabular-nums text-muted-foreground">
            {formatRawValue(ch.rawValue, rawValueMaxDecimals)}
          </TableCell>
          <TableCell className="font-mono text-muted-foreground">{ch.config.formule || '—'}</TableCell>
          <TableCell className="text-center text-muted-foreground">{ch.config.decimals}</TableCell>
          <TableCell className="text-center text-muted-foreground">{ch.config.algorithm}</TableCell>
          <TableCell className="text-center text-muted-foreground">{ch.config.meanInterval / 60} min</TableCell>
        </TableRow>
      )
    })

  const sectionRow = (label: string, colSpan: number, visible: boolean, onToggle: () => void) => (
    <TableRow className="hover:bg-transparent">
      <TableCell colSpan={colSpan} className="py-1.5 px-3">
        <div className="flex items-center justify-between">
          <span className="text-[10px] font-semibold text-muted-foreground uppercase tracking-wide">{label}</span>
          <button
            onClick={onToggle}
            className="text-muted-foreground hover:text-foreground transition-colors"
            title={visible ? `Nascondi ${label.toLowerCase()}` : `Mostra ${label.toLowerCase()}`}
          >
            {visible ? <IconEye size={13} /> : <IconEyeOff size={13} />}
          </button>
        </div>
      </TableCell>
    </TableRow>
  )

  return (
    <Table>
      <TableHeader>
        <TableRow>
          <TableHead>Nome</TableHead>
          <TableHead>Unità</TableHead>
          <TableHead className="text-right">Valore</TableHead>
          <TableHead className="text-right">Raw</TableHead>
          <TableHead>Formula</TableHead>
          <TableHead className="text-center">Dec.</TableHead>
          <TableHead className="text-center">Alg.</TableHead>
          <TableHead className="text-center">Media</TableHead>
        </TableRow>
      </TableHeader>
      <TableBody>
        {params.length > 0 && (
          <>
            {sectionRow('Parametri', 8, paramsVisible, onToggleParams)}
            {paramsVisible && renderRows(params)}
          </>
        )}
        {diags.length > 0 && (
          <>
            {sectionRow('Diagnostici', 8, diagsVisible, onToggleDiags)}
            {diagsVisible && renderRows(diags)}
          </>
        )}
      </TableBody>
    </Table>
  )
}

// ── Componente principale ─────────────────────────────────────────────────────

interface ReadingsSectionProps {
  instrumentId: string
  moduleConfig: OpasModule | null
}

export function ReadingsSection({ instrumentId, moduleConfig }: ReadingsSectionProps) {
  const nav = useNavigation()
  const [readings, setReadings] = useState<InstrumentReading[]>([])
  const [view, setView] = useState<'cards' | 'table'>('cards')
  const [selected, setSelected] = useState<MergedChannel | null>(null)
  const [paramsVisible, setParamsVisible] = useState(true)
  const [diagsVisible, setDiagsVisible] = useState(true)
  const [rawValueMaxDecimals, setRawValueMaxDecimals] = useState(DEFAULT_RAW_VALUE_MAX_DECIMALS)

  const goToGraphs = (channelName?: string) => {
    nav?.navigateTo("nav.graphs", { instrumentName: instrumentId, channelName, kind: 'raw' })
  }

  useEffect(() => {
    const load = async () => {
      const result = await window.electron.getInstrumentReadings(instrumentId)
      if (result) setReadings(result)
    }
    load()
    const interval = setInterval(load, 5000)
    return () => clearInterval(interval)
  }, [instrumentId])

  useEffect(() => {
    window.electron.getSettings?.().then(settings => {
      if (settings?.rawValueMaxDecimals !== undefined) setRawValueMaxDecimals(settings.rawValueMaxDecimals)
    })
  }, [])

  const csvMap = new Map<string, { value: number | null; rawValue: number | null; timestamp: string | null }>()
  for (const reading of readings) {
    for (const ch of reading.channels) {
      if (!csvMap.has(ch.name)) {
        csvMap.set(ch.name, { value: ch.value, rawValue: ch.rawValue ?? null, timestamp: reading.timestamp })
      }
    }
  }

  const channels: MergedChannel[] = (moduleConfig?.channels.map(cfg => ({
    config: cfg,
    value: csvMap.get(cfg.name)?.value ?? null,
    rawValue: csvMap.get(cfg.name)?.rawValue ?? null,
    timestamp: csvMap.get(cfg.name)?.timestamp ?? null,
  })) ?? readings.flatMap(r => r.channels.map(ch => ({
    config: {
      id: 0, name: ch.name, active: true, position: 0, type: 0,
      unit: '', decimals: 2, storeCsv: true, algorithm: 0, formule: 'y=x',
      meanInterval: 3600, readingsMinPercentage: 75, dataArrayIdx: 0,
      address: null, regularExpression: null, databaseId: 0, parameterId: 0,
      detectionLimit: null, allowedMinValue: null, allowedMaxValue: null,
      allowedMinMean: null, negativeValueSetToZero: null, dataType: 0,
      dataFormule: null, registerId: 0, parameterNote: null,
    } as OpasChannel,
    value: ch.value,
    rawValue: ch.rawValue ?? null,
    timestamp: r.timestamp,
  })))).sort((a, b) => a.config.position - b.config.position)

  const params = channels.filter(c => c.config.type === 0)
  const diags = channels.filter(c => c.config.type !== 0)
  const isTemporary = moduleConfig?.temporary ?? false

  if (channels.length === 0) {
    return <p className="text-sm text-muted-foreground">Nessuna lettura disponibile.</p>
  }

  return (
    <>
      <div className="space-y-2">
        <div className="flex justify-end gap-1">
          <Button
            variant="ghost"
            size="sm" className="h-7 gap-1.5 text-xs"
            onClick={() => goToGraphs()}
            title="Vedi in Grafici"
          >
            <IconChartLine size={14} />
            Grafici
          </Button>
          <Button
            variant={view === 'cards' ? 'secondary' : 'ghost'}
            size="icon" className="size-7"
            onClick={() => setView('cards')}
            title="Vista schede"
          >
            <IconLayoutGrid size={14} />
          </Button>
          <Button
            variant={view === 'table' ? 'secondary' : 'ghost'}
            size="icon" className="size-7"
            onClick={() => setView('table')}
            title="Vista tabella"
          >
            <IconTable size={14} />
          </Button>
        </div>
        {view === 'cards'
          ? <ChannelsCards
              params={params} diags={diags} isTemporary={isTemporary} rawValueMaxDecimals={rawValueMaxDecimals} onSelect={setSelected}
              onViewGraph={(ch) => goToGraphs(ch.config.name)}
              paramsVisible={paramsVisible} diagsVisible={diagsVisible}
              onToggleParams={() => setParamsVisible(v => !v)} onToggleDiags={() => setDiagsVisible(v => !v)}
            />
          : <ChannelsTable
              params={params} diags={diags} isTemporary={isTemporary} rawValueMaxDecimals={rawValueMaxDecimals} onSelect={setSelected}
              onViewGraph={(ch) => goToGraphs(ch.config.name)}
              paramsVisible={paramsVisible} diagsVisible={diagsVisible}
              onToggleParams={() => setParamsVisible(v => !v)} onToggleDiags={() => setDiagsVisible(v => !v)}
            />
        }
      </div>
      <ChannelEditDialog
        channel={selected?.config ?? null}
        moduleId={moduleConfig?.id ?? null}
        onClose={() => setSelected(null)}
      />
    </>
  )
}
