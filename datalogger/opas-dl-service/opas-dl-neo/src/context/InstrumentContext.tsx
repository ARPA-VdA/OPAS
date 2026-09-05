import React, { createContext, useContext } from 'react';

export type InstrumentValue = {
  lastModified: any;
  id: string;
  value: number;
  // optional numeric/id coming from filename (e.g. API_100_3 -> sourceId = '3')
  sourceId?: string;
  // true when the reading is missing (pCod=128): driver alive, no real value reported
  isMissing?: boolean;
};

interface InstrumentContextType {
  instrumentValues: InstrumentValue[];
}

const InstrumentContext = createContext<InstrumentContextType | undefined>(undefined);

export interface InstrumentProviderProps {
  children: React.ReactNode;
  instrumentValues: InstrumentValue[];
}

export function InstrumentProvider({ children, instrumentValues }: InstrumentProviderProps) {
  return (
    <InstrumentContext.Provider value={{ instrumentValues }}>
      {children}
    </InstrumentContext.Provider>
  );
}

export function useInstruments() {
  const context = useContext(InstrumentContext);
  if (!context) {
    throw new Error('useInstruments must be used within an InstrumentProvider');
  }
  return context;
}
