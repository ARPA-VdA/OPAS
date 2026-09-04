import { useEffect, useState } from "react"
import { useViews } from "@/context/ViewsContext"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { IconLayoutGrid, IconTable, IconPlus } from "@tabler/icons-react"
import { ViewDetail } from "@/components/views/view-detail"
import { CreateViewDialog } from "@/components/views/create-view-dialog"

export function ViewsContent() {
  const { views, isLoading, selectedId, selectView, refresh } = useViews()
  const [modules, setModules] = useState<OpasModule[]>([])
  const [createDialogOpen, setCreateDialogOpen] = useState(false)

  useEffect(() => {
    const loadConfig = () => window.electron.getOpasConfig().then(config => {
      const data = config?.data as OpasConfigData | undefined
      setModules(data?.modules ?? [])
    })
    loadConfig()
    window.addEventListener('opas-config-saved', loadConfig)
    return () => window.removeEventListener('opas-config-saved', loadConfig)
  }, [])

  if (selectedId) {
    return <ViewDetail id={selectedId} onBack={() => selectView(null)} />
  }

  if (isLoading) {
    return <div className="p-4 text-sm text-muted-foreground">Caricamento…</div>
  }

  return (
    <div className="flex flex-col gap-4 p-4">
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
        {views.map(view => (
          <Card
            key={view.id}
            onClick={() => selectView(view.id)}
            className="cursor-pointer hover:shadow-sm hover:border-primary/50 transition-all py-0 gap-0"
          >
            <CardHeader className="p-3 pb-2">
              <CardTitle className="text-base truncate">{view.name}</CardTitle>
            </CardHeader>
            <CardContent className="px-3 pb-3 pt-0">
              <div className="flex items-center justify-between text-xs text-muted-foreground">
                <span>{view.channelCount} canali</span>
                <span className="flex items-center gap-1">
                  {view.displayMode === 'cards' ? <IconLayoutGrid size={13} /> : <IconTable size={13} />}
                  {view.displayMode === 'cards' ? 'Card' : 'Tabella'}
                </span>
              </div>
            </CardContent>
          </Card>
        ))}

        <Card
          onClick={() => setCreateDialogOpen(true)}
          className="py-0 gap-0 flex items-center justify-center min-h-[100px] border-dashed shadow-none cursor-pointer hover:border-primary/50 hover:bg-muted/30 transition-all"
        >
          <div className="flex flex-col items-center gap-1.5 text-muted-foreground p-4">
            <IconPlus size={20} />
            <span className="text-xs font-medium">Nuova vista</span>
          </div>
        </Card>
      </div>

      <CreateViewDialog
        open={createDialogOpen}
        onClose={() => setCreateDialogOpen(false)}
        modules={modules}
        onCreated={(id) => { refresh(); selectView(id) }}
      />
    </div>
  )
}
