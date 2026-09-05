import osUtils from 'os-utils';
import fs from 'fs';
import os from 'os';
import path from "path";
import { BrowserWindow, app } from 'electron';
import { ipcWebContentsSend } from './utils.js';
import { getOutputPath, getInstantFilePath, getInstantRawFilePath } from './pathResolver.js';
import { getSettings } from './configManager.js';
import { getOpasConfig } from './opasConfigManager.js';

const POLLING_INTERVAL = 1000;

// Captured at module load, i.e. as early as the Electron main process starts
// bringing up its own modules - the closest approximation of "UI start time"
// available without adding a separate timestamp IPC round-trip.
const UI_START_TIME = Date.now();

const METADATA_COLUMNS = new Set(['timestamp', 'instrument_id', 'time', 'date', 'datetime', 'simulation']);

// Mirrors the sanitization applied to module names on the UI side
// (components/pages/contents/main/instruments.tsx) so InstrumentValue.id
// matches what the dashboard looks up.
function sanitizeName(name: string): string {
    return name.replace(/[^A-Za-z0-9_\-]/g, '_').replace(/^_+|_+$/g, '');
}

// file_istantanei/<DataFileHeader>.dat rows: "yyyy-MM-dd HH:mm:ss,channelId,value,pCod"
// (see opas_dl_commons/libs/output_broker.py _write_instant_file). pCod
// 128 = missing value (value column left empty), 0 = valid.
function parseInstantFile(filePath: string): Map<number, { timestamp: string; value: number; pCod: number }> {
    const result = new Map<number, { timestamp: string; value: number; pCod: number }>();
    const content = fs.readFileSync(filePath, 'utf-8');
    const lines = content.split(/\r?\n/).filter(l => l.trim().length > 0);
    for (const line of lines) {
        const parts = line.split(',');
        if (parts.length < 4) continue;
        const [ts, idStr, valueStr, pCodStr] = parts;
        const channelId = parseInt(idStr, 10);
        if (Number.isNaN(channelId)) continue;
        result.set(channelId, {
            timestamp: ts,
            value: valueStr === '' ? NaN : parseFloat(valueStr),
            pCod: parseInt(pCodStr, 10) || 0,
        });
    }
    return result;
}

function parseInstantTimestamp(ts: string): number {
    const parsed = Date.parse(ts.replace(' ', 'T'));
    return Number.isNaN(parsed) ? Date.now() : parsed;
}

// Representative channel shown for a module on the dashboard: the "parametro"
// channel (type 0) with the lowest Position, falling back to the first
// diagnostic channel if the module has no parametro defined.
function pickRepresentativeChannel(channels: OpasChannel[]): OpasChannel | null {
    if (channels.length === 0) return null;
    const parametri = channels.filter(c => c.type === 0);
    const pool = parametri.length > 0 ? parametri : channels;
    return pool.reduce((best, c) => (c.position < best.position ? c : best), pool[0]);
}

function readInstrumentValuesFromInstantFile(instantPath: string, rawInstantPath: string, modules: OpasModule[]): InstrumentValue[] {
    const readings = parseInstantFile(instantPath);
    // Raw companion file may not exist yet (older service build) - absence
    // just means no raw values are available, never an error.
    const rawReadings = fs.existsSync(rawInstantPath) ? parseInstantFile(rawInstantPath) : new Map<number, { timestamp: string; value: number; pCod: number }>();
    const values: InstrumentValue[] = [];

    for (const module of modules) {
        const channel = pickRepresentativeChannel(module.channels);
        const sing_value: InstrumentValue = { id: sanitizeName(module.name), value: NaN };
        if (channel) {
            sing_value.sourceId = String(channel.databaseId);
            const reading = readings.get(channel.databaseId);
            if (reading) {
                sing_value.value = reading.value;
                sing_value.lastModified = parseInstantTimestamp(reading.timestamp);
                sing_value.isMissing = reading.pCod === 128;
            }
            const rawReading = rawReadings.get(channel.databaseId);
            if (rawReading && !Number.isNaN(rawReading.value)) {
                sing_value.rawValue = rawReading.value;
            }
        }
        values.push(sing_value);
    }

    return values;
}

let resourcesInterval: ReturnType<typeof setInterval> | null = null;
let instrumentsInterval: ReturnType<typeof setInterval> | null = null;

export function stopPolling() {
    if (resourcesInterval !== null) { clearInterval(resourcesInterval); resourcesInterval = null; }
    if (instrumentsInterval !== null) { clearInterval(instrumentsInterval); instrumentsInterval = null; }
}

export function pollResources(mainWindow: BrowserWindow) {
    resourcesInterval = setInterval(async () => {
        try {
            const cpuUsage = await getCpuUsage(); // fraction 0..1
            const cpuModel = os.cpus()[0]?.model || '';

            const ramUsage = getRamUsage(); // fraction 0..1
            const totalMemoryBytes = os.totalmem();
            const ramTotalGB = Math.round((totalMemoryBytes / 1_000_000_000) * 10) / 10; // one decimal GB
            const ramUsedGB = Math.round((ramTotalGB * ramUsage) * 10) / 10;

            const storageData = getStorageData(); // { total: GB, usage: fraction }
            const storageTotalGB = storageData.total;
            const storageUsedGB = Math.round((storageTotalGB * storageData.usage) * 10) / 10;

            const payload = {
                cpuUsage,
                cpuModel,
                ramUsage,
                ramTotalGB,
                ramUsedGB,
                storageUsage: storageData.usage,
                storageTotalGB,
                storageUsedGB
            };

            ipcWebContentsSend("statistics", mainWindow.webContents, payload as any);
        } catch (err) {
            console.error('[ResourceManager] Error building/sending statistics:', err);
            // send minimal payload so UI can still handle updates
            try {
                const fallback = { cpuUsage: 0, ramUsage: 0, storageUsage: 0 };
                ipcWebContentsSend("statistics", mainWindow.webContents, fallback as any);
            } catch (e) {
                console.error('[ResourceManager] Failed to send fallback statistics:', e);
            }
        }
    }, POLLING_INTERVAL);
}

export function pollInstrumentsValues(mainWindow: BrowserWindow) {
    instrumentsInterval = setInterval(async () => {
        const values = readInstrumentValues();
        ipcWebContentsSend("instrumentValues", mainWindow.webContents, values);
    }, POLLING_INTERVAL);
}

function readInstrumentValues(): InstrumentValue[] {
    const config = getOpasConfig();
    const dataFileHeader = config?.data?.dataFileHeader;
    if (dataFileHeader) {
        const instantPath = getInstantFilePath(dataFileHeader);
        if (fs.existsSync(instantPath)) {
            try {
                const rawInstantPath = getInstantRawFilePath(dataFileHeader);
                return readInstrumentValuesFromInstantFile(instantPath, rawInstantPath, config!.data.modules);
            } catch (err) {
                console.error(`[ResourceManager] Error reading instant file ${instantPath}:`, err);
            }
        }
    }
    return readInstrumentValuesFromLegacyOutput();
}

function readInstrumentValuesFromLegacyOutput(): InstrumentValue[] {
    const values: InstrumentValue[] = [];
    const outputDir = getOutputPath();
    // Legge tutti i file nella cartella output
    if (fs.existsSync(outputDir)) {
            const files = fs.readdirSync(outputDir);

            for (const file of files) {
                const filePath = path.join(outputDir, file);
                if (file.endsWith(".txt")) {
                    const baseName = path.basename(file, ".txt");
                    // Remove trailing suffixes like _1, _2, or multiple groups (_1_2)
                    const instrumentName = baseName.replace(/(_\d+)+$/, '');
                    const sing_value: InstrumentValue = { id: instrumentName, value: 0 };
                    try {
                        const content = fs.readFileSync(filePath, "utf-8");
                        const firstLine = content.split(/\r?\n/)[0].trim();
                        sing_value.value = parseFloat(firstLine);
                        const stats = fs.statSync(filePath);
                        sing_value.lastModified = stats.mtime.getTime();
                        values.push(sing_value);
                    } catch (err) {
                        console.error(`Errore leggendo ${filePath}:`, err);
                        sing_value.value = NaN;
                    }
                } else if (file.endsWith(".csv")) {
                    const baseName = path.basename(file, ".csv");
                    // Filename format: <instrumentName>_<numericId>
                    const lastUnderscore = baseName.lastIndexOf('_');
                    let instrumentName = baseName;
                    let sourceId: string | undefined;
                    if (lastUnderscore > 0) {
                        instrumentName = baseName.slice(0, lastUnderscore);
                        sourceId = baseName.slice(lastUnderscore + 1);
                    }
                    const sing_value: InstrumentValue = { id: instrumentName, value: 0, sourceId };
                    try {
                        const content = fs.readFileSync(filePath, "utf-8");
                        const lines = content.split(/\r?\n/).filter(l => l.trim().length > 0);
                        if (lines.length === 0) {
                            sing_value.value = NaN;
                        } else {
                            const header = lines[0].split(',').map(h => h.trim());
                            const dataLines = lines.slice(1);
                            const lastLine = dataLines.length > 0 ? dataLines[dataLines.length - 1] : lines[0];
                            const cols = lastLine.split(',').map(c => c.trim());

                            // Prefer a column named SO2 when present
                            let valueIndex = header.findIndex(h => h.toUpperCase() === 'SO2');
                            if (valueIndex === -1) {
                                // fallback to last non-metadata column
                                for (let i = header.length - 1; i >= 0; i--) {
                                    if (!METADATA_COLUMNS.has(header[i].toLowerCase())) {
                                        valueIndex = i;
                                        break;
                                    }
                                }
                            }
                            const raw = cols[valueIndex];
                            sing_value.value = valueIndex === -1 ? NaN : parseFloat(raw);
                        }
                        const stats = fs.statSync(filePath);
                        sing_value.lastModified = stats.mtime.getTime();
                        values.push(sing_value);
                    } catch (err) {
                        console.error(`Errore leggendo ${filePath}:`, err);
                        sing_value.value = NaN;
                    }
                }
            }
    } else {
        console.warn(`[ResourceManager] Output directory does not exist: ${outputDir}`);
    }
    return values;
}

export function getInstrumentReadings(instrumentId: string): InstrumentReading[] {
    const config = getOpasConfig();
    // instrumentId is MergedInstrument.id (instruments.tsx), which is the module's
    // raw, unsanitized name — match on that directly instead of sanitizing the
    // module name first, or every module lookup here fails and silently falls
    // through to the legacy per-driver CSV path below.
    const module = config?.data?.modules.find(m => m.name === instrumentId);
    if (module) {
        return getInstrumentReadingsFromInstantFile(module, config!.data.dataFileHeader);
    }
    return getInstrumentReadingsFromLegacyOutput(instrumentId);
}

// Reads file_istantanei rather than files_letture_csv: the instant file is
// rewritten in full every polling cycle (including a P.COD 128 row with an
// empty value when a channel goes missing), so it's the only source that
// correctly reflects a channel going stale - files_letture_csv is append-only
// and simply stops gaining rows when the value is missing, so its last line
// would just show the last reading forever, however stale.
function getInstrumentReadingsFromInstantFile(module: OpasModule, dataFileHeader: string): InstrumentReading[] {
    if (!dataFileHeader) return [];
    const instantPath = getInstantFilePath(dataFileHeader);
    if (!fs.existsSync(instantPath)) return [];

    const readings = parseInstantFile(instantPath);
    // Raw companion file may not exist yet (older service build) - absence
    // just means no raw values are available, never an error.
    const rawInstantPath = getInstantRawFilePath(dataFileHeader);
    const rawReadings = fs.existsSync(rawInstantPath) ? parseInstantFile(rawInstantPath) : new Map<number, { timestamp: string; value: number; pCod: number }>();
    let latestTimestamp: string | null = null;

    const channels: InstrumentChannel[] = module.channels.map(ch => {
        const reading = readings.get(ch.databaseId);
        const rawReading = rawReadings.get(ch.databaseId);
        const rawValue = rawReading && !Number.isNaN(rawReading.value) ? rawReading.value : null;
        if (!reading) return { name: ch.name, value: null, rawValue };
        if (!latestTimestamp || reading.timestamp > latestTimestamp) latestTimestamp = reading.timestamp;
        return { name: ch.name, value: Number.isNaN(reading.value) ? null : reading.value, rawValue };
    });

    return [{ sourceId: String(module.id), timestamp: latestTimestamp, channels }];
}

function getInstrumentReadingsFromLegacyOutput(instrumentId: string): InstrumentReading[] {
    const outputDir = getOutputPath();
    // Python drivers sanitize the module name the same way: replace non-alphanumeric with '_'
    const safeName = sanitizeName(instrumentId);
    const results: InstrumentReading[] = [];
    if (!fs.existsSync(outputDir)) return results;

    const files = fs.readdirSync(outputDir).filter(f => {
        if (!f.endsWith('.csv')) return false;
        const base = path.basename(f, '.csv');
        const lastUnderscore = base.lastIndexOf('_');
        const name = lastUnderscore > 0 ? base.slice(0, lastUnderscore) : base;
        return name === safeName;
    });

    for (const file of files) {
        const base = path.basename(file, '.csv');
        const lastUnderscore = base.lastIndexOf('_');
        const sourceId = lastUnderscore > 0 ? base.slice(lastUnderscore + 1) : '0';

        try {
            const content = fs.readFileSync(path.join(outputDir, file), 'utf-8');
            const lines = content.split(/\r?\n/).filter(l => l.trim().length > 0);
            if (lines.length < 2) continue;

            const headers = lines[0].split(',').map(h => h.trim());
            const lastRow = lines[lines.length - 1].split(',').map(c => c.trim());

            const timestampIdx = headers.findIndex(h => METADATA_COLUMNS.has(h.toLowerCase()));
            const timestamp = timestampIdx >= 0 ? lastRow[timestampIdx] ?? null : null;

            const channels: InstrumentChannel[] = headers
                .map((name, i) => ({ name, raw: lastRow[i] ?? '' }))
                .filter(({ name }) => !METADATA_COLUMNS.has(name.toLowerCase()))
                .map(({ name, raw }) => ({ name, value: raw !== '' ? parseFloat(raw) : null }));

            results.push({ sourceId, timestamp, channels });
        } catch {
            // skip unreadable files
        }
    }

    return results;
}

export function getStaticData() {
    const totalStorage = getStorageData().total;
    const cpuModel = os.cpus()[0].model;
    const totalMemoryGB = Math.floor(osUtils.totalmem() / 1024);
    // app.getVersion() (not a Vite-build-time constant) so it reflects
    // electron-builder's --config.extraMetadata.version override used by
    // pack_service.py, not the version frozen into package.json at the time
    // `vite build` ran (see opas-dl-service/pack_service.py's docstring).
    const appVersion = app.getVersion();

    return {
        totalStorage,
        cpuModel,
        totalMemoryGB,
        appVersion,
        uiStartTime: UI_START_TIME,
    };
}

function getCpuUsage(): Promise<number> {
    return new Promise(resolve => {
        osUtils.cpuUsage(resolve)
    });
}

function getRamUsage() {
    return 1 - osUtils.freememPercentage();
}

function getStorageData() {
    // Stat the drive/share actually hosting the service's data output
    // (opasDlPath), not just the OS system drive - they can differ (a
    // different drive, or a network share). fs.statfsSync accepts any
    // existing path and returns the filesystem containing it.
    const settings = getSettings();
    const targetPath = (settings.opasDlPath && fs.existsSync(settings.opasDlPath))
        ? settings.opasDlPath
        : (process.platform === 'win32' ? 'C://' : '/');

    const stats = fs.statfsSync(targetPath);
    const total = stats.bsize * stats.blocks;
    const free = stats.bsize * stats.bfree;

    return {
        total: Math.floor(total / 1_000_000_000),
        usage: 1 - free / total
    }
}