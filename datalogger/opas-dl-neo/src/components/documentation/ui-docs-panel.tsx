import { useDocumentation } from '@/context/DocumentationContext'
import { DocsPanel } from './docs-panel'

export function UiDocsPanel() {
  const { uiDocs, isUiLoading, selectedUiFile, selectUiFile } = useDocumentation()

  return (
    <DocsPanel
      docs={uiDocs}
      isLoading={isUiLoading}
      selectedFile={selectedUiFile}
      selectFile={selectUiFile}
      emptyMessage="Documentazione UI non trovata per questa versione dell'app."
    />
  )
}
