import { UNSET_OPTION_VALUE, type FieldGroupDef } from "./field-group-form"

const LOG_LEVEL_OPTIONS = [
  { value: UNSET_OPTION_VALUE, label: '(usa il default di stazione)' },
  { value: 'DEBUG', label: 'DEBUG' },
  { value: 'INFO', label: 'INFO' },
  { value: 'WARNING', label: 'WARNING' },
  { value: 'ERROR', label: 'ERROR' },
]

// Sottoinsieme editabile di OpasModule: canali, comandi e stato di calibrazione
// restano fuori da questo form (i canali hanno il proprio field-group dedicato).
export type ModuleFormValue = Omit<OpasModule, 'channels' | 'moduleCommands' | 'moduleCommand'>

export const MODULE_FIELD_GROUPS: FieldGroupDef<ModuleFormValue>[] = [
  {
    title: 'Identità',
    fields: [
      { key: 'id', label: 'ID', kind: 'number' },
      { key: 'name', label: 'Nome', kind: 'text' },
      { key: 'active', label: 'Attivo', kind: 'boolean' },
      { key: 'moduleType', label: 'Tipo modulo', kind: 'number' },
      { key: 'position', label: 'Posizione', kind: 'number' },
      { key: 'temporary', label: 'Temporaneo', kind: 'boolean' },
    ],
  },
  {
    title: 'Informazioni e polling',
    fields: [
      { key: 'info', label: 'Info', kind: 'text' },
      { key: 'pollingInterval', label: 'Intervallo polling (s)', kind: 'number' },
      { key: 'pollingDiagsEveryX', label: 'Polling diagnostica ogni X cicli', kind: 'number' },
      { key: 'timeoutAnswer', label: 'Timeout risposta (ms)', kind: 'number' },
      { key: 'logLevel', label: 'Livello di log', kind: 'select', options: LOG_LEVEL_OPTIONS },
    ],
  },
  {
    title: 'Comunicazione',
    fields: [
      {
        key: 'comunicationType',
        label: 'Tipo (0=Seriale, 1=TCP/IP, 3=PipeFile, 4=UDP, 5=Modbus Seriale, 6=Modbus Ethernet, 7=HTTP)',
        kind: 'number',
      },
      { key: 'address', label: 'Indirizzo (Modbus: ID slave/unit)', kind: 'text' },
      { key: 'comPortName', label: 'Porta COM', kind: 'text' },
      { key: 'comPortBauds', label: 'Baud rate', kind: 'number' },
      { key: 'comPortParity', label: 'Parità', kind: 'number' },
      { key: 'comPortDataBits', label: 'Data bits', kind: 'number' },
      { key: 'comPortStopBits', label: 'Stop bits', kind: 'number' },
      { key: 'tcpipAddress', label: 'Indirizzo TCP/IP', kind: 'text' },
      { key: 'tcpipPort', label: 'Porta TCP/IP', kind: 'number' },
      { key: 'tcpipForceOpenPort', label: 'Forza apertura porta', kind: 'boolean' },
      { key: 'pipeFileName', label: 'File pipe (percorso)', kind: 'text' },
      { key: 'pipeFileMissingError', label: 'File mancante = errore', kind: 'boolean' },
    ],
  },
]

export function toModuleFormValue(module: OpasModule): ModuleFormValue {
  const { channels, moduleCommands, moduleCommand, ...rest } = module
  return rest
}
