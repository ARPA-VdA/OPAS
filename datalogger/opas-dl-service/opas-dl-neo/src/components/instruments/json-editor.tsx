import { Textarea } from "@/components/ui/textarea"

interface JsonEditorProps {
  value: string
  onChange: (value: string) => void
  error: string | null
  editable: boolean
}

export function JsonEditor({ value, onChange, error, editable }: JsonEditorProps) {
  return (
    <div className="flex flex-col h-full min-h-0">
      <Textarea
        className="font-mono text-xs flex-1 min-h-0 resize-none"
        value={value}
        disabled={!editable}
        onChange={e => onChange(e.target.value)}
      />
      {error && <p className="text-xs text-destructive mt-1 shrink-0">{error}</p>}
    </div>
  )
}
