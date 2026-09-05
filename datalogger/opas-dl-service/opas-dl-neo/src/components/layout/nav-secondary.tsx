"use client"

import * as React from "react"
import { type Icon } from "@tabler/icons-react"
import { useTranslation } from "react-i18next"

import {
  SidebarGroup,
  SidebarGroupContent,
  SidebarMenu,
  SidebarMenuButton,
  SidebarMenuItem,
} from "@/components/ui/sidebar"
import { useNavigation } from "@/context/NavigationContext"
import { NavDocumentation } from "./nav-documentation"

export function NavSecondary({
  items,
  onItemClick,
  ...props
}: {
  items: {
    titleKey: string
    url: string
    icon: Icon
    component?: React.ReactNode
  }[]
  onItemClick?: (titleKey: string) => void
} & React.ComponentPropsWithoutRef<typeof SidebarGroup>) {
  const { t } = useTranslation();
  const navCtx = useNavigation();
  return (
    <SidebarGroup {...props}>
      <SidebarGroupContent>
        <SidebarMenu>
          {items.map((item) => (
            item.titleKey === "nav.documentation" ? (
              <NavDocumentation key={item.titleKey} titleKey={item.titleKey} icon={item.icon} onItemClick={onItemClick} />
            ) : (
              <SidebarMenuItem key={t(item.titleKey)}>
                <SidebarMenuButton asChild isActive={navCtx?.activePage === item.titleKey}>
                  {onItemClick ? (
                    <button
                      onClick={() => onItemClick(item.titleKey)}
                      className="w-full text-left"
                    >
                      <item.icon />
                      <span>{t(item.titleKey)}</span>
                    </button>
                  ) : (
                    <a href={item.url}>
                      <item.icon />
                      <span>{t(item.titleKey)}</span>
                    </a>
                  )}
                </SidebarMenuButton>
              </SidebarMenuItem>
            )
          ))}
        </SidebarMenu>
      </SidebarGroupContent>
    </SidebarGroup>
  )
}
