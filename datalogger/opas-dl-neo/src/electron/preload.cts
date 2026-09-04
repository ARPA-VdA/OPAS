import { contextBridge, ipcRenderer } from "electron";

contextBridge.exposeInMainWorld("electron", {
    subscribeStatistics: (callback: (stats: any) => void) => {
        const wrapped = (_: Electron.IpcRendererEvent, stats: any) => callback(stats);
        ipcRenderer.on("statistics", wrapped);
        return () => ipcRenderer.removeListener("statistics", wrapped);
    },
    subscribeValues: (callback: (values: any) => void) => {
        const wrapped = (_: Electron.IpcRendererEvent, values: any) => callback(values);
        ipcRenderer.on("instrumentValues", wrapped);
        return () => ipcRenderer.removeListener("instrumentValues", wrapped);
    },
    getStaticData: () => ipcRenderer.invoke("getStaticData"),
    getSettings: () => ipcRenderer.invoke("getSettings"),
    saveSettings: (settings: any) => ipcRenderer.invoke("saveSettings", settings),
    getOpasConfig: () => ipcRenderer.invoke("getOpasConfig"),
    getDrivers: () => ipcRenderer.invoke("getDrivers"),
    getDriverCatalog: () => ipcRenderer.invoke("getDriverCatalog"),
    driverAction: (driverId: string, action: string) => ipcRenderer.invoke("driverAction", driverId, action),
    getServiceStartTime: () => ipcRenderer.invoke("getServiceStartTime"),
    getLogLevel: () => ipcRenderer.invoke("getLogLevel"),
    setLogLevel: (level: string) => ipcRenderer.invoke("setLogLevel", level),
    saveOpasChannel: (moduleId: number, channelId: number, patch: any, configFilename?: string) => ipcRenderer.invoke("saveOpasChannel", moduleId, channelId, patch, configFilename),
    saveOpasModule: (moduleId: number, patch: any, configFilename?: string) => ipcRenderer.invoke("saveOpasModule", moduleId, patch, configFilename),
    getInstrumentTypes: () => ipcRenderer.invoke("getInstrumentTypes"),
    getNewInstrumentDraft: (typeKey: string) => ipcRenderer.invoke("getNewInstrumentDraft", typeKey),
    createOpasModule: (module: any, configFilename?: string) => ipcRenderer.invoke("createOpasModule", module, configFilename),
    listConfigLibrary: () => ipcRenderer.invoke("listConfigLibrary"),
    getConfigByFilename: (filename: string) => ipcRenderer.invoke("getConfigByFilename", filename),
    listViews: () => ipcRenderer.invoke("listViews"),
    getViewById: (id: string) => ipcRenderer.invoke("getViewById", id),
    createView: (payload: any) => ipcRenderer.invoke("createView", payload),
    updateView: (id: string, patch: any) => ipcRenderer.invoke("updateView", id, patch),
    deleteView: (id: string) => ipcRenderer.invoke("deleteView", id),
    createConfig: (payload: any) => ipcRenderer.invoke("createConfig", payload),
    activateConfig: (filename: string) => ipcRenderer.invoke("activateConfig", filename),
    saveConfigStation: (filename: string, patch: any) => ipcRenderer.invoke("saveConfigStation", filename, patch),
    importConfigFile: () => ipcRenderer.invoke("importConfigFile"),
    exportConfigFile: (filename: string) => ipcRenderer.invoke("exportConfigFile", filename),
    exportCsv: (defaultFilename: string, content: string) => ipcRenderer.invoke("exportCsv", defaultFilename, content),
    getLogLines: () => ipcRenderer.invoke("getLogLines"),
    openLogFile: () => ipcRenderer.invoke("openLogFile"),
    selectFolder: () => ipcRenderer.invoke("selectFolder"),
    getInstrumentReadings: (instrumentId: string) => ipcRenderer.invoke("getInstrumentReadings", instrumentId),
    getChannelHistory: (requests: any) => ipcRenderer.invoke("getChannelHistory", requests),
    getDriverLogLines: (driverId: string) => ipcRenderer.invoke("getDriverLogLines", driverId),
    getDebugPaths: () => ipcRenderer.invoke("getDebugPaths"),
    getServiceDocs: (lang: string) => ipcRenderer.invoke("getServiceDocs", lang)
} satisfies Window['electron']);