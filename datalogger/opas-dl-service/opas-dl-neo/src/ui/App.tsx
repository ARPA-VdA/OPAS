import { useEffect, useState } from 'react'
import './App.css'

import Page from '@/components/pages/page';
import { GraphWindowContent } from '@/components/graphs/graph-window-content';
import type { InstrumentValue } from '@/context/InstrumentContext';

// A "detached" graph window (see openGraphsWindow, main.ts) loads this same
// bundle with ?window=graphs&panel=<json> instead of the normal app shell -
// no sidebar/navigation, just the one popped-out graph.
function readGraphsWindowParams(): { isGraphsWindow: boolean; initialState?: any } {
  const params = new URLSearchParams(window.location.search);
  if (params.get('window') !== 'graphs') return { isGraphsWindow: false };
  const raw = params.get('panel');
  return { isGraphsWindow: true, initialState: raw ? JSON.parse(decodeURIComponent(raw)) : undefined };
}

function App() {
  const [instrumentValues, setInstrumentValues] = useState<InstrumentValue[]>([]);

  useEffect(()=>{
    const unsubscribe = window.electron.subscribeValues((values) => {
      setInstrumentValues(values.map(v => ({
        ...v,
        lastModified: v.lastModified || new Date()
      })));
    });
    return unsubscribe;
  }, []);

  const graphsWindow = readGraphsWindowParams();
  if (graphsWindow.isGraphsWindow) {
    return <GraphWindowContent initialState={graphsWindow.initialState} />
  }

  return (
    <Page instrumentValues={instrumentValues} />
  )
}

export default App
