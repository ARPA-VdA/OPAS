import {
  Table,
  TableBody,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table"
import { ServiceRow } from "./service-row"

// DriverInfo/DriverConnection are ambient (declared in types.d.ts) - no
// import needed, referenced directly like OpasModule/OpasConfigData
// elsewhere. This table used to keep its own narrower copy that never
// learned about UDP/PipeFile/Modbus, so the dashboard's driver list silently
// showed "—" for any of the newer communication types.

interface ServicesTableProps {
  drivers: DriverInfo[];
  onAction?: (driverId: string, action: 'start' | 'stop' | 'restart') => void;
}

export function ServicesTable({ drivers, onAction }: ServicesTableProps) {
  return (
    <Table className="text-sm">
      <TableHeader>
        <TableRow>
          <TableHead>PID</TableHead>
          <TableHead>Strumento</TableHead>
          <TableHead>Driver</TableHead>
          <TableHead>Modello</TableHead>
          <TableHead>Connessione</TableHead>
          <TableHead>Uptime</TableHead>
          <TableHead className="text-right">Azioni</TableHead>
        </TableRow>
      </TableHeader>
      <TableBody>
        {drivers.map((driver) => (
          <ServiceRow key={driver.id} driver={driver} onAction={onAction} />
        ))}
        {drivers.length === 0 && (
          <TableRow>
            <td colSpan={7} className="text-muted-foreground py-6 text-sm px-2">
              Nessun driver attivo
            </td>
          </TableRow>
        )}
      </TableBody>
    </Table>
  );
}
