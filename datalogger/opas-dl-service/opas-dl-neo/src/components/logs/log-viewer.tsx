import { useCallback, useEffect, useRef, useState } from "react"
import { Button } from "@/components/ui/button"
import {
  ContextMenu, ContextMenuContent, ContextMenuItem, ContextMenuTrigger,
} from "@/components/ui/context-menu"
import { IconArrowDown, IconCopy, IconExternalLink } from "@tabler/icons-react"
import { mergeLogLines } from "@/lib/logBuffer"

const LOG_BUFFER = 200
const LOG_POLL_MS = 2000
const SCROLL_THRESHOLD = 8

const LEVEL_COLORS: Record<string, string> = {
  DEBUG:    'text-zinc-500',
  INFO:     'text-sky-400',
  WARNING:  'text-amber-400',
  WARN:     'text-amber-400',
  ERROR:    'text-rose-400',
  CRITICAL: 'text-rose-500',
}

function renderLogLine(line: string) {
  const match = line.match(/\[(DEBUG|INFO|WARNING|WARN|ERROR|CRITICAL)\]/)
  if (!match) return <span className="text-zinc-600 dark:text-zinc-400">{line}</span>
  const full = match[0]
  const level = match[1]
  const idx = line.indexOf(full)
  return (
    <span className="text-zinc-600 dark:text-zinc-400">
      {line.slice(0, idx)}
      <span className={LEVEL_COLORS[level]}>{full}</span>
      {line.slice(idx + full.length)}
    </span>
  )
}

export function LogViewer() {
  const [lines, setLines] = useState<string[]>([])
  const [pinned, setPinned] = useState(true)
  const [selectedText, setSelectedText] = useState('')
  const containerRef = useRef<HTMLDivElement>(null)
  const pinnedRef = useRef(pinned)

  useEffect(() => {
    pinnedRef.current = pinned
  }, [pinned])

  const fetchLines = useCallback(async () => {
    const result = await window.electron.getLogLines()
    if (!result) return
    setLines(prev => mergeLogLines(prev, result, pinnedRef.current, LOG_BUFFER))
  }, [])

  useEffect(() => {
    fetchLines()
    const interval = setInterval(fetchLines, LOG_POLL_MS)
    return () => clearInterval(interval)
  }, [fetchLines])

  useEffect(() => {
    if (pinned && containerRef.current) {
      containerRef.current.scrollTop = containerRef.current.scrollHeight
    }
  }, [lines, pinned])

  const handleScroll = () => {
    const el = containerRef.current
    if (!el) return
    setPinned(el.scrollTop + el.clientHeight >= el.scrollHeight - SCROLL_THRESHOLD)
  }

  return (
    <div className="relative rounded-md overflow-hidden border border-zinc-300 dark:border-zinc-800 flex flex-col h-[320px]">
      <div className="flex items-center justify-between bg-zinc-200 dark:bg-zinc-900 px-3 py-1.5 border-b border-zinc-300 dark:border-zinc-800">
        <span className="text-xs text-zinc-600 dark:text-zinc-400 font-mono">service.log</span>
        <Button
          variant="ghost" size="icon"
          className="size-6 text-zinc-600 hover:text-zinc-900 dark:text-zinc-400 dark:hover:text-zinc-100"
          onClick={() => window.electron.openLogFile()}
        >
          <IconExternalLink size={13} />
        </Button>
      </div>
      <ContextMenu>
        <ContextMenuTrigger asChild>
          <div
            ref={containerRef}
            onScroll={handleScroll}
            onContextMenu={() => setSelectedText(window.getSelection()?.toString() ?? '')}
            className="flex-1 min-h-0 overflow-y-auto bg-zinc-100 dark:bg-zinc-950 px-3 py-2 font-mono text-xs leading-5"
          >
            {lines.length === 0
              ? <span className="text-zinc-500 dark:text-zinc-600">Nessun log disponibile</span>
              : lines.map((line, i) => (
                <div key={i} className="whitespace-pre-wrap break-all">{renderLogLine(line)}</div>
              ))
            }
          </div>
        </ContextMenuTrigger>
        <ContextMenuContent>
          <ContextMenuItem
            disabled={!selectedText}
            onSelect={() => navigator.clipboard.writeText(selectedText)}
          >
            <IconCopy size={14} />
            Copia selezione
          </ContextMenuItem>
        </ContextMenuContent>
      </ContextMenu>
      {!pinned && (
        <button
          onClick={() => {
            if (containerRef.current) containerRef.current.scrollTop = containerRef.current.scrollHeight
            setPinned(true)
          }}
          className="absolute bottom-2 right-2 flex items-center justify-center size-6 rounded bg-zinc-300 hover:bg-zinc-400 text-zinc-700 dark:bg-zinc-700 dark:hover:bg-zinc-600 dark:text-zinc-200 transition-colors"
        >
          <IconArrowDown size={13} />
        </button>
      )}
    </div>
  )
}
