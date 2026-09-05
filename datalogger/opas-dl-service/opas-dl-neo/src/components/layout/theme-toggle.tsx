"use client"

import * as React from "react"
import { Sun, Moon } from "lucide-react"
import { cn } from "@/lib/utils"

const THEME_KEY = "theme"

export function ThemeToggle({ className }: { className?: string }) {
  const [isDark, setIsDark] = React.useState<boolean>(false)

  React.useEffect(() => {
    try {
      const stored = localStorage.getItem(THEME_KEY)
      if (stored === "dark") {
        document.documentElement.classList.add("dark")
        setIsDark(true)
        return
      }
      if (stored === "light") {
        document.documentElement.classList.remove("dark")
        setIsDark(false)
        return
      }
      const prefersDark = window.matchMedia && window.matchMedia("(prefers-color-scheme: dark)").matches
      if (prefersDark) {
        document.documentElement.classList.add("dark")
        setIsDark(true)
      } else {
        document.documentElement.classList.remove("dark")
        setIsDark(false)
      }
    } catch (e) {
      // ignore (SSR safety)
    }
  }, [])

  const toggle = React.useCallback(() => {
    const next = !isDark
    setIsDark(next)
    try {
      if (next) {
        document.documentElement.classList.add("dark")
        localStorage.setItem(THEME_KEY, "dark")
      } else {
        document.documentElement.classList.remove("dark")
        localStorage.setItem(THEME_KEY, "light")
      }
    } catch (e) {
      // ignore
    }
  }, [isDark])

  return (
    <button
      type="button"
      role="switch"
      aria-checked={isDark}
      onClick={toggle}
      title={isDark ? "Tema chiaro" : "Tema scuro"}
      className={cn(
        "peer focus-visible:ring-ring focus-visible:ring-offset-background inline-flex h-6 w-11 shrink-0 cursor-pointer items-center rounded-full border-2 border-transparent transition-colors focus-visible:ring-2 focus-visible:ring-offset-2 focus-visible:outline-hidden disabled:cursor-not-allowed disabled:opacity-50",
        isDark ? "bg-primary border-muted" : "bg-muted/40",
        className,
      )}
    >
      <span className={cn("sr-only")}>{isDark ? "Switch to light theme" : "Switch to dark theme"}</span>
      <span
        className={cn(
          "relative inline-flex h-6 w-11 flex-shrink-0 cursor-pointer items-center rounded-full transition-colors duration-200",
        )}
      >
        <span
          aria-hidden
          className={cn(
            "bg-background pointer-events-none flex h-5 w-5 items-center justify-center rounded-full shadow-lg ring-0 transition-transform duration-200 absolute left-0 top-1/2 -translate-y-1/2 z-10",
            isDark ? "translate-x-5" : "translate-x-0",
          )}
        >
          <span className="flex h-full w-full items-center justify-center text-xs">
            {isDark ? <Moon className="size-3" /> : <Sun className="size-3" />}
          </span>
        </span>
      </span>
    </button>
  )
}

export default ThemeToggle
