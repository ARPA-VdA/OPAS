import { useDocumentation } from '@/context/DocumentationContext'
import { DocsPanel } from './docs-panel'

export function ServiceDocsPanel() {
  const { docs, isLoading, selectedFile, selectFile } = useDocumentation()

  return (
    <DocsPanel
      docs={docs}
      isLoading={isLoading}
      selectedFile={selectedFile}
      selectFile={selectFile}
      emptyMessage={
        <>
          Nessuna documentazione trovata. Verifica che la cartella <code className="font-mono bg-muted px-1 py-0.5 rounded">docs/</code> esista
          nella cartella del servizio Opas DL configurata in Impostazioni.
        </>
      }
    />
  )
}
