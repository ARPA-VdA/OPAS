import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table"
import { channelTypeInfo } from "@/lib/channelType"
import { formatValue, formatRawValue, DEFAULT_RAW_VALUE_MAX_DECIMALS } from "@/components/instruments/readings-section"
import type { ViewChannelData } from "./types"

interface ViewTableProps {
  channels: ViewChannelData[]
}

export function ViewTable({ channels }: ViewTableProps) {
  if (channels.length === 0) {
    return <p className="text-sm text-muted-foreground">Nessun canale selezionato o disponibile.</p>
  }

  const rows = [...channels].sort((a, b) =>
    a.module.name.localeCompare(b.module.name) || a.channel.position - b.channel.position
  )

  return (
    <Table>
      <TableHeader>
        <TableRow>
          <TableHead>Strumento</TableHead>
          <TableHead>Canale</TableHead>
          <TableHead>Tipo</TableHead>
          <TableHead className="text-right">Valore</TableHead>
          <TableHead className="text-right">Raw</TableHead>
          <TableHead>Formula</TableHead>
          <TableHead>Unità</TableHead>
          <TableHead>Ultimo agg.</TableHead>
        </TableRow>
      </TableHeader>
      <TableBody>
        {rows.map(ch => {
          const { icon: TypeIcon, label: typeLabel } = channelTypeInfo(ch.channel.type)
          const valueEl = formatValue(ch.value, ch.channel.decimals)
          return (
            <TableRow key={`${ch.moduleId}-${ch.channel.id}`} className={!ch.channel.active ? 'opacity-50' : ''}>
              <TableCell className="font-medium">{ch.module.name}</TableCell>
              <TableCell>{ch.channel.name}</TableCell>
              <TableCell>
                <span className="flex items-center gap-1.5 text-muted-foreground text-xs">
                  <TypeIcon size={13} />
                  {typeLabel}
                </span>
              </TableCell>
              <TableCell className="text-right font-mono tabular-nums">
                {valueEl}
              </TableCell>
              <TableCell className="text-right font-mono tabular-nums text-muted-foreground">
                {formatRawValue(ch.rawValue, DEFAULT_RAW_VALUE_MAX_DECIMALS)}
              </TableCell>
              <TableCell className="font-mono text-muted-foreground">{ch.channel.formule || '—'}</TableCell>
              <TableCell className="text-muted-foreground">{ch.channel.unit || '—'}</TableCell>
              <TableCell className="text-muted-foreground">{ch.timestamp ?? '—'}</TableCell>
            </TableRow>
          )
        })}
      </TableBody>
    </Table>
  )
}
