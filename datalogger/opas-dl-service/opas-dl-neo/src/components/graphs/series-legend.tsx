import { IconX } from "@tabler/icons-react"
import { getSeriesColor } from "@/lib/seriesColor"
import type { SeriesDef } from "./types"

interface SeriesLegendProps {
  series: SeriesDef[]
  onRemove: (id: string) => void
}

export function SeriesLegend({ series, onRemove }: SeriesLegendProps) {
  if (series.length === 0) {
    return <p className="text-sm text-muted-foreground">Nessuna serie selezionata. Aggiungine una dall'elenco strumenti.</p>
  }

  return (
    <div className="flex flex-wrap gap-2">
      {series.map((s) => (
        <div
          key={s.id}
          className="flex items-center gap-1.5 rounded-full border border-border bg-muted/30 pl-2.5 pr-1.5 py-1 text-xs"
        >
          <span
            className="size-2 rounded-full shrink-0"
            style={{ backgroundColor: getSeriesColor(s.colorIndex).light }}
          />
          <span className="font-medium">{s.channelName}</span>
          <span className="text-muted-foreground">· {s.instrumentName}</span>
          <button
            type="button"
            onClick={() => onRemove(s.id)}
            className="rounded-full p-0.5 hover:bg-muted transition-colors text-muted-foreground hover:text-foreground"
            title="Rimuovi"
          >
            <IconX size={12} />
          </button>
        </div>
      ))}
    </div>
  )
}
