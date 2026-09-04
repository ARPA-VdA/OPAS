import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import { Switch } from "@/components/ui/switch"
import { Tooltip, TooltipContent, TooltipTrigger } from "@/components/ui/tooltip"
import { useEditMode } from "@/context/EditModeContext"
import {
  IconNetwork, IconUsb, IconFileText, IconWorld, IconAlertTriangle,
  IconPlayerStop, IconPlayerPlay, IconRefresh, IconUsers, IconFileOff,
} from "@tabler/icons-react"

export interface MergedInstrument {
  id: string
  lastModified: Date | null
  lastValue: number | null
  isMissing: boolean
  alive: boolean
  pid: number | null
  model: string | null
  brand: string | null
  driverVersion: string | null
  startTime: string | null
  uptimeSeconds: number | null
  driverFile: string | null
  sharedComPort: string | null
  sharedWith: string[]
  driverKey: string | null
  // whether this module's ModuleType resolves to an installed driver folder
  // at all (from GET /driver-catalog) - lets the UI tell "driver registered
  // but stopped" apart from "no driver exists for this instrument type"
  driverExists: boolean
  moduleConfig: OpasModule | null
}

interface InstrumentCardProps {
  instrument: MergedInstrument
  onClick: () => void
  onAction?: (driverKey: string, action: 'start' | 'stop' | 'restart') => void
  onToggleActive?: (module: OpasModule, checked: boolean) => void
}

export type NotAliveReason = 'stopped' | 'unregistered' | 'missing'

// Distinguishes why a non-running instrument has no active driver process:
// - 'stopped': registered in driver_manager (driverKey present) but not
//   running right now - a real Play button can restart it.
// - 'unregistered': not in driver_manager's registry, but its ModuleType DOES
//   resolve to an installed driver folder (per GET /driver-catalog) - e.g. a
//   module that was disabled at startup (never registered) or added without
//   a service restart. Enabling it (see config-detail.tsx/instruments.tsx's
//   handleToggleModuleActive) registers it, at which point this becomes
//   'stopped'.
// - 'missing': not registered AND no driver resolves for this ModuleType at
//   all - a configuration problem (bad/unmapped ModuleType), not something a
//   restart or enable/disable toggle can fix.
export function notAliveReason(driverKey: string | null, driverExists: boolean): NotAliveReason {
  if (driverKey) return 'stopped'
  return driverExists ? 'unregistered' : 'missing'
}

export function formatUptime(seconds: number | null): string {
  if (seconds === null) return '—'
  if (seconds < 60) return `${seconds}s`
  const m = Math.floor(seconds / 60) % 60
  const h = Math.floor(seconds / 3600) % 24
  const d = Math.floor(seconds / 86400)
  if (d > 0) return `${d}g ${h}h`
  if (h > 0) return `${h}h ${m}m`
  return `${m}m`
}

// Derived straight from the module's own config, not from the driver registry's
// reported connection: that field only exists once the driver is registered
// (see driver_manager.py), so a never-started/disabled instrument would show
// nothing even though its COM port / IP / pipe file is right there in the config.
export function moduleConnection(m: OpasModule | null): DriverConnection | null {
  if (!m) return null
  switch (m.comunicationType) {
    case 1: // Ethernet TCP/IP
      return { type: 'TCP/IP', host: m.tcpipAddress ?? null, port: m.tcpipPort ?? null, baudRate: null }
    case 4: // Ethernet UDP
      return { type: 'UDP', host: m.tcpipAddress ?? null, port: m.tcpipPort ?? null, baudRate: null }
    case 6: // Modbus Ethernet
      return { type: 'Modbus Ethernet', host: m.tcpipAddress ?? null, port: m.tcpipPort ?? null, baudRate: null }
    case 7: // HTTP (not part of the original VB.NET enum)
      return { type: 'HTTP', host: m.tcpipAddress ?? null, port: m.tcpipPort ?? null, baudRate: null }
    case 0: // Seriale
      return { type: 'Serial', host: m.comPortName != null ? `COM${m.comPortName}` : null, port: null, baudRate: m.comPortBauds ?? null }
    case 5: // Modbus Seriale
      return { type: 'Modbus Seriale', host: m.comPortName != null ? `COM${m.comPortName}` : null, port: null, baudRate: m.comPortBauds ?? null }
    case 3: // PipeFile
      return { type: 'PipeFile', host: m.pipeFileName || null, port: null, baudRate: null }
    default:
      return null
  }
}

export function ConnectionBadge({ connection }: { connection: DriverConnection | null }) {
  if (!connection?.type) return <span className="text-muted-foreground text-xs">—</span>

  if (connection.type === 'PipeFile') {
    return (
      <span className="flex items-center gap-1 text-xs text-muted-foreground">
        <IconFileText size={12} className="text-violet-500 shrink-0" />
        {connection.host || '—'}
      </span>
    )
  }

  if (connection.type === 'HTTP') {
    return (
      <span className="flex items-center gap-1 text-xs text-muted-foreground">
        <IconWorld size={12} className="text-green-600 shrink-0" />
        {`${connection.host ?? ''}${connection.port ? `:${connection.port}` : ''}`}
      </span>
    )
  }

  const isSerial = connection.type === 'Serial' || connection.type === 'Modbus Seriale'
  const label = isSerial
    ? `${connection.host ?? 'Serial'}${connection.baudRate ? ` · ${connection.baudRate}` : ''}`
    : `${connection.host ?? ''}${connection.port ? `:${connection.port}` : ''}`
  return (
    <span className="flex items-center gap-1 text-xs text-muted-foreground">
      {isSerial
        ? <IconUsb size={12} className="text-orange-500 shrink-0" />
        : <IconNetwork size={12} className="text-blue-500 shrink-0" />}
      {label}
      {connection.type.startsWith('Modbus') && <span className="text-muted-foreground">(Modbus)</span>}
    </span>
  )
}

export function InstrumentCard({ instrument, onClick, onAction, onToggleActive }: InstrumentCardProps) {
  const { editMode } = useEditMode()
  const { id, alive, model, brand, moduleConfig, lastModified,
          pid, uptimeSeconds, startTime, driverKey, driverExists, isMissing,
          sharedComPort, sharedWith } = instrument
  const connection = moduleConnection(moduleConfig)
  const reason = notAliveReason(driverKey, driverExists)

  const handleAction = (e: React.MouseEvent, action: 'start' | 'stop' | 'restart') => {
    e.stopPropagation()
    if (driverKey) onAction?.(driverKey, action)
  }

  const infoItems = [
    pid != null   && { label: 'PID',    value: String(pid), mono: true },
    { label: 'Uptime', value: formatUptime(uptimeSeconds) },
    moduleConfig  && { label: 'Poll',   value: `${moduleConfig.pollingInterval}s` },
    startTime     && { label: 'Avv.',   value: new Date(startTime).toLocaleTimeString('it-IT') },
  ].filter(Boolean) as { label: string; value: string; mono?: boolean }[]

  const connectionProblem = alive && isMissing
  const notConnected = !alive || connectionProblem
  const disabled = moduleConfig ? !moduleConfig.active : false

  return (
    <Card
      className={`cursor-pointer hover:shadow-sm hover:border-primary/50 transition-all py-0 gap-0 h-full min-w-0 flex flex-col ${disabled ? 'opacity-60 grayscale' : ''}`}
      onClick={onClick}
    >
      <CardHeader className="p-3 pb-2">
        <div className="flex items-center gap-2 min-w-0">
          <div className="flex-1 min-w-0 flex items-baseline gap-1.5">
            {moduleConfig && (
              <span className="text-muted-foreground font-mono text-xs shrink-0">{moduleConfig.id}</span>
            )}
            <CardTitle className="text-base font-bold truncate min-w-0">{id}</CardTitle>
            {moduleConfig?.temporary && (
              <Tooltip>
                <TooltipTrigger asChild>
                  <span className="inline-flex text-muted-foreground shrink-0" onClick={(e) => e.stopPropagation()}>
                    <IconFileOff size={13} />
                  </span>
                </TooltipTrigger>
                <TooltipContent>Strumento temporaneo: dati salvati solo su CSV, non su file .dat</TooltipContent>
              </Tooltip>
            )}
          </div>
          <div className="flex items-center shrink-0">
            {moduleConfig && (
              <span onClick={(e) => e.stopPropagation()}>
                <Switch
                  checked={moduleConfig.active}
                  disabled={!editMode}
                  onCheckedChange={(checked) => onToggleActive?.(moduleConfig, checked)}
                />
              </span>
            )}
          </div>
        </div>
        {(model || brand) && (
          <p className="text-xs text-muted-foreground truncate mt-0.5">
            {[model, brand].filter(Boolean).join(' · ')}
          </p>
        )}
      </CardHeader>

      <CardContent className="px-3 pb-3 pt-0 flex-1 flex flex-col gap-2">
        <div className={`flex items-center justify-between gap-2 rounded-md px-2 py-1.5 ${
          alive ? 'bg-green-50 dark:bg-green-500/10'
            : reason === 'missing' ? 'bg-muted/40' : 'bg-red-50 dark:bg-red-500/10'
        }`}>
          {alive ? (
            <div className="flex flex-wrap gap-x-3 gap-y-0.5 text-xs">
              {infoItems.map(item => (
                <span key={item.label} className="text-muted-foreground">
                  {item.label}{' '}
                  <span className={`text-foreground font-medium${item.mono ? ' font-mono' : ''}`}>
                    {item.value}
                  </span>
                </span>
              ))}
            </div>
          ) : (
            <span className={`text-xs font-medium ${reason === 'missing' ? 'text-muted-foreground' : 'text-red-700 dark:text-red-400'}`}>
              {reason === 'stopped' && `${id} non avviato`}
              {reason === 'unregistered' && 'Driver non registrato (serve un riavvio)'}
              {reason === 'missing' && 'Nessun driver disponibile'}
            </span>
          )}
          {driverKey && (
            <div className="flex items-center gap-1 shrink-0" onClick={e => e.stopPropagation()}>
              {alive ? (
                <>
                  <Tooltip>
                    <TooltipTrigger asChild>
                      <Button variant="outline" size="icon" className="size-6" onClick={e => handleAction(e, 'restart')}>
                        <IconRefresh size={12} className="text-blue-500" />
                      </Button>
                    </TooltipTrigger>
                    <TooltipContent>Riavvia</TooltipContent>
                  </Tooltip>
                  <Tooltip>
                    <TooltipTrigger asChild>
                      <Button variant="outline" size="icon" className="size-6" onClick={e => handleAction(e, 'stop')}>
                        <IconPlayerStop size={12} className="text-red-500" />
                      </Button>
                    </TooltipTrigger>
                    <TooltipContent>Stop</TooltipContent>
                  </Tooltip>
                </>
              ) : (
                <Tooltip>
                  <TooltipTrigger asChild>
                    <Button variant="outline" size="icon" className="size-6" onClick={e => handleAction(e, 'start')}>
                      <IconPlayerPlay size={12} className="text-green-500" />
                    </Button>
                  </TooltipTrigger>
                  <TooltipContent>Avvia</TooltipContent>
                </Tooltip>
              )}
            </div>
          )}
        </div>

        <div className={`mt-auto flex items-center justify-between gap-2 rounded-md px-2 ${
          notConnected ? 'bg-amber-50 dark:bg-amber-500/10 py-1' : 'border-t border-border/50 pt-1.5'
        }`}>
          <div className="flex items-center gap-1.5 min-w-0">
            <ConnectionBadge connection={connection} />
            {sharedComPort && (
              <Tooltip>
                <TooltipTrigger asChild>
                  <IconUsers size={12} className="text-indigo-500 shrink-0" />
                </TooltipTrigger>
                <TooltipContent>
                  Porta condivisa con: {sharedWith.length > 0 ? sharedWith.join(', ') : 'altri strumenti'}
                </TooltipContent>
              </Tooltip>
            )}
            {notConnected && (
              <Tooltip>
                <TooltipTrigger asChild>
                  <IconAlertTriangle size={12} className="text-amber-500 shrink-0" />
                </TooltipTrigger>
                <TooltipContent>
                  {alive && 'Nessuna lettura dallo strumento'}
                  {!alive && reason === 'stopped' && 'Driver non avviato'}
                  {!alive && reason === 'unregistered' && 'Driver non registrato (serve un riavvio)'}
                  {!alive && reason === 'missing' && 'Nessun driver disponibile per questo strumento'}
                </TooltipContent>
              </Tooltip>
            )}
          </div>
          {!notConnected && lastModified && (
            <span className="text-xs text-muted-foreground shrink-0">
              {new Date(lastModified).toLocaleTimeString('it-IT')}
            </span>
          )}
        </div>
      </CardContent>
    </Card>
  )
}
