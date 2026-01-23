// import { useState } from 'react'
// import reactLogo from './assets/react.svg'
import './App.css'

// import { Button } from "@/components/ui/button"
import DashboardPage from "@/components/pages/CustomSidebarPage"

function App() {
  // const [count, setCount] = useState(0)
  // @ts-ignore
  window.electron.getStaticData();
  // return (
  //   <>
  //     <div>
  //       <a href="https://react.dev" target="_blank">
  //         <img src={reactLogo} className="logo react" alt="React logo" />
  //       </a>
  //     </div>
  //     <h1>Vite + React</h1>
  //     <div className="card">
  //       <Button onClick={() => setCount((count) => count + 1)}>count is {count}</Button>
  //       <button>
  //         count is {count}
  //       </button>
  //       <p>
  //         Edit <code>src/App.tsx</code> and save to test HMR
  //       </p>
  //     </div>
  //     <p className="read-the-docs">
  //       Click on the Vite and React logos to learn more
  //     </p>
  //   </>
    
  // )
  return (
    <DashboardPage />
  )
}

export default App
