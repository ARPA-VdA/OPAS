import * as React from "react"
import { useState, useEffect } from "react"
import { useTranslation } from "react-i18next"

import { NavMain } from "./nav-main"
import { NavSecondary } from "./nav-secondary"
import { NavUser } from "./nav-user"

import {
  Sidebar,
  SidebarContent,
  SidebarFooter,
  SidebarHeader,
  SidebarMenu,
  SidebarMenuButton,
  SidebarMenuItem,
} from "@/components/ui/sidebar"

import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select"

import {
  navigationConfig,
  secondaryNavConfig,
  userConfig,
} from "@/config/navigation"

import itFlag from "@/assets/flags/it.svg"
import gbFlag from "@/assets/flags/gb.svg"
import itPaFlag from "@/assets/flags/it-pa.svg"
import logo from "@/assets/logo/logo-stambecco-dx.png"

const LANGUAGES = {
  it: {
    label: "IT",
    icon: itFlag,
  },
  en: {
    label: "EN",
    icon: gbFlag,
  },
  it_pa: {
    label: "IT-PA",
    icon: itPaFlag,
  }
} as const

type Language = keyof typeof LANGUAGES

export function AppSidebar({
  onMenuClick,
  ...props
}: React.ComponentProps<typeof Sidebar> & {
  onMenuClick?: (title: string) => void
}) {
  const { i18n } = useTranslation()

  const initialLang = (i18n.language?.startsWith("it") ? "it" : "en") as Language
  const [language, setLanguage] = useState<Language>(initialLang)

  useEffect(() => {
    if (i18n.language !== language) {
      i18n.changeLanguage(language)
    }
  }, [language, i18n])

  const handleLanguageChange = (lang: Language) => {
    setLanguage(lang)
    i18n.changeLanguage(lang)
  }

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

              {/* -------- Language Select -------- */}
              {/* <Select value={language} onValueChange={handleLanguageChange}>
                <SelectTrigger className="w-16 h-8 px-2">
                  <SelectValue>
                    <img
                      src={LANGUAGES[language].icon}
                      alt={language}
                      className="w-5 h-5 object-contain"
                    />
                  </SelectValue>
                </SelectTrigger>

                <SelectContent>
                  {(Object.keys(LANGUAGES) as Language[]).map((lang) => (
                    <SelectItem key={lang} value={lang}>
                      <div className="flex items-center gap-2">
                        <img
                          src={LANGUAGES[lang].icon}
                          alt={lang}
                          className="w-5 h-5"
                        />
                        <span>{LANGUAGES[lang].label}</span>
                      </div>
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select> */}
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

      {/* ---------------- Footer ---------------- */}
      {/* <SidebarFooter>
        <NavUser user={userConfig} onItemClick={onMenuClick} />
      </SidebarFooter> */}
    </Sidebar>
  )
}
