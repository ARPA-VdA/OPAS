import { useEffect, useMemo, useState } from "react"
import {
  DndContext, closestCorners, KeyboardSensor, PointerSensor, useSensor, useSensors, type DragEndEvent,
} from "@dnd-kit/core"
import { restrictToVerticalAxis } from "@dnd-kit/modifiers"
import {
  SortableContext, arrayMove, sortableKeyboardCoordinates, useSortable, verticalListSortingStrategy,
} from "@dnd-kit/sortable"
import { CSS } from "@dnd-kit/utilities"
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Tooltip, TooltipContent, TooltipTrigger } from "@/components/ui/tooltip"
import { IconGripVertical, IconArrowRight, IconChevronRight } from "@tabler/icons-react"
import { channelTypeInfo } from "@/lib/channelType"
import { channelKey } from "@/lib/channelIds"

type FlatChannel = { channel: OpasChannel; moduleId: number; moduleName: string }

function flattenChannels(modules: OpasModule[]): FlatChannel[] {
  return modules.flatMap(m => m.channels.map(ch => ({ channel: ch, moduleId: m.id, moduleName: m.name })))
}

interface ChannelIdOverviewProps {
  modules: OpasModule[]
  duplicateIds: Set<number>
  editMode: boolean
  configFilename: string
}

export function ChannelIdOverview({ modules, duplicateIds, editMode, configFilename }: ChannelIdOverviewProps) {
  const [reordering, setReordering] = useState(false)
  const [tableVisible, setTableVisible] = useState(false)

  const flat = useMemo(() => flattenChannels(modules), [modules])

  const duplicateCount = flat.filter(f => duplicateIds.has(f.channel.databaseId)).length

  const sortedFlat = useMemo(
    () => [...flat].sort((a, b) => a.channel.databaseId - b.channel.databaseId),
    [flat]
  )

  // Duplicates must always be visible - the manual toggle can still open it
  // otherwise, but can't hide it while a conflict exists.
  const visible = tableVisible || duplicateCount > 0

  if (reordering) {
    return <ReorderParametri modules={modules} configFilename={configFilename} onDone={() => setReordering(false)} />
  }

  return (
    <div className="rounded-md border border-border bg-muted/10 p-3 space-y-3">
      <div className="flex items-center justify-between gap-2 flex-wrap">
        <button
          type="button"
          onClick={() => setTableVisible(v => !v)}
          className="flex items-center gap-2 hover:opacity-80 transition-opacity"
        >
          <IconChevronRight
            size={14}
            className={`shrink-0 text-muted-foreground transition-transform ${visible ? 'rotate-90' : ''}`}
          />
          <p className="text-sm font-semibold">ID Database</p>
          <span className="text-xs text-muted-foreground">{flat.length} canali</span>
          {duplicateCount > 0 && <Badge variant="destructive">{duplicateCount} da correggere</Badge>}
        </button>
        {editMode && (
          <Button variant="outline" size="sm" onClick={() => setReordering(true)}>
            Riordina e rinumera parametri
          </Button>
        )}
      </div>

      {visible && (
      <Table>
        <TableHeader>
          <TableRow>
            <TableHead>ID Database</TableHead>
            <TableHead>Canale</TableHead>
            <TableHead>Strumento</TableHead>
          </TableRow>
        </TableHeader>
        <TableBody>
          {sortedFlat.map(({ channel, moduleId, moduleName }) => {
            const isDup = duplicateIds.has(channel.databaseId)
            return (
              <TableRow key={channelKey(moduleId, channel.id)} className={isDup ? "bg-destructive/10" : undefined}>
                <TableCell className="font-mono">
                  <div className="flex items-center gap-2">
                    <DatabaseIdCell
                      moduleId={moduleId}
                      channel={channel}
                      configFilename={configFilename}
                      editMode={editMode}
                    />
                    {isDup && (
                      <Badge variant="destructive">{channel.databaseId === 0 ? "Non assegnato" : "Duplicato"}</Badge>
                    )}
                  </div>
                </TableCell>
                <TableCell>
                  <div className="flex items-center gap-1.5">
                    {(() => {
                      const { icon: TypeIcon, label } = channelTypeInfo(channel.type)
                      return (
                        <Tooltip>
                          <TooltipTrigger asChild>
                            <span className="inline-flex text-muted-foreground shrink-0">
                              <TypeIcon size={16} />
                            </span>
                          </TooltipTrigger>
                          <TooltipContent>{label}</TooltipContent>
                        </Tooltip>
                      )
                    })()}
                    {channel.name}
                  </div>
                </TableCell>
                <TableCell className="text-muted-foreground">{moduleName}</TableCell>
              </TableRow>
            )
          })}
          {sortedFlat.length === 0 && (
            <TableRow>
              <TableCell colSpan={3} className="text-center text-muted-foreground">Nessun canale</TableCell>
            </TableRow>
          )}
        </TableBody>
      </Table>
      )}
    </div>
  )
}

function DatabaseIdCell({ moduleId, channel, configFilename, editMode }: {
  moduleId: number; channel: OpasChannel; configFilename: string; editMode: boolean
}) {
  const [editing, setEditing] = useState(false)
  const [value, setValue] = useState(String(channel.databaseId))
  const [saving, setSaving] = useState(false)

  useEffect(() => { setValue(String(channel.databaseId)) }, [channel.databaseId])

  async function commit() {
    const parsed = parseInt(value, 10)
    if (!Number.isNaN(parsed) && parsed !== channel.databaseId) {
      setSaving(true)
      await window.electron.saveOpasChannel(moduleId, channel.id, { databaseId: parsed }, configFilename)
      window.dispatchEvent(new Event('opas-config-saved'))
      setSaving(false)
    }
    setEditing(false)
  }

  if (!editMode) return <span>{channel.databaseId}</span>

  if (editing) {
    return (
      <Input
        type="number"
        autoFocus
        value={value}
        disabled={saving}
        onChange={(e) => setValue(e.target.value)}
        onBlur={commit}
        onKeyDown={(e) => {
          if (e.key === 'Enter') commit()
          if (e.key === 'Escape') { setValue(String(channel.databaseId)); setEditing(false) }
        }}
        onClick={(e) => e.stopPropagation()}
        className="h-7 w-20 px-1.5 text-xs font-mono"
      />
    )
  }

  return (
    <button
      type="button"
      onClick={(e) => { e.stopPropagation(); setEditing(true) }}
      className="hover:underline decoration-dotted underline-offset-2"
      title="Modifica ID database"
    >
      {channel.databaseId}
    </button>
  )
}

interface ReorderParametriProps {
  modules: OpasModule[]
  configFilename: string
  onDone: () => void
}

function ReorderParametri({ modules, configFilename, onDone }: ReorderParametriProps) {
  const flat = useMemo(() => flattenChannels(modules), [modules])

  const parametri = useMemo(
    () => flat.filter(f => f.channel.type === 0).sort((a, b) => a.channel.databaseId - b.channel.databaseId),
    [flat]
  )
  // Diagnostici keep their current DatabaseId untouched - the 1..N assignment
  // below must never hand a parametro an id already taken by one of these.
  const diagnosticiIds = useMemo(
    () => new Set(flat.filter(f => f.channel.type !== 0).map(f => f.channel.databaseId)),
    [flat]
  )
  const byKey = useMemo(() => {
    const map = new Map<string, FlatChannel>()
    for (const f of parametri) map.set(channelKey(f.moduleId, f.channel.id), f)
    return map
  }, [parametri])

  const [order, setOrder] = useState(() => parametri.map(f => channelKey(f.moduleId, f.channel.id)))
  const [saving, setSaving] = useState(false)

  // Sequential candidate 1, 2, 3... in the user-chosen order, skipping any
  // value already occupied by an (untouched) diagnostico.
  const newIds = useMemo(() => {
    const result = new Map<string, number>()
    let candidate = 1
    for (const key of order) {
      while (diagnosticiIds.has(candidate)) candidate++
      result.set(key, candidate)
      candidate++
    }
    return result
  }, [order, diagnosticiIds])

  const changedCount = order.filter(key => {
    const f = byKey.get(key)
    return f && newIds.get(key) !== f.channel.databaseId
  }).length

  const sensors = useSensors(
    useSensor(PointerSensor, { activationConstraint: { distance: 5 } }),
    useSensor(KeyboardSensor, { coordinateGetter: sortableKeyboardCoordinates }),
  )

  function handleDragEnd(event: DragEndEvent) {
    const { active, over } = event
    if (!over || active.id === over.id) return
    setOrder(prev => {
      const oldIndex = prev.indexOf(String(active.id))
      const newIndex = prev.indexOf(String(over.id))
      if (oldIndex === -1 || newIndex === -1) return prev
      return arrayMove(prev, oldIndex, newIndex)
    })
  }

  async function handleConfirm() {
    setSaving(true)
    try {
      // Sequential, not Promise.all: the control server does a read-modify-write of
      // the whole config file per request (no locking) - see handleModuleDragEnd
      // in config-detail.tsx for the same constraint on module reordering.
      for (const key of order) {
        const f = byKey.get(key)
        const newId = newIds.get(key)
        if (!f || newId === undefined || newId === f.channel.databaseId) continue
        await window.electron.saveOpasChannel(f.moduleId, f.channel.id, { databaseId: newId }, configFilename)
      }
      window.dispatchEvent(new Event('opas-config-saved'))
      onDone()
    } finally {
      setSaving(false)
    }
  }

  return (
    <div className="rounded-md border border-border bg-muted/10 p-3 space-y-3">
      <div className="flex items-center justify-between gap-2 flex-wrap">
        <div>
          <p className="text-sm font-semibold">Riordina parametri</p>
          <p className="text-xs text-muted-foreground">Trascina per ordinare, poi conferma per assegnare gli ID database in sequenza. I diagnostici non vengono toccati.</p>
        </div>
        <div className="flex items-center gap-2 shrink-0">
          <Button variant="outline" size="sm" onClick={onDone} disabled={saving}>Annulla</Button>
          <Button size="sm" onClick={handleConfirm} disabled={saving || changedCount === 0}>
            {saving ? 'Salvataggio…' : `Conferma (${changedCount} da cambiare)`}
          </Button>
        </div>
      </div>

      {parametri.length === 0 ? (
        <p className="text-sm text-muted-foreground py-4 text-center">Nessun canale parametro in questa configurazione.</p>
      ) : (
        <DndContext sensors={sensors} collisionDetection={closestCorners} modifiers={[restrictToVerticalAxis]} onDragEnd={handleDragEnd}>
          <SortableContext items={order} strategy={verticalListSortingStrategy}>
            <div className="flex flex-col gap-1">
              {order.map(key => {
                const f = byKey.get(key)
                if (!f) return null
                const newId = newIds.get(key) ?? f.channel.databaseId
                return (
                  <ParametroRow
                    key={key}
                    id={key}
                    channelName={f.channel.name}
                    moduleName={f.moduleName}
                    currentId={f.channel.databaseId}
                    newId={newId}
                    changed={newId !== f.channel.databaseId}
                  />
                )
              })}
            </div>
          </SortableContext>
        </DndContext>
      )}
    </div>
  )
}

function ParametroRow({ id, channelName, moduleName, currentId, newId, changed }: {
  id: string; channelName: string; moduleName: string; currentId: number; newId: number; changed: boolean
}) {
  const { attributes, listeners, setNodeRef, transform, transition, isDragging } = useSortable({ id })

  return (
    <div
      ref={setNodeRef}
      style={{ transform: CSS.Transform.toString(transform), transition }}
      className={`flex items-center gap-2 rounded-md border border-border bg-card px-2 py-1.5 text-sm ${isDragging ? 'relative z-10 opacity-80' : ''}`}
    >
      <button
        type="button"
        {...attributes}
        {...listeners}
        className="shrink-0 touch-none cursor-grab active:cursor-grabbing text-muted-foreground"
      >
        <IconGripVertical size={14} />
      </button>
      <span className="flex-1 min-w-0 truncate">{channelName}</span>
      <span className="text-xs text-muted-foreground shrink-0">{moduleName}</span>
      <span className={`font-mono text-xs shrink-0 flex items-center gap-1 ${changed ? 'text-amber-600 dark:text-amber-400' : 'text-muted-foreground'}`}>
        {currentId}
        {changed && (
          <>
            <IconArrowRight size={12} />
            {newId}
          </>
        )}
      </span>
    </div>
  )
}
