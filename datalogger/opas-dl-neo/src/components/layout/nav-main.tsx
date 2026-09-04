import { IconCirclePlusFilled, IconMail, type Icon } from "@tabler/icons-react"

import { Button } from "@/components/ui/button"
import { useTranslation } from "react-i18next"
import {
  SidebarGroup,
  SidebarGroupContent,
  SidebarMenu,
  SidebarMenuButton,
  SidebarMenuItem,
} from "@/components/ui/sidebar"
import { useNavigation } from "@/context/NavigationContext"
import { NavViews } from "./nav-views"

export function NavMain({
  items,
  onItemClick,
}: {
  items: {
    titleKey: string
    url: string
    icon?: Icon
  }[]
  onItemClick?: (title: string) => void
}) {
  const { t } = useTranslation();
  const navCtx = useNavigation();
  return (
    <SidebarGroup>
      <SidebarGroupContent className="flex flex-col gap-2">
        {/* <SidebarMenu>
          <SidebarMenuItem className="flex items-center gap-2">
            <SidebarMenuButton
              tooltip="Quick Create"
              className="bg-primary text-primary-foreground hover:bg-primary/90 hover:text-primary-foreground active:bg-primary/90 active:text-primary-foreground min-w-8 duration-200 ease-linear"
            >
              <IconCirclePlusFilled />
              <span>Quick Create</span>
            </SidebarMenuButton>
            <Button
              size="icon"
              className="size-8 group-data-[collapsible=icon]:opacity-0"
              variant="outline"
            >
              <IconMail />
              <span className="sr-only">Inbox</span>
            </Button>
          </SidebarMenuItem>
        </SidebarMenu> */}
        <SidebarMenu>
          {items.map((item) => (
            item.titleKey === "nav.views" ? (
              <NavViews key={item.titleKey} titleKey={item.titleKey} icon={item.icon!} onItemClick={onItemClick} />
            ) : (
              <SidebarMenuItem key={t(item.titleKey)}>
                <SidebarMenuButton
                  tooltip={t(item.titleKey)}
                  isActive={navCtx?.activePage === item.titleKey}
                  onClick={() => onItemClick?.(item.titleKey)}
                >
                  {item.icon && <item.icon />}
                  <span>{t(item.titleKey)}</span>
                </SidebarMenuButton>
              </SidebarMenuItem>
            )
          ))}
        </SidebarMenu>
      </SidebarGroupContent>
    </SidebarGroup>
  )
}
