import { IconPencil } from "@tabler/icons-react"
import { useNavigation } from "@/context/NavigationContext"
import { useEditMode } from "@/context/EditModeContext"

export function SiteFooter() {
  const navCtx = useNavigation()
  const { editMode } = useEditMode()
  const isInstrumentsPage = navCtx?.activePage === "nav.instruments"
  const isConfigurationsPage = navCtx?.activePage === "nav.configurations"

  if ((!isInstrumentsPage && !isConfigurationsPage) || !editMode) return null

  return (
    <div className="flex items-center justify-center gap-2 shrink-0 border-t-2 border-amber-400 dark:border-amber-400 bg-amber-200 dark:bg-amber-500/35 px-4 py-1.5 text-sm font-semibold text-amber-950 dark:text-amber-200">
      <IconPencil size={14} className="shrink-0" />
      <span>
        {isInstrumentsPage
          ? "Modalità modifica attiva: le configurazioni degli strumenti sono modificabili."
          : "Modalità modifica attiva: le configurazioni sono modificabili."}
      </span>
    </div>
  )
}
