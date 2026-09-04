type Statistics = {
    cpuUsage: number;
    cpuModel?: string;
    ramUsage: number;
    ramTotalGB?: number;
    ramUsedGB?: number;
    storageUsage?: number;
    storageTotalGB?: number;
    storageUsedGB?: number;
};

type StaticData = {
    totalStorage: number;
    cpuModel: string;
    totalMemoryGB: number;
    appVersion: string;
    // ms since epoch, captured when the Electron main process module loaded
    // (resourceManager.ts) - an approximation of "when the UI started" good
    // enough for the Sistema page, shown next to the Python service's own
    // start time (see getServiceStartTime).
    uiStartTime: number;
};

type ServiceStartTime = {
    // ms since epoch, or null if the control server couldn't be reached
    // (service_master.py not up yet / crashed) or hasn't set it yet.
    startTime: number | null;
};

type AppConfig = {
    opasDlPath?: string;
    version: string;
    lastModified: string;
    // Max decimals shown for the raw (pre-Formule) instrument value in the
    // instrument UI (readings-section.tsx). Display-only cap, not rounding
    // applied to the stored file_istantanei_raw values.
    rawValueMaxDecimals?: number;
};

type InstrumentValue = {
    id: string;
    value: number;
    lastModified?: number;
    // optional numeric/id coming from filename (e.g. API_100_3 -> sourceId = '3')
    sourceId?: string;
    // true when the instant-reading file reports pCod=128 (missing value):
    // the driver is alive but got no real reading
    isMissing?: boolean;
    // Value as read off the instrument, before Channel["Formule"] is applied
    // (file_istantanei_raw). Undefined when no raw value is available (e.g.
    // an older service build without this file).
    rawValue?: number;
};

type OpasChannel = {
    id: number;
    name: string;
    active: boolean;
    position: number;
    type: number;           // 0 = parametro, 1 = diagnostico
    unit: string;
    decimals: number;
    storeCsv: boolean;
    algorithm: number;
    formule: string;
    meanInterval: number;
    readingsMinPercentage: number;
    dataArrayIdx: number;
    address: string | null;
    regularExpression: string | null;
    databaseId: number;
    parameterId: number;
    detectionLimit: number | null;
    allowedMinValue: number | null;
    allowedMaxValue: number | null;
    allowedMinMean: number | null;
    negativeValueSetToZero: boolean | null;
    dataType: number;
    dataFormule: string | null;
    registerId: number;
    parameterNote: string | null;
    addressCalibration: number | null;
    registerFunctionCode: number | null;
    registerOrder: number | null;
    registerType: number | null;
    registerQuantity: number | null;
};

type OpasModule = {
    id: number;
    moduleType: number;
    comunicationType: number;
    active: boolean;
    status: number;
    name: string;
    info: string;
    pollingInterval: number;
    pollingDiagsEveryX: number;
    pollingLastTime: number;
    temporary: boolean;
    address: string;
    slot: unknown;
    position: number;
    timeoutAnswer: number;
    dateTimeShift: number;
    moduleDateAllowdGap: number;
    moduleCheckWarnings?: boolean;
    minutesFrameWindow: boolean[];
    comPortName: string | number;
    comPortBauds: number;
    comPortParity: number;
    comPortDataBits: number;
    comPortStopBits: number;
    tcpipAddress: string;
    tcpipPort: number;
    tcpipForceOpenPort: boolean;
    pipeFileName: string;
    pipeFileMissingError: boolean;
    /** Per-module log level override; null = inherit the station-wide default (see getLogLevel/setLogLevel). */
    logLevel: string | null;
    channels: OpasChannel[];
    moduleCommands: unknown[];
    inCalibration: boolean;
    moduleCommand: unknown;
    currentCalibrationStatus: number;
    currentCalibrationCommand: number;
};

type OpasConfigData = {
    name: string;
    stationLocation: string;
    stationLatitude: number;
    stationLongitude: number;
    stationAltitude: number;
    configLastUpdate: string;
    dataFileHeader: string;
    generateReadingsFile: boolean;
    generateZipDataFile: boolean;
    dataFileFormat: number;
    modules: OpasModule[];
    moduleAdamCalibrations: unknown;
    generatePipeFiles: boolean;
    stationAlarm: number;
    minimunFreeDiskSpace: number;
    calculateSpanDeltaZero: boolean;
};

type OpasModuleConfig = {
    ID: number;
    Name: string;
    ModuleType: number;
    Active: boolean;
};

type InstrumentChannel = {
    name: string;
    value: number | null;
    // Value as read off the instrument, before Channel["Formule"] is applied
    // (file_istantanei_raw). Null when no raw value is available.
    rawValue?: number | null;
};

type InstrumentReading = {
    sourceId: string;
    timestamp: string | null;
    channels: InstrumentChannel[];
};

// 'raw' = files_letture_csv (every reading), 'hourly' = files_medie_csv (hourly
// rollup, timestamp = start of the hour it summarizes).
type HistoryKind = 'raw' | 'hourly';

type HistoryPoint = {
    timestamp: string;
    value: number | null;
    // hourly kind only, decoded from files_medie_csv's pCod bit flags.
    isMissing?: boolean;
};

type HistoryRequest = {
    seriesId: string;
    channelName: string;
    kind: HistoryKind;
    fromDate: string;
    toDate: string;
};

type HistoryResult = {
    seriesId: string;
    channelName: string;
    kind: HistoryKind;
    points: HistoryPoint[];
    error?: string;
};

type OpasData = Record<string, unknown>;

type OpasConfig = Record<string, unknown>;

type OpasConfigWithFile = {
    data: OpasConfig;
    fileName: string;
} | null;

type DriverConnection = {
    type: 'TCP/IP' | 'Serial' | 'UDP' | 'PipeFile' | 'Modbus Seriale' | 'Modbus Ethernet' | 'HTTP' | null;
    host: string | null;
    port: number | null;
    baudRate: number | null;
};

type DriverInfo = {
    id: string;
    name: string;
    alive: boolean;
    pid: number | null;
    model: string | null;
    brand: string | null;
    driverVersion: string | null;
    connection: DriverConnection | null;
    startTime: string | null;
    uptimeSeconds: number | null;
    driverFile: string | null;
    // set when this module's COM port is shared with other modules via
    // shared_serial_ports.py's broker (the real COM port name); null otherwise
    sharedComPort: string | null;
    // instrument IDs of the other modules sharing that same port
    sharedWith: string[];
};

type ServiceDocFile = {
    filename: string;
    title: string;
    content: string;
};

type InstrumentTypeInfo = {
    key: string;
    moduleType: number;
    name: string;
    producer: string;
    description: string;
    version: string;
};

type DriverCatalogModuleType = {
    moduleType: number;
    name: string | null;
    producer: string | null;
    description: string | null;
    version: string | null;
};

type DriverCatalogInstrument = {
    id: number | null;
    name: string | null;
};

type DriverCatalogEntry = {
    path: string;
    group: string;
    folderName: string;
    moduleTypes: DriverCatalogModuleType[];
    instruments: DriverCatalogInstrument[];
};

// Una config è sempre in una delle due posizioni: active/ (isActive: true,
// esattamente una) o samples/ (tutte le altre) - vedi opas-dl-service/docs/*/
// architecture.md, sezione "Config file layout".
type ConfigLibraryEntry = {
    filename: string;
    isActive: boolean;
    name: string;
    stationLocation: string;
    dataFileHeader: string;
    configLastUpdate: string;
    moduleCount: number;
};

type ConfigStationFields = Partial<Pick<OpasConfigData,
    'name' | 'stationLocation' | 'stationLatitude' | 'stationLongitude' | 'stationAltitude' | 'dataFileHeader'>>;

type CreateConfigPayload =
    | { mode: 'duplicate'; filename: string; sourceFilename: string; fields?: ConfigStationFields }
    | { mode: 'blank'; filename: string; fields?: ConfigStationFields }
    | { mode: 'import'; filename: string; content: Record<string, unknown> };

type ImportedConfigFile = {
    suggestedFilename: string;
    content: Record<string, unknown>;
};

// channelId is OpasChannel.id (module-scoped), same addressing convention as
// saveOpasChannel(moduleId, channelId, ...) and channelKey() in lib/channelIds.ts -
// not OpasChannel.databaseId, which is only meaningful for instant-file lookups.
type ViewChannelRef = {
    moduleId: number;
    channelId: number;
};

type ViewDisplayMode = 'cards' | 'table';

type ViewEntry = {
    id: string;
    name: string;
    displayMode: ViewDisplayMode;
    channelCount: number;
    lastModified: string;
};

type ViewData = {
    id: string;
    name: string;
    displayMode: ViewDisplayMode;
    channels: ViewChannelRef[];
    lastModified: string;
};

type CreateViewPayload = {
    name: string;
    displayMode: ViewDisplayMode;
    channels: ViewChannelRef[];
};

type EventPayloadMapping = {
    statistics: Statistics;
    getStaticData: StaticData;
    instrumentValues: InstrumentValue[];
    getStation: StationConfig;
    getSettings: AppConfig;
    saveSettings: void;
    getOpasConfig: OpasConfigWithFile;
    getDrivers: Record<string, Omit<DriverInfo, 'id'>> | null;
    getDriverCatalog: DriverCatalogEntry[] | null;
    driverAction: { result: string; pid?: number } | null;
    getServiceStartTime: ServiceStartTime | null;
    getLogLevel: { level: string } | null;
    setLogLevel: { success: boolean; level: string } | null;
    saveOpasChannel: { success: boolean; channel: OpasChannel } | null;
    saveOpasModule: { success: boolean; module: OpasModule } | null;
    getInstrumentTypes: InstrumentTypeInfo[];
    getNewInstrumentDraft: OpasModule | null;
    createOpasModule: { success: boolean; module: OpasModule } | null;
    listConfigLibrary: ConfigLibraryEntry[];
    getConfigByFilename: OpasConfigWithFile;
    createConfig: { success: boolean; filename: string } | null;
    activateConfig: { success: boolean; activeFilename: string } | null;
    importConfigFile: ImportedConfigFile | null;
    exportConfigFile: { success: boolean; canceled?: boolean } | null;
    exportCsv: { success: boolean; canceled?: boolean } | null;
    saveConfigStation: { success: boolean; data: Record<string, unknown> } | null;
    getLogLines: string[];
    openLogFile: void;
    selectFolder: string | null;
    getInstrumentReadings: InstrumentReading[];
    getChannelHistory: HistoryResult[];
    getDriverLogLines: string[];
    getDebugPaths: {
        opasDlPath: string;
        opasDlPathExists: boolean;
        opasConfigDir: string;
        opasConfigDirExists: boolean;
        configFile: string | null;
        configFileExists: boolean;
        configParseError: string | null;
        dataDir: string;
        dataDirExists: boolean;
        instantFilePath: string | null;
        instantFilePathExists: boolean;
        outputPath: string;
        outputPathExists: boolean;
        logPath: string;
        logPathExists: boolean;
        driversPath: string;
        driversPathExists: boolean;
    };
    getServiceDocs: ServiceDocFile[];
    listViews: ViewEntry[];
    getViewById: ViewData | null;
    createView: { success: boolean; id: string } | null;
    updateView: { success: boolean } | null;
    deleteView: { success: boolean } | null;
};

// add data to Window (che esiste già)
interface Window {
    electron: {
        subscribeStatistics: (callback: (statistics: Statistics) => void) => () => void;
        subscribeValues: (callback: (values: InstrumentValue[]) => void) => () => void;
        getStaticData: () => Promise<StaticData>;
        getSettings: () => Promise<AppConfig>;
        saveSettings: (settings: Partial<AppConfig>) => Promise<void>;
        getOpasConfig: () => Promise<OpasConfigWithFile>;
        getDrivers: () => Promise<Record<string, Omit<DriverInfo, 'id'>> | null>;
        getDriverCatalog: () => Promise<DriverCatalogEntry[] | null>;
        driverAction: (driverId: string, action: 'start' | 'stop' | 'restart') => Promise<{ result: string; pid?: number } | null>;
        getServiceStartTime: () => Promise<ServiceStartTime | null>;
        getLogLevel: () => Promise<{ level: string } | null>;
        setLogLevel: (level: string) => Promise<{ success: boolean; level: string } | null>;
        saveOpasChannel: (moduleId: number, channelId: number, patch: Partial<OpasChannel>, configFilename?: string) => Promise<{ success: boolean; channel: OpasChannel } | null>;
        saveOpasModule: (moduleId: number, patch: Partial<OpasModule>, configFilename?: string) => Promise<{ success: boolean; module: OpasModule } | null>;
        getInstrumentTypes: () => Promise<InstrumentTypeInfo[]>;
        getNewInstrumentDraft: (typeKey: string) => Promise<OpasModule | null>;
        createOpasModule: (module: OpasModule, configFilename?: string) => Promise<{ success: boolean; module: OpasModule } | null>;
        listConfigLibrary: () => Promise<ConfigLibraryEntry[]>;
        getConfigByFilename: (filename: string) => Promise<OpasConfigWithFile>;
        createConfig: (payload: CreateConfigPayload) => Promise<{ success: boolean; filename: string } | null>;
        activateConfig: (filename: string) => Promise<{ success: boolean; activeFilename: string } | null>;
        importConfigFile: () => Promise<ImportedConfigFile | null>;
        exportConfigFile: (filename: string) => Promise<{ success: boolean; canceled?: boolean } | null>;
        exportCsv: (defaultFilename: string, content: string) => Promise<{ success: boolean; canceled?: boolean } | null>;
        saveConfigStation: (filename: string, patch: ConfigStationFields) => Promise<{ success: boolean; data: Record<string, unknown> } | null>;
        getLogLines: () => Promise<string[]>;
        openLogFile: () => Promise<void>;
        selectFolder: () => Promise<string | null>;
        getInstrumentReadings: (instrumentId: string) => Promise<InstrumentReading[]>;
        getChannelHistory: (requests: HistoryRequest[]) => Promise<HistoryResult[]>;
        getDriverLogLines: (driverId: string) => Promise<string[]>;
        getDebugPaths: () => Promise<EventPayloadMapping['getDebugPaths']>;
        getServiceDocs: (lang: string) => Promise<ServiceDocFile[]>;
        listViews: () => Promise<ViewEntry[]>;
        getViewById: (id: string) => Promise<ViewData | null>;
        createView: (payload: CreateViewPayload) => Promise<{ success: boolean; id: string } | null>;
        updateView: (id: string, patch: Partial<CreateViewPayload>) => Promise<{ success: boolean } | null>;
        deleteView: (id: string) => Promise<{ success: boolean } | null>;
    }
}