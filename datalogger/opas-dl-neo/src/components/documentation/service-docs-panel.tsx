import { useMemo } from 'react'
import ReactMarkdown from 'react-markdown'
import remarkGfm from 'remark-gfm'
import { cn } from '@/lib/utils'
import { useDocumentation } from '@/context/DocumentationContext'

const EXTERNAL_HREF = /^([a-z][a-z0-9+.-]*:|\/\/)/i

// Doc content links to other files by their plain relative filename (e.g. "architecture.md#config-resolution").
// Those must switch the in-app selection instead of doing a real browser
// navigation - a real navigation reloads the whole SPA (blank/broken in a
// packaged build, a full state reset in dev) since there's no route for it.
function createMarkdownComponents(docs: ServiceDocFile[], selectFile: (filename: string) => void) {
  return {
  h1: (props: React.ComponentProps<'h1'>) => (
    <h1 className="text-xl font-semibold mt-0 mb-3 text-foreground" {...props} />
  ),
  h2: (props: React.ComponentProps<'h2'>) => (
    <h2 className="text-lg font-semibold mt-6 mb-2 text-foreground border-b border-border pb-1" {...props} />
  ),
  h3: (props: React.ComponentProps<'h3'>) => (
    <h3 className="text-base font-semibold mt-4 mb-2 text-foreground" {...props} />
  ),
  p: (props: React.ComponentProps<'p'>) => (
    <p className="text-sm leading-6 text-foreground/90 mb-3 break-words" {...props} />
  ),
  a: ({ href, children, ...props }: React.ComponentProps<'a'>) => {
    const filename = href && !EXTERNAL_HREF.test(href) ? href.split('#')[0].split('/').pop() : undefined
    const target = filename ? docs.find(d => d.filename === filename) : undefined
    if (target) {
      return (
        <a
          href={href}
          className="text-primary underline underline-offset-2 hover:no-underline break-words cursor-pointer"
          onClick={(e) => { e.preventDefault(); selectFile(target.filename) }}
          {...props}
        >
          {children}
        </a>
      )
    }
    return (
      <a
        href={href}
        target="_blank"
        rel="noopener noreferrer"
        className="text-primary underline underline-offset-2 hover:no-underline break-words"
        {...props}
      >
        {children}
      </a>
    )
  },
  ul: (props: React.ComponentProps<'ul'>) => (
    <ul className="list-disc pl-5 text-sm leading-6 mb-3 space-y-1" {...props} />
  ),
  ol: (props: React.ComponentProps<'ol'>) => (
    <ol className="list-decimal pl-5 text-sm leading-6 mb-3 space-y-1" {...props} />
  ),
  li: (props: React.ComponentProps<'li'>) => (
    <li className="text-foreground/90 break-words" {...props} />
  ),
  code: ({ className, children, ...props }: React.ComponentProps<'code'>) => {
    const isBlock = /language-/.test(className || '')
    if (isBlock) {
      return <code className={cn('font-mono text-xs', className)} {...props}>{children}</code>
    }
    return (
      <code className="font-mono text-xs bg-muted px-1 py-0.5 rounded break-words" {...props}>
        {children}
      </code>
    )
  },
  pre: (props: React.ComponentProps<'pre'>) => (
    <pre className="bg-muted rounded-md p-3 overflow-x-auto mb-3 text-xs max-w-full" {...props} />
  ),
  table: (props: React.ComponentProps<'table'>) => (
    <div className="overflow-x-auto mb-3 max-w-full">
      <table className="text-sm border-collapse w-full" {...props} />
    </div>
  ),
  th: (props: React.ComponentProps<'th'>) => (
    <th className="border border-border bg-muted px-2 py-1 text-left font-medium break-words" {...props} />
  ),
  td: (props: React.ComponentProps<'td'>) => (
    <td className="border border-border px-2 py-1 align-top break-words" {...props} />
  ),
  blockquote: (props: React.ComponentProps<'blockquote'>) => (
    <blockquote className="border-l-2 border-border pl-3 italic text-muted-foreground mb-3" {...props} />
  ),
  }
}

export function ServiceDocsPanel() {
  const { docs, isLoading, selectedFile, selectFile } = useDocumentation()
  const markdownComponents = useMemo(() => createMarkdownComponents(docs, selectFile), [docs, selectFile])

  if (isLoading) {
    return <p className="text-muted-foreground text-sm p-4">Caricamento documentazione...</p>
  }

  if (docs.length === 0) {
    return (
      <div className="text-sm text-muted-foreground p-4">
        Nessuna documentazione trovata. Verifica che la cartella <code className="font-mono bg-muted px-1 py-0.5 rounded">docs/</code> esista
        nella cartella del servizio Opas DL configurata in Impostazioni.
      </div>
    )
  }

  const active = docs.find(d => d.filename === selectedFile) ?? docs[0]

  return (
    <div className="h-full min-h-0 overflow-y-auto overflow-x-hidden">
      <ReactMarkdown remarkPlugins={[remarkGfm]} components={markdownComponents}>
        {active.content}
      </ReactMarkdown>
    </div>
  )
}
