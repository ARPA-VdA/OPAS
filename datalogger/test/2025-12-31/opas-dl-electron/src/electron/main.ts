import { app, BrowserWindow } from 'electron';
import path from 'path';
import { isDev } from './utils.js';
import { pollResources } from './resourceManager.js';
import { getPreloadPath } from './pathResolver.js';

app.on("ready", () => {
    const mainWindow = new BrowserWindow({
        width: 1280,
        height: 800,
        minWidth: 1024,
        minHeight: 768,
        webPreferences: {
            preload: getPreloadPath(),
        }
    });
    if (isDev()) {
        mainWindow.loadURL('http://localhost:5123');
    } else {
        mainWindow.loadFile(path.join(app.getAppPath(), '/dist-react/index.html'));
    }
    pollResources(mainWindow);
})