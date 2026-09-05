import fs from 'fs';
import path from 'path';
import { app } from 'electron';

const SETTINGS_FILE = 'app-settings.json';

interface AppConfig {
  opasDlPath?: string;
  version: string;
  lastModified: string;
  rawValueMaxDecimals?: number;
}

const DEFAULT_CONFIG: AppConfig = {
  opasDlPath: '',
  version: '1.0.0',
  lastModified: new Date().toISOString(),
  rawValueMaxDecimals: 3,
};

function getSettingsPath(): string {
    return path.join(app.getPath('userData'), SETTINGS_FILE);
}

export function getSettings(): AppConfig {
    const settingsPath = getSettingsPath();
    
    try {
        if (fs.existsSync(settingsPath)) {
            const content = fs.readFileSync(settingsPath, 'utf-8');
            const parsed = JSON.parse(content);
            // Merge with defaults to ensure all required fields exist
            return { ...DEFAULT_CONFIG, ...parsed };
        }
    } catch (err) {
        console.error('[Config] Error reading settings:', err);
    }
    
    return { ...DEFAULT_CONFIG };
}

export function saveSettings(settings: Partial<AppConfig>): void {
    try {
        const settingsPath = getSettingsPath();
        const currentConfig = getSettings();
        const newConfig: AppConfig = {
            ...currentConfig,
            ...settings,
            lastModified: new Date().toISOString(),
        };
        fs.writeFileSync(settingsPath, JSON.stringify(newConfig, null, 2), 'utf-8');
    } catch (err) {
        console.error('[Config] Error saving settings:', err);
        throw err;
    }
}
