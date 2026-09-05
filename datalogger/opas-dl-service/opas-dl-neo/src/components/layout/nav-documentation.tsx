"use client"

import { useState } from "react"
import { IconChevronRight, type Icon } from "@tabler/icons-react"
import { useTranslation } from "react-i18next"

import { cn } from "@/lib/utils"
import {
  SidebarMenuItem,
  SidebarMenuButton,
  SidebarMenuSub,
  SidebarMenuSubItem,
  SidebarMenuSubButton,
} from "@/components/ui/sidebar"
import { useNavigation } from "@/context/NavigationContext"
import { useDocumentation, indexFilename } from "@/context/DocumentationContext"

interface NavDocumentationProps {
  titleKey: string
  icon: Icon
  onItemClick?: (titleKey: string) => void
}

function ExpandToggle({ open, onToggle, label }: { open: boolean; onToggle: () => void; label: string }) {
  return (
    <button
      type="button"
      onClick={(e) => { e.stopPropagation(); onToggle() }}
      aria-label={label}
      aria-expanded={open}
      className="shrink-0 flex items-center justify-center size-6 rounded-md text-muted-foreground hover:bg-sidebar-accent hover:text-sidebar-accent-foreground"
    >
      <IconChevronRight size={14} className={cn("transition-transform", open && "rotate-90")} />
    </button>
  )
}

export function NavDocumentation({ titleKey, icon: ItemIcon, onItemClick }: NavDocumentationProps) {
  const { t } = useTranslation()
  const navCtx = useNavigation()
  const doc = useDocumentation()
  const onThisPage = navCtx?.activePage === titleKey

  const [docOpen, setDocOpen] = useState(false)
  const [serviceOpen, setServiceOpen] = useState(true)

  const goTo = () => onItemClick?.(titleKey)

  // The index/README file is already shown when clicking "Servizio Python"
  // itself (see viewServiceIndex), so it doesn't need its own list entry.
  const index = indexFilename(doc.docs)
  const otherDocs = doc.docs.filter((file) => file.filename !== index)

  return (
    <SidebarMenuItem>
      <SidebarMenuButton asChild isActive={onThisPage && doc.section === 'overview'}>
        <button onClick={() => { goTo(); setDocOpen(o => !o); doc.viewOverview() }} className="w-full text-left">
          <ItemIcon />
          <span>{t(titleKey)}</span>
        </button>
      </SidebarMenuButton>
      {docOpen && (
        <SidebarMenuSub>
          <SidebarMenuSubItem>
            <div className="flex items-center gap-1">
              {otherDocs.length > 0 && (
                <ExpandToggle open={serviceOpen} onToggle={() => setServiceOpen(o => !o)} label={serviceOpen ? "Comprimi Servizio Python" : "Espandi Servizio Python"} />
              )}
              <SidebarMenuSubButton asChild isActive={onThisPage && doc.section === 'service'} className="flex-1">
                <button onClick={() => { goTo(); doc.viewServiceIndex() }} className="w-full text-left">
                  Servizio Python
                </button>
              </SidebarMenuSubButton>
            </div>
            {serviceOpen && otherDocs.length > 0 && (
              <SidebarMenuSub>
                {otherDocs.map((file) => (
                  <SidebarMenuSubItem key={file.filename}>
                    <SidebarMenuSubButton
                      asChild
                      size="sm"
                      isActive={onThisPage && doc.section === 'service' && doc.selectedFile === file.filename}
                    >
                      <button onClick={() => { goTo(); doc.selectFile(file.filename) }} className="w-full text-left truncate">
                        {file.title}
                      </button>
                    </SidebarMenuSubButton>
                  </SidebarMenuSubItem>
                ))}
              </SidebarMenuSub>
            )}
          </SidebarMenuSubItem>
          <SidebarMenuSubItem>
            <div className="flex items-center gap-1">
              <span className="shrink-0 size-6" aria-hidden="true" />
              <SidebarMenuSubButton asChild isActive={onThisPage && doc.section === 'ui'} className="flex-1">
                <button onClick={() => { goTo(); doc.selectSection('ui') }} className="w-full text-left">
                  UI
                </button>
              </SidebarMenuSubButton>
            </div>
          </SidebarMenuSubItem>
        </SidebarMenuSub>
      )}
    </SidebarMenuItem>
  )
}
