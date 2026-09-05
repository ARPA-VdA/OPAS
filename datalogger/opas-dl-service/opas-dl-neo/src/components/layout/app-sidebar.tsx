import * as React from "react"

import { NavMain } from "./nav-main"
import { NavSecondary } from "./nav-secondary"

import {
  Sidebar,
  SidebarContent,
  SidebarHeader,
  SidebarMenu,
  SidebarMenuButton,
  SidebarMenuItem,
} from "@/components/ui/sidebar"

import {
  navigationConfig,
  secondaryNavConfig,
} from "@/config/navigation"

import logo from "@/assets/logo/logo-stambecco-dx.png"

export function AppSidebar({
  onMenuClick,
  ...props
}: React.ComponentProps<typeof Sidebar> & {
  onMenuClick?: (title: string) => void
}) {
  return (
    <Sidebar collapsible="offcanvas" {...props}>
      {/* ---------------- Header ---------------- */}
      <SidebarHeader>
        <SidebarMenu>
          <SidebarMenuItem>
            <div className="flex items-center justify-between">
              <SidebarMenuButton
                asChild
                className="data-[slot=sidebar-menu-button]:!p-1.5 flex-1"
              >
                <a href="#">
                  <img src={logo} alt="" className="!size-5 object-contain" />
                  <span className="text-base font-semibold">
                    Opas DL Neo
                  </span>
                </a>
              </SidebarMenuButton>
            </div>
          </SidebarMenuItem>
        </SidebarMenu>
      </SidebarHeader>

      {/* ---------------- Content ---------------- */}
      <SidebarContent>
        <NavMain items={navigationConfig} onItemClick={onMenuClick} />
        <NavSecondary
          items={secondaryNavConfig}
          onItemClick={onMenuClick}
          className="mt-auto"
        />
      </SidebarContent>
    </Sidebar>
  )
}
