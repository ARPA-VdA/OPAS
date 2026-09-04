import fs from 'fs';
import path from 'path';
import crypto from 'crypto';
import { app } from 'electron';

function getViewsDir(): string {
    const dir = path.join(app.getPath('userData'), 'views');
    if (!fs.existsSync(dir)) {
        fs.mkdirSync(dir, { recursive: true });
    }
    return dir;
}

// Rejects ids with path separators, so an id coming from IPC can't escape
// the views/ directory - same guard as isSafeConfigFilename in opasConfigManager.ts.
function isSafeViewId(id: string): boolean {
    return id.length > 0 && path.basename(id) === id;
}

function readViewFile(fullPath: string): ViewData | null {
    try {
        const content = fs.readFileSync(fullPath, 'utf-8');
        return JSON.parse(content) as ViewData;
    } catch (err) {
        console.error('[Views] Error reading view file:', fullPath, err);
        return null;
    }
}

export function listViews(): ViewEntry[] {
    const dir = getViewsDir();
    const entries: ViewEntry[] = [];

    try {
        const files = fs.readdirSync(dir).filter(f => f.toLowerCase().endsWith('.json'));
        for (const filename of files) {
            const data = readViewFile(path.join(dir, filename));
            if (!data) continue;
            entries.push({
                id: data.id,
                name: data.name,
                displayMode: data.displayMode,
                channelCount: data.channels.length,
                lastModified: data.lastModified,
            });
        }
    } catch (err) {
        console.error('[Views] Error listing views:', err);
    }

    entries.sort((a, b) => a.name.localeCompare(b.name));
    return entries;
}

export function getViewById(id: string): ViewData | null {
    if (!isSafeViewId(id)) return null;
    const fullPath = path.join(getViewsDir(), `${id}.json`);
    if (!fs.existsSync(fullPath)) return null;
    return readViewFile(fullPath);
}

export function createView(payload: CreateViewPayload): { success: boolean; id: string } | null {
    try {
        const id = crypto.randomUUID();
        const data: ViewData = {
            id,
            name: payload.name,
            displayMode: payload.displayMode,
            channels: payload.channels,
            lastModified: new Date().toISOString(),
        };
        fs.writeFileSync(path.join(getViewsDir(), `${id}.json`), JSON.stringify(data, null, 2), 'utf-8');
        return { success: true, id };
    } catch (err) {
        console.error('[Views] Error creating view:', err);
        return null;
    }
}

export function updateView(id: string, patch: Partial<CreateViewPayload>): { success: boolean } | null {
    if (!isSafeViewId(id)) return null;
    const fullPath = path.join(getViewsDir(), `${id}.json`);
    const existing = readViewFile(fullPath);
    if (!existing) return null;

    try {
        const data: ViewData = {
            ...existing,
            ...patch,
            id: existing.id,
            lastModified: new Date().toISOString(),
        };
        fs.writeFileSync(fullPath, JSON.stringify(data, null, 2), 'utf-8');
        return { success: true };
    } catch (err) {
        console.error('[Views] Error updating view:', id, err);
        return null;
    }
}

export function deleteView(id: string): { success: boolean } | null {
    if (!isSafeViewId(id)) return null;
    const fullPath = path.join(getViewsDir(), `${id}.json`);
    if (!fs.existsSync(fullPath)) return { success: true };

    try {
        fs.unlinkSync(fullPath);
        return { success: true };
    } catch (err) {
        console.error('[Views] Error deleting view:', id, err);
        return null;
    }
}
