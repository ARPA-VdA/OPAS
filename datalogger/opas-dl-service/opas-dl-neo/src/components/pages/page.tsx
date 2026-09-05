import { AppSidebar } from "@/components/layout/app-sidebar"
import {
  SidebarInset,
  SidebarProvider,
} from "@/components/ui/sidebar"
import { useState } from "react"

import { navigationConfig, secondaryNavConfig } from "@/config/navigation"
import BaseContent from "./base-content"
import { InstrumentProvider, type InstrumentValue } from "@/context/InstrumentContext"
import { NavigationProvider } from "@/context/NavigationContext"
import { DocumentationProvider } from "@/context/DocumentationContext"
import { ViewsProvider } from "@/context/ViewsContext"
import { EditModeProvider } from "@/context/EditModeContext"
import { useTranslation } from "react-i18next"

interface PageProps {
  instrumentValues?: InstrumentValue[];
}

export default function Page({ instrumentValues = [] }: PageProps) {
  const [selectedMenu, setSelectedMenu] = useState(navigationConfig[0].titleKey)
  const [navPayload, setNavPayload] = useState<unknown>(null)

  const currentItem =
    navigationConfig.find(item => item.titleKey === selectedMenu) ||
    secondaryNavConfig.find(item => item.titleKey === selectedMenu) ||
    navigationConfig[0]
  const { t } = useTranslation();
  const navigateTo = (titleKey: string, payload?: unknown) => {
    setSelectedMenu(titleKey)
    setNavPayload(payload ?? null)
  }
  return (
    <InstrumentProvider instrumentValues={instrumentValues}>
      <NavigationProvider
        activePage={selectedMenu}
        onNavigate={navigateTo}
        payload={navPayload}
        onClearPayload={() => setNavPayload(null)}
      >
        <EditModeProvider>
          <DocumentationProvider>
            <ViewsProvider>
              <SidebarProvider
                className="h-svh overflow-hidden"
                style={
                  {
                    "--sidebar-width": "calc(var(--spacing) * 72)",
                    "--header-height": "calc(var(--spacing) * 12)",
                  } as React.CSSProperties
                }
              >
                <AppSidebar variant="inset" onMenuClick={(key) => navigateTo(key)} />
                <SidebarInset>
                  <BaseContent name={t(currentItem.titleKey)}>
                    {currentItem.component}
                  </BaseContent>
                </SidebarInset>
              </SidebarProvider>
            </ViewsProvider>
          </DocumentationProvider>
        </EditModeProvider>
      </NavigationProvider>
    </InstrumentProvider>
  )
}
