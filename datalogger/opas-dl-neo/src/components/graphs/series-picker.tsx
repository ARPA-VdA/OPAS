import { useMemo, useState } from "react"
import { useDraggable } from "@dnd-kit/core"
import { CSS } from "@dnd-kit/utilities"
import { Collapsible, CollapsibleContent, CollapsibleTrigger } from "@/components/ui/collapsible"
import { ToggleGroup, ToggleGroupItem } from "@/components/ui/toggle-group"
import { IconChevronRight, IconPlus, IconGripVertical, IconFileOff, IconEyeOff } from "@tabler/icons-react"
import { channelTypeInfo, channelTypeLabelPlural } from "@/lib/channelType"

// Draggable payload carried by a channel row - read back in GraphsContent's
// DndContext onDragEnd to know which module/channel was dropped on which panel.
export type ChannelDragData = { module: OpasModule; channel: OpasChannel }

// 0 = parametro, 1 = diagnostico, 2 = allarme (see lib/channelType.ts).
const CHANNEL_TYPES = [0, 1, 2] as const
// Sits in the same ToggleGroup as the channel-type filters (so it renders as
// a 4th, visually identical button) but toggles instrument visibility rather
// than a channel type - kept out of CHANNEL_TYPES's numeric id space.
const DISABLED_FILTER_VALUE = "disabled"
// Same clearly-visible fill for every filter button when active.
const FILTER_ITEM_CLASS = "data-[state=on]:bg-primary data-[state=on]:text-primary-foreground"

interface SeriesPickerProps {
  modules: OpasModule[]
  // Click still works as a shortcut (adds to the first graph) alongside drag
  // (which can target any graph) - see GraphsContent. Only shown while a
  // single graph exists: with more than one, "the first graph" stops being
  // an obvious target, so drag becomes the only (unambiguous) way to add.
  onAdd: (module: OpasModule, channel: OpasChannel) => void
  showAddButton: boolean
}

export function SeriesPicker({ modules, onAdd, showAddButton }: SeriesPickerProps) {
  const [open, setOpen] = useState<Set<string>>(new Set())
  // Only "Parametri" (type 0) shown by default - Diagnostici/Allarmi are
  // opt-in via the filter below.
  const [typeFilter, setTypeFilter] = useState<string[]>(['0'])
  const [showDisabled, setShowDisabled] = useState(true)

  const toggle = (name: string) => {
    setOpen((prev) => {
      const next = new Set(prev)
      if (next.has(name)) next.delete(name)
      else next.add(name)
      return next
    })
  }

  // Combined value for the single ToggleGroup below: the active type-filter
  // codes plus DISABLED_FILTER_VALUE when disabled instruments should show.
  const filterValues = useMemo(
    () => [...typeFilter, ...(showDisabled ? [DISABLED_FILTER_VALUE] : [])],
    [typeFilter, showDisabled]
  )

  const handleFilterChange = (values: string[]) => {
    const nextTypeFilter = values.filter((v) => v !== DISABLED_FILTER_VALUE)
    if (nextTypeFilter.length === 0) return // always keep at least one type selected
    setTypeFilter(nextTypeFilter)
    setShowDisabled(values.includes(DISABLED_FILTER_VALUE))
  }

  // Instruments hidden by the "disabilitati" switch drop out entirely; the
  // remaining ones keep only channels matching the type filter, and any
  // instrument left with zero matching channels is dropped too (rather than
  // shown expandable-but-empty).
  const visibleModules = useMemo(() => {
    return modules
      .filter(m => showDisabled || m.active)
      .map(m => ({ ...m, channels: m.channels.filter(c => typeFilter.includes(String(c.type))) }))
      .filter(m => m.channels.length > 0)
  }, [modules, typeFilter, showDisabled])

  if (modules.length === 0) {
    return <p className="text-sm text-muted-foreground p-2">Nessuno strumento in configurazione.</p>
  }

  return (
    <div className="flex flex-col gap-2">
      <div className="flex items-center gap-2 flex-wrap pb-2 border-b border-border">
        <ToggleGroup
          type="multiple"
          variant="outline"
          size="sm"
          value={filterValues}
          onValueChange={handleFilterChange}
          className="flex-wrap justify-start"
        >
          {CHANNEL_TYPES.map((t) => {
            const { icon: TypeIcon } = channelTypeInfo(t)
            return (
              <ToggleGroupItem key={t} value={String(t)} title={channelTypeLabelPlural(t)} className={FILTER_ITEM_CLASS}>
                <TypeIcon size={14} />
              </ToggleGroupItem>
            )
          })}
          <ToggleGroupItem value={DISABLED_FILTER_VALUE} title="Mostra strumenti disabilitati" className={FILTER_ITEM_CLASS}>
            <IconEyeOff size={14} />
          </ToggleGroupItem>
        </ToggleGroup>
      </div>

      <div className="flex flex-col gap-0.5">
      {visibleModules.length === 0 && (
        <p className="text-sm text-muted-foreground p-2">Nessuno strumento corrisponde ai filtri.</p>
      )}
      {visibleModules.map((module) => {
        const isOpen = open.has(module.name)
        return (
          <Collapsible key={module.name} open={isOpen} onOpenChange={() => toggle(module.name)}>
            <CollapsibleTrigger asChild>
              <button
                type="button"
                title={!module.active ? "Strumento disabilitato" : undefined}
                className={`flex items-center gap-1.5 w-full text-left text-sm font-medium py-1.5 px-1 rounded hover:bg-muted/50 transition-colors ${!module.active ? "opacity-50" : ""}`}
              >
                <IconChevronRight
                  size={14}
                  className={`shrink-0 text-muted-foreground transition-transform duration-150 ${isOpen ? "rotate-90" : ""}`}
                />
                {module.name}
                {module.temporary && (
                  <span className="inline-flex text-muted-foreground shrink-0" title="Strumento temporaneo: dati salvati solo su CSV, non su file .dat">
                    <IconFileOff size={13} />
                  </span>
                )}
              </button>
            </CollapsibleTrigger>
            <CollapsibleContent className="pl-5 flex flex-col gap-0.5 pb-1">
              {module.channels.map((channel) => (
                <ChannelPickerRow key={channel.name} module={module} channel={channel} onAdd={onAdd} showAddButton={showAddButton} />
              ))}
            </CollapsibleContent>
          </Collapsible>
        )
      })}
      </div>
    </div>
  )
}

function ChannelPickerRow({ module, channel, onAdd, showAddButton }: { module: OpasModule; channel: OpasChannel; onAdd: (module: OpasModule, channel: OpasChannel) => void; showAddButton: boolean }) {
  const dragId = `${module.name}::${channel.name}`
  const { attributes, listeners, setNodeRef, transform, isDragging } = useDraggable({
    id: dragId,
    data: { module, channel } satisfies ChannelDragData,
  })

  // A channel with no instant data right now either because it's disabled
  // itself, or because its whole instrument is - a disabled module polls
  // nothing, so none of its channels (even ones individually marked active)
  // are actually producing readings.
  const disabled = !module.active || !channel.active
  const title = !module.active
    ? "Strumento disabilitato: nessun dato istantaneo"
    : !channel.active
      ? "Canale disabilitato"
      : "Trascina su un grafico"
  const { icon: TypeIcon, label: typeLabel } = channelTypeInfo(channel.type)

  return (
    <div
      ref={setNodeRef}
      style={{ transform: CSS.Translate.toString(transform) }}
      className={`flex items-center justify-between gap-1 rounded hover:bg-muted/50 transition-colors ${isDragging ? "opacity-40" : ""} ${disabled ? "opacity-50" : ""}`}
    >
      <button
        type="button"
        {...listeners}
        {...attributes}
        className="flex-1 flex items-center gap-1 text-sm py-1 px-1.5 text-left cursor-grab active:cursor-grabbing"
        title={title}
      >
        <IconGripVertical size={12} className="text-muted-foreground shrink-0" />
        <span className="inline-flex text-muted-foreground shrink-0" title={typeLabel}>
          <TypeIcon size={13} />
        </span>
        {channel.name}
      </button>
      {showAddButton && (
        <button
          type="button"
          onClick={() => onAdd(module, channel)}
          className="text-muted-foreground hover:text-primary transition-colors p-1"
          title="Aggiungi al grafico"
        >
          <IconPlus size={14} />
        </button>
      )}
    </div>
  )
}
