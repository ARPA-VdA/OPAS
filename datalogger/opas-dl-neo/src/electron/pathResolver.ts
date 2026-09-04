import path from "path";
import { app } from 'electron';
import { isDev } from './utils.js';
import { getSettings } from './configManager.js';

export function getPreloadPath() {
    return path.join(
        app.getAppPath(),
        isDev() ? '.' : '..',
        '/dist-electron/preload.cjs'
    );
}

export function getSplashImagePath() {
    // Mirrors getPreloadPath()'s dev/prod resolution: in dev app.getAppPath() is the
    // project root, in a packaged build it's resources/app.asar, and extraResources
    // (see electron-builder.json) copies this file to resources/ preserving its path.
    return path.join(
        app.getAppPath(),
        isDev() ? '.' : '..',
        '/build/splash/splash.png'
    );
}

export function getOutputPath() {
    // Root of the service's output tree
    const settings = getSettings();
    const opasDlPath = settings.opasDlPath || '';
    return path.join(opasDlPath, 'src', 'py_out');
}

export function getOpasNeoDataDir() {
    // Root of the OPAS NEO instant-reading output (file_istantanei, files_letture_csv,
    // files_letture_dat), written by opas_dl_commons/libs/output_broker.py
    const settings = getSettings();
    const opasDlPath = settings.opasDlPath || '';
    return path.join(opasDlPath, 'src', 'py_out', 'data');
}

export function getInstantFilePath(stationHeader: string) {
    return path.join(getOpasNeoDataDir(), 'file_istantanei', `${stationHeader}.dat`);
}

// Parallel to file_istantanei, same row format, carries the pre-Formule raw
// reading (see opas_dl_commons/libs/output_broker.py _write_instant_raw_file
// and docs/driver-contract.md §5.4). Not part of the centro network contract
// - UI-only, may not exist for an older service build.
export function getInstantRawFilePath(stationHeader: string) {
    return path.join(getOpasNeoDataDir(), 'file_istantanei_raw', `${stationHeader}.dat`);
}

// Matches output_broker.py's _append_letture_csv/_append_medie_csv SafeChannelName
// sanitization exactly: only "/" and "\" are replaced with "_", nothing else.
export function sanitizeCsvChannelName(channelName: string) {
    return channelName.replace(/\//g, '_').replace(/\\/g, '_');
}

export function getLettureCsvDir() {
    // Root of per-channel daily "raw reading" CSVs (files_letture_csv/<YYYYMM>/...)
    return path.join(getOpasNeoDataDir(), 'files_letture_csv');
}

export function getMedieCsvDir() {
    // Root of per-channel daily "hourly average" CSVs (files_medie_csv/<YYYYMM>/...)
    return path.join(getOpasNeoDataDir(), 'files_medie_csv');
}

function formatYyyyMm(date: Date) {
    return `${date.getFullYear()}${String(date.getMonth() + 1).padStart(2, '0')}`;
}

function formatYyyyMmDd(date: Date) {
    return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}-${String(date.getDate()).padStart(2, '0')}`;
}

export function getLettureCsvFilePath(channelName: string, date: Date) {
    const safeName = sanitizeCsvChannelName(channelName);
    return path.join(getLettureCsvDir(), formatYyyyMm(date), `${safeName}-${formatYyyyMmDd(date)}.csv`);
}

export function getMedieCsvFilePath(channelName: string, date: Date) {
    const safeName = sanitizeCsvChannelName(channelName);
    return path.join(getMedieCsvDir(), formatYyyyMm(date), `${safeName}-${formatYyyyMmDd(date)}.csv`);
}

export function getLogPath() {
    const settings = getSettings();
    const opasDlPath = settings.opasDlPath || '';
    const logPath = path.join(opasDlPath, 'src', 'py_out', 'logs', 'service.log');
    return logPath;
}

export function getDriverLogPath(driverId: string | number) {
    const settings = getSettings();
    const opasDlPath = settings.opasDlPath || '';
    return path.join(opasDlPath, 'src', 'py_out', 'logs', `driver_${driverId}.log`);
}

export function getServiceDocsPath(lang: 'en' | 'it') {
    // Root of the Python service's own documentation (architecture, control
    // API, driver contract) — see opas-dl-service/docs/README.md. Bilingual:
    // one copy under docs/en/, one under docs/it/.
    const settings = getSettings();
    const opasDlPath = settings.opasDlPath || '';
    return path.join(opasDlPath, 'docs', lang);
}

export function getDriversDictPath() {
    // Static catalog of installable instrument types + the "FullConfig" default
    // module/channel template, used by the "add instrument" flow to build a
    // pre-filled draft. Read directly from disk like the active config (config
    // reads are always direct filesystem, never via the control HTTP API).
    const settings = getSettings();
    const opasDlPath = settings.opasDlPath || '';
    return path.join(opasDlPath, 'src', 'opas_dl_commons', 'drivers', 'drivers_dict.json');
}

export function getDriversPath() {
    // Root of the installed driver folders (opas_dl_commons/drivers/), the
    // parent of getDriversDictPath()'s drivers_dict.json and of each driver's
    // <NAME>/driver.py (possibly nested, e.g. "API/API_100").
    const settings = getSettings();
    const opasDlPath = settings.opasDlPath || '';
    return path.join(opasDlPath, 'src', 'opas_dl_commons', 'drivers');
}

export function getOpasConfigPath() {
    // Read opasDlPath from settings and build active config folder path
    const settings = getSettings();
    const opasDlPath = settings.opasDlPath || '';
    const opasConfigPath = path.join(opasDlPath, 'src', 'opas_dl_commons', 'config', 'active');

    // if (settings.opasDlPath) {
    //     console.log(`[PathResolver] Using configured opasDlPath: ${settings.opasDlPath}`);
    // } else {
    //     console.log(`[PathResolver] Using default opasDlPath: ${opasDlPath}`);
    // }
    // console.log(`[PathResolver] Opas config path: ${opasConfigPath}`);
    return opasConfigPath;
}

export function getOpasConfigSamplesPath() {
    // Sibling of getOpasConfigPath()'s "active" folder: holds every config file
    // that is NOT currently active (bundled templates, plus anything the user
    // duplicates/creates/imports from the Configurazioni page) - see
    // opas-dl-service/docs/*/architecture.md's config-management section.
    const settings = getSettings();
    const opasDlPath = settings.opasDlPath || '';
    return path.join(opasDlPath, 'src', 'opas_dl_commons', 'config', 'samples');
}