import { useCallback, useEffect, useState, type ReactNode } from "react"
import { Card } from "@/components/ui/card"
import { useInstruments } from "@/context/InstrumentContext"
import { useNavigation } from "@/context/NavigationContext"
import { mergeInstruments } from "@/lib/mergeInstruments"
import { instrumentNotResponding } from "@/components/instruments/instrument-card"
import { IconDatabaseX, IconPlugConnectedX, IconCloudOff, IconChevronRight } from "@tabler/icons-react"

const DRIVERS_POLL_MS = 5000
const SERVICE_STATUS_POLL_MS = 15000

interface AlarmRow {
  key: string
  icon: ReactNode
  message: string
  onClick: () => void
}

export function SystemAlarmsBanner() {
  const { instrumentValues } = useInstruments()
  const nav = useNavigation()

  const [opasConfig, setOpasConfig] = useState<OpasConfigWithFile>(null)
  const [drivers, setDrivers] = useState<Record<string, Omit<DriverInfo, 'id'>> | null>(null)
  const [driverCatalog, setDriverCatalog] = useState<DriverCatalogEntry[] | null>(null)
  const [storage, setStorage] = useState<{ usedGB: number | null; totalGB: number | null }>({ usedGB: null, totalGB: null })
  const [serviceUnreachable, setServiceUnreachable] = useState(false)

  const configData = opasConfig?.data

  const loadOpasConfig = useCallback(async () => {
    const loaded = await window.electron.getOpasConfig?.()
    setOpasConfig(loaded ?? null)
  }, [])

  const fetchDrivers = useCallback(async () => {
    const raw = await window.electron.getDrivers()
    setDrivers(raw)
  }, [])

  const fetchDriverCatalog = useCallback(async () => {
    const catalog = await window.electron.getDriverCatalog()
    setDriverCatalog(catalog)
  }, [])

  const checkService = useCallback(async () => {
    const result = await window.electron.getServiceStartTime()
    setServiceUnreachable(result === null)
  }, [])

  useEffect(() => {
    loadOpasConfig()
    window.addEventListener('settings-saved', loadOpasConfig)
    window.addEventListener('opas-config-saved', loadOpasConfig)
    return () => {
      window.removeEventListener('settings-saved', loadOpasConfig)
      window.removeEventListener('opas-config-saved', loadOpasConfig)
    }
  }, [loadOpasConfig])

  useEffect(() => {
    fetchDrivers()
    fetchDriverCatalog()
    const interval = setInterval(() => { fetchDrivers(); fetchDriverCatalog() }, DRIVERS_POLL_MS)
    return () => clearInterval(interval)
  }, [fetchDrivers, fetchDriverCatalog])

  useEffect(() => {
    checkService()
    const interval = setInterval(checkService, SERVICE_STATUS_POLL_MS)
    return () => clearInterval(interval)
  }, [checkService])

  useEffect(() => {
    const unsubscribe = window.electron.subscribeStatistics?.((stats: Statistics) => {
      setStorage({
        usedGB: typeof stats.storageUsedGB === 'number' ? stats.storageUsedGB : null,
        totalGB: typeof stats.storageTotalGB === 'number' ? stats.storageTotalGB : null,
      })
    })
    return () => unsubscribe?.()
  }, [])

  const alarms: AlarmRow[] = []

  // 1. Disco quasi pieno
  const threshold = configData?.minimunFreeDiskSpace ?? 0
  if (threshold > 0 && storage.usedGB !== null && storage.totalGB !== null) {
    const freeGB = storage.totalGB - storage.usedGB
    if (freeGB <= threshold) {
      alarms.push({
        key: 'disk',
        icon: <IconDatabaseX size={18} className="text-amber-600 dark:text-amber-400 shrink-0" />,
        message: `Disco quasi pieno: ${freeGB.toFixed(1)} GB liberi (soglia ${threshold} GB)`,
        onClick: () => nav?.navigateTo('nav.system'),
      })
    }
  }

  // 2. Strumenti che non rispondono (esclude quelli disabilitati volontariamente)
  const modules = configData?.modules ?? []
  const resolvedModuleIds = new Set<number>(
    (driverCatalog ?? []).flatMap(entry => entry.instruments.map(i => i.id).filter((id): id is number => id !== null))
  )
  const merged = mergeInstruments(instrumentValues, drivers, modules, resolvedModuleIds)
  const problemCount = merged.filter(i => i.moduleConfig?.active !== false && instrumentNotResponding(i)).length
  if (problemCount > 0) {
    alarms.push({
      key: 'instruments',
      icon: <IconPlugConnectedX size={18} className="text-amber-600 dark:text-amber-400 shrink-0" />,
      message: problemCount === 1
        ? '1 strumento non risponde'
        : `${problemCount} strumenti non rispondono`,
      onClick: () => nav?.navigateTo('nav.instruments'),
    })
  }

  // 3. Servizio Python non raggiungibile
  if (serviceUnreachable) {
    alarms.push({
      key: 'service',
      icon: <IconCloudOff size={18} className="text-amber-600 dark:text-amber-400 shrink-0" />,
      message: 'Servizio Python non raggiungibile',
      onClick: () => nav?.navigateTo('nav.system'),
    })
  }

  if (alarms.length === 0) return null

  return (
    <div className="flex flex-col gap-2">
      {alarms.map(alarm => (
        <Card
          key={alarm.key}
          onClick={alarm.onClick}
          className="cursor-pointer hover:shadow-sm hover:border-primary/50 transition-all py-0 gap-0 bg-amber-50 dark:bg-amber-500/10 border-amber-200 dark:border-amber-500/30"
        >
          <div className="flex items-center gap-2 px-3 py-2.5">
            {alarm.icon}
            <span className="flex-1 min-w-0 text-sm font-medium text-amber-800 dark:text-amber-300 truncate">
              {alarm.message}
            </span>
            <IconChevronRight size={16} className="text-amber-600/70 dark:text-amber-400/70 shrink-0" />
          </div>
        </Card>
      ))}
    </div>
  )
}
