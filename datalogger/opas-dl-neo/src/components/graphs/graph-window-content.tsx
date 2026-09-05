import { useEffect, useMemo, useRef, useState } from "react"
import { GraphPanel, type GraphPanelHandle } from "@/components/graphs/graph-panel"
import { SeriesPicker } from "@/components/graphs/series-picker"
import type { GraphPanelState } from "@/components/graphs/types"

interface GraphWindowContentProps {
  initialState?: GraphPanelState
}

// Body of a "detached" graph window (opened via openGraphsWindow) - a
// stripped-down single-panel version of GraphsContent, no multi-panel
// management chrome, no drag & drop (click-to-add via SeriesPicker covers
// adding channels with only one panel to target).
export function GraphWindowContent({ initialState }: GraphWindowContentProps) {
  const [opasConfig, setOpasConfig] = useState<OpasConfigWithFile>(null)

  useEffect(() => {
    window.electron.getOpasConfig?.().then(c => setOpasConfig(c ?? null))
  }, [])

  const modules = useMemo(
    () => opasConfig?.data?.modules ?? [],
    [opasConfig]
  )

  const panelRef = useRef<GraphPanelHandle | null>(null)

  return (
    <div className="p-4 flex flex-col gap-6 min-h-full">
      <h2 className="text-lg font-semibold">Grafico</h2>

      <div className="grid grid-cols-1 lg:grid-cols-[260px_1fr] gap-4 items-start">
        <div className="rounded-xl border border-border bg-card p-3 lg:sticky lg:top-4">
          <p className="text-sm font-semibold text-foreground mb-2">Strumenti</p>
          <SeriesPicker
            modules={modules}
            onAdd={(module, channel) => panelRef.current?.addSeries(module, channel)}
            showAddButton
          />
        </div>

        <GraphPanel
          ref={panelRef}
          title="Grafico"
          initialState={initialState}
        />
      </div>
    </div>
  )
}
