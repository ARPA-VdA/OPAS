import { app, BrowserWindow, dialog, ipcMain, shell } from 'electron';
import path from 'path';
import fs from 'fs';
import { isDev, ipcHandle } from './utils.js';
import { pollResources, pollInstrumentsValues, getStaticData, getInstrumentReadings, stopPolling } from './resourceManager.js';
import { getChannelHistory } from './historyManager.js';
import { getPreloadPath, getLogPath, getDriverLogPath, getOpasConfigPath, getOutputPath, getOpasNeoDataDir, getInstantFilePath, getServiceDocsPath, getSplashImagePath, getDriversPath } from './pathResolver.js';
import { getSettings, saveSettings } from './configManager.js';
import { listViews, getViewById, createView, updateView, deleteView } from './viewsManager.js';
import { getOpasConfig, channelPatchToRaw, modulePatchToRaw, moduleToRawForCreate, getInstrumentTypes, getNewInstrumentDraft, listConfigLibrary, getConfigByFilename, resolveConfigFilePath, stationFieldsToRaw } from './opasConfigManager.js';

const CONTROL_SERVER_URL = 'http://127.0.0.1:8080';

if (isDev()) {
    app.commandLine.appendSwitch('remote-debugging-port', '9222');
}

app.on("will-quit", () => stopPolling());

// Matches build/splash/splash.png's aspect ratio (the OPAS DL Neo wordmark
// lockup, wide rather than square) so the whole image is visible with no
// cropping - see pathResolver.getSplashImagePath().
const SPLASH_WIDTH = 440;
const SPLASH_HEIGHT = 265;

function createSplashWindow(): BrowserWindow {
    const splash = new BrowserWindow({
        width: SPLASH_WIDTH,
        height: SPLASH_HEIGHT,
        frame: false,
        resizable: false,
        movable: false,
        // Shown immediately below, right after construction - safe to do
        // here (unlike for a transparent window) because this window is
        // opaque: backgroundColor paints synchronously, so there is no
        // still-blank frame for Windows' compositor to get stuck on.
        show: true,
        backgroundColor: '#ffffff',
        alwaysOnTop: true,
        skipTaskbar: true,
        webPreferences: {
            devTools: false,
        },
    });
    // Inline data: URL rather than a separate .html file - electron-builder.json only
    // packages dist-electron/ and dist-react/, and tsc doesn't copy plain .html assets,
    // so a standalone splash.html would silently go missing from packaged builds.
    let imageTag = '';
    try {
        const imageBase64 = fs.readFileSync(getSplashImagePath()).toString('base64');
        imageTag = `<img class="logo" src="data:image/png;base64,${imageBase64}" alt="">`;
    } catch {
        // Image missing (e.g. debug run outside the normal project layout) - splash
        // still works fine without it.
    }
    const html = `<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<style>
  html, body { height: 100%; margin: 0; overflow: hidden; }
  body {
    position: relative;
    background: #ffffff;
    -webkit-app-region: drag;
  }
  .logo {
    position: absolute; inset: 0;
    width: 100%; height: 100%;
    object-fit: contain;
  }
</style>
</head>
<body>
  ${imageTag}
</body>
</html>`;
    splash.loadURL(`data:text/html;charset=utf-8,${encodeURIComponent(html)}`);
    return splash;
}

// Floor on how long the splash stays up, timed from the moment it's shown -
// mainWindow below loads an already-unpacked production bundle from disk and
// can become ready in just a few ms, which previously destroyed the splash
// in the same tick it was shown (show() immediately followed by destroy()
// never gives the OS a chance to actually paint a frame in between - the
// splash was technically "shown" but 0ms visible, indistinguishable from not
// working at all).
const MIN_SPLASH_VISIBLE_MS = 600;

app.on("ready", () => {
    const splash = createSplashWindow();
    const splashShownAt = Date.now();
    const mainWindow = new BrowserWindow({
        width: 1280,
        height: 800,
        minWidth: 1024,
        minHeight: 768,
        show: false,
        webPreferences: {
            preload: getPreloadPath(),
        }
    });
    const revealMainWindow = () => {
        const wait = Math.max(0, MIN_SPLASH_VISIBLE_MS - (Date.now() - splashShownAt));
        setTimeout(() => {
            if (!splash.isDestroyed()) splash.destroy();
            mainWindow.show();
        }, wait);
    };
    mainWindow.once('ready-to-show', revealMainWindow);
    mainWindow.webContents.once('did-fail-load', revealMainWindow);
    if (isDev()) {
        mainWindow.loadURL('http://localhost:5123');
    } else {
        mainWindow.loadFile(path.join(app.getAppPath(), '/dist-react/index.html'));
    }
    pollResources(mainWindow);
    pollInstrumentsValues(mainWindow);
    ipcHandle("getStaticData", () => {
        return getStaticData();
    });
    ipcMain.handle("getSettings", () => {
        return getSettings();
    });
    ipcMain.handle("saveSettings", (_: any, settings: { opasDlPath?: string }) => {
        return saveSettings(settings);
    });
    ipcMain.handle("getOpasConfig", () => {
        return getOpasConfig();
    });
    ipcMain.handle("getDrivers", async () => {
        try {
            const res = await fetch(`${CONTROL_SERVER_URL}/drivers`);
            if (!res.ok) return null;
            const raw: Record<string, any> = await res.json();
            // Normalize Python snake_case keys to camelCase for the renderer
            const result: Record<string, any> = {};
            for (const [id, info] of Object.entries(raw)) {
                const conn = info.connection;
                result[id] = {
                    instrumentId: info.instrument_id ?? id,
                    name: info.name ?? null,
                    alive: Boolean(info.alive),
                    pid: info.pid ?? null,
                    model: info.model ?? null,
                    brand: info.brand ?? null,
                    driverVersion: info.driver_version ?? null,
                    startTime: info.start_time ?? null,
                    uptimeSeconds: info.uptime_seconds ?? null,
                    driverFile: info.driver_file ?? null,
                    sharedComPort: info.shared_com_port ?? null,
                    sharedWith: Array.isArray(info.shared_with) ? info.shared_with : [],
                    connection: conn ? {
                        type: conn.type ?? null,
                        host: conn.host ?? null,
                        port: conn.port ?? null,
                        baudRate: conn.baud_rate ?? null,
                    } : null,
                };
            }
            return result;
        } catch {
            return null;
        }
    });
    ipcMain.handle("getDriverCatalog", async () => {
        try {
            const res = await fetch(`${CONTROL_SERVER_URL}/driver-catalog`);
            if (!res.ok) return null;
            const raw = await res.json();
            return Array.isArray(raw?.drivers) ? raw.drivers : [];
        } catch {
            return null;
        }
    });
    ipcMain.handle("driverAction", async (_: any, driverId: string, action: string) => {
        const ALLOWED = ['start', 'stop', 'restart'];
        if (!ALLOWED.includes(action)) return { error: 'invalid action' };
        try {
            const res = await fetch(`${CONTROL_SERVER_URL}/drivers/${encodeURIComponent(driverId)}/${action}`);
            if (!res.ok) return null;
            return await res.json();
        } catch {
            return null;
        }
    });
    ipcMain.handle("getServiceStartTime", async () => {
        try {
            const res = await fetch(`${CONTROL_SERVER_URL}/status`);
            if (!res.ok) return null;
            const raw = await res.json();
            // Python reports seconds since epoch (time.time()); the renderer
            // works in ms (Date.now()), same convention as uiStartTime.
            const startTime = typeof raw?.start_time === 'number' ? raw.start_time * 1000 : null;
            return { startTime };
        } catch {
            return null;
        }
    });
    ipcMain.handle("getLogLevel", async () => {
        try {
            const res = await fetch(`${CONTROL_SERVER_URL}/logging`);
            if (!res.ok) return null;
            return await res.json();
        } catch {
            return null;
        }
    });
    ipcMain.handle("setLogLevel", async (_: any, level: string) => {
        try {
            const res = await fetch(`${CONTROL_SERVER_URL}/logging`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ level }),
            });
            if (!res.ok) return null;
            return await res.json();
        } catch {
            return null;
        }
    });
    ipcMain.handle("saveOpasChannel", async (_: any, moduleId: number, channelId: number, patch: Partial<OpasChannel>, configFilename?: string) => {
        try {
            const query = configFilename ? `?config=${encodeURIComponent(configFilename)}` : '';
            const res = await fetch(`${CONTROL_SERVER_URL}/modules/${moduleId}/channels/${channelId}${query}`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(channelPatchToRaw(patch)),
            });
            if (!res.ok) return null;
            return await res.json();
        } catch {
            return null;
        }
    });
    ipcMain.handle("saveOpasModule", async (_: any, moduleId: number, patch: Partial<OpasModule>, configFilename?: string) => {
        try {
            const query = configFilename ? `?config=${encodeURIComponent(configFilename)}` : '';
            const res = await fetch(`${CONTROL_SERVER_URL}/modules/${moduleId}${query}`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(modulePatchToRaw(patch)),
            });
            if (!res.ok) return null;
            return await res.json();
        } catch {
            return null;
        }
    });
    ipcMain.handle("getInstrumentTypes", () => {
        return getInstrumentTypes();
    });
    ipcMain.handle("getNewInstrumentDraft", (_: any, typeKey: string) => {
        return getNewInstrumentDraft(typeKey);
    });
    ipcMain.handle("createOpasModule", async (_: any, module: OpasModule, configFilename?: string) => {
        try {
            const query = configFilename ? `?config=${encodeURIComponent(configFilename)}` : '';
            const res = await fetch(`${CONTROL_SERVER_URL}/modules${query}`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(moduleToRawForCreate(module)),
            });
            if (!res.ok) return null;
            return await res.json();
        } catch {
            return null;
        }
    });
    ipcMain.handle("listConfigLibrary", () => {
        return listConfigLibrary();
    });
    ipcMain.handle("getConfigByFilename", (_: any, filename: string) => {
        return getConfigByFilename(filename);
    });
    ipcMain.handle("listViews", () => {
        return listViews();
    });
    ipcMain.handle("getViewById", (_: any, id: string) => {
        return getViewById(id);
    });
    ipcMain.handle("createView", (_: any, payload: CreateViewPayload) => {
        return createView(payload);
    });
    ipcMain.handle("updateView", (_: any, id: string, patch: Partial<CreateViewPayload>) => {
        return updateView(id, patch);
    });
    ipcMain.handle("deleteView", (_: any, id: string) => {
        return deleteView(id);
    });
    ipcMain.handle("createConfig", async (_: any, payload: CreateConfigPayload) => {
        try {
            const body: Record<string, unknown> = { mode: payload.mode, filename: payload.filename };
            if (payload.mode === 'duplicate') {
                body.sourceFilename = payload.sourceFilename;
                if (payload.fields) body.fields = stationFieldsToRaw(payload.fields);
            } else if (payload.mode === 'blank') {
                if (payload.fields) body.fields = stationFieldsToRaw(payload.fields);
            } else {
                body.content = payload.content;
            }

            const res = await fetch(`${CONTROL_SERVER_URL}/configs`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(body),
            });
            if (!res.ok) return null;
            return await res.json();
        } catch {
            return null;
        }
    });
    ipcMain.handle("saveConfigStation", async (_: any, filename: string, patch: ConfigStationFields) => {
        try {
            const res = await fetch(`${CONTROL_SERVER_URL}/configs/${encodeURIComponent(filename)}/station`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(stationFieldsToRaw(patch)),
            });
            if (!res.ok) return null;
            return await res.json();
        } catch {
            return null;
        }
    });
    ipcMain.handle("activateConfig", async (_: any, filename: string) => {
        try {
            const res = await fetch(`${CONTROL_SERVER_URL}/configs/${encodeURIComponent(filename)}/activate`, {
                method: 'POST',
            });
            if (!res.ok) return null;
            return await res.json();
        } catch {
            return null;
        }
    });
    ipcMain.handle("importConfigFile", async () => {
        const result = await dialog.showOpenDialog(mainWindow, {
            properties: ['openFile'],
            title: 'Seleziona file di configurazione',
            buttonLabel: 'Importa',
            filters: [{ name: 'Config JSON', extensions: ['json'] }],
        });
        if (result.canceled || result.filePaths.length === 0) return null;
        try {
            const filePath = result.filePaths[0];
            const content = fs.readFileSync(filePath, 'utf-8').replace(/^﻿/, '');
            const parsed = JSON.parse(content);
            if (typeof parsed !== 'object' || parsed === null || Array.isArray(parsed)) return null;
            return { suggestedFilename: path.basename(filePath), content: parsed };
        } catch (err) {
            console.error('[main] Failed to read imported config file:', err);
            return null;
        }
    });
    ipcMain.handle("exportConfigFile", async (_: any, filename: string) => {
        const sourcePath = resolveConfigFilePath(filename);
        if (!sourcePath) return { success: false };

        const result = await dialog.showSaveDialog(mainWindow, {
            title: 'Esporta configurazione',
            defaultPath: filename,
            buttonLabel: 'Esporta',
            filters: [{ name: 'Config JSON', extensions: ['json'] }],
        });
        if (result.canceled || !result.filePath) return { success: false, canceled: true };

        try {
            fs.copyFileSync(sourcePath, result.filePath);
            return { success: true };
        } catch (err) {
            console.error('[main] Failed to export config file:', err);
            return { success: false };
        }
    });
    ipcMain.handle("exportCsv", async (_: any, defaultFilename: string, content: string) => {
        const result = await dialog.showSaveDialog(mainWindow, {
            title: 'Esporta CSV',
            defaultPath: defaultFilename,
            buttonLabel: 'Esporta',
            filters: [{ name: 'CSV', extensions: ['csv'] }],
        });
        if (result.canceled || !result.filePath) return { success: false, canceled: true };

        try {
            // BOM so Excel (which sniffs plain "csv" as the system codepage
            // otherwise) opens the é/à/ù etc. in instrument/channel names as UTF-8.
            const BOM = '﻿';
            fs.writeFileSync(result.filePath, BOM + content, 'utf-8');
            return { success: true };
        } catch (err) {
            console.error('[main] Failed to export CSV:', err);
            return { success: false };
        }
    });
    ipcMain.handle("getLogLines", () => {
        const logPath = getLogPath();
        try {
            if (!fs.existsSync(logPath)) return [];
            const content = fs.readFileSync(logPath, 'utf-8');
            return content.split('\n').filter((l: string) => l.trim()).slice(-100);
        } catch {
            return [];
        }
    });
    ipcMain.handle("getDriverLogLines", (_: any, driverId: string) => {
        const logPath = getDriverLogPath(driverId);
        try {
            if (!fs.existsSync(logPath)) return [];
            const content = fs.readFileSync(logPath, 'utf-8');
            return content.split('\n').filter((l: string) => l.trim()).slice(-200);
        } catch {
            return [];
        }
    });
    ipcMain.handle("openLogFile", async () => {
        const logPath = getLogPath();
        if (process.platform === 'win32') {
            // .log files often have no default app on Windows — use notepad directly
            const { spawn } = await import('child_process');
            spawn('notepad.exe', [logPath], { detached: true, stdio: 'ignore' }).unref();
        } else {
            await shell.openPath(logPath);
        }
    });
    ipcMain.handle("getInstrumentReadings", (_: any, instrumentId: string) => {
        return getInstrumentReadings(instrumentId);
    });
    ipcMain.handle("getChannelHistory", (_: any, requests: HistoryRequest[]) => {
        return getChannelHistory(requests);
    });
    ipcMain.handle("getServiceDocs", (_: any, lang: string) => {
        const requestedLang = lang === 'it' ? 'it' : 'en';
        let docsDir = getServiceDocsPath(requestedLang);
        if (!fs.existsSync(docsDir) || fs.readdirSync(docsDir).length === 0) {
            // Fall back to English if the requested language folder is missing/empty.
            docsDir = getServiceDocsPath('en');
        }
        try {
            if (!fs.existsSync(docsDir)) return [];
            const files = fs.readdirSync(docsDir).filter((f: string) => f.toLowerCase().endsWith('.md'));
            // README first (it's the index), then alphabetically.
            files.sort((a: string, b: string) => {
                const aReadme = a.toLowerCase() === 'readme.md';
                const bReadme = b.toLowerCase() === 'readme.md';
                if (aReadme !== bReadme) return aReadme ? -1 : 1;
                return a.localeCompare(b);
            });
            return files.map((filename: string) => {
                const content = fs.readFileSync(path.join(docsDir, filename), 'utf-8');
                const headingMatch = content.match(/^#\s+(.+)$/m);
                const title = headingMatch ? headingMatch[1].trim() : filename.replace(/\.md$/i, '');
                return { filename, title, content };
            });
        } catch {
            return [];
        }
    });
    ipcMain.handle("getDebugPaths", () => {
        const settings = getSettings();
        const opasConfigDir = getOpasConfigPath();
        const outputPath = getOutputPath();
        const logPath = getLogPath();
        const driversPath = getDriversPath();

        // Same selection as getOpasConfig() in opasConfigManager.ts: filter to
        // .json, take the first match - active/ is meant to hold exactly one
        // Config-*.json (see CLAUDE.md), so this is a single path like every
        // other row here, not a list.
        let configFile: string | null = null;
        let configFileExists = false;
        let configParseError: string | null = null;
        try {
            if (fs.existsSync(opasConfigDir)) {
                const jsonFiles = fs.readdirSync(opasConfigDir).filter(f => f.toLowerCase().endsWith('.json'));
                if (jsonFiles.length > 0) {
                    configFile = path.join(opasConfigDir, jsonFiles[0]);
                    configFileExists = fs.existsSync(configFile);
                    try {
                        JSON.parse(fs.readFileSync(configFile, 'utf-8').replace(/^﻿/, ''));
                    } catch (e: any) {
                        configParseError = e?.message ?? String(e);
                    }
                }
            }
        } catch { /* empty */ }

        // The path actually read on every poll (resourceManager.ts) is the OPAS NEO
        // instant file, resolved from the active config's dataFileHeader.
        const dataDir = getOpasNeoDataDir();
        const dataFileHeader = getOpasConfig()?.data?.dataFileHeader ?? null;
        const instantFilePath = dataFileHeader ? getInstantFilePath(dataFileHeader) : null;

        const opasDlPath = settings.opasDlPath ?? '';
        return {
            opasDlPath,
            opasDlPathExists: opasDlPath ? fs.existsSync(opasDlPath) : false,
            opasConfigDir,
            opasConfigDirExists: fs.existsSync(opasConfigDir),
            configFile,
            configFileExists,
            configParseError,
            dataDir,
            dataDirExists: fs.existsSync(dataDir),
            instantFilePath,
            instantFilePathExists: instantFilePath ? fs.existsSync(instantFilePath) : false,
            outputPath,
            outputPathExists: fs.existsSync(outputPath),
            logPath,
            logPathExists: fs.existsSync(logPath),
            driversPath,
            driversPathExists: fs.existsSync(driversPath),
        };
    });
    ipcMain.handle("selectFolder", async () => {
        const result = await dialog.showOpenDialog(mainWindow, {
            properties: ['openDirectory'],
            title: 'Seleziona cartella del servizio Opas DL',
            buttonLabel: 'Seleziona'
        });
        return result.canceled ? null : result.filePaths[0];
    });
});