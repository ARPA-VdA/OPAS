import { useState } from "react"
import { Button } from "@/components/ui/button"
import { Switch } from "@/components/ui/switch"
import { Tooltip, TooltipContent, TooltipTrigger } from "@/components/ui/tooltip"
import {
  IconArrowLeft, IconAlertTriangle,
  IconPlayerStop, IconPlayerPlay, IconRefresh, IconUsers,
} from "@tabler/icons-react"
import { useEditMode } from "@/context/EditModeContext"
import { type MergedInstrument, formatUptime, notAliveReason } from "./instrument-card"
import { ReadingsSection } from "./readings-section"
import { ModuleEditDialog } from "./module-edit-dialog"
import { LogSection } from "./log-section"

interface InstrumentDetailProps {
  instrument: MergedInstrument
  onBack: () => void
  onAction?: (driverKey: string, action: 'start' | 'stop' | 'restart') => void
  onToggleActive?: (module: OpasModule, checked: boolean) => void
}

function moduleCommunicationSummary(m: OpasModule): string {
  switch (m.comunicationType) {
    case 1:
      return `TCP/IP · ${m.tcpipAddress}${m.tcpipPort ? ':' + m.tcpipPort : ''}`
    case 4:
      return `UDP · ${m.tcpipAddress}${m.tcpipPort ? ':' + m.tcpipPort : ''}`
    case 6:
      return `Modbus Ethernet · ${m.tcpipAddress}${m.tcpipPort ? ':' + m.tcpipPort : ''}`
    case 7:
      return `HTTP · ${m.tcpipAddress}${m.tcpipPort ? ':' + m.tcpipPort : ''}`
    case 0:
      return `Seriale · COM${m.comPortName}${m.comPortBauds ? ' · ' + m.comPortBauds + ' baud' : ''}`
    case 5:
      return `Modbus Seriale · COM${m.comPortName}${m.comPortBauds ? ' · ' + m.comPortBauds + ' baud' : ''}`
    case 3:
      return `PipeFile · ${m.pipeFileName || '—'}`
    default:
      return `Tipo ${m.comunicationType}`
  }
}

export function InstrumentDetail({ instrument, onBack, onAction, onToggleActive }: InstrumentDetailProps) {
  const { editMode } = useEditMode()
  const {
    id, alive, model, brand, moduleConfig, isMissing,
    pid, uptimeSeconds, startTime, driverVersion, driverKey, driverExists,
    sharedComPort, sharedWith,
  } = instrument
  const connectionProblem = alive && isMissing
  const notConnected = !alive || connectionProblem
  const reason = notAliveReason(driverKey, driverExists)
  const disabled = moduleConfig ? !moduleConfig.active : false
  const [moduleDialogOpen, setModuleDialogOpen] = useState(false)

  const handleAction = (action: 'start' | 'stop' | 'restart') => {
    if (driverKey) onAction?.(driverKey, action)
  }

  const driverInfoItems = [
    pid != null && { label: 'PID', value: String(pid), mono: true },
    { label: 'Uptime', value: formatUptime(uptimeSeconds) },
    startTime && { label: 'Avviato', value: new Date(startTime).toLocaleTimeString('it-IT') },
    driverVersion && { label: 'Versione', value: driverVersion },
  ].filter(Boolean) as { label: string; value: string; mono?: boolean }[]

  const moduleInfoItems = moduleConfig ? [
    { label: 'ID modulo', value: String(moduleConfig.id) },
    { label: 'Attivo', value: moduleConfig.active ? 'Sì' : 'No' },
    moduleConfig.info && { label: 'Info', value: moduleConfig.info },
    { label: 'Polling', value: `${moduleConfig.pollingInterval}s` },
    { label: 'Temporaneo', value: moduleConfig.temporary ? 'Sì' : 'No' },
    { label: 'Comunicazione', value: moduleCommunicationSummary(moduleConfig) },
  ].filter(Boolean) as { label: string; value: string }[] : []

  return (
    <div className={`flex flex-col ${disabled ? 'opacity-60 grayscale' : ''}`}>
      <div className="sticky top-0 z-10 flex flex-col gap-2 bg-background px-4 pt-4 pb-3 border-b border-border/60">
        <div className="flex items-center gap-3">
          <Button variant="ghost" size="icon" onClick={onBack} className="shrink-0">
            <IconArrowLeft size={18} />
          </Button>
          <div className="flex items-center gap-2 min-w-0">
            {moduleConfig && <span className="text-sm text-muted-foreground font-mono shrink-0">{moduleConfig.id}</span>}
            <h2 className="text-xl font-bold truncate">{id}</h2>
            {(model || brand) && (
              <span className="text-sm text-muted-foreground hidden sm:block">
                {[brand, model].filter(Boolean).join(' · ')}
              </span>
            )}
          </div>
          {moduleConfig && (
            <span className="ml-auto shrink-0">
              <Switch
                checked={moduleConfig.active}
                disabled={!editMode}
                onCheckedChange={(checked) => onToggleActive?.(moduleConfig, checked)}
              />
            </span>
          )}
        </div>

        <div className={`flex flex-wrap items-center justify-between gap-2 rounded-md px-3 py-2 ${
          alive ? 'bg-green-50 dark:bg-green-500/10'
            : reason === 'missing' ? 'bg-muted/40' : 'bg-red-50 dark:bg-red-500/10'
        }`}>
          {alive ? (
            <div className="flex flex-wrap items-center gap-x-3 gap-y-1 text-xs">
              {driverInfoItems.map(item => (
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
              {reason === 'missing' && 'Nessun driver disponibile per questo strumento'}
            </span>
          )}
          {driverKey && (
            <div className="flex items-center gap-1 shrink-0">
              {alive ? (
                <>
                  <Tooltip>
                    <TooltipTrigger asChild>
                      <Button variant="outline" size="icon" className="size-7" onClick={() => handleAction('restart')}>
                        <IconRefresh size={14} className="text-blue-500" />
                      </Button>
                    </TooltipTrigger>
                    <TooltipContent>Riavvia</TooltipContent>
                  </Tooltip>
                  <Tooltip>
                    <TooltipTrigger asChild>
                      <Button variant="outline" size="icon" className="size-7" onClick={() => handleAction('stop')}>
                        <IconPlayerStop size={14} className="text-red-500" />
                      </Button>
                    </TooltipTrigger>
                    <TooltipContent>Stop</TooltipContent>
                  </Tooltip>
                </>
              ) : (
                <Tooltip>
                  <TooltipTrigger asChild>
                    <Button variant="outline" size="icon" className="size-7" onClick={() => handleAction('start')}>
                      <IconPlayerPlay size={14} className="text-green-500" />
                    </Button>
                  </TooltipTrigger>
                  <TooltipContent>Avvia</TooltipContent>
                </Tooltip>
              )}
            </div>
          )}
        </div>
      </div>

      <div className="flex flex-col gap-6 p-4">
        <div className="flex flex-col gap-2">
          {moduleInfoItems.length > 0 && (
            <button
              type="button"
              onClick={() => setModuleDialogOpen(true)}
              title="Modifica configurazione modulo"
              className="flex flex-wrap items-center gap-x-3 gap-y-1 rounded-md border border-border bg-muted/20 px-3 py-2 text-xs text-left hover:bg-muted/50 hover:border-primary/40 transition-all"
            >
              {moduleInfoItems.map(item => (
                <span key={item.label} className="text-muted-foreground">
                  {item.label}{' '}
                  <span className="text-foreground font-medium">{item.value}</span>
                </span>
              ))}
            </button>
          )}

          {notConnected && (
            <div className="flex items-center gap-1.5 rounded-md bg-amber-50 dark:bg-amber-500/10 px-3 py-1.5 text-xs text-amber-700 dark:text-amber-400">
              <IconAlertTriangle size={14} className="shrink-0" />
              <span>
                {alive && 'Nessuna lettura dallo strumento'}
                {!alive && reason === 'stopped' && 'Driver non avviato'}
                {!alive && reason === 'unregistered' && 'Driver non registrato (serve un riavvio)'}
                {!alive && reason === 'missing' && 'Nessun driver disponibile per questo strumento'}
              </span>
            </div>
          )}

          {sharedComPort && (
            <div className="flex items-center gap-1.5 rounded-md bg-indigo-50 dark:bg-indigo-500/10 px-3 py-1.5 text-xs text-indigo-700 dark:text-indigo-400">
              <IconUsers size={14} className="shrink-0" />
              <span>
                Porta COM{sharedComPort} condivisa con: {sharedWith.length > 0 ? sharedWith.join(', ') : 'altri strumenti'}
              </span>
            </div>
          )}
        </div>

        <ReadingsSection instrumentId={id} moduleConfig={moduleConfig} />

        <LogSection
          driverId={moduleConfig ? String(moduleConfig.id) : null}
          instrumentName={id}
        />
      </div>

      <ModuleEditDialog
        module={moduleDialogOpen ? moduleConfig : null}
        onClose={() => setModuleDialogOpen(false)}
      />
    </div>
  )
}
