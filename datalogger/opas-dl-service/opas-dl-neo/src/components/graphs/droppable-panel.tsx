import type { ReactNode } from "react"
import { useDroppable } from "@dnd-kit/core"
import { cn } from "@/lib/utils"

interface DroppablePanelProps {
  id: string
  children: ReactNode
}

export function DroppablePanel({ id, children }: DroppablePanelProps) {
  const { setNodeRef, isOver } = useDroppable({ id })

  return (
    <div
      ref={setNodeRef}
      className={cn(
        "rounded-xl transition-shadow",
        isOver && "ring-2 ring-primary ring-offset-2 ring-offset-background"
      )}
    >
      {children}
    </div>
  )
}
