import { SiteHeader } from "@/components/layout/site-header"
import { SiteFooter } from "@/components/layout/site-footer"
import type { ReactNode } from "react"

import data from "../../app/dashboard/data.json"

export default function BaseContent({
  name,
  children,
}: {
  name: string
  children?: ReactNode
})  {
    return (
        <div className="h-full flex flex-col">
            <SiteHeader title={name} />
            <div className="flex-1 min-h-0 overflow-y-auto">
                {children}
            </div>
            <SiteFooter />
        </div>
    )
}
