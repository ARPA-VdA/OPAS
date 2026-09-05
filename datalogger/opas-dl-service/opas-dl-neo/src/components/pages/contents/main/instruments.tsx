import { useCallback, useEffect, useState } from "react"
import { useInstruments } from "@/context/InstrumentContext"
import { useEditMode } from "@/context/EditModeContext"
import { useNavigation } from "@/context/NavigationContext"
import { InstrumentCard } from "@/components/instruments/instrument-card"
import { InstrumentDetail } from "@/components/instruments/instrument-detail"
import { AddInstrumentDialog } from "@/components/instruments/add-instrument-dialog"
import { mergeInstruments } from "@/lib/mergeInstruments"
import { Card } from "@/components/ui/card"
import { IconPlus } from "@tabler/icons-react"

export function InstrumentsContent() {
  const { instrumentValues } = useInstruments()
  const { editMode } = useEditMode()
  const nav = useNavigation()
  const [drivers, setDrivers] = useState<Record<string, Omit<DriverInfo, 'id'>> | null>(null)
  const [driverCatalog, setDriverCatalog] = useState<DriverCatalogEntry[] | null>(null)
  const [modules, setModules] = useState<OpasModule[]>([])
  const [selectedId, setSelectedId] = useState<string | null>(null)
  const [addDialogOpen, setAddDialogOpen] = useState(false)

  const fetchDrivers = useCallback(async () => {
    const raw = await window.electron.getDrivers()
    setDrivers(raw)
  }, [])

  const fetchDriverCatalog = useCallback(async () => {
    const catalog = await window.electron.getDriverCatalog()
    setDriverCatalog(catalog)
  }, [])

  const handleAction = async (driverKey: string, action: 'start' | 'stop' | 'restart') => {
    await window.electron.driverAction(driverKey, action)
    fetchDrivers()
  }

  const handleToggleModuleActive = async (module: OpasModule, checked: boolean) => {
    const result = await window.electron.saveOpasModule(module.id, { active: checked })
    if (result?.success) {
      await window.electron.driverAction(String(module.id), 'restart')
      window.dispatchEvent(new Event('opas-config-saved'))
    }
  }

  const loadConfig = useCallback(async () => {
    const config = await window.electron.getOpasConfig?.()
    const data = config?.data
    setModules(data?.modules ?? [])
  }, [])

  useEffect(() => {
    const handleConfigSaved = () => {
      loadConfig()
      fetchDrivers()
      fetchDriverCatalog()
    }
    loadConfig()
    fetchDrivers()
    fetchDriverCatalog()
    window.addEventListener('settings-saved', loadConfig)
    window.addEventListener('opas-config-saved', handleConfigSaved)
    const interval = setInterval(fetchDrivers, 5000)
    return () => {
      clearInterval(interval)
      window.removeEventListener('settings-saved', loadConfig)
      window.removeEventListener('opas-config-saved', handleConfigSaved)
    }
  }, [fetchDrivers, fetchDriverCatalog, loadConfig])

  // One-shot: another page (e.g. the driver detail dialog) can navigate here
  // asking to land directly on a specific instrument's detail view, by
  // module Name (the same value MergedInstrument.id uses - see
  // mergeInstruments above). Consumed once, then cleared, so navigating back
  // to this page later doesn't re-select it.
  useEffect(() => {
    const payload = nav?.payload as { selectInstrumentName?: string } | null | undefined
    if (payload?.selectInstrumentName) {
      setSelectedId(payload.selectInstrumentName)
      nav?.clearPayload()
    }
  }, [nav?.payload])

  const resolvedModuleIds = new Set<number>(
    (driverCatalog ?? []).flatMap(entry => entry.instruments.map(i => i.id).filter((id): id is number => id !== null))
  )
  const instruments = mergeInstruments(instrumentValues, drivers, modules, resolvedModuleIds)
  const selected = selectedId ? instruments.find(i => i.id === selectedId) ?? null : null

  if (selected) {
    return (
      <InstrumentDetail
        instrument={selected}
        onBack={() => setSelectedId(null)}
        onAction={handleAction}
        onToggleActive={handleToggleModuleActive}
      />
    )
  }

  return (
    <div className="flex flex-col gap-4 p-4">
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
        {instruments.map(instrument => (
          <InstrumentCard
            key={instrument.id}
            instrument={instrument}
            onClick={() => setSelectedId(instrument.id)}
            onAction={handleAction}
            onToggleActive={handleToggleModuleActive}
          />
        ))}
        {editMode && (
          <Card
            onClick={() => setAddDialogOpen(true)}
            className="py-0 gap-0 flex items-center justify-center min-h-[100px] border-dashed shadow-none cursor-pointer hover:border-primary/50 hover:bg-muted/30 transition-all"
          >
            <div className="flex flex-col items-center gap-1.5 text-muted-foreground p-4">
              <IconPlus size={20} />
              <span className="text-xs font-medium">Aggiungi strumento</span>
            </div>
          </Card>
        )}
      </div>

      <AddInstrumentDialog
        open={addDialogOpen}
        onClose={() => setAddDialogOpen(false)}
        existingModules={modules}
      />
    </div>
  )
}
