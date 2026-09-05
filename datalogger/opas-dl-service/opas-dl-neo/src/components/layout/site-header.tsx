import { Separator } from "@/components/ui/separator"
import { SidebarTrigger } from "@/components/ui/sidebar"
import { Switch } from "@/components/ui/switch"
import { Label } from "@/components/ui/label"
import { IconPencil } from "@tabler/icons-react"
import {
  Breadcrumb,
  BreadcrumbList,
  BreadcrumbItem,
  BreadcrumbPage,
  BreadcrumbSeparator,
} from "@/components/ui/breadcrumb"
import { ThemeToggle } from "./theme-toggle"
import { useNavigation } from "@/context/NavigationContext"
import { useDocumentation, indexFilename } from "@/context/DocumentationContext"
import { useEditMode } from "@/context/EditModeContext"

export function SiteHeader({ title = "Documents" }: { title?: string }) {
  const navCtx = useNavigation()
  const doc = useDocumentation()
  const { editMode, setEditMode } = useEditMode()
  const isInstrumentsPage = navCtx?.activePage === "nav.instruments"
  const isConfigurationsPage = navCtx?.activePage === "nav.configurations"
  // Any page gated by editMode needs its nav key added here AND to the matching check in site-footer.tsx.
  const showEditModeSwitch = isInstrumentsPage || isConfigurationsPage
  const isDocumentationPage = navCtx?.activePage === "nav.documentation"
  const docTitle = isDocumentationPage && doc.section === "service"
    ? doc.docs.find(d => d.filename === doc.selectedFile)?.title
    : null
  // The index/README file is what "Servizio Python" itself already shows,
  // so it doesn't need its own breadcrumb crumb on top of the page title.
  const showDocCrumb = docTitle && doc.selectedFile !== indexFilename(doc.docs)

  return (
    <header className="flex h-(--header-height) shrink-0 items-center gap-2 border-b transition-[width,height] ease-linear group-has-data-[collapsible=icon]/sidebar-wrapper:h-(--header-height)">
      <div className="flex w-full items-center gap-1 px-4 lg:gap-2 lg:px-6">
        <SidebarTrigger className="-ml-1" />
        <Separator
          orientation="vertical"
          className="mx-2 data-[orientation=vertical]:h-4"
        />
        {showDocCrumb ? (
          <Breadcrumb>
            <BreadcrumbList className="flex-nowrap text-base">
              <BreadcrumbItem>
                <span className="font-medium text-foreground">{title}</span>
              </BreadcrumbItem>
              <BreadcrumbSeparator />
              <BreadcrumbItem>
                <BreadcrumbPage className="font-medium truncate max-w-[40vw]">{docTitle}</BreadcrumbPage>
              </BreadcrumbItem>
            </BreadcrumbList>
          </Breadcrumb>
        ) : (
          <h1 className="text-base font-medium">{title}</h1>
        )}
        <div className="ml-auto flex items-center gap-3">
          {showEditModeSwitch && (
            <>
              <div className="flex items-center gap-1.5" title="Modalità modifica">
                <Switch
                  id="edit-mode-switch"
                  checked={editMode}
                  onCheckedChange={setEditMode}
                />
                <Label htmlFor="edit-mode-switch" className="text-muted-foreground cursor-pointer">
                  <IconPencil size={14} />
                </Label>
              </div>
              <Separator orientation="vertical" className="data-[orientation=vertical]:h-4" />
            </>
          )}
          <ThemeToggle />
        </div>
      </div>
    </header>
  )
}
