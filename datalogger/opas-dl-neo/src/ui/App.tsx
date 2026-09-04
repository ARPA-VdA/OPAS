// import { useState } from 'react'
// import reactLogo from './assets/react.svg'
import { useEffect, useState } from 'react'
import './App.css'

// import { Button } from "@/components/ui/button"
// import DashboardPage from "@/components/pages/DashboardPage"
import Page from '@/components/pages/page';
import type { InstrumentValue } from '@/context/InstrumentContext';

function App() {
  // const [count, setCount] = useState(0)
  const [instrumentValues, setInstrumentValues] = useState<InstrumentValue[]>([]);
  
  useEffect(()=>{
    // window.electron.subscribeStatistics((stats) => console.log(stats));
    const unsubscribe = window.electron.subscribeValues((values) => {
      //console.log(values);
      setInstrumentValues(values.map(v => ({
        ...v,
        lastModified: v.lastModified || new Date()
      })));
    });
    return unsubscribe;
  }, []);
  return (
    <Page instrumentValues={instrumentValues} />
  )
}

export default App
