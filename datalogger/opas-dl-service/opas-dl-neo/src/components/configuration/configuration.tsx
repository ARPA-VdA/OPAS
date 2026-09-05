interface ConfigurationProps {
  fileName?: string
  modulesCount: number
  dataFileHeader?: string
  lastUpdate?: Date | string
}

export function Configuration({ fileName, modulesCount, dataFileHeader, lastUpdate }: ConfigurationProps) {
  return (
    <div className="grid gap-4 md:grid-cols-2">
      <div>
        <p className="text-sm text-muted-foreground">File Config</p>
        <p className="font-medium">{fileName || '—'}</p>
      </div>
      <div>
        <p className="text-sm text-muted-foreground">Moduli totali</p>
        <p className="font-medium">{modulesCount}</p>
      </div>
      <div>
        <p className="text-sm text-muted-foreground">Header</p>
        <p className="font-medium">{dataFileHeader || '—'}</p>
      </div>
      <div>
        <p className="text-sm text-muted-foreground">Ultimo aggiornamento</p>
        <p className="font-medium">
          {lastUpdate ? new Date(lastUpdate).toLocaleString('it-IT') : '—'}
        </p>
      </div>
    </div>
  )
}
