import { useEffect, useState } from "react"
import {
  Dialog, DialogContent, DialogHeader, DialogTitle, DialogDescription, DialogFooter,
} from "@/components/ui/dialog"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { ToggleGroup, ToggleGroupItem } from "@/components/ui/toggle-group"
import { IconLayoutGrid, IconTable } from "@tabler/icons-react"
import { ChannelMultiPicker } from "./channel-multi-picker"
import { channelKey } from "@/lib/channelIds"

interface CreateViewDialogProps {
  open: boolean
  onClose: () => void
  modules: OpasModule[]
  onCreated: (id: string) => void
}

export function CreateViewDialog({ open, onClose, modules, onCreated }: CreateViewDialogProps) {
  const [name, setName] = useState('')
  const [displayMode, setDisplayMode] = useState<ViewDisplayMode>('cards')
  const [selected, setSelected] = useState<Set<string>>(new Set())
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    if (!open) return
    setName('')
    setDisplayMode('cards')
    setSelected(new Set())
    setError(null)
  }, [open])

  const handleToggle = (moduleId: number, channelId: number) => {
    setSelected((prev) => {
      const key = channelKey(moduleId, channelId)
      const next = new Set(prev)
      if (next.has(key)) next.delete(key)
      else next.add(key)
      return next
    })
  }

  const canCreate = !saving && name.trim() !== '' && selected.size > 0

  async function handleCreate() {
    setSaving(true)
    setError(null)
    try {
      const channels: ViewChannelRef[] = [...selected].map(key => {
        const [moduleId, channelId] = key.split('-').map(Number)
        return { moduleId, channelId }
      })
      const result = await window.electron.createView({ name: name.trim(), displayMode, channels })
      if (!result?.success) {
        setError('Creazione non riuscita.')
        return
      }
      window.dispatchEvent(new Event('views-saved'))
      onCreated(result.id)
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
          <DialogTitle>Nuova vista</DialogTitle>
          <DialogDescription>
            Scegli gli strumenti e i canali da mostrare, come griglia di card o come tabella.
          </DialogDescription>
        </DialogHeader>

        <div className="space-y-3">
          <div className="space-y-1.5">
            <Label htmlFor="view-name">Nome</Label>
            <Input
              id="view-name"
              value={name}
              onChange={e => setName(e.target.value)}
              placeholder="Es. Sala controllo"
            />
          </div>

          <div className="space-y-1.5">
            <Label>Visualizzazione</Label>
            <ToggleGroup
              type="single"
              variant="outline"
              value={displayMode}
              onValueChange={v => { if (v) setDisplayMode(v as ViewDisplayMode) }}
              className="w-full"
            >
              <ToggleGroupItem value="cards" className="flex-1 gap-1.5">
                <IconLayoutGrid size={14} /> Card
              </ToggleGroupItem>
              <ToggleGroupItem value="table" className="flex-1 gap-1.5">
                <IconTable size={14} /> Tabella
              </ToggleGroupItem>
            </ToggleGroup>
          </div>

          <div className="space-y-1.5">
            <Label>Canali</Label>
            <ChannelMultiPicker modules={modules} selected={selected} onToggle={handleToggle} />
          </div>
        </div>

        {error && <p className="text-sm text-destructive">{error}</p>}

        <DialogFooter>
          <Button onClick={handleCreate} disabled={!canCreate}>Crea vista</Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  )
}
