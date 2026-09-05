import { useCallback, useEffect, useState } from 'react'
import { SystemStatsGrid, type SystemStat } from "@/components/system/system-stats-grid"

const initialSystemStats: SystemStat[] = [
  { id: 'cpu', label: 'CPU', value: '0%', subtitle: 'Utilizzo' },
  { id: 'ram', label: 'RAM', value: '0%', subtitle: 'Utilizzo' },
  { id: 'disk', label: 'Disco', value: '0%', subtitle: 'Utilizzo' },
  { id: 'drivers', label: 'Drivers Attivi', value: '0', subtitle: 'In esecuzione' },
  { id: 'uiStart', label: 'UI avviata', value: '—' },
  { id: 'serviceStart', label: 'Servizio avviato', value: '—' },
]

function formatStartTime(ms: number | null): string {
  if (ms === null) return '—'
  const d = new Date(ms)
  return `${d.toLocaleTimeString('it-IT')} · ${d.toLocaleDateString('it-IT')}`
}

export function SystemContent() {
  const [appVersion, setAppVersion] = useState<string | null>(null)
  const [systemStatsState, setSystemStatsState] = useState(initialSystemStats)
  const [driverCounts, setDriverCounts] = useState({ active: 0, total: 0 })
  const [debugPaths, setDebugPaths] = useState<EventPayloadMapping['getDebugPaths'] | null>(null)

  useEffect(() => {
    window.electron.getStaticData?.().then(data => {
      if (data?.appVersion) setAppVersion(data.appVersion)
      if (data?.uiStartTime) {
        setSystemStatsState(prev => prev.map(s =>
          s.id === 'uiStart' ? { ...s, value: formatStartTime(data.uiStartTime) } : s
        ))
      }
    })
  }, [])

  useEffect(() => {
    window.electron.getServiceStartTime?.().then(result => {
      setSystemStatsState(prev => prev.map(s =>
        s.id === 'serviceStart' ? { ...s, value: formatStartTime(result?.startTime ?? null) } : s
      ))
    })
  }, [])

  useEffect(() => {
    window.electron.getDebugPaths?.().then(setDebugPaths)
  }, [])

  const fetchDriverCounts = useCallback(async () => {
    const raw = await window.electron.getDrivers()
    if (!raw) return
    const entries = Object.values(raw)
    setDriverCounts({ active: entries.filter(d => d.alive).length, total: entries.length })
  }, [])

  useEffect(() => {
    fetchDriverCounts()
    const interval = setInterval(fetchDriverCounts, 5000)
    return () => clearInterval(interval)
  }, [fetchDriverCounts])

  useEffect(() => {
    const unsubscribe = window.electron.subscribeStatistics?.((stats: any) => {
      setSystemStatsState(prev => prev.map(s => {
        if (s.id === 'cpu') {
          const pct = Math.round((stats.cpuUsage ?? 0) * 100)
          return { ...s, value: `${pct}%`, subtitle: stats.cpuModel || s.subtitle }
        }
        if (s.id === 'ram') {
          const pct = Math.round((stats.ramUsage ?? 0) * 100)
          const subtitle = (typeof stats.ramUsedGB === 'number' && typeof stats.ramTotalGB === 'number')
            ? `${stats.ramUsedGB} / ${stats.ramTotalGB} GB`
            : s.subtitle
          return { ...s, value: `${pct}%`, subtitle }
        }
        if (s.id === 'disk') {
          const pct = Math.round((stats.storageUsage ?? 0) * 100)
          const subtitle = (typeof stats.storageUsedGB === 'number' && typeof stats.storageTotalGB === 'number')
            ? `${stats.storageUsedGB} / ${stats.storageTotalGB} GB`
            : s.subtitle
          return { ...s, value: `${pct}%`, subtitle }
        }
        return s
      }))
    })
    return () => unsubscribe?.()
  }, [])

  return (
    <div className="p-4 flex flex-col gap-4">
      <div className="rounded-xl border border-border bg-card p-4 flex items-center justify-between max-w-md">
        <div>
          <p className="text-sm font-semibold text-foreground">Opas DL Neo</p>
          <p className="text-xs text-muted-foreground">Versione installata</p>
        </div>
        <span className="font-mono text-sm text-foreground">{appVersion ?? '—'}</span>
      </div>

      <div className={`grid grid-cols-1 gap-4 ${debugPaths ? 'lg:grid-cols-2' : ''}`}>
        <div className="rounded-xl border border-border bg-card p-4">
          <p className="text-sm font-semibold text-foreground mb-3">Stato</p>
          <SystemStatsGrid stats={systemStatsState.map(s =>
            s.id === 'drivers'
              ? { ...s, value: String(driverCounts.active), subtitle: driverCounts.total > 0 ? `${driverCounts.active} / ${driverCounts.total} attivi` : 'Nessun driver' }
              : s
          )} />
        </div>

        {debugPaths && (
          <div className="rounded-xl border border-border bg-card p-4">
            <p className="text-sm font-semibold text-foreground mb-3">Debug Paths</p>
            <div className="font-mono text-xs space-y-1">
              {([
                ['opasDlPath', debugPaths.opasDlPath, debugPaths.opasDlPath ? debugPaths.opasDlPathExists : null, null],
                ['opasConfigDir', debugPaths.opasConfigDir, debugPaths.opasConfigDirExists, null],
                ['configFile', debugPaths.configFile ?? '', debugPaths.configFile ? debugPaths.configFileExists : null, debugPaths.configParseError],
                ['dataDir', debugPaths.dataDir, debugPaths.dataDirExists, null],
                ['instantFilePath', debugPaths.instantFilePath ?? '', debugPaths.instantFilePath ? debugPaths.instantFilePathExists : null, null],
                ['outputPath', debugPaths.outputPath, debugPaths.outputPathExists, null],
                ['logPath', debugPaths.logPath, debugPaths.logPathExists, null],
                ['driversPath', debugPaths.driversPath, debugPaths.driversPathExists, null],
              ] as [string, string, boolean | null, string | null][]).map(([label, value, exists, error]) => (
                <div key={label} className="flex gap-2">
                  <span className="text-muted-foreground shrink-0">{label}:</span>
                  <span className={exists === false || error ? 'text-red-600 dark:text-red-400' : exists === true ? 'text-green-600 dark:text-green-400' : 'text-foreground'}>
                    {value || '(non impostato)'}
                    {exists === true && !error && ' ✓'}
                    {exists === false && ' ✗ NON TROVATO'}
                    {error && ` — JSON non valido: ${error}`}
                  </span>
                </div>
              ))}
            </div>
          </div>
        )}
      </div>
    </div>
  )
}
