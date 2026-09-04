import type { ReactNode } from "react"
import { IconArrowRight } from "@tabler/icons-react"
import { useNavigation } from "@/context/NavigationContext"

interface DashboardSectionProps {
  title?: string
  children: ReactNode
  className?: string
  navigateTo?: string
}

export function DashboardSection({ title, children, className, navigateTo }: DashboardSectionProps) {
  const navCtx = useNavigation()

  return (
    <div className={`w-full space-y-3 ${className ?? ''}`}>
      {(title || navigateTo) && (
        <div className="flex items-center justify-between">
          {title && <h2 className="text-2xl font-bold text-left">{title}</h2>}
          {navigateTo && navCtx && (
            <button
              onClick={() => navCtx.navigateTo(navigateTo)}
              className="flex items-center gap-1 text-sm text-muted-foreground hover:text-foreground transition-colors"
            >
              Vai alla pagina
              <IconArrowRight size={16} />
            </button>
          )}
        </div>
      )}
      <div className="flex flex-col flex-1 min-h-0">
        {children}
      </div>
    </div>
  )
}
