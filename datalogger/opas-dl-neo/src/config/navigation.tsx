import type { ReactNode } from "react"
import {
  IconChartBar,
  IconDashboard,
  IconFileSettings,
  IconCar,
  IconTemperatureCelsius,
  IconLayoutDashboard,
  type Icon,
  IconSettings,
  IconInfoCircle,
  IconBook,
} from "@tabler/icons-react"
import { DashboardContent } from "@/components/pages/contents/main/dashboard"
import { InstrumentsContent } from "@/components/pages/contents/main/instruments"
import { DriversContent } from "@/components/pages/contents/main/drivers"
import { ConfigurationsContent } from "@/components/pages/contents/main/configurations"
import { GraphsContent } from "@/components/pages/contents/main/graphs"
import { ViewsContent } from "@/components/pages/contents/main/views"
import { SettingsContent } from "@/components/pages/contents/secondary/settings"
import { DocumentationContent } from "@/components/pages/contents/secondary/documentation"
import { SystemContent } from "@/components/pages/contents/secondary/system"
import { ProfileContent } from "@/components/pages/contents/user/profile"

export interface MenuItemConfig {
  titleKey: string
  url: string
  icon: Icon
  component: ReactNode
}

export interface SecondaryItemConfig {
  titleKey: string
  url: string
  icon: Icon
  component: ReactNode
}

export interface UserConfig {
  name: string
  email: string
  avatar: string
  titleKey: string
  component: ReactNode
  logoutKey: string
}

export const navigationConfig: MenuItemConfig[] = [
  {
    titleKey: "nav.dashboard",
    url: "#",
    icon: IconDashboard,
    component: <DashboardContent />,
  },
  {
    titleKey: "nav.instruments",
    url: "#",
    icon: IconTemperatureCelsius,
    component: <InstrumentsContent />,
  },
  {
    titleKey: "nav.drivers",
    url: "#",
    icon: IconCar,
    component: <DriversContent />,
  },
  {
    titleKey: "nav.configurations",
    url: "#",
    icon: IconFileSettings,
    component: <ConfigurationsContent />,
  },
  {
    titleKey: "nav.graphs",
    url: "#",
    icon: IconChartBar,
    component: <GraphsContent />,
  },
  {
    titleKey: "nav.views",
    url: "#",
    icon: IconLayoutDashboard,
    component: <ViewsContent />,
  },
]


export const secondaryNavConfig: SecondaryItemConfig[] = [
  {
    titleKey: "nav.settings",
    url: "#",
    icon: IconSettings,
    component: <SettingsContent />,
  },
  {
    titleKey: "nav.documentation",
    url: "#",
    icon: IconBook,
    component: <DocumentationContent />,
  },
  {
    titleKey: "nav.system",
    url: "#",
    icon: IconInfoCircle,
    component: <SystemContent />,
  },
]

export const userConfig: UserConfig = {
  name: "Utente Demo",
  email: "demo@example.com",
  avatar: "/avatars/shadcn.jpg",
  titleKey: "user.profile",
  component: <ProfileContent />,
  logoutKey: "user.logout"
}