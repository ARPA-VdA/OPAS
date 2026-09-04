import { useMemo, useState } from "react"
import { Collapsible, CollapsibleContent, CollapsibleTrigger } from "@/components/ui/collapsible"
import { ToggleGroup, ToggleGroupItem } from "@/components/ui/toggle-group"
import { Checkbox } from "@/components/ui/checkbox"
import { IconChevronRight, IconFileOff, IconEyeOff } from "@tabler/icons-react"
import { channelTypeInfo, channelTypeLabelPlural } from "@/lib/channelType"
import { channelKey } from "@/lib/channelIds"

// 0 = parametro, 1 = diagnostico, 2 = allarme (see lib/channelType.ts).
const CHANNEL_TYPES = [0, 1, 2] as const
const DISABLED_FILTER_VALUE = "disabled"
const FILTER_ITEM_CLASS = "data-[state=on]:bg-primary data-[state=on]:text-primary-foreground"

interface ChannelMultiPickerProps {
  modules: OpasModule[]
  selected: Set<string>
  onToggle: (moduleId: number, channelId: number) => void
}

export function ChannelMultiPicker({ modules, selected, onToggle }: ChannelMultiPickerProps) {
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

      <div className="flex flex-col gap-0.5 max-h-80 overflow-y-auto">
        {visibleModules.length === 0 && (
          <p className="text-sm text-muted-foreground p-2">Nessuno strumento corrisponde ai filtri.</p>
        )}
        {visibleModules.map((module) => {
          const isOpen = open.has(module.id)
          const selectedCount = module.channels.filter(c => selected.has(channelKey(module.id, c.id))).length
          return (
            <Collapsible key={module.id} open={isOpen} onOpenChange={() => toggleOpen(module.id)}>
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
                  {selectedCount > 0 && (
                    <span className="text-xs text-primary font-normal">{selectedCount} selezionati</span>
                  )}
                </button>
              </CollapsibleTrigger>
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
