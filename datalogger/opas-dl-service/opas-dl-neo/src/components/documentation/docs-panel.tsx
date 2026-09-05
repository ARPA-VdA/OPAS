import { useMemo, type ReactNode } from 'react'
import ReactMarkdown from 'react-markdown'
import remarkGfm from 'remark-gfm'
import { baseMarkdownComponents } from './markdown-components'

const EXTERNAL_HREF = /^([a-z][a-z0-9+.-]*:|\/\/)/i

// Doc content links to other files by their plain relative filename (e.g. "architecture.md#config-resolution").
// Those must switch the in-app selection instead of doing a real browser
// navigation - a real navigation reloads the whole SPA (blank/broken in a
// packaged build, a full state reset in dev) since there's no route for it.
function createMarkdownComponents(docs: ServiceDocFile[], selectFile: (filename: string) => void) {
  return {
    ...baseMarkdownComponents(),
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
  }
}

interface DocsPanelProps {
  docs: ServiceDocFile[]
  isLoading: boolean
  selectedFile: string | null
  selectFile: (filename: string) => void
  emptyMessage: ReactNode
}

// Renders a folder of .md files loaded via IPC (getServiceDocs / getUiDocs):
// loading state, empty state, and the active file with in-app cross-links.
export function DocsPanel({ docs, isLoading, selectedFile, selectFile, emptyMessage }: DocsPanelProps) {
  const markdownComponents = useMemo(() => createMarkdownComponents(docs, selectFile), [docs, selectFile])

  if (isLoading) {
    return <p className="text-muted-foreground text-sm p-4">Caricamento documentazione...</p>
  }

  if (docs.length === 0) {
    return <div className="text-sm text-muted-foreground p-4">{emptyMessage}</div>
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
