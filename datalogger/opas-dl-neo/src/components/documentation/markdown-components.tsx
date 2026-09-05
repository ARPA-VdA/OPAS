import { cn } from '@/lib/utils'

// Shared prose styling for markdown-rendered docs (service docs, UI docs, ...).
// Callers add their own `a` renderer on top since link behavior differs per panel.
export function baseMarkdownComponents() {
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
