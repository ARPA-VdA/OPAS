import { useCallback, useEffect, useMemo, useState } from "react"
import {
  DndContext, closestCorners, KeyboardSensor, PointerSensor, useSensor, useSensors, type DragEndEvent,
} from "@dnd-kit/core"
import { restrictToVerticalAxis } from "@dnd-kit/modifiers"
import {
  SortableContext, arrayMove, sortableKeyboardCoordinates, useSortable, verticalListSortingStrategy,
} from "@dnd-kit/sortable"
import { CSS } from "@dnd-kit/utilities"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { Switch } from "@/components/ui/switch"
import { Collapsible, CollapsibleContent, CollapsibleTrigger } from "@/components/ui/collapsible"
import {
  Dialog, DialogContent, DialogHeader, DialogTitle, DialogDescription, DialogFooter, DialogClose,
} from "@/components/ui/dialog"
import { useEditMode } from "@/context/EditModeContext"
import { ModuleEditDialog } from "@/components/instruments/module-edit-dialog"
import { ChannelEditDialog } from "@/components/instruments/channel-edit-dialog"
import { AddInstrumentDialog } from "@/components/instruments/add-instrument-dialog"
import { StationEditDialog } from "@/components/configurations/station-edit-dialog"
import { ChannelIdOverview } from "@/components/configurations/channel-id-overview"
import { channelTypeInfo, channelTypeLabelPlural } from "@/lib/channelType"
import { computeDuplicateDatabaseIds } from "@/lib/channelIds"
import {
  IconArrowLeft, IconPlus, IconStar, IconPencil, IconSearch, IconChevronRight, IconGripVertical, IconDownload,
} from "@tabler/icons-react"

// Groups a module's channels by Type (0=parametro, 1=diagnostico, 2=allarme,
// see channelTypeInfo), each group's channels sorted by Position, groups
// themselves ordered by type ascending - one column per type in ModuleRow.
function groupChannelsByType(channels: OpasChannel[]): { type: number; channels: OpasChannel[] }[] {
  const byType = new Map<number, OpasChannel[]>()
  for (const channel of channels) {
    const group = byType.get(channel.type)
    if (group) group.push(channel)
    else byType.set(channel.type, [channel])
  }
  return [...byType.entries()]
    .sort(([a], [b]) => a - b)
    .map(([type, channels]) => ({ type, channels: [...channels].sort((a, b) => a.position - b.position) }))
}

interface ModuleRowProps {
  module: OpasModule
  expanded: boolean
  editMode: boolean
  duplicateIds: Set<number>
  onToggleExpanded: () => void
  onToggleActive: (checked: boolean) => void
  onEdit: () => void
  onSelectChannel: (channel: OpasChannel) => void
}

function ModuleRow({ module, expanded, editMode, duplicateIds, onToggleExpanded, onToggleActive, onEdit, onSelectChannel }: ModuleRowProps) {
  const { attributes, listeners, setNodeRef, transform, transition, isDragging } = useSortable({
    id: module.id,
    disabled: !editMode,
  })

  return (
    <Card
      ref={setNodeRef}
      style={{ transform: CSS.Transform.toString(transform), transition }}
      className={`gap-0 py-0 ${isDragging ? 'relative z-10 opacity-80' : ''}`}
    >
      <Collapsible open={expanded} onOpenChange={onToggleExpanded}>
        <CollapsibleTrigger asChild>
          <CardHeader className="p-3 cursor-pointer hover:bg-muted/30 transition-colors rounded-t-xl">
            <div className="flex items-center gap-2">
              {editMode && (
                <button
                  type="button"
                  {...attributes}
                  {...listeners}
                  onClick={(e) => e.stopPropagation()}
                  className="shrink-0 touch-none cursor-grab active:cursor-grabbing text-muted-foreground"
                >
                  <IconGripVertical size={14} />
                </button>
              )}
              <IconChevronRight
                size={14}
                className={`shrink-0 text-muted-foreground transition-transform ${expanded ? 'rotate-90' : ''}`}
              />
              <CardTitle className="flex-1 min-w-0 text-base font-bold truncate">{module.id} {module.name}</CardTitle>
              <span onClick={(e) => e.stopPropagation()} className="shrink-0">
                <Switch
                  checked={module.active}
                  disabled={!editMode}
                  onCheckedChange={onToggleActive}
                />
              </span>
              <Button
                variant="ghost"
                size="icon"
                className="size-6 shrink-0"
                title={editMode ? "Modifica strumento" : "Visualizza strumento"}
                onClick={(e) => { e.stopPropagation(); onEdit() }}
              >
                {editMode ? <IconPencil size={14} /> : <IconSearch size={14} />}
              </Button>
            </div>
          </CardHeader>
        </CollapsibleTrigger>
        <CollapsibleContent>
          <CardContent className="px-3 pb-3 pt-0">
            {module.channels.length === 0 ? (
              <p className="text-xs text-muted-foreground px-2 py-1">Nessun canale</p>
            ) : (
              <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-x-0 gap-y-3 sm:divide-x sm:divide-border">
                {groupChannelsByType(module.channels).map(({ type, channels }) => {
                  const { icon: TypeIcon } = channelTypeInfo(type)
                  return (
                    <div key={type} className="space-y-1 min-w-0 px-3 first:pl-0">
                      <div className="flex items-center gap-1.5 px-2 text-[11px] font-semibold text-muted-foreground uppercase tracking-wide">
                        <TypeIcon size={13} />
                        {channelTypeLabelPlural(type)}
                      </div>
                      {channels.map(channel => {
                        const isDup = duplicateIds.has(channel.databaseId)
                        return (
                          <button
                            key={channel.id}
                            type="button"
                            onClick={() => onSelectChannel(channel)}
                            title={isDup ? (channel.databaseId === 0 ? "ID database non assegnato" : "ID database duplicato in questa configurazione") : undefined}
                            className={`w-full flex items-center justify-between gap-2 rounded px-2 py-1 text-xs text-left transition-colors ${
                              isDup ? 'bg-destructive/10 hover:bg-destructive/20' : 'hover:bg-muted/50'
                            }`}
                          >
                            <span className="flex items-center gap-1.5 min-w-0">
                              <span className={`shrink-0 font-mono ${isDup ? 'text-destructive font-semibold' : 'text-muted-foreground'}`}>
                                {channel.databaseId}
                              </span>
                              <span className="truncate">{channel.name}</span>
                            </span>
                            <span className="text-muted-foreground shrink-0 font-mono">
                              {channel.unit}
                            </span>
                          </button>
                        )
                      })}
                    </div>
                  )
                })}
              </div>
            )}
          </CardContent>
        </CollapsibleContent>
      </Collapsible>
    </Card>
  )
}

interface ConfigDetailProps {
  entry: ConfigLibraryEntry
  onBack: () => void
  onActivated: () => void
}

export function ConfigDetail({ entry, onBack, onActivated }: ConfigDetailProps) {
  const { editMode } = useEditMode()
  const [data, setData] = useState<OpasConfigData | null>(null)
  const [loading, setLoading] = useState(true)
  const [selectedModule, setSelectedModule] = useState<OpasModule | null>(null)
  const [selectedChannel, setSelectedChannel] = useState<{ channel: OpasChannel; moduleId: number } | null>(null)
  const [addDialogOpen, setAddDialogOpen] = useState(false)
  const [stationDialogOpen, setStationDialogOpen] = useState(false)
  const [activating, setActivating] = useState(false)
  const [activateDialogOpen, setActivateDialogOpen] = useState(false)
  const [expandedModules, setExpandedModules] = useState<Set<number>>(new Set())
  const sensors = useSensors(
    useSensor(PointerSensor, { activationConstraint: { distance: 5 } }),
    useSensor(KeyboardSensor, { coordinateGetter: sortableKeyboardCoordinates }),
  )
  const duplicateIds = useMemo(() => computeDuplicateDatabaseIds(data?.modules ?? []), [data])

  const load = useCallback(async () => {
    setLoading(true)
    const result = await window.electron.getConfigByFilename(entry.filename)
    setData(result?.data ?? null)
    setLoading(false)
  }, [entry.filename])

  useEffect(() => {
    load()
    window.addEventListener('opas-config-saved', load)
    return () => window.removeEventListener('opas-config-saved', load)
  }, [load])

  async function handleExport() {
    await window.electron.exportConfigFile(entry.filename)
  }

  async function handleActivate() {
    setActivateDialogOpen(false)
    setActivating(true)
    try {
      const result = await window.electron.activateConfig(entry.filename)
      if (result?.success) {
        onActivated()
      }
    } finally {
      setActivating(false)
    }
  }

  function toggleModuleExpanded(moduleId: number) {
    setExpandedModules(prev => {
      const next = new Set(prev)
      if (next.has(moduleId)) next.delete(moduleId)
      else next.add(moduleId)
      return next
    })
  }

  async function handleToggleModuleActive(module: OpasModule, checked: boolean) {
    const result = await window.electron.saveOpasModule(module.id, { active: checked }, entry.filename)
    if (result?.success) {
      if (entry.isActive) {
        await window.electron.driverAction(String(module.id), 'restart')
      }
      window.dispatchEvent(new Event('opas-config-saved'))
    }
  }

  async function handleModuleDragEnd(event: DragEndEvent) {
    const { active, over } = event
    if (!over || active.id === over.id) return
    const oldIndex = modules.findIndex(m => m.id === active.id)
    const newIndex = modules.findIndex(m => m.id === over.id)
    if (oldIndex === -1 || newIndex === -1) return
    const reordered = arrayMove(modules, oldIndex, newIndex)
    const updates = reordered
      .map((module, index) => ({ module, index }))
      .filter(({ module, index }) => module.position !== index)
    if (updates.length === 0) return
    // Sequential, not Promise.all: the control server does a read-modify-write of the
    // whole config file per request (no locking), so concurrent saves for different
    // modules race and can silently clobber each other's position update.
    for (const { module, index } of updates) {
      await window.electron.saveOpasModule(module.id, { position: index }, entry.filename)
    }
    window.dispatchEvent(new Event('opas-config-saved'))
  }

  if (loading) {
    return <div className="p-4 text-sm text-muted-foreground">Caricamento…</div>
  }

  const modules = [...(data?.modules ?? [])].sort((a, b) => a.position - b.position)

  return (
    <div className="flex flex-col gap-4 p-4">
      <div className="flex items-center gap-3">
        <Button variant="ghost" size="icon" onClick={onBack} className="shrink-0">
          <IconArrowLeft size={18} />
        </Button>
        <div className="flex-1 min-w-0">
          <h2 className="text-xl font-bold truncate flex items-center gap-2">
            {data?.name || entry.filename}
            {entry.isActive && (
              <Badge className="gap-1 shrink-0 bg-green-100 text-green-700 border-green-200 dark:bg-green-500/20 dark:text-green-400 dark:border-green-500/30">
                <IconStar size={12} /> Attiva
              </Badge>
            )}
          </h2>
          <p className="text-sm text-muted-foreground truncate">{entry.filename}</p>
        </div>
        <Button variant="outline" onClick={handleExport} className="shrink-0 gap-1.5">
          <IconDownload size={14} /> Esporta
        </Button>
        {!entry.isActive && (
          <Button onClick={() => setActivateDialogOpen(true)} disabled={activating} className="shrink-0">
            Rendi attiva
          </Button>
        )}
      </div>

      <button
        type="button"
        onClick={() => setStationDialogOpen(true)}
        title={editMode ? 'Modifica intestazione' : 'Visualizza intestazione'}
        className="grid grid-cols-2 sm:grid-cols-4 gap-3 rounded-md border border-border bg-muted/20 p-3 text-sm text-left relative cursor-pointer hover:bg-muted/50 hover:border-primary/40 transition-all"
      >
        <div>
          <p className="text-muted-foreground text-xs">Località</p>
          <p className="font-medium truncate">{data?.stationLocation || '—'}</p>
        </div>
        <div>
          <p className="text-muted-foreground text-xs">Header file dati</p>
          <p className="font-medium truncate">{data?.dataFileHeader || '—'}</p>
        </div>
        <div>
          <p className="text-muted-foreground text-xs">Strumenti</p>
          <p className="font-medium">{modules.length}</p>
        </div>
        <div>
          <p className="text-muted-foreground text-xs">Ultimo aggiornamento</p>
          <p className="font-medium truncate">
            {data?.configLastUpdate ? new Date(data.configLastUpdate).toLocaleString('it-IT') : '—'}
          </p>
        </div>
      </button>

      {editMode && (
        <ChannelIdOverview modules={modules} duplicateIds={duplicateIds} editMode={editMode} configFilename={entry.filename} />
      )}

      <DndContext sensors={sensors} collisionDetection={closestCorners} modifiers={[restrictToVerticalAxis]} onDragEnd={handleModuleDragEnd}>
        <SortableContext items={modules.map(m => m.id)} strategy={verticalListSortingStrategy}>
          <div className="flex flex-col gap-2">
            {modules.map(module => (
              <ModuleRow
                key={module.id}
                module={module}
                expanded={expandedModules.has(module.id)}
                editMode={editMode}
                duplicateIds={duplicateIds}
                onToggleExpanded={() => toggleModuleExpanded(module.id)}
                onToggleActive={(checked) => handleToggleModuleActive(module, checked)}
                onEdit={() => setSelectedModule(module)}
                onSelectChannel={(channel) => setSelectedChannel({ channel, moduleId: module.id })}
              />
            ))}

            {editMode && (
              <Card
                onClick={() => setAddDialogOpen(true)}
                className="py-3 gap-0 flex-row items-center justify-center border-dashed shadow-none cursor-pointer hover:border-primary/50 hover:bg-muted/30 transition-all"
              >
                <div className="flex items-center gap-1.5 text-muted-foreground">
                  <IconPlus size={18} />
                  <span className="text-xs font-medium">Aggiungi strumento</span>
                </div>
              </Card>
            )}
          </div>
        </SortableContext>
      </DndContext>

      <StationEditDialog
        filename={entry.filename}
        data={stationDialogOpen ? data : null}
        onClose={() => setStationDialogOpen(false)}
      />
      <ModuleEditDialog
        module={selectedModule}
        onClose={() => setSelectedModule(null)}
        configFilename={entry.filename}
      />
      <ChannelEditDialog
        channel={selectedChannel?.channel ?? null}
        moduleId={selectedChannel?.moduleId ?? null}
        onClose={() => setSelectedChannel(null)}
        configFilename={entry.filename}
      />
      <AddInstrumentDialog
        open={addDialogOpen}
        onClose={() => setAddDialogOpen(false)}
        existingModules={modules}
        configFilename={entry.filename}
      />

      <Dialog open={activateDialogOpen} onOpenChange={setActivateDialogOpen}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Rendere attiva questa configurazione?</DialogTitle>
            <DialogDescription>
              "{entry.filename}" diventerà la configurazione attiva; quella attualmente
              attiva verrà spostata nella libreria. Il cambiamento avrà effetto sui driver
              in esecuzione solo dopo un riavvio del servizio.
            </DialogDescription>
          </DialogHeader>
          <DialogFooter>
            <DialogClose asChild>
              <Button variant="outline">Annulla</Button>
            </DialogClose>
            <Button onClick={handleActivate}>Rendi attiva</Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  )
}
