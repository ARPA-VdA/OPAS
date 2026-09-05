import { useEffect, useState } from "react"
import {
  Dialog, DialogContent, DialogHeader, DialogTitle, DialogFooter,
} from "@/components/ui/dialog"
import { Tabs, TabsList, TabsTrigger, TabsContent } from "@/components/ui/tabs"
import { Button } from "@/components/ui/button"
import { useEditMode } from "@/context/EditModeContext"
import { FieldGroupForm } from "./field-group-form"
import { JsonEditor } from "./json-editor"
import { MODULE_FIELD_GROUPS, toModuleFormValue, type ModuleFormValue } from "./module-field-groups"

interface ModuleEditDialogProps {
  module: OpasModule | null
  onClose: () => void
  // Filename of the config this module belongs to, when it isn't the active
  // config (e.g. editing a samples/ file from the Configurazioni page) - see
  // saveOpasModule's optional configFilename param. Omitted => active config,
  // same as before. When set, "Salva e riavvia driver" is hidden: there is no
  // running driver for a config that isn't active.
  configFilename?: string
}

export function ModuleEditDialog({ module, onClose, configFilename }: ModuleEditDialogProps) {
  const { editMode: editable } = useEditMode()
  const [draft, setDraft] = useState<ModuleFormValue | null>(module ? toModuleFormValue(module) : null)
  const [mode, setMode] = useState<'form' | 'json'>('form')
  const [jsonText, setJsonText] = useState('')
  const [jsonError, setJsonError] = useState<string | null>(null)
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    const initial = module ? toModuleFormValue(module) : null
    setDraft(initial)
    setJsonText(initial ? JSON.stringify(initial, null, 2) : '')
    setJsonError(null)
    setMode('form')
    setError(null)
  }, [module])

  function updateField(key: keyof ModuleFormValue, value: unknown) {
    setDraft(prev => prev ? ({ ...prev, [key]: value } as ModuleFormValue) : prev)
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
    if (!module) return
    let patch: ModuleFormValue = draft as ModuleFormValue
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
      const result = await window.electron.saveOpasModule(module.id, patch, configFilename)
      if (!result?.success) {
        setError('Salvataggio non riuscito.')
        return
      }
      if (restart && !configFilename) {
        await window.electron.driverAction(String(module.id), 'restart')
      }
      window.dispatchEvent(new Event('opas-config-saved'))
      onClose()
    } catch {
      setError('Salvataggio non riuscito.')
    } finally {
      setSaving(false)
    }
  }

  const open = module !== null
  const disableSave = saving || !editable || (mode === 'json' && !!jsonError)

  return (
    <Dialog open={open} onOpenChange={o => { if (!o) onClose() }}>
      <DialogContent className="sm:max-w-2xl h-[min(85vh,44rem)] max-h-[85vh] !overflow-hidden flex flex-col gap-0 p-0">
        {draft && (
          <>
            <DialogHeader className="shrink-0 border-b px-6 py-4">
              <DialogTitle>{draft.name}</DialogTitle>
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
                  groups={MODULE_FIELD_GROUPS}
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
