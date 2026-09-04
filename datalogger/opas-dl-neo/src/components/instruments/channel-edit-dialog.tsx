import { useEffect, useState } from "react"
import {
  Dialog, DialogContent, DialogHeader, DialogTitle, DialogFooter,
} from "@/components/ui/dialog"
import { Tabs, TabsList, TabsTrigger, TabsContent } from "@/components/ui/tabs"
import { Button } from "@/components/ui/button"
import { useEditMode } from "@/context/EditModeContext"
import { FieldGroupForm } from "./field-group-form"
import { JsonEditor } from "./json-editor"
import { CHANNEL_FIELD_GROUPS } from "./channel-field-groups"

interface ChannelEditDialogProps {
  channel: OpasChannel | null
  moduleId: number | null
  onClose: () => void
  // Same meaning as ModuleEditDialogProps.configFilename - see there.
  configFilename?: string
}

export function ChannelEditDialog({ channel, moduleId, onClose, configFilename }: ChannelEditDialogProps) {
  const { editMode: editable } = useEditMode()
  const [draft, setDraft] = useState<OpasChannel | null>(channel)
  const [mode, setMode] = useState<'form' | 'json'>('form')
  const [jsonText, setJsonText] = useState('')
  const [jsonError, setJsonError] = useState<string | null>(null)
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    setDraft(channel)
    setJsonText(channel ? JSON.stringify(channel, null, 2) : '')
    setJsonError(null)
    setMode('form')
    setError(null)
  }, [channel])

  function updateField(key: keyof OpasChannel, value: unknown) {
    setDraft(prev => prev ? ({ ...prev, [key]: value } as OpasChannel) : prev)
  }

  function switchMode(next: 'form' | 'json') {
    if (next === 'json' && draft) {
      setJsonText(JSON.stringify(draft, null, 2))
      setJsonError(null)
    } else if (next === 'form' && mode === 'json') {
      try {
        setDraft(JSON.parse(jsonText))
        setJsonError(null)
      } catch (e: any) {
        setJsonError(e?.message ?? 'JSON non valido')
        return
      }
    }
    setMode(next)
  }

  async function handleSave(restart: boolean) {
    if (!channel || moduleId == null) return
    let patch: OpasChannel = draft as OpasChannel
    if (mode === 'json') {
      try {
        patch = JSON.parse(jsonText)
        setJsonError(null)
      } catch (e: any) {
        setJsonError(e?.message ?? 'JSON non valido')
        return
      }
    }
    setSaving(true)
    setError(null)
    try {
      const result = await window.electron.saveOpasChannel(moduleId, channel.id, patch, configFilename)
      if (!result?.success) {
        setError('Salvataggio non riuscito.')
        return
      }
      if (restart && !configFilename) {
        await window.electron.driverAction(String(moduleId), 'restart')
      }
      window.dispatchEvent(new Event('opas-config-saved'))
      onClose()
    } catch {
      setError('Salvataggio non riuscito.')
    } finally {
      setSaving(false)
    }
  }

  const open = channel !== null
  const disableSave = saving || !editable || (mode === 'json' && !!jsonError)

  return (
    <Dialog open={open} onOpenChange={o => { if (!o) onClose() }}>
      <DialogContent className="sm:max-w-2xl h-[min(85vh,44rem)] max-h-[85vh] !overflow-hidden flex flex-col gap-0 p-0">
        {draft && (
          <>
            <DialogHeader className="shrink-0 border-b px-6 py-4">
              <DialogTitle className="flex items-center gap-2">
                {draft.name}
                {draft.unit && <span className="text-sm font-normal text-muted-foreground">{draft.unit}</span>}
              </DialogTitle>
            </DialogHeader>

            <Tabs value={mode} onValueChange={v => switchMode(v as 'form' | 'json')} className="flex-1 min-h-0 gap-0">
              <div className="shrink-0 px-6 pt-4">
                <TabsList>
                  <TabsTrigger value="form">Form</TabsTrigger>
                  <TabsTrigger value="json">JSON</TabsTrigger>
                </TabsList>
              </div>

              <TabsContent value="form" className="min-h-0 overflow-y-auto px-6 py-4">
                <FieldGroupForm
                  groups={CHANNEL_FIELD_GROUPS}
                  draft={draft}
                  updateField={updateField}
                  editable={editable}
                />
              </TabsContent>

              <TabsContent value="json" className="min-h-0 overflow-y-auto px-6 py-4 flex flex-col">
                <JsonEditor
                  value={jsonText}
                  onChange={v => { setJsonText(v); setJsonError(null) }}
                  error={jsonError}
                  editable={editable}
                />
              </TabsContent>
            </Tabs>

            {error && <p className="shrink-0 px-6 pt-2 text-sm text-destructive">{error}</p>}
            {!editable && (
              <p className="shrink-0 px-6 pt-2 text-sm text-muted-foreground">
                Sola lettura: attiva "Modalità modifica" per modificare questi valori.
              </p>
            )}

            <DialogFooter className="shrink-0 border-t px-6 py-4">
              {configFilename ? (
                <Button onClick={() => handleSave(false)} disabled={disableSave}>
                  Salva
                </Button>
              ) : (
                <>
                  <Button variant="secondary" onClick={() => handleSave(false)} disabled={disableSave}>
                    Salva
                  </Button>
                  <Button onClick={() => handleSave(true)} disabled={disableSave}>
                    Salva e riavvia driver
                  </Button>
                </>
              )}
            </DialogFooter>
          </>
        )}
      </DialogContent>
    </Dialog>
  )
}
