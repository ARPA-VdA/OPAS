import { createContext, useCallback, useContext, useEffect, useState, type ReactNode } from 'react';

interface ViewsContextType {
  views: ViewEntry[];
  isLoading: boolean;
  selectedId: string | null;
  selectView: (id: string | null) => void;
  refresh: () => void;
}

const ViewsContext = createContext<ViewsContextType | undefined>(undefined);

export function ViewsProvider({ children }: { children: ReactNode }) {
  const [views, setViews] = useState<ViewEntry[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [selectedId, setSelectedId] = useState<string | null>(null);

  const load = useCallback(() => {
    setIsLoading(true);
    window.electron.listViews().then((result) => {
      setViews(result);
      setIsLoading(false);
    });
  }, []);

  useEffect(() => {
    load();
    // Dispatched by create/rename/delete flows (see create-view-dialog.tsx,
    // view-detail.tsx) - same cross-component refresh signal already used
    // for OPAS configs ('opas-config-saved').
    window.addEventListener('views-saved', load);
    return () => window.removeEventListener('views-saved', load);
  }, [load]);

  return (
    <ViewsContext.Provider value={{ views, isLoading, selectedId, selectView: setSelectedId, refresh: load }}>
      {children}
    </ViewsContext.Provider>
  );
}

export function useViews(): ViewsContextType {
  const ctx = useContext(ViewsContext);
  if (!ctx) throw new Error('useViews must be used within a ViewsProvider');
  return ctx;
}
