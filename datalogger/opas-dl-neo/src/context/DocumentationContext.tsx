import { createContext, useCallback, useContext, useEffect, useState, type ReactNode } from 'react';
import { useTranslation } from 'react-i18next';

type DocSection = 'overview' | 'service' | 'ui';

interface DocumentationContextType {
  docs: ServiceDocFile[];
  isLoading: boolean;
  section: DocSection;
  selectedFile: string | null;
  selectSection: (section: DocSection) => void;
  selectFile: (filename: string) => void;
  viewOverview: () => void;
  viewServiceIndex: () => void;
}

const DocumentationContext = createContext<DocumentationContextType | undefined>(undefined);

export function indexFilename(docs: ServiceDocFile[]): string | null {
  return docs.find(d => d.filename.toLowerCase() === 'readme.md')?.filename ?? docs[0]?.filename ?? null;
}

// it and it_pa (Piedmontese) both use the Italian doc set; everything else falls back to English.
function docsLangFor(i18nLanguage: string): 'it' | 'en' {
  return i18nLanguage?.startsWith('it') ? 'it' : 'en';
}

export function DocumentationProvider({ children }: { children: ReactNode }) {
  const { i18n } = useTranslation();
  const [docs, setDocs] = useState<ServiceDocFile[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [section, setSection] = useState<DocSection>('overview');
  const [selectedFile, setSelectedFile] = useState<string | null>(null);

  useEffect(() => {
    let cancelled = false;
    setIsLoading(true);
    window.electron.getServiceDocs(docsLangFor(i18n.language)).then((result) => {
      if (cancelled) return;
      setDocs(result);
      // Filenames are stable across languages (same set under docs/en/ and docs/it/),
      // so a language switch keeps the current selection instead of resetting it.
      setSelectedFile((prev) => prev && result.some(d => d.filename === prev) ? prev : indexFilename(result));
      setIsLoading(false);
    });
    return () => { cancelled = true };
  }, [i18n.language]);

  const selectFile = useCallback((filename: string) => {
    setSection('service');
    setSelectedFile(filename);
  }, []);

  const viewOverview = useCallback(() => {
    setSection('overview');
  }, []);

  const viewServiceIndex = useCallback(() => {
    setSection('service');
    setSelectedFile((prev) => indexFilename(docs) ?? prev);
  }, [docs]);

  return (
    <DocumentationContext.Provider
      value={{
        docs,
        isLoading,
        section,
        selectedFile,
        selectSection: setSection,
        selectFile,
        viewOverview,
        viewServiceIndex,
      }}
    >
      {children}
    </DocumentationContext.Provider>
  );
}

export function useDocumentation(): DocumentationContextType {
  const ctx = useContext(DocumentationContext);
  if (!ctx) throw new Error('useDocumentation must be used within a DocumentationProvider');
  return ctx;
}
