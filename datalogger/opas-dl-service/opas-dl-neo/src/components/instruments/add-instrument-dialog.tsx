import { useEffect, useState } from "react"
import {
  Dialog, DialogContent, DialogHeader, DialogTitle, DialogDescription, DialogFooter,
} from "@/components/ui/dialog"
import { Tabs, TabsList, TabsTrigger, TabsContent } from "@/components/ui/tabs"
import { Button } from "@/components/ui/button"
import { Card } from "@/components/ui/card"
import { IconArrowLeft, IconAlertTriangle } from "@tabler/icons-react"
import { useEditMode } from "@/context/EditModeContext"
import { sanitizeInstrumentName } from "@/lib/instrumentName"
import { FieldGroupForm } from "./field-group-form"
import { JsonEditor } from "./json-editor"
import { MODULE_FIELD_GROUPS, toModuleFormValue } from "./module-field-groups"
import { CHANNEL_FIELD_GROUPS } from "./channel-field-groups"

interface AddInstrumentDialogProps {
  open: boolean
  onClose: () => void
  existingModules: OpasModule[]
  // Filename of the config to add this module to, when it isn't the active
  // config (e.g. from the Configurazioni page editing a samples/ file) - see
  // createOpasModule's optional configFilename param. Omitted => active config,
  // same as before.
  configFilename?: string
}

type Step = 'pick' | 'edit'

export function AddInstrumentDialog({ open, onClose, existingModules, configFilename }: AddInstrumentDialogProps) {
  const { editMode: editable } = useEditMode()
  const [step, setStep] = useState<Step>('pick')
  const [types, setTypes] = useState<InstrumentTypeInfo[]>([])
  const [typesLoading, setTypesLoading] = useState(false)
  const [draft, setDraft] = useState<OpasModule | null>(null)
  const [mode, setMode] = useState<'form' | 'json'>('form')
  const [jsonText, setJsonText] = useState('')
  const [jsonError, setJsonError] = useState<string | null>(null)
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    if (!open) return
    setStep('pick')
    setDraft(null)
    setMode('form')
    setJsonError(null)
    setError(null)
    setTypesLoading(true)
    window.electron.getInstrumentTypes()
      .then(setTypes)
      .finally(() => setTypesLoading(false))
  }, [open])

  async function handlePickType(key: string) {
    const result = await window.electron.getNewInstrumentDraft(key)
    if (!result) {
      setError('Impossibile caricare il modello per questo tipo di strumento.')
      return
    }
    setDraft(result)
    setJsonText(JSON.stringify(result, null, 2))
    setJsonError(null)
    setMode('form')
    setError(null)
    setStep('edit')
  }

  function updateModuleField(key: keyof OpasModule, value: unknown) {
    setDraft(prev => prev ? ({ ...prev, [key]: value } as OpasModule) : prev)
  }

  function updateChannelField(index: number, key: keyof OpasChannel, value: unknown) {
    setDraft(prev => {
      if (!prev) return prev
      const channels = prev.channels.map((ch, i) => i === index ? { ...ch, [key]: value } : ch)
      return { ...prev, channels }
    })
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

  async function handleCreate() {
    if (!draft) return
    let finalDraft: OpasModule = draft
    if (mode === 'json') {
      try {
        finalDraft = JSON.parse(jsonText)
        setJsonError(null)
      } catch (e: any) {
        setJsonError(e?.message ?? 'JSON non valido')
        return
      }
    }
    setSaving(true)
    setError(null)
    try {
      const result = await window.electron.createOpasModule(finalDraft, configFilename)
      if (!result?.success) {
        setError('Creazione non riuscita.')
        return
      }
      window.dispatchEvent(new Event('opas-config-saved'))
      onClose()
    } catch {
      setError('Creazione non riuscita.')
    } finally {
      setSaving(false)
    }
  }

  const nameCollision = draft
    ? existingModules.some(m => sanitizeInstrumentName(m.name).toLowerCase() === sanitizeInstrumentName(draft.name).toLowerCase())
    : false
  const disableCreate = saving || !editable || !draft?.name?.trim() || nameCollision || (mode === 'json' && !!jsonError)

  return (
    <Dialog open={open} onOpenChange={o => { if (!o) onClose() }}>
      <DialogContent className="sm:max-w-2xl h-[min(85vh,44rem)] max-h-[85vh] !overflow-hidden flex flex-col gap-0 p-0">
        {step === 'pick' ? (
          <>
            <DialogHeader className="shrink-0 border-b px-6 py-4">
              <DialogTitle>Aggiungi strumento</DialogTitle>
              <DialogDescription>Scegli il tipo di strumento da aggiungere.</DialogDescription>
            </DialogHeader>

            <div className="min-h-0 flex-1 overflow-y-auto px-6 py-4">
              {typesLoading ? (
                <p className="text-sm text-muted-foreground">Caricamento…</p>
              ) : types.length === 0 ? (
                <p className="text-sm text-muted-foreground">Nessun tipo di strumento disponibile.</p>
              ) : (
                <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                  {types.map(t => (
                    <Card
                      key={t.key}
                      onClick={() => handlePickType(t.key)}
                      className="p-3 gap-1 cursor-pointer hover:border-primary/50 hover:bg-muted/30 transition-all"
                    >
                      <p className="text-sm font-semibold">{t.name}</p>
                      {t.producer && <p className="text-xs text-muted-foreground">{t.producer}</p>}
                      {t.description && <p className="text-xs text-muted-foreground">{t.description}</p>}
                    </Card>
                  ))}
                </div>
              )}
              {error && <p className="text-sm text-destructive mt-3">{error}</p>}
            </div>
          </>
        ) : draft && (
          <>
            <DialogHeader className="shrink-0 border-b px-6 py-4">
              <div className="flex items-center gap-2">
                <Button variant="ghost" size="icon" className="size-7 -ml-1" onClick={() => setStep('pick')}>
                  <IconArrowLeft size={16} />
                </Button>
                <DialogTitle>{draft.name || 'Nuovo strumento'}</DialogTitle>
              </div>
            </DialogHeader>

            <Tabs value={mode} onValueChange={v => switchMode(v as 'form' | 'json')} className="flex-1 min-h-0 gap-0">
              <div className="shrink-0 px-6 pt-4">
                <TabsList>
                  <TabsTrigger value="form">Form</TabsTrigger>
                  <TabsTrigger value="json">JSON</TabsTrigger>
                </TabsList>
              </div>

              <TabsContent value="form" className="min-h-0 overflow-y-auto px-6 py-4 space-y-6">
                <FieldGroupForm
                  groups={MODULE_FIELD_GROUPS}
                  draft={toModuleFormValue(draft)}
                  updateField={updateModuleField}
                  editable={editable}
                  disabledKeys={['id']}
                />
                <div className="space-y-3">
                  <p className="text-xs font-semibold text-muted-foreground uppercase tracking-wide">Canali</p>
                  {draft.channels.map((channel, idx) => (
                    <div key={idx} className="rounded-md border p-3 space-y-2">
                      <p className="text-sm font-medium">{channel.name || `Canale ${idx + 1}`}</p>
                      <FieldGroupForm
                        groups={CHANNEL_FIELD_GROUPS}
                        draft={channel}
                        updateField={(key, value) => updateChannelField(idx, key, value)}
                        editable={editable}
                        disabledKeys={['id', 'databaseId']}
                      />
                    </div>
                  ))}
                </div>
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

            <div className="shrink-0 px-6 pt-2 space-y-1">
              {nameCollision && (
                <p className="flex items-center gap-1.5 text-sm text-destructive">
                  <IconAlertTriangle size={14} className="shrink-0" />
                  Esiste già uno strumento con questo nome.
                </p>
              )}
              {error && <p className="text-sm text-destructive">{error}</p>}
              <p className="text-sm text-muted-foreground">
                {configFilename
                  ? 'Lo strumento sarà visibile e controllabile quando questa configurazione diventerà quella attiva.'
                  : 'Lo strumento sarà visibile e controllabile dopo il prossimo riavvio del servizio.'}
              </p>
              {!editable && (
                <p className="text-sm text-muted-foreground">
                  Sola lettura: attiva "Modalità modifica" per modificare questi valori.
                </p>
              )}
            </div>

            <DialogFooter className="shrink-0 border-t px-6 py-4">
              <Button onClick={handleCreate} disabled={disableCreate}>
                Crea strumento
              </Button>
            </DialogFooter>
          </>
        )}
      </DialogContent>
    </Dialog>
  )
}
