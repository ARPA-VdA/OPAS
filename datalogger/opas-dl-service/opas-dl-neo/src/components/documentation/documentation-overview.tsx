import { IconTerminal2, IconLayoutDashboard, IconChevronRight } from "@tabler/icons-react"
import { useDocumentation } from "@/context/DocumentationContext"

export function DocumentationOverview() {
  const doc = useDocumentation()

  return (
    <div className="flex flex-col gap-3 p-4 max-w-2xl">
      <p className="text-sm text-muted-foreground mb-1">
        Documentazione del progetto OPAS DL, divisa per area.
      </p>
      <button
        onClick={() => doc.viewServiceIndex()}
        className="flex items-center gap-3 text-left border border-border rounded-lg p-4 hover:bg-accent/50 transition-colors"
      >
        <IconTerminal2 size={20} className="shrink-0 text-muted-foreground" />
        <div className="flex-1 min-w-0">
          <div className="font-medium text-foreground">Servizio Python</div>
          <p className="text-sm text-muted-foreground mt-0.5">
            Architettura, API di controllo e contratto dei driver del servizio opas-dl-service ({doc.docs.length} documenti).
          </p>
        </div>
        <IconChevronRight size={16} className="shrink-0 text-muted-foreground" />
      </button>
      <button
        onClick={() => doc.viewUiIndex()}
        className="flex items-center gap-3 text-left border border-border rounded-lg p-4 hover:bg-accent/50 transition-colors"
      >
        <IconLayoutDashboard size={20} className="shrink-0 text-muted-foreground" />
        <div className="flex-1 min-w-0">
          <div className="font-medium text-foreground">UI</div>
          <p className="text-sm text-muted-foreground mt-0.5">
            Panoramica delle sezioni dell'applicazione ({doc.uiDocs.length} documenti).
          </p>
        </div>
        <IconChevronRight size={16} className="shrink-0 text-muted-foreground" />
      </button>
    </div>
  )
}
