import { useEffect, useState } from "react"
import {
  Dialog, DialogContent, DialogHeader, DialogTitle, DialogFooter,
} from "@/components/ui/dialog"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { useEditMode } from "@/context/EditModeContext"

interface StationEditDialogProps {
  filename: string
  data: OpasConfigData | null
  onClose: () => void
}

export function StationEditDialog({ filename, data, onClose }: StationEditDialogProps) {
  const { editMode: editable } = useEditMode()
  const [name, setName] = useState('')
  const [stationLocation, setStationLocation] = useState('')
  const [dataFileHeader, setDataFileHeader] = useState('')
  const [stationLatitude, setStationLatitude] = useState('')
  const [stationLongitude, setStationLongitude] = useState('')
  const [stationAltitude, setStationAltitude] = useState('')
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    if (!data) return
    setName(data.name)
    setStationLocation(data.stationLocation)
    setDataFileHeader(data.dataFileHeader)
    setStationLatitude(String(data.stationLatitude ?? ''))
    setStationLongitude(String(data.stationLongitude ?? ''))
    setStationAltitude(String(data.stationAltitude ?? ''))
    setError(null)
  }, [data])

  async function handleSave() {
    setSaving(true)
    setError(null)
    try {
      const patch: ConfigStationFields = {
        name,
        stationLocation,
        dataFileHeader,
        stationLatitude: stationLatitude.trim() === '' ? undefined : Number(stationLatitude),
        stationLongitude: stationLongitude.trim() === '' ? undefined : Number(stationLongitude),
        stationAltitude: stationAltitude.trim() === '' ? undefined : Number(stationAltitude),
      }
      const result = await window.electron.saveConfigStation(filename, patch)
      if (!result?.success) {
        setError('Salvataggio non riuscito.')
        return
      }
      window.dispatchEvent(new Event('opas-config-saved'))
      onClose()
    } catch {
      setError('Salvataggio non riuscito.')
    } finally {
      setSaving(false)
    }
  }

  const open = data !== null
  const disableSave = saving || !editable

  return (
    <Dialog open={open} onOpenChange={o => { if (!o) onClose() }}>
      <DialogContent className="sm:max-w-md">
        <DialogHeader>
          <DialogTitle>Modifica intestazione</DialogTitle>
        </DialogHeader>

        <div className="space-y-3">
          <div className="space-y-1.5">
            <Label htmlFor="station-name">Nome stazione</Label>
            <Input id="station-name" value={name} onChange={e => setName(e.target.value)} disabled={!editable} />
          </div>
          <div className="space-y-1.5">
            <Label htmlFor="station-location">Località</Label>
            <Input id="station-location" value={stationLocation} onChange={e => setStationLocation(e.target.value)} disabled={!editable} />
          </div>
          <div className="space-y-1.5">
            <Label htmlFor="station-header">Header file dati</Label>
            <Input id="station-header" value={dataFileHeader} onChange={e => setDataFileHeader(e.target.value)} disabled={!editable} />
          </div>
          <div className="grid grid-cols-3 gap-3">
            <div className="space-y-1.5">
              <Label htmlFor="station-lat">Latitudine</Label>
              <Input id="station-lat" type="number" value={stationLatitude} onChange={e => setStationLatitude(e.target.value)} disabled={!editable} />
            </div>
            <div className="space-y-1.5">
              <Label htmlFor="station-lon">Longitudine</Label>
              <Input id="station-lon" type="number" value={stationLongitude} onChange={e => setStationLongitude(e.target.value)} disabled={!editable} />
            </div>
            <div className="space-y-1.5">
              <Label htmlFor="station-alt">Altitudine</Label>
              <Input id="station-alt" type="number" value={stationAltitude} onChange={e => setStationAltitude(e.target.value)} disabled={!editable} />
            </div>
          </div>
        </div>

        {error && <p className="text-sm text-destructive">{error}</p>}
        {!editable && (
          <p className="text-sm text-muted-foreground">
            Sola lettura: attiva "Modalità modifica" per modificare questi valori.
          </p>
        )}

        <DialogFooter>
          <Button onClick={handleSave} disabled={disableSave}>
            Salva
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  )
}
