import { useMemo, useState } from "react"
import { Collapsible, CollapsibleContent, CollapsibleTrigger } from "@/components/ui/collapsible"
import { ToggleGroup, ToggleGroupItem } from "@/components/ui/toggle-group"
import { Checkbox } from "@/components/ui/checkbox"
import { Button } from "@/components/ui/button"
import { IconChevronRight, IconFileOff, IconEyeOff, IconChecklist, IconSquareOff } from "@tabler/icons-react"
import { channelTypeInfo, channelTypeLabelPlural } from "@/lib/channelType"
import { channelKey } from "@/lib/channelIds"

// Type 0 = "parametro" (vedi lib/channelType.ts) - i bottoni "seleziona"/
// "deseleziona tutti i parametri" operano sempre su questo insieme,
// indipendentemente dai filtri/visibilità correnti del picker (non solo sui
// canali attualmente mostrati), così il loro comportamento resta prevedibile
// qualunque sia lo stato dei filtri quando vengono premuti.
const PARAMETRO_TYPE = 0

// 0 = parametro, 1 = diagnostico, 2 = allarme (see lib/channelType.ts).
const CHANNEL_TYPES = [0, 1, 2] as const
const DISABLED_FILTER_VALUE = "disabled"
const FILTER_ITEM_CLASS = "data-[state=on]:bg-primary data-[state=on]:text-primary-foreground"

interface ChannelMultiPickerProps {
  modules: OpasModule[]
  selected: Set<string>
  onToggle: (moduleId: number, channelId: number) => void
  onSelectAll: (keys: string[]) => void
  onDeselectAll: (keys: string[]) => void
}

export function ChannelMultiPicker({ modules, selected, onToggle, onSelectAll, onDeselectAll }: ChannelMultiPickerProps) {
  // Keyed by module.id, not module.name (unlike SeriesPicker) - two modules
  // can share a name, and that would make one instrument's expand state leak
  // onto its same-named sibling.
  const [open, setOpen] = useState<Set<number>>(new Set())
  const [typeFilter, setTypeFilter] = useState<string[]>(['0'])
  const [showDisabled, setShowDisabled] = useState(true)

  const toggleOpen = (moduleId: number) => {
    setOpen((prev) => {
      const next = new Set(prev)
      if (next.has(moduleId)) next.delete(moduleId)
      else next.add(moduleId)
      return next
    })
  }

  const filterValues = useMemo(
    () => [...typeFilter, ...(showDisabled ? [DISABLED_FILTER_VALUE] : [])],
    [typeFilter, showDisabled]
  )

  const handleFilterChange = (values: string[]) => {
    const nextTypeFilter = values.filter((v) => v !== DISABLED_FILTER_VALUE)
    if (nextTypeFilter.length === 0) return
    setTypeFilter(nextTypeFilter)
    setShowDisabled(values.includes(DISABLED_FILTER_VALUE))
  }

  const visibleModules = useMemo(() => {
    return modules
      .filter(m => showDisabled || m.active)
      .map(m => ({ ...m, channels: m.channels.filter(c => typeFilter.includes(String(c.type))) }))
      .filter(m => m.channels.length > 0)
  }, [modules, typeFilter, showDisabled])

  const allParametroKeys = useMemo(() => {
    return modules.flatMap(m => m.channels.filter(c => c.type === PARAMETRO_TYPE).map(c => channelKey(m.id, c.id)))
  }, [modules])
  const allParametroSelected = allParametroKeys.length > 0 && allParametroKeys.every(k => selected.has(k))

  const handleToggleAll = () => {
    if (allParametroSelected) onDeselectAll(allParametroKeys)
    else onSelectAll(allParametroKeys)
  }

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
        <Button
          type="button"
          variant="outline"
          size="sm"
          className="ml-auto"
          disabled={allParametroKeys.length === 0}
          onClick={handleToggleAll}
        >
          {allParametroSelected ? <IconSquareOff size={14} /> : <IconChecklist size={14} />}
          {allParametroSelected ? "Deseleziona tutti i parametri" : "Seleziona tutti i parametri"}
        </Button>
      </div>

      <div className="flex flex-col gap-0.5 max-h-80 overflow-y-auto">
        {visibleModules.length === 0 && (
          <p className="text-sm text-muted-foreground p-2">Nessuno strumento corrisponde ai filtri.</p>
        )}
        {visibleModules.map((module) => {
          const isOpen = open.has(module.id)
          const moduleKeys = module.channels.map(c => channelKey(module.id, c.id))
          const selectedCount = moduleKeys.filter(k => selected.has(k)).length
          const moduleCheckedState: boolean | "indeterminate" =
            selectedCount === 0 ? false : selectedCount === moduleKeys.length ? true : "indeterminate"
          return (
            <Collapsible key={module.id} open={isOpen} onOpenChange={() => toggleOpen(module.id)}>
              <div className="flex items-center gap-1.5 w-full rounded hover:bg-muted/50 transition-colors">
                <Checkbox
                  className="ml-1.5 shrink-0"
                  checked={moduleCheckedState}
                  onCheckedChange={() => (selectedCount > 0 ? onDeselectAll(moduleKeys) : onSelectAll(moduleKeys))}
                  title={selectedCount > 0 ? "Deseleziona tutti i canali di questo strumento" : "Seleziona tutti i canali di questo strumento"}
                />
                <CollapsibleTrigger asChild>
                  <button
                    type="button"
                    title={!module.active ? "Strumento disabilitato" : undefined}
                    className={`flex items-center gap-1.5 flex-1 min-w-0 text-left text-sm font-medium py-1.5 px-1 rounded ${!module.active ? "opacity-50" : ""}`}
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
                    {selectedCount > 0 && (
                      <span className="text-xs text-primary font-normal">{selectedCount} selezionati</span>
                    )}
                  </button>
                </CollapsibleTrigger>
              </div>
              <CollapsibleContent className="pl-5 flex flex-col gap-0.5 pb-1">
                {module.channels.map((channel) => (
                  <ChannelCheckboxRow
                    key={channel.id}
                    module={module}
                    channel={channel}
                    checked={selected.has(channelKey(module.id, channel.id))}
                    onToggle={() => onToggle(module.id, channel.id)}
                  />
                ))}
              </CollapsibleContent>
            </Collapsible>
          )
        })}
      </div>
    </div>
  )
}

function ChannelCheckboxRow({ module, channel, checked, onToggle }: { module: OpasModule; channel: OpasChannel; checked: boolean; onToggle: () => void }) {
  const disabled = !module.active || !channel.active
  const { icon: TypeIcon, label: typeLabel } = channelTypeInfo(channel.type)
  const id = `view-channel-${module.id}-${channel.id}`

  return (
    <label
      htmlFor={id}
      className={`flex items-center gap-2 rounded hover:bg-muted/50 transition-colors py-1 px-1.5 cursor-pointer ${disabled ? "opacity-50" : ""}`}
    >
      <Checkbox id={id} checked={checked} onCheckedChange={onToggle} />
      <span className="inline-flex text-muted-foreground shrink-0" title={typeLabel}>
        <TypeIcon size={13} />
      </span>
      <span className="text-sm">{channel.name}</span>
    </label>
  )
}
