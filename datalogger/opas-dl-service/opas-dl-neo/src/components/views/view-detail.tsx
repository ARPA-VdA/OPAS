import { useCallback, useEffect, useMemo, useState } from "react"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { ToggleGroup, ToggleGroupItem } from "@/components/ui/toggle-group"
import {
  Dialog, DialogContent, DialogHeader, DialogTitle, DialogDescription, DialogFooter, DialogClose,
} from "@/components/ui/dialog"
import {
  IconArrowLeft, IconPencil, IconTrash, IconCheck, IconX, IconLayoutGrid, IconTable,
  IconStar, IconStarFilled,
} from "@tabler/icons-react"
import { resolveViewChannels } from "@/lib/viewResolution"
import { ViewCardsGrid } from "./view-cards-grid"
import { ViewTable } from "./view-table"
import type { ViewChannelData, ViewInstrumentInfo } from "./types"

// Same cadence as readings-section.tsx's single-instrument poll, generalized
// to every distinct instrument referenced by this view.
const READINGS_POLL_MS = 5000
// Brand/model/alive rarely change - a much slower poll than instant readings
// keeps this from hammering the control-server-backed getDrivers() IPC.
const DRIVERS_POLL_MS = 20000

interface ViewDetailProps {
  id: string
  onBack: () => void
}

export function ViewDetail({ id, onBack }: ViewDetailProps) {
  const [data, setData] = useState<ViewData | null>(null)
  const [modules, setModules] = useState<OpasModule[]>([])
  const [drivers, setDrivers] = useState<Record<string, Omit<DriverInfo, 'id'>> | null>(null)
  const [readingsByInstrument, setReadingsByInstrument] = useState<Map<string, InstrumentReading[]>>(new Map())
  const [renaming, setRenaming] = useState(false)
  const [nameDraft, setNameDraft] = useState('')
  const [deleteDialogOpen, setDeleteDialogOpen] = useState(false)

  const loadView = useCallback(() => {
    window.electron.getViewById(id).then(setData)
  }, [id])

  const loadConfig = useCallback(() => {
    window.electron.getOpasConfig().then(config => {
      const configData = config?.data
      setModules(configData?.modules ?? [])
    })
  }, [])

  useEffect(() => { loadView() }, [loadView])

  useEffect(() => {
    loadConfig()
    window.addEventListener('opas-config-saved', loadConfig)
    return () => window.removeEventListener('opas-config-saved', loadConfig)
  }, [loadConfig])

  useEffect(() => {
    const load = () => window.electron.getDrivers().then(setDrivers)
    load()
    const interval = setInterval(load, DRIVERS_POLL_MS)
    return () => clearInterval(interval)
  }, [])

  // channelId is scoped to its module, so refs are only meaningful against
  // whichever config is active right now - see resolveViewChannels.
  const resolved = useMemo(() => resolveViewChannels(data?.channels ?? [], modules), [data, modules])

  useEffect(() => {
    if (resolved.length === 0) {
      setReadingsByInstrument(new Map())
      return
    }
    // getInstrumentReadings() matches by module.name (first match wins if
    // duplicated - a pre-existing app-wide limitation, not specific here).
    const instrumentNames = [...new Set(resolved.map(r => r.module.name))]
    let cancelled = false
    const load = async () => {
      const entries = await Promise.all(
        instrumentNames.map(async (name) => [name, await window.electron.getInstrumentReadings(name)] as const)
      )
      if (cancelled) return
      setReadingsByInstrument(new Map(entries))
    }
    load()
    const interval = setInterval(load, READINGS_POLL_MS)
    return () => { cancelled = true; clearInterval(interval) }
  }, [resolved])

  const instrumentInfo = useMemo(() => {
    const map = new Map<number, ViewInstrumentInfo>()
    const driversByName = new Map(Object.values(drivers ?? {}).map(info => [info.name, info]))
    for (const { moduleId, module } of resolved) {
      if (map.has(moduleId)) continue
      const driverInfo = driversByName.get(module.name)
      map.set(moduleId, {
        alive: driverInfo?.alive ?? false,
        brand: driverInfo?.brand ?? null,
        model: driverInfo?.model ?? null,
      })
    }
    return map
  }, [resolved, drivers])

  const channelData: ViewChannelData[] = useMemo(() => {
    return resolved.map(r => {
      const readings = readingsByInstrument.get(r.module.name) ?? []
      let value: number | null = null
      let rawValue: number | null = null
      let timestamp: string | null = null
      for (const reading of readings) {
        const match = reading.channels.find(c => c.name === r.channel.name)
        if (match) {
          value = match.value
          rawValue = match.rawValue ?? null
          timestamp = reading.timestamp
          break
        }
      }
      return { ...r, value, rawValue, timestamp }
    })
  }, [resolved, readingsByInstrument])

  const handleStartRename = () => {
    setNameDraft(data?.name ?? '')
    setRenaming(true)
  }

  const handleSaveRename = async () => {
    if (!data || nameDraft.trim() === '') {
      setRenaming(false)
      return
    }
    await window.electron.updateView(data.id, { name: nameDraft.trim() })
    setRenaming(false)
    window.dispatchEvent(new Event('views-saved'))
    loadView()
  }

  const handleToggleFavorite = async () => {
    if (!data) return
    const next = !data.favorite
    setData({ ...data, favorite: next })
    await window.electron.setFavoriteView(data.id, next)
    window.dispatchEvent(new Event('views-saved'))
  }

  const handleDisplayModeChange = async (mode: ViewDisplayMode) => {
    if (!data) return
    setData({ ...data, displayMode: mode })
    await window.electron.updateView(data.id, { displayMode: mode })
    window.dispatchEvent(new Event('views-saved'))
  }

  const handleDelete = async () => {
    if (!data) return
    await window.electron.deleteView(data.id)
    window.dispatchEvent(new Event('views-saved'))
    setDeleteDialogOpen(false)
    onBack()
  }

  if (!data) {
    return (
      <div className="flex flex-col gap-4 p-4">
        <Button variant="ghost" size="icon" onClick={onBack} className="shrink-0 w-fit">
          <IconArrowLeft size={18} />
        </Button>
        <p className="text-sm text-muted-foreground">Vista non trovata.</p>
      </div>
    )
  }

  return (
    <div className="flex flex-col gap-4 p-4">
      <div className="flex items-center gap-3">
        <Button variant="ghost" size="icon" onClick={onBack} className="shrink-0">
          <IconArrowLeft size={18} />
        </Button>

        {renaming ? (
          <div className="flex items-center gap-1.5 flex-1 min-w-0">
            <Input
              autoFocus
              value={nameDraft}
              onChange={e => setNameDraft(e.target.value)}
              onKeyDown={e => { if (e.key === 'Enter') handleSaveRename(); if (e.key === 'Escape') setRenaming(false) }}
              className="h-8 max-w-xs"
            />
            <Button variant="ghost" size="icon" className="size-8" onClick={handleSaveRename}>
              <IconCheck size={16} />
            </Button>
            <Button variant="ghost" size="icon" className="size-8" onClick={() => setRenaming(false)}>
              <IconX size={16} />
            </Button>
          </div>
        ) : (
          <div className="flex items-center gap-1.5 flex-1 min-w-0">
            <h2 className="text-xl font-bold truncate">{data.name}</h2>
            <Button variant="ghost" size="icon" className="size-7 shrink-0" onClick={handleStartRename} title="Rinomina">
              <IconPencil size={14} />
            </Button>
          </div>
        )}

        <ToggleGroup
          type="single"
          variant="outline"
          size="sm"
          value={data.displayMode}
          onValueChange={v => { if (v) handleDisplayModeChange(v as ViewDisplayMode) }}
        >
          <ToggleGroupItem value="cards" title="Vista schede">
            <IconLayoutGrid size={14} />
          </ToggleGroupItem>
          <ToggleGroupItem value="table" title="Vista tabella">
            <IconTable size={14} />
          </ToggleGroupItem>
        </ToggleGroup>

        <Button
          variant="outline"
          size="icon"
          className="shrink-0"
          onClick={handleToggleFavorite}
          title={data.favorite ? "Rimuovi dalle preferite" : "Imposta come vista preferita"}
        >
          {data.favorite
            ? <IconStarFilled size={16} className="text-amber-500" />
            : <IconStar size={16} />}
        </Button>

        <Button variant="outline" size="icon" className="shrink-0 text-destructive hover:text-destructive" onClick={() => setDeleteDialogOpen(true)} title="Elimina vista">
          <IconTrash size={16} />
        </Button>
      </div>

      {data.displayMode === 'cards'
        ? <ViewCardsGrid channels={channelData} instrumentInfo={instrumentInfo} />
        : <ViewTable channels={channelData} />
      }

      <Dialog open={deleteDialogOpen} onOpenChange={setDeleteDialogOpen}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Eliminare questa vista?</DialogTitle>
            <DialogDescription>
              "{data.name}" verrà rimossa definitivamente. Gli strumenti e i canali che mostra non vengono modificati.
            </DialogDescription>
          </DialogHeader>
          <DialogFooter>
            <DialogClose asChild>
              <Button variant="outline">Annulla</Button>
            </DialogClose>
            <Button variant="destructive" onClick={handleDelete}>Elimina</Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  )
}
