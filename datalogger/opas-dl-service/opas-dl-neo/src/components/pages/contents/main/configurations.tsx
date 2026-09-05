import { useCallback, useEffect, useState } from "react"
import { useEditMode } from "@/context/EditModeContext"
import { useNavigation } from "@/context/NavigationContext"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Badge } from "@/components/ui/badge"
import { CreateConfigDialog } from "@/components/configurations/create-config-dialog"
import { ConfigDetail } from "@/components/configurations/config-detail"
import { IconPlus, IconStar } from "@tabler/icons-react"

export function ConfigurationsContent() {
  const { editMode } = useEditMode()
  const nav = useNavigation()
  const [entries, setEntries] = useState<ConfigLibraryEntry[]>([])
  const [loading, setLoading] = useState(true)
  const [selectedFilename, setSelectedFilename] = useState<string | null>(null)
  const [createDialogOpen, setCreateDialogOpen] = useState(false)

  const load = useCallback(async () => {
    setLoading(true)
    const result = await window.electron.listConfigLibrary()
    setEntries(result ?? [])
    setLoading(false)
  }, [])

  useEffect(() => {
    load()
    window.addEventListener('opas-config-saved', load)
    return () => window.removeEventListener('opas-config-saved', load)
  }, [load])

  // One-shot: the dashboard's hero card can navigate here asking to land
  // directly on the active configuration's detail view - see the analogous
  // payload consumption in instruments.tsx. Consumed once, then cleared, so
  // navigating back to this page later doesn't re-select it.
  useEffect(() => {
    const payload = nav?.payload as { selectFilename?: string } | null | undefined
    if (payload?.selectFilename) {
      setSelectedFilename(payload.selectFilename)
      nav?.clearPayload()
    }
  }, [nav?.payload])

  const selected = selectedFilename ? entries.find(e => e.filename === selectedFilename) ?? null : null

  if (selected) {
    return (
      <ConfigDetail
        entry={selected}
        onBack={() => setSelectedFilename(null)}
        onActivated={load}
      />
    )
  }

  if (loading) {
    return <div className="p-4 text-sm text-muted-foreground">Caricamento…</div>
  }

  return (
    <div className="flex flex-col gap-4 p-4">
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
        {entries.map(entry => (
          <Card
            key={entry.filename}
            onClick={() => setSelectedFilename(entry.filename)}
            className={`cursor-pointer hover:shadow-sm transition-all py-0 gap-0 ${
              entry.isActive
                ? 'border-green-300 dark:border-green-500/40 bg-green-50/60 dark:bg-green-500/5 hover:border-green-400 dark:hover:border-green-500/60'
                : 'hover:border-primary/50'
            }`}
          >
            <CardHeader className="p-3 pb-2">
              <div className="flex items-center justify-between gap-2">
                <CardTitle className="text-base truncate">{entry.name || entry.filename}</CardTitle>
                {entry.isActive && (
                  <Badge className="gap-1 shrink-0 bg-green-100 text-green-700 border-green-200 dark:bg-green-500/20 dark:text-green-400 dark:border-green-500/30">
                    <IconStar size={12} /> Attiva
                  </Badge>
                )}
              </div>
              <p className="text-xs text-muted-foreground truncate">{entry.filename}</p>
            </CardHeader>
            <CardContent className="px-3 pb-3 pt-0">
              <div className="flex items-center justify-between text-xs text-muted-foreground">
                <span>{entry.moduleCount} strumenti</span>
              </div>
            </CardContent>
          </Card>
        ))}

        {editMode && (
          <Card
            onClick={() => setCreateDialogOpen(true)}
            className="py-0 gap-0 flex items-center justify-center min-h-[100px] border-dashed shadow-none cursor-pointer hover:border-primary/50 hover:bg-muted/30 transition-all"
          >
            <div className="flex flex-col items-center gap-1.5 text-muted-foreground p-4">
              <IconPlus size={20} />
              <span className="text-xs font-medium">Aggiungi configurazione</span>
            </div>
          </Card>
        )}
      </div>

      <CreateConfigDialog
        open={createDialogOpen}
        onClose={() => setCreateDialogOpen(false)}
        existingEntries={entries}
        onCreated={(filename) => { load(); setSelectedFilename(filename) }}
      />
    </div>
  )
}
