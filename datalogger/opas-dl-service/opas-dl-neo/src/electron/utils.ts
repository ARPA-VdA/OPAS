import { ipcMain } from "electron";
import type { WebContents } from "electron/main";

export function isDev(): boolean {
    return process.env.NODE_ENV === 'development';
}

export function ipcHandle<Key extends keyof EventPayloadMapping>(
    key: Key,
    handler: () => EventPayloadMapping[Key]) {
    ipcMain.handle(key, () => handler());
}

export function ipcWebContentsSend<Key extends keyof EventPayloadMapping>(
    key: Key,
    webContents: WebContents,
    payload: EventPayloadMapping[Key]) {
    webContents.send(key, payload);
}