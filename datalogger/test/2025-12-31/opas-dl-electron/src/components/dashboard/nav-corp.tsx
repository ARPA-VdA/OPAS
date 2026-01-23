"use client"

import * as React from "react"

import {
  SidebarMenu,
  SidebarMenuButton,
  SidebarMenuItem,
} from "@/components/ui/sidebar"

export function NavCorp({
    corp,
}: {
    corp: {
        name: string
        logo: React.ElementType
        plan: string
    }
}) {
    return (
        // <SidebarMenu>
        //     <SidebarMenuItem>
        //         <SidebarMenuButton
        //             asChild
        //             className="data-[slot=sidebar-menu-button]:!p-1.5"
        //         >
        //             <a href="#">
        //                 <corp.logo className="!size-5" />
        //                 <span className="text-base font-semibold">{corp.name}</span>
        //             </a>
        //         </SidebarMenuButton>
        //     </SidebarMenuItem>
        // </SidebarMenu>
        <SidebarMenu>
          <SidebarMenuItem>
            <SidebarMenuButton size="lg" asChild>
              <a href="#">
                <div className="bg-sidebar-primary text-sidebar-primary-foreground flex aspect-square size-8 items-center justify-center rounded-lg">
                  <corp.logo className="size-5" />
                </div>
                <div className="flex flex-col gap-0.5 leading-none">
                  <span className="font-medium">{corp.name}</span>
                  <span className="">v1.0.0</span>
                </div>
              </a>
            </SidebarMenuButton>
          </SidebarMenuItem>
        </SidebarMenu>
    )
}
