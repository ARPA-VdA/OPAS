import { useEffect, useState } from "react"
import {
  Dialog, DialogContent, DialogHeader, DialogTitle, DialogDescription, DialogFooter,
} from "@/components/ui/dialog"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { ToggleGroup, ToggleGroupItem } from "@/components/ui/toggle-group"
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select"
import { IconCopy, IconFilePlus, IconUpload } from "@tabler/icons-react"

interface CreateConfigDialogProps {
  open: boolean
  onClose: () => void
  existingEntries: ConfigLibraryEntry[]
  onCreated: (filename: string) => void
}

type Mode = 'duplicate' | 'blank' | 'import'

export function CreateConfigDialog({ open, onClose, existingEntries, onCreated }: CreateConfigDialogProps) {
  const [mode, setMode] = useState<Mode>('duplicate')
  const [filename, setFilename] = useState('')
  const [sourceFilename, setSourceFilename] = useState('')
  const [name, setName] = useState('')
  const [stationLocation, setStationLocation] = useState('')
  const [dataFileHeader, setDataFileHeader] = useState('')
  const [importedContent, setImportedContent] = useState<Record<string, unknown> | null>(null)
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    if (!open) return
    setMode('duplicate')
    setFilename('')
    setSourceFilename(existingEntries.find(e => e.isActive)?.filename ?? existingEntries[0]?.filename ?? '')
    setName('')
    setStationLocation('')
    setDataFileHeader('')
    setImportedContent(null)
    setError(null)
  }, [open, existingEntries])

  async function handleImportFile() {
    setError(null)
    const result = await window.electron.importConfigFile()
    if (!result) return
    setImportedContent(result.content)
    setFilename(result.suggestedFilename)
  }

  const trimmedFilename = filename.trim()
  const filenameValid = /^[^/\\]+\.json$/i.test(trimmedFilename)
  const filenameCollides = existingEntries.some(e => e.filename.toLowerCase() === trimmedFilename.toLowerCase())
  const canCreate = !saving && filenameValid && !filenameCollides &&
    (mode !== 'duplicate' || !!sourceFilename) &&
    (mode !== 'import' || !!importedContent)

  async function handleCreate() {
    setSaving(true)
    setError(null)
    try {
      const fields: ConfigStationFields = {
        ...(name.trim() ? { name: name.trim() } : {}),
        ...(stationLocation.trim() ? { stationLocation: stationLocation.trim() } : {}),
        ...(dataFileHeader.trim() ? { dataFileHeader: dataFileHeader.trim() } : {}),
      }

      let payload: CreateConfigPayload
      if (mode === 'duplicate') {
        payload = { mode: 'duplicate', filename: trimmedFilename, sourceFilename, fields }
      } else if (mode === 'blank') {
        payload = { mode: 'blank', filename: trimmedFilename, fields }
      } else {
        payload = { mode: 'import', filename: trimmedFilename, content: importedContent! }
      }

      const result = await window.electron.createConfig(payload)
      if (!result?.success) {
        setError('Creazione non riuscita. Verifica che il nome file non sia già in uso.')
        return
      }
      onCreated(result.filename)
      onClose()
    } catch {
      setError('Creazione non riuscita.')
    } finally {
      setSaving(false)
    }
  }

  return (
    <Dialog open={open} onOpenChange={o => { if (!o) onClose() }}>
      <DialogContent className="sm:max-w-lg">
        <DialogHeader>
          <DialogTitle>Aggiungi configurazione</DialogTitle>
          <DialogDescription>
            Crea una nuova configurazione nella libreria. Diventerà quella attiva solo se
            scegli di attivarla in seguito.
          </DialogDescription>
        </DialogHeader>

        <ToggleGroup
          type="single"
          variant="outline"
          value={mode}
          onValueChange={v => { if (v) setMode(v as Mode) }}
          className="w-full"
        >
          <ToggleGroupItem value="duplicate" className="flex-1 gap-1.5">
            <IconCopy size={14} /> Duplica
          </ToggleGroupItem>
          <ToggleGroupItem value="blank" className="flex-1 gap-1.5">
            <IconFilePlus size={14} /> Vuota
          </ToggleGroupItem>
          <ToggleGroupItem value="import" className="flex-1 gap-1.5">
            <IconUpload size={14} /> Importa
          </ToggleGroupItem>
        </ToggleGroup>

        <div className="space-y-3">
          {mode === 'duplicate' && (
            <div className="space-y-1.5">
              <Label>Da duplicare</Label>
              <Select value={sourceFilename} onValueChange={setSourceFilename}>
                <SelectTrigger className="w-full">
                  <SelectValue placeholder="Scegli una configurazione" />
                </SelectTrigger>
                <SelectContent>
                  {existingEntries.map(e => (
                    <SelectItem key={e.filename} value={e.filename}>
                      {e.name || e.filename}{e.isActive ? ' (attiva)' : ''}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>
          )}

          {mode === 'import' && (
            <div className="space-y-1.5">
              <Label>File da importare</Label>
              <Button variant="outline" onClick={handleImportFile} className="w-full justify-start">
                {importedContent ? 'File selezionato — scegline un altro' : 'Scegli file...'}
              </Button>
            </div>
          )}

          <div className="space-y-1.5">
            <Label htmlFor="config-filename">Nome file</Label>
            <Input
              id="config-filename"
              value={filename}
              onChange={e => setFilename(e.target.value)}
              placeholder="Config-Nuova-Stazione.json"
            />
            {trimmedFilename !== '' && !filenameValid && (
              <p className="text-xs text-destructive">Deve essere un nome semplice che termina in .json</p>
            )}
            {filenameValid && filenameCollides && (
              <p className="text-xs text-destructive">Esiste già una configurazione con questo nome.</p>
            )}
          </div>

          {mode !== 'import' && (
            <>
              <div className="space-y-1.5">
                <Label htmlFor="config-name">Nome stazione</Label>
                <Input id="config-name" value={name} onChange={e => setName(e.target.value)} placeholder="Es. Stazione di backup" />
              </div>
              <div className="space-y-1.5">
                <Label htmlFor="config-location">Località</Label>
                <Input id="config-location" value={stationLocation} onChange={e => setStationLocation(e.target.value)} />
              </div>
              <div className="space-y-1.5">
                <Label htmlFor="config-header">Header file dati</Label>
                <Input id="config-header" value={dataFileHeader} onChange={e => setDataFileHeader(e.target.value)} />
              </div>
            </>
          )}
        </div>

        {error && <p className="text-sm text-destructive">{error}</p>}

        <DialogFooter>
          <Button onClick={handleCreate} disabled={!canCreate}>Crea configurazione</Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  )
}
