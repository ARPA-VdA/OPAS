import { useCallback, useEffect, useMemo, useRef, useState } from "react"
import { useNavigation } from "@/context/NavigationContext"
import {
  DndContext, DragOverlay, PointerSensor, KeyboardSensor, useSensor, useSensors,
  type DragEndEvent, type DragStartEvent,
} from "@dnd-kit/core"
import { Button } from "@/components/ui/button"
import { Separator } from "@/components/ui/separator"
import { IconPlus, IconGripVertical } from "@tabler/icons-react"
import { GraphPanel, type GraphPanelHandle } from "@/components/graphs/graph-panel"
import { DroppablePanel } from "@/components/graphs/droppable-panel"
import { SeriesPicker, type ChannelDragData } from "@/components/graphs/series-picker"

export function GraphsContent() {
  const nav = useNavigation()
  const [opasConfig, setOpasConfig] = useState<OpasConfigWithFile>(null)
  const [panelIds, setPanelIds] = useState<string[]>(['p0'])
  const [activeDrag, setActiveDrag] = useState<ChannelDragData | null>(null)
  const nextPanelIdRef = useRef(1)
  const panelRefs = useRef(new Map<string, GraphPanelHandle>())
  // Stable per-id ref callbacks - without caching, a fresh closure on every
  // render would make React detach+reattach every panel's ref each time.
  const refCallbacks = useRef(new Map<string, (instance: GraphPanelHandle | null) => void>())

  useEffect(() => {
    window.electron.getOpasConfig?.().then(c => setOpasConfig(c ?? null))
  }, [])

  const modules = useMemo(
    () => (opasConfig?.data as OpasConfigData | undefined)?.modules ?? [],
    [opasConfig]
  )

  const addPanel = () => {
    setPanelIds(prev => [...prev, `p${nextPanelIdRef.current++}`])
  }

  const removePanel = (id: string) => {
    panelRefs.current.delete(id)
    refCallbacks.current.delete(id)
    setPanelIds(prev => prev.filter(p => p !== id))
  }

  const getPanelRefCallback = useCallback((id: string) => {
    let cb = refCallbacks.current.get(id)
    if (!cb) {
      cb = (instance: GraphPanelHandle | null) => {
        if (instance) panelRefs.current.set(id, instance)
        else panelRefs.current.delete(id)
      }
      refCallbacks.current.set(id, cb)
    }
    return cb
  }, [])

  // Click on a picker row: shortcut that always targets the first graph.
  // Dragging (below) can target any graph, including the first.
  const addToFirstPanel = (module: OpasModule, channel: OpasChannel) => {
    panelRefs.current.get(panelIds[0])?.addSeries(module, channel)
  }

  // One-shot: another page (instrument detail's "Vedi in Grafici") can
  // navigate here asking to land directly on a specific instrument's (or
  // single channel's) data. Always targets the first graph. Waits for
  // modules to load before resolving instrumentName/channelName.
  useEffect(() => {
    const payload = nav?.payload as { instrumentName?: string; channelName?: string; kind?: HistoryKind } | null | undefined
    if (!payload?.instrumentName || modules.length === 0) return
    const module = modules.find(m => m.name === payload.instrumentName)
    if (module) {
      const panel = panelRefs.current.get(panelIds[0])
      if (payload.kind) panel?.setKind(payload.kind)
      const toAdd = payload.channelName
        ? module.channels.filter(c => c.name === payload.channelName)
        : module.channels.filter(c => c.type === 0)
      for (const channel of toAdd) panel?.addSeries(module, channel)
    }
    nav?.clearPayload()
  }, [nav?.payload, modules, panelIds])

  const sensors = useSensors(
    useSensor(PointerSensor, { activationConstraint: { distance: 5 } }),
    useSensor(KeyboardSensor),
  )

  const handleDragStart = (event: DragStartEvent) => {
    setActiveDrag(event.active.data.current as ChannelDragData)
  }

  const handleDragEnd = (event: DragEndEvent) => {
    setActiveDrag(null)
    const { active, over } = event
    if (!over) return
    const data = active.data.current as ChannelDragData | undefined
    if (!data) return
    panelRefs.current.get(String(over.id))?.addSeries(data.module, data.channel)
  }

  return (
    <DndContext sensors={sensors} onDragStart={handleDragStart} onDragEnd={handleDragEnd}>
      <div className="p-4 flex flex-col gap-6 min-h-full">
        <div className="flex items-center justify-between gap-2">
          <h2 className="text-lg font-semibold">Grafici</h2>
          <Button variant="outline" size="sm" onClick={addPanel} className="gap-1.5">
            <IconPlus size={16} />
            Nuovo grafico
          </Button>
        </div>

        <div className="grid grid-cols-1 lg:grid-cols-[260px_1fr] gap-4 items-start">
          <div className="rounded-xl border border-border bg-card p-3 lg:sticky lg:top-4">
            <p className="text-sm font-semibold text-foreground mb-2">Strumenti</p>
            <SeriesPicker modules={modules} onAdd={addToFirstPanel} showAddButton={panelIds.length === 1} />
          </div>

          <div className="flex flex-col gap-6">
            {panelIds.map((id, index) => (
              <div key={id} className="flex flex-col gap-6">
                {index > 0 && <Separator />}
                <DroppablePanel id={id}>
                  <GraphPanel
                    ref={getPanelRefCallback(id)}
                    title={`Grafico ${index + 1}`}
                    onRemove={panelIds.length > 1 ? () => removePanel(id) : undefined}
                  />
                </DroppablePanel>
              </div>
            ))}
          </div>
        </div>
      </div>

      <DragOverlay dropAnimation={null}>
        {activeDrag && (
          <div className="flex items-center gap-1.5 rounded-md border border-primary bg-card px-2.5 py-1.5 text-sm shadow-lg">
            <IconGripVertical size={12} className="text-muted-foreground" />
            {activeDrag.channel.name}
          </div>
        )}
      </DragOverlay>
    </DndContext>
  )
}
