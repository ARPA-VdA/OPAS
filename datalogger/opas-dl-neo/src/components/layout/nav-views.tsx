"use client"

import { useState } from "react"
import { type Icon } from "@tabler/icons-react"
import { useTranslation } from "react-i18next"

import {
  SidebarMenuItem,
  SidebarMenuButton,
  SidebarMenuSub,
  SidebarMenuSubItem,
  SidebarMenuSubButton,
} from "@/components/ui/sidebar"
import { useNavigation } from "@/context/NavigationContext"
import { useViews } from "@/context/ViewsContext"

interface NavViewsProps {
  titleKey: string
  icon: Icon
  onItemClick?: (titleKey: string) => void
}

export function NavViews({ titleKey, icon: ItemIcon, onItemClick }: NavViewsProps) {
  const { t } = useTranslation()
  const navCtx = useNavigation()
  const viewsCtx = useViews()
  const onThisPage = navCtx?.activePage === titleKey

  const [open, setOpen] = useState(false)

  const goToList = () => {
    onItemClick?.(titleKey)
    viewsCtx.selectView(null)
  }

  return (
    <SidebarMenuItem>
      <SidebarMenuButton asChild isActive={onThisPage && viewsCtx.selectedId === null}>
        <button onClick={() => { goToList(); setOpen(o => !o) }} className="w-full text-left">
          <ItemIcon />
          <span>{t(titleKey)}</span>
        </button>
      </SidebarMenuButton>
      {open && viewsCtx.views.length > 0 && (
        <SidebarMenuSub>
          {viewsCtx.views.map((view) => (
            <SidebarMenuSubItem key={view.id}>
              <SidebarMenuSubButton
                asChild
                isActive={onThisPage && viewsCtx.selectedId === view.id}
              >
                <button
                  onClick={() => { onItemClick?.(titleKey); viewsCtx.selectView(view.id) }}
                  className="w-full text-left truncate"
                >
                  {view.name}
                </button>
              </SidebarMenuSubButton>
            </SidebarMenuSubItem>
          ))}
        </SidebarMenuSub>
      )}
    </SidebarMenuItem>
  )
}
