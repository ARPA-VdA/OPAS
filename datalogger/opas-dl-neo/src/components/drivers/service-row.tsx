import { TableCell, TableRow } from "@/components/ui/table"
import { Button } from "@/components/ui/button"
import { Tooltip, TooltipContent, TooltipTrigger } from "@/components/ui/tooltip"
import { IconRefresh, IconPlayerStop, IconPlayerPlay } from "@tabler/icons-react"
import { ConnectionBadge } from "@/components/instruments/instrument-card"
import { useNavigation } from "@/context/NavigationContext"

// driverFile is relative to drivers/, e.g. "API_400/driver.py" or
// "API/API_100/driver.py" (see driver_manager.py's driver_file). Show only
// the driver folder path, dropping the trailing "/driver.py" — this also
// matches DriverCatalogEntry.path, used to preselect this driver on nav.drivers.
function formatDriverName(driverFile: string): string {
  return driverFile.replace(/[/\\]driver\.py$/i, '')
}

function formatUptime(seconds: number | null): string {
  if (seconds === null) return '—'
  if (seconds < 60) return `${seconds}s`
  const m = Math.floor(seconds / 60) % 60
  const h = Math.floor(seconds / 3600) % 24
  const d = Math.floor(seconds / 86400)
  if (d > 0) return `${d}g ${h}h`
  if (h > 0) return `${h}h ${m}m`
  return `${m}m`
}

interface ServiceRowProps {
  driver: DriverInfo;
  onAction?: (driverId: string, action: 'start' | 'stop' | 'restart') => void;
}

export function ServiceRow({ driver, onAction }: ServiceRowProps) {
  const nav = useNavigation()
  const driverPath = driver.driverFile ? formatDriverName(driver.driverFile) : null

  return (
    <TableRow>
      <TableCell>
        <div className="flex items-center gap-2">
          <span
            className={`inline-block size-3 rounded-full ${
              driver.alive ? 'bg-green-500' : 'bg-red-500'
            }`}
          />
          <span>{driver.pid ?? ''}</span>
        </div>
      </TableCell>

      <TableCell className="font-medium">
        <button
          type="button"
          onClick={() => nav?.navigateTo("nav.instruments", { selectInstrumentName: driver.name })}
          className="hover:text-primary hover:underline transition-colors cursor-pointer"
        >
          {driver.name}
        </button>
      </TableCell>

      <TableCell>
        {driverPath ? (
          <button
            type="button"
            onClick={() => nav?.navigateTo("nav.drivers", { selectDriverPath: driverPath })}
            className="hover:text-primary hover:underline transition-colors cursor-pointer"
          >
            {driverPath}
          </button>
        ) : (
          '—'
        )}
      </TableCell>

      <TableCell>
        <span className="font-medium">{driver.model ?? '—'}</span>
        {driver.brand && <span className="block text-xs text-muted-foreground">{driver.brand}</span>}
      </TableCell>

      <TableCell>
        <ConnectionBadge connection={driver.connection} />
      </TableCell>

      <TableCell>{formatUptime(driver.uptimeSeconds)}</TableCell>

      <TableCell>
        <div className="flex gap-1 justify-end">
          {driver.alive ? (
            <>
              <Tooltip>
                <TooltipTrigger asChild>
                  <Button variant="outline" size="icon" onClick={() => onAction?.(driver.id, 'restart')}>
                    <IconRefresh size={16} className="text-blue-500" />
                  </Button>
                </TooltipTrigger>
                <TooltipContent>Riavvia</TooltipContent>
              </Tooltip>

              <Tooltip>
                <TooltipTrigger asChild>
                  <Button variant="outline" size="icon" onClick={() => onAction?.(driver.id, 'stop')}>
                    <IconPlayerStop size={16} className="text-red-500" />
                  </Button>
                </TooltipTrigger>
                <TooltipContent>Stop</TooltipContent>
              </Tooltip>
            </>
          ) : (
            <Tooltip>
              <TooltipTrigger asChild>
                <Button variant="outline" size="icon" onClick={() => onAction?.(driver.id, 'start')}>
                  <IconPlayerPlay size={16} className="text-green-500" />
                </Button>
              </TooltipTrigger>
              <TooltipContent>Avvia</TooltipContent>
            </Tooltip>
          )}
        </div>
      </TableCell>
    </TableRow>
  );
}
