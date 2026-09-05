import { createContext, useCallback, useContext, useEffect, useState, type ReactNode } from 'react';
import { useTranslation } from 'react-i18next';

type DocSection = 'overview' | 'service' | 'ui';

interface DocumentationContextType {
  docs: ServiceDocFile[];
  isLoading: boolean;
  uiDocs: ServiceDocFile[];
  isUiLoading: boolean;
  section: DocSection;
  selectedFile: string | null;
  selectedUiFile: string | null;
  selectSection: (section: DocSection) => void;
  selectFile: (filename: string) => void;
  selectUiFile: (filename: string) => void;
  viewOverview: () => void;
  viewServiceIndex: () => void;
  viewUiIndex: () => void;
}

const DocumentationContext = createContext<DocumentationContextType | undefined>(undefined);

export function indexFilename(docs: ServiceDocFile[]): string | null {
  return docs.find(d => d.filename.toLowerCase() === 'readme.md')?.filename ?? docs[0]?.filename ?? null;
}

// Any Italian-language variant uses the Italian doc set; everything else falls back to English.
function docsLangFor(i18nLanguage: string): 'it' | 'en' {
  return i18nLanguage?.startsWith('it') ? 'it' : 'en';
}

export function DocumentationProvider({ children }: { children: ReactNode }) {
  const { i18n } = useTranslation();
  const [docs, setDocs] = useState<ServiceDocFile[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [selectedFile, setSelectedFile] = useState<string | null>(null);

  const [uiDocs, setUiDocs] = useState<ServiceDocFile[]>([]);
  const [isUiLoading, setIsUiLoading] = useState(true);
  const [selectedUiFile, setSelectedUiFile] = useState<string | null>(null);

  const [section, setSection] = useState<DocSection>('overview');

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

  useEffect(() => {
    let cancelled = false;
    setIsUiLoading(true);
    window.electron.getUiDocs(docsLangFor(i18n.language)).then((result) => {
      if (cancelled) return;
      setUiDocs(result);
      setSelectedUiFile((prev) => prev && result.some(d => d.filename === prev) ? prev : indexFilename(result));
      setIsUiLoading(false);
    });
    return () => { cancelled = true };
  }, [i18n.language]);

  const selectFile = useCallback((filename: string) => {
    setSection('service');
    setSelectedFile(filename);
  }, []);

  const selectUiFile = useCallback((filename: string) => {
    setSection('ui');
    setSelectedUiFile(filename);
  }, []);

  const viewOverview = useCallback(() => {
    setSection('overview');
  }, []);

  const viewServiceIndex = useCallback(() => {
    setSection('service');
    setSelectedFile((prev) => indexFilename(docs) ?? prev);
  }, [docs]);

  const viewUiIndex = useCallback(() => {
    setSection('ui');
    setSelectedUiFile((prev) => indexFilename(uiDocs) ?? prev);
  }, [uiDocs]);

  return (
    <DocumentationContext.Provider
      value={{
        docs,
        isLoading,
        uiDocs,
        isUiLoading,
        section,
        selectedFile,
        selectedUiFile,
        selectSection: setSection,
        selectFile,
        selectUiFile,
        viewOverview,
        viewServiceIndex,
        viewUiIndex,
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
