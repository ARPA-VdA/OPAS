import { useCallback, useEffect, useMemo, useState } from "react"
import { useNavigation } from "@/context/NavigationContext"
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { Tooltip, TooltipContent, TooltipTrigger } from "@/components/ui/tooltip"
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogDescription,
} from "@/components/ui/dialog"
import {
  IconFolder,
  IconCpu,
  IconRefresh,
  IconChevronRight,
  IconAlertTriangle,
} from "@tabler/icons-react"

type TreeNode = {
  name: string
  fullPath: string
  children: TreeNode[]
  entry: DriverCatalogEntry | null
}

function buildTree(catalog: DriverCatalogEntry[]): TreeNode {
  const root: TreeNode = { name: "drivers", fullPath: "", children: [], entry: null }
  for (const entry of catalog) {
    const parts = entry.path.split("/")
    let node = root
    let pathSoFar = ""
    for (let i = 0; i < parts.length; i++) {
      const part = parts[i]
      pathSoFar = pathSoFar ? `${pathSoFar}/${part}` : part
      let child = node.children.find(c => c.name === part)
      if (!child) {
        child = { name: part, fullPath: pathSoFar, children: [], entry: null }
        node.children.push(child)
      }
      node = child
      if (i === parts.length - 1) {
        node.entry = entry
      }
    }
  }
  const sortChildren = (node: TreeNode) => {
    node.children.sort((a, b) => a.name.localeCompare(b.name))
    node.children.forEach(sortChildren)
  }
  sortChildren(root)
  return root
}

type FlatRow = { node: TreeNode; depth: number; isLast: boolean }

function flattenTree(node: TreeNode, depth: number, collapsed: Set<string>, out: FlatRow[]) {
  node.children.forEach((child, i) => {
    out.push({ node: child, depth, isLast: i === node.children.length - 1 })
    if (child.children.length > 0 && !collapsed.has(child.fullPath)) {
      flattenTree(child, depth + 1, collapsed, out)
    }
  })
}

export function DriversContent() {
  const nav = useNavigation()
  const [catalog, setCatalog] = useState<DriverCatalogEntry[] | null>(null)
  const [loading, setLoading] = useState(true)
  const [selected, setSelected] = useState<DriverCatalogEntry | null>(null)
  const [collapsed, setCollapsed] = useState<Set<string>>(new Set())

  const fetchCatalog = useCallback(async () => {
    setLoading(true)
    try {
      const result = await window.electron.getDriverCatalog()
      setCatalog(result)
    } finally {
      setLoading(false)
    }
  }, [])

  useEffect(() => {
    fetchCatalog()
  }, [fetchCatalog])

  // Arriving from another page (e.g. the dashboard driver table) with a specific
  // driver to preselect. Waits for the catalog to load before consuming the
  // one-shot payload, since the target entry is looked up by path.
  useEffect(() => {
    const payload = nav?.payload as { selectDriverPath?: string } | null | undefined
    if (!payload?.selectDriverPath || !catalog) return
    const entry = catalog.find(e => e.path === payload.selectDriverPath)
    if (entry) setSelected(entry)
    nav?.clearPayload()
  }, [nav?.payload, catalog])

  const tree = useMemo(() => buildTree(catalog ?? []), [catalog])
  const rows = useMemo(() => {
    const out: FlatRow[] = []
    flattenTree(tree, 0, collapsed, out)
    return out
  }, [tree, collapsed])

  const driverCount = catalog?.length ?? 0

  const toggleCollapsed = (fullPath: string) => {
    setCollapsed(prev => {
      const next = new Set(prev)
      if (next.has(fullPath)) next.delete(fullPath)
      else next.add(fullPath)
      return next
    })
  }

  return (
    <div className="flex flex-col gap-4 p-4">
      <div className="flex items-center justify-between gap-2 rounded-md border border-border bg-muted/20 px-3 py-2">
        <p className="text-sm text-muted-foreground">
          <code className="rounded bg-muted px-1.5 py-0.5 text-xs font-mono">drivers/</code>
          {" "}del servizio
          {!loading && catalog !== null && (
            <span className="ml-1.5 text-xs">
              · {driverCount} driver{driverCount === 1 ? "" : ""} installat{driverCount === 1 ? "o" : "i"}
            </span>
          )}
        </p>
        <Button variant="outline" size="sm" disabled={loading} onClick={fetchCatalog}>
          <IconRefresh size={16} className={loading ? "animate-spin" : undefined} />
          Aggiorna
        </Button>
      </div>

      {catalog === null && !loading && (
        <div className="flex items-center gap-2 rounded-md border border-destructive/30 bg-destructive/5 px-3 py-2 text-sm text-destructive">
          <IconAlertTriangle size={16} className="shrink-0" />
          Impossibile leggere il catalogo driver: verifica che il servizio Python sia in esecuzione.
        </div>
      )}

      {catalog !== null && catalog.length === 0 && !loading && (
        <p className="text-sm text-muted-foreground">Nessun driver trovato nella cartella drivers/.</p>
      )}

      {catalog !== null && catalog.length > 0 && (
        <div className="rounded-lg border shadow-sm overflow-hidden">
          <Table>
            <TableHeader>
              <TableRow className="hover:bg-transparent">
                <TableHead className="h-9 bg-muted/40 text-xs font-semibold uppercase tracking-wide text-muted-foreground">Nome</TableHead>
                <TableHead className="h-9 bg-muted/40 text-xs font-semibold uppercase tracking-wide text-muted-foreground">Tipi di modulo</TableHead>
                <TableHead className="h-9 bg-muted/40 text-xs font-semibold uppercase tracking-wide text-muted-foreground">Strumenti</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {rows.map(({ node, depth }) => (
                <DirectoryRow
                  key={node.fullPath}
                  node={node}
                  depth={depth}
                  collapsed={collapsed.has(node.fullPath)}
                  onToggleCollapsed={() => toggleCollapsed(node.fullPath)}
                  onSelect={() => node.entry && setSelected(node.entry)}
                />
              ))}
            </TableBody>
          </Table>
        </div>
      )}

      <DriverDetailDialog entry={selected} onClose={() => setSelected(null)} />
    </div>
  )
}

function DirectoryRow({
  node,
  depth,
  collapsed,
  onToggleCollapsed,
  onSelect,
}: {
  node: TreeNode
  depth: number
  collapsed: boolean
  onToggleCollapsed: () => void
  onSelect: () => void
}) {
  const isFolder = node.children.length > 0
  const isOrphan = node.entry !== null && node.entry.moduleTypes.length === 0
  const indent = depth * 22

  return (
    <TableRow
      className={
        isFolder
          ? "cursor-pointer bg-muted/10 hover:bg-muted/30 transition-colors"
          : "cursor-pointer hover:bg-primary/5 transition-colors"
      }
      onClick={isFolder ? onToggleCollapsed : onSelect}
    >
      <TableCell className="py-2">
        <div className="flex items-center gap-2" style={{ paddingLeft: indent }}>
          <IconChevronRight
            size={14}
            className={`shrink-0 text-muted-foreground transition-transform duration-150 ${
              isFolder ? (collapsed ? "" : "rotate-90") : "opacity-0"
            }`}
          />
          {isFolder ? (
            <IconFolder size={16} className="shrink-0 text-amber-500" />
          ) : (
            <IconCpu size={16} className="shrink-0 text-blue-500" />
          )}
          <span className={isFolder ? "text-sm font-semibold" : "text-sm font-medium"}>
            {isFolder ? node.fullPath : node.name}
          </span>
          {isFolder && (
            <span className="text-xs text-muted-foreground">
              ({countDrivers(node)})
            </span>
          )}
          {isOrphan && (
            <Tooltip>
              <TooltipTrigger asChild>
                <IconAlertTriangle size={13} className="shrink-0 text-amber-500" />
              </TooltipTrigger>
              <TooltipContent>Non referenziato in drivers_dict.json</TooltipContent>
            </Tooltip>
          )}
        </div>
      </TableCell>
      <TableCell className="py-2">
        {!isFolder && node.entry && node.entry.moduleTypes.length > 0 && (
          <div className="flex flex-wrap gap-1">
            {node.entry.moduleTypes.map(mt => (
              <Badge key={mt.moduleType} variant="secondary" className="text-xs font-normal px-2.5 py-0.5">
                {mt.name ?? mt.moduleType}
              </Badge>
            ))}
          </div>
        )}
      </TableCell>
      <TableCell className="py-2">
        {!isFolder && node.entry && (
          node.entry.instruments.length === 0 ? (
            <span className="text-xs text-muted-foreground">—</span>
          ) : (
            <Tooltip>
              <TooltipTrigger asChild>
                <Badge variant="outline" className="text-xs font-normal px-2.5 py-0.5 cursor-default">
                  {node.entry.instruments.length} {node.entry.instruments.length === 1 ? "strumento" : "strumenti"}
                </Badge>
              </TooltipTrigger>
              <TooltipContent>
                {node.entry.instruments.map(i => i.name).join(", ")}
              </TooltipContent>
            </Tooltip>
          )
        )}
      </TableCell>
    </TableRow>
  )
}

function countDrivers(node: TreeNode): number {
  let count = node.entry ? 1 : 0
  for (const child of node.children) count += countDrivers(child)
  return count
}

function DriverDetailDialog({ entry, onClose }: { entry: DriverCatalogEntry | null; onClose: () => void }) {
  const nav = useNavigation()

  const goToInstrument = (name: string) => {
    nav?.navigateTo("nav.instruments", { selectInstrumentName: name })
    onClose()
  }

  return (
    <Dialog open={entry !== null} onOpenChange={o => { if (!o) onClose() }}>
      <DialogContent className="sm:max-w-lg">
        {entry && (
          <>
            <DialogHeader>
              <DialogTitle className="flex items-center gap-2">
                <IconCpu size={18} className="text-blue-500 shrink-0" />
                {entry.folderName}
              </DialogTitle>
              <DialogDescription className="font-mono text-xs">{entry.path}</DialogDescription>
            </DialogHeader>

            <div className="space-y-4">
              <div className="space-y-2">
                <p className="text-xs font-semibold text-muted-foreground uppercase tracking-wide">
                  Tipi di modulo supportati
                </p>
                {entry.moduleTypes.length === 0 ? (
                  <p className="text-sm text-muted-foreground">
                    Nessuna voce in drivers_dict.json fa riferimento a questa cartella.
                  </p>
                ) : (
                  <div className="space-y-2">
                    {entry.moduleTypes.map(mt => (
                      <div key={mt.moduleType} className="rounded-md border bg-muted/20 p-2.5 text-sm">
                        <div className="flex items-center justify-between gap-2">
                          <span className="font-medium">{mt.name ?? `ModuleType ${mt.moduleType}`}</span>
                          <Badge variant="outline" className="text-xs font-normal px-2.5 py-0.5">ModuleType {mt.moduleType}</Badge>
                        </div>
                        {mt.producer && <p className="text-xs text-muted-foreground mt-0.5">{mt.producer}</p>}
                        {mt.description && <p className="text-xs text-muted-foreground">{mt.description}</p>}
                        {mt.version && <p className="text-xs text-muted-foreground">v{mt.version}</p>}
                      </div>
                    ))}
                  </div>
                )}
              </div>

              <div className="space-y-2">
                <p className="text-xs font-semibold text-muted-foreground uppercase tracking-wide">
                  Strumenti associati
                </p>
                {entry.instruments.length === 0 ? (
                  <p className="text-sm text-muted-foreground">Nessuno strumento nella config attiva usa questo driver.</p>
                ) : (
                  <ul className="space-y-1">
                    {entry.instruments.map(inst => (
                      <li key={inst.id}>
                        {inst.name ? (
                          <button
                            type="button"
                            onClick={() => goToInstrument(inst.name!)}
                            className="w-full flex items-center gap-1.5 text-sm text-left rounded px-1 -mx-1 py-0.5 hover:bg-muted/50 hover:text-primary transition-colors cursor-pointer"
                          >
                            <span className="size-1.5 rounded-full bg-primary shrink-0" />
                            <span className="flex-1">{inst.name}</span>
                          </button>
                        ) : (
                          <div className="flex items-center gap-1.5 text-sm">
                            <span className="size-1.5 rounded-full bg-primary shrink-0" />
                            {`Strumento ${inst.id}`}
                          </div>
                        )}
                      </li>
                    ))}
                  </ul>
                )}
              </div>
            </div>
          </>
        )}
      </DialogContent>
    </Dialog>
  )
}
