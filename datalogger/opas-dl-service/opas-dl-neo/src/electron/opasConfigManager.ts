import fs from 'fs';
import path from 'path';
import { getOpasConfigPath, getOpasConfigSamplesPath, getDriversDictPath } from './pathResolver.js';

export type OpasChannel = {
    id: number;
    name: string;
    active: boolean;
    position: number;
    type: number;
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

// Tipo per un singolo modulo
export type OpasModule = {
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

// Tipo principale per la configurazione Opas
export type OpasConfigData = {
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

export type OpasConfigWithFile = {
    data: OpasConfigData;
    fileName: string;
} | null;

function getPreferredConfigFile(files: string[]): string | null {
    return files.length > 0 ? files[0] : null;
}

// Mapping raw PascalCase (config file) -> camelCase (TypeScript), condiviso da
// getOpasConfig() e da getNewInstrumentDraft() (che costruisce un modulo "finto"
// a partire da drivers_dict.json e deve passare per la stessa normalizzazione).
export function rawToOpasChannel(c: any): OpasChannel {
    return {
        id: Number(c.ID ?? 0),
        name: String(c.Name ?? ''),
        active: Boolean(c.Active ?? false),
        position: Number(c.Position ?? 0),
        type: Number(c.Type ?? 0),
        unit: String(c.Unit ?? ''),
        decimals: Number(c.Decimals ?? 0),
        storeCsv: Boolean(c.StoreCsv ?? false),
        algorithm: Number(c.Algorithm ?? 0),
        formule: String(c.Formule ?? ''),
        meanInterval: Number(c.MeanInterval ?? 0),
        readingsMinPercentage: Number(c.ReadingsMinPercentage ?? 0),
        dataArrayIdx: Number(c.DataArrayIdx ?? 0),
        address: c.Address != null ? String(c.Address) : null,
        regularExpression: c.RegularExpression != null && c.RegularExpression !== '' ? String(c.RegularExpression) : null,
        databaseId: Number(c.DatabaseId ?? 0),
        parameterId: Number(c.ParameterId ?? 0),
        detectionLimit: c.DetectionLimit != null ? Number(c.DetectionLimit) : null,
        allowedMinValue: c.AllowedMinValue != null ? Number(c.AllowedMinValue) : null,
        allowedMaxValue: c.AllowedMaxValue != null ? Number(c.AllowedMaxValue) : null,
        allowedMinMean: c.AllowedMinMean != null ? Number(c.AllowedMinMean) : null,
        negativeValueSetToZero: c.NegativeValueSetToZero != null ? Boolean(c.NegativeValueSetToZero) : null,
        dataType: Number(c.DataType ?? 0),
        dataFormule: c.DataFormule != null ? String(c.DataFormule) : null,
        registerId: Number(c.RegisterId ?? 0),
        parameterNote: c.ParameterNote != null ? String(c.ParameterNote) : null,
        addressCalibration: c.AddressCalibration != null ? Number(c.AddressCalibration) : null,
        registerFunctionCode: c.RegisterFunctionCode != null ? Number(c.RegisterFunctionCode) : null,
        registerOrder: c.RegisterOrder != null ? Number(c.RegisterOrder) : null,
        registerType: c.RegisterType != null ? Number(c.RegisterType) : null,
        registerQuantity: c.RegisterQuantity != null ? Number(c.RegisterQuantity) : null,
    };
}

export function rawToOpasModule(m: any): OpasModule {
    return {
        id: Number(m.ID ?? 0),
        moduleType: Number(m.ModuleType ?? 0),
        comunicationType: Number(m.ComunicationType ?? 0),
        active: Boolean(m.Active ?? false),
        status: Number(m.Status ?? 0),
        name: String(m.Name ?? ''),
        info: String(m.Info ?? ''),
        pollingInterval: Number(m.PollingInterval ?? 0),
        pollingDiagsEveryX: Number(m.PollingDiagsEveryX ?? 0),
        pollingLastTime: Number(m.PollingLastTime ?? 0),
        temporary: Boolean(m.Temporary ?? false),
        address: String(m.Address ?? ''),
        slot: m.Slot ?? null,
        position: Number(m.Position ?? 0),
        timeoutAnswer: Number(m.TimeoutAnswer ?? 0),
        dateTimeShift: Number(m.DateTimeShift ?? 0),
        moduleDateAllowdGap: Number(m.ModuleDateAllowdGap ?? 0),
        moduleCheckWarnings: m.ModuleCheckWarnings !== undefined ? Boolean(m.ModuleCheckWarnings) : undefined,
        minutesFrameWindow: Array.isArray(m.MinutesFrameWindow) ? m.MinutesFrameWindow.map((v: any) => Boolean(v)) : [],
        comPortName: typeof m.ComPortName === 'number' ? m.ComPortName : String(m.ComPortName ?? ''),
        comPortBauds: Number(m.ComPortBauds ?? 0),
        comPortParity: Number(m.ComPortParity ?? 0),
        comPortDataBits: Number(m.ComPortDataBits ?? 0),
        comPortStopBits: Number(m.ComPortStopBits ?? 0),
        tcpipAddress: String(m.TCPIPAddress ?? ''),
        tcpipPort: Number(m.TCPIPPort ?? 0),
        tcpipForceOpenPort: Boolean(m.TCPIPForceOpenPort ?? false),
        pipeFileName: String(m.PipeFileName ?? ''),
        pipeFileMissingError: Boolean(m.PipeFileMissingError ?? false),
        logLevel: m.LogLevel ?? null,
        channels: Array.isArray(m.Channels) ? m.Channels.map(rawToOpasChannel) : [],
        moduleCommands: Array.isArray(m.ModuleCommands) ? m.ModuleCommands : [],
        inCalibration: Boolean(m.InCalibration ?? false),
        moduleCommand: m.ModuleCommand ?? null,
        currentCalibrationStatus: Number(m.CurrentCalibrationStatus ?? 0),
        currentCalibrationCommand: Number(m.CurrentCalibrationCommand ?? 0),
    };
}

// Parsing/mapping condiviso da getOpasConfig() (config attiva) e dalle funzioni
// di libreria sotto (config in samples/) - un solo punto che traduce il JSON
// grezzo PascalCase nel tipo OpasConfigData.
function readConfigFile(fullPath: string): OpasConfigData | null {
    try {
        const content = fs.readFileSync(fullPath, 'utf-8').replace(/^﻿/, '');
        const parsed = JSON.parse(content);

        return {
            name: String(parsed.Name ?? ''),
            stationLocation: String(parsed.StationLocation ?? ''),
            stationLatitude: Number(parsed.StationLatitude ?? 0),
            stationLongitude: Number(parsed.StationLongitude ?? 0),
            stationAltitude: Number(parsed.StationAltitude ?? 0),
            configLastUpdate: String(parsed.ConfigLastUpdate ?? ''),
            dataFileHeader: String(parsed.DataFileHeader ?? ''),
            generateReadingsFile: Boolean(parsed.GenerateReadingsFile ?? false),
            generateZipDataFile: Boolean(parsed.GenerateZipDataFile ?? false),
            dataFileFormat: Number(parsed.DataFileFormat ?? 0),
            modules: Array.isArray(parsed.Modules) ? parsed.Modules.map(rawToOpasModule) : [],
            moduleAdamCalibrations: parsed.ModuleAdamCalibrations ?? null,
            generatePipeFiles: Boolean(parsed.GeneratePipeFiles ?? false),
            stationAlarm: Number(parsed.StationAlarm ?? 0),
            minimunFreeDiskSpace: Number(parsed.MinimunFreeDiskSpace ?? 0),
            calculateSpanDeltaZero: Boolean(parsed.CalculateSpanDeltaZero ?? false),
        };
    } catch (err) {
        console.error('[OpasConfig] Error reading config file:', fullPath, err);
        return null;
    }
}

export function getOpasConfig(): OpasConfigWithFile {
    try {
        const configDir = getOpasConfigPath();
        if (!configDir || !fs.existsSync(configDir)) {
            return null;
        }

        const jsonFiles = fs
            .readdirSync(configDir)
            .filter(file => file.toLowerCase().endsWith('.json'));
        const fileName = getPreferredConfigFile(jsonFiles);

        if (!fileName) {
            return null;
        }

        const data = readConfigFile(path.join(configDir, fileName));
        return data ? { data, fileName } : null;
    } catch (err) {
        console.error('[OpasConfig] Error reading config JSON:', err);
        return null;
    }
}

// ── Libreria configurazioni (pagina Configurazioni): una sola attiva in
// active/, tutte le altre in samples/ - vedi opas-dl-service/docs/*/
// architecture.md, sezione "Config file layout". Sola lettura via filesystem,
// come getOpasConfig() sopra: solo le scritture passano dal control server
// (vedi createConfig/activateConfig più sotto, e i corrispondenti IPC in
// main.ts).

export type ConfigLibraryEntry = {
    filename: string;
    isActive: boolean;
    name: string;
    stationLocation: string;
    dataFileHeader: string;
    configLastUpdate: string;
    moduleCount: number;
};

// Rifiuta nomi con separatori di percorso, cosi' un filename proveniente
// dall'IPC non puo' far uscire una lettura dalla cartella active/samples
// prevista (stesso controllo lato server in control_server.py).
function isSafeConfigFilename(filename: string): boolean {
    return filename.length > 0 && path.basename(filename) === filename;
}

function describeConfigFile(fullPath: string, filename: string, isActive: boolean): ConfigLibraryEntry | null {
    const data = readConfigFile(fullPath);
    if (!data) return null;
    return {
        filename,
        isActive,
        name: data.name,
        stationLocation: data.stationLocation,
        dataFileHeader: data.dataFileHeader,
        configLastUpdate: data.configLastUpdate,
        moduleCount: data.modules.length,
    };
}

export function listConfigLibrary(): ConfigLibraryEntry[] {
    const entries: ConfigLibraryEntry[] = [];

    try {
        const activeDir = getOpasConfigPath();
        if (activeDir && fs.existsSync(activeDir)) {
            const jsonFiles = fs.readdirSync(activeDir).filter(f => f.toLowerCase().endsWith('.json'));
            const activeFileName = getPreferredConfigFile(jsonFiles);
            if (activeFileName) {
                const entry = describeConfigFile(path.join(activeDir, activeFileName), activeFileName, true);
                if (entry) entries.push(entry);
            }
        }
    } catch (err) {
        console.error('[OpasConfig] Error reading active config for library listing:', err);
    }

    try {
        const samplesDir = getOpasConfigSamplesPath();
        if (samplesDir && fs.existsSync(samplesDir)) {
            const jsonFiles = fs.readdirSync(samplesDir).filter(f => f.toLowerCase().endsWith('.json')).sort();
            for (const filename of jsonFiles) {
                const entry = describeConfigFile(path.join(samplesDir, filename), filename, false);
                if (entry) entries.push(entry);
            }
        }
    } catch (err) {
        console.error('[OpasConfig] Error reading samples library:', err);
    }

    return entries;
}

// Stessa logica di lookup di getConfigByFilename sotto (attiva prima, poi
// samples), ma restituisce il percorso su disco invece del contenuto
// mappato - usato per esportare il file grezzo così com'è (vedi
// exportConfigFile in main.ts).
export function resolveConfigFilePath(filename: string): string | null {
    if (!isSafeConfigFilename(filename)) return null;

    const activeDir = getOpasConfigPath();
    if (activeDir) {
        const activePath = path.join(activeDir, filename);
        if (fs.existsSync(activePath)) return activePath;
    }

    const samplesDir = getOpasConfigSamplesPath();
    if (samplesDir) {
        const samplesPath = path.join(samplesDir, filename);
        if (fs.existsSync(samplesPath)) return samplesPath;
    }

    return null;
}

export function getConfigByFilename(filename: string): OpasConfigWithFile {
    try {
        const fullPath = resolveConfigFilePath(filename);
        if (!fullPath) return null;
        const data = readConfigFile(fullPath);
        return data ? { data, fileName: filename } : null;
    } catch (err) {
        console.error('[OpasConfig] Error reading config by filename:', filename, err);
        return null;
    }
}

// Mapping camelCase (TypeScript) -> PascalCase (file JSON), inverso di quello in getOpasConfig().
// Usato per convertire le modifiche di un canale prima di inviarle al control server,
// che è l'unico a scrivere il file di config.
const CHANNEL_FIELD_MAP: Record<keyof OpasChannel, string> = {
    id: 'ID',
    name: 'Name',
    active: 'Active',
    position: 'Position',
    type: 'Type',
    unit: 'Unit',
    decimals: 'Decimals',
    storeCsv: 'StoreCsv',
    algorithm: 'Algorithm',
    formule: 'Formule',
    meanInterval: 'MeanInterval',
    readingsMinPercentage: 'ReadingsMinPercentage',
    dataArrayIdx: 'DataArrayIdx',
    address: 'Address',
    regularExpression: 'RegularExpression',
    databaseId: 'DatabaseId',
    parameterId: 'ParameterId',
    detectionLimit: 'DetectionLimit',
    allowedMinValue: 'AllowedMinValue',
    allowedMaxValue: 'AllowedMaxValue',
    allowedMinMean: 'AllowedMinMean',
    negativeValueSetToZero: 'NegativeValueSetToZero',
    dataType: 'DataType',
    dataFormule: 'DataFormule',
    registerId: 'RegisterId',
    parameterNote: 'ParameterNote',
    addressCalibration: 'AddressCalibration',
    registerFunctionCode: 'RegisterFunctionCode',
    registerOrder: 'RegisterOrder',
    registerType: 'RegisterType',
    registerQuantity: 'RegisterQuantity',
};

export function channelPatchToRaw(patch: Partial<OpasChannel>): Record<string, unknown> {
    const raw: Record<string, unknown> = {};
    for (const [key, value] of Object.entries(patch)) {
        const rawKey = CHANNEL_FIELD_MAP[key as keyof OpasChannel];
        if (rawKey) raw[rawKey] = value;
    }
    return raw;
}

// Sottoinsieme editabile di OpasModule esposto dal dialog "Modulo": informazioni
// identificative, polling e parametri di comunicazione. Channels/comandi/calibrazione
// restano gestiti altrove (Channels ha il proprio dialog dedicato).
const MODULE_FIELD_MAP: Partial<Record<keyof OpasModule, string>> = {
    id: 'ID',
    name: 'Name',
    active: 'Active',
    moduleType: 'ModuleType',
    position: 'Position',
    temporary: 'Temporary',
    info: 'Info',
    pollingInterval: 'PollingInterval',
    pollingDiagsEveryX: 'PollingDiagsEveryX',
    timeoutAnswer: 'TimeoutAnswer',
    comunicationType: 'ComunicationType',
    address: 'Address',
    comPortName: 'ComPortName',
    comPortBauds: 'ComPortBauds',
    comPortParity: 'ComPortParity',
    comPortDataBits: 'ComPortDataBits',
    comPortStopBits: 'ComPortStopBits',
    tcpipAddress: 'TCPIPAddress',
    tcpipPort: 'TCPIPPort',
    tcpipForceOpenPort: 'TCPIPForceOpenPort',
    pipeFileName: 'PipeFileName',
    pipeFileMissingError: 'PipeFileMissingError',
    logLevel: 'LogLevel',
};

export function modulePatchToRaw(patch: Partial<OpasModule>): Record<string, unknown> {
    const raw: Record<string, unknown> = {};
    for (const [key, value] of Object.entries(patch)) {
        const rawKey = MODULE_FIELD_MAP[key as keyof OpasModule];
        if (rawKey) raw[rawKey] = value;
    }
    return raw;
}

// Mapping completo (a differenza di MODULE_FIELD_MAP, che copre solo il
// sottoinsieme editabile dal dialog) usato per creare un modulo ex novo: il
// control server non ha un valore precedente da cui fare il merge, quindi
// serve scrivere tutti i campi, non solo quelli patchabili da UI.
const FULL_MODULE_FIELD_MAP: Record<Exclude<keyof OpasModule, 'channels'>, string> = {
    id: 'ID',
    moduleType: 'ModuleType',
    comunicationType: 'ComunicationType',
    active: 'Active',
    status: 'Status',
    name: 'Name',
    info: 'Info',
    pollingInterval: 'PollingInterval',
    pollingDiagsEveryX: 'PollingDiagsEveryX',
    pollingLastTime: 'PollingLastTime',
    temporary: 'Temporary',
    address: 'Address',
    slot: 'Slot',
    position: 'Position',
    timeoutAnswer: 'TimeoutAnswer',
    dateTimeShift: 'DateTimeShift',
    moduleDateAllowdGap: 'ModuleDateAllowdGap',
    moduleCheckWarnings: 'ModuleCheckWarnings',
    minutesFrameWindow: 'MinutesFrameWindow',
    comPortName: 'ComPortName',
    comPortBauds: 'ComPortBauds',
    comPortParity: 'ComPortParity',
    comPortDataBits: 'ComPortDataBits',
    comPortStopBits: 'ComPortStopBits',
    tcpipAddress: 'TCPIPAddress',
    tcpipPort: 'TCPIPPort',
    tcpipForceOpenPort: 'TCPIPForceOpenPort',
    pipeFileName: 'PipeFileName',
    pipeFileMissingError: 'PipeFileMissingError',
    logLevel: 'LogLevel',
    moduleCommands: 'ModuleCommands',
    inCalibration: 'InCalibration',
    moduleCommand: 'ModuleCommand',
    currentCalibrationStatus: 'CurrentCalibrationStatus',
    currentCalibrationCommand: 'CurrentCalibrationCommand',
};

export function moduleToRawForCreate(module: OpasModule): Record<string, unknown> {
    const raw: Record<string, unknown> = {};
    for (const [key, rawKey] of Object.entries(FULL_MODULE_FIELD_MAP)) {
        raw[rawKey] = (module as any)[key] ?? null;
    }
    raw.Channels = module.channels.map(ch => channelPatchToRaw(ch));
    return raw;
}

// Mapping camelCase -> PascalCase per i soli campi di stazione modificabili da
// "Aggiungi configurazione" (duplica/vuota) - inverso parziale di quello usato
// in readConfigFile(). Analogo a CHANNEL_FIELD_MAP/MODULE_FIELD_MAP sopra: la
// UI lavora sempre in camelCase, solo qui si torna alle chiavi grezze del file.
const STATION_FIELD_MAP: Record<keyof ConfigStationFields, string> = {
    name: 'Name',
    stationLocation: 'StationLocation',
    stationLatitude: 'StationLatitude',
    stationLongitude: 'StationLongitude',
    stationAltitude: 'StationAltitude',
    dataFileHeader: 'DataFileHeader',
};

export function stationFieldsToRaw(fields: ConfigStationFields): Record<string, unknown> {
    const raw: Record<string, unknown> = {};
    for (const [key, value] of Object.entries(fields)) {
        const rawKey = STATION_FIELD_MAP[key as keyof ConfigStationFields];
        if (rawKey) raw[rawKey] = value;
    }
    return raw;
}

// ── Catalogo tipi strumento (drivers_dict.json) e bozza per "Aggiungi strumento" ──

export type InstrumentTypeInfo = {
    key: string;
    moduleType: number;
    name: string;
    producer: string;
    description: string;
    version: string;
};

function readDriversDict(): Record<string, any> | null {
    try {
        const filePath = getDriversDictPath();
        if (!filePath || !fs.existsSync(filePath)) return null;
        const content = fs.readFileSync(filePath, 'utf-8').replace(/^﻿/, '');
        return JSON.parse(content);
    } catch (err) {
        console.error('[OpasConfig] Error reading drivers_dict.json:', err);
        return null;
    }
}

export function getInstrumentTypes(): InstrumentTypeInfo[] {
    const dict = readDriversDict();
    if (!dict) return [];
    return Object.entries(dict)
        .filter(([key]) => key !== 'FullConfig')
        .map(([key, entry]: [string, any]) => ({
            key,
            moduleType: Number(key),
            name: String(entry.Name ?? key),
            producer: String(entry.Producer ?? ''),
            description: String(entry.Description ?? ''),
            version: String(entry.Version ?? ''),
        }));
}

// Unisce il template completo FullConfig.Modules[0] (che fa da default per ogni
// campo, incluso un unico canale modello) con il DefaultConfig, spesso parziale
// o vuoto, del tipo strumento scelto. ID/Position/DatabaseId dei canali sono
// placeholder: il control server li riassegna sempre in POST /modules per
// garantirne l'unicità (vedi create_module in control_server.py). Il fallback
// "?? index" sul Position dei canali è necessario perché nessuno dei
// DefaultConfig.Channels parziali imposta un proprio Position: senza, ogni
// canale unito erediterebbe il Position:0 del template ed entrerebbero tutti
// in collisione tra loro.
export function getNewInstrumentDraft(typeKey: string): OpasModule | null {
    const dict = readDriversDict();
    if (!dict) return null;
    const template = dict.FullConfig?.Modules?.[0];
    const entry = dict[typeKey];
    if (!template || !entry) return null;

    const defaultConfig = entry.DefaultConfig ?? {};
    const { Channels: defaultChannels, ...moduleOverrides } = defaultConfig;

    const mergedModuleRaw: Record<string, any> = {
        ...template,
        ...moduleOverrides,
        ModuleType: Number(typeKey),
        Name: moduleOverrides.Name ?? entry.Name ?? template.Name,
        ID: 0,
    };

    const templateChannel = template.Channels?.[0] ?? {};
    const sourceChannels = Array.isArray(defaultChannels) && defaultChannels.length > 0
        ? defaultChannels
        : [templateChannel];

    mergedModuleRaw.Channels = sourceChannels.map((partial: any, index: number) => ({
        ...templateChannel,
        ...partial,
        ID: 0,
        DatabaseId: 0,
        Position: partial.Position ?? index,
    }));

    return rawToOpasModule(mergedModuleRaw);
}
