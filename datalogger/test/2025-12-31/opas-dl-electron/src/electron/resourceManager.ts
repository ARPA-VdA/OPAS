import osUtils from 'os-utils';
import fs from 'fs';
import { BrowserWindow } from 'electron';

const POLLING_INTERVAL = 500;

export function pollResources(mainWindow: BrowserWindow) {
    setInterval(async ()=>{
        const cpuUsage = await getCpuUsage();
        const ramUsage = getRamUsage();
        const storageData = getStorageData();
        mainWindow.webContents.send("statistics", {cpuUsage, ramUsage, storageData});
        // console.log({cpuUsage, ramUsage, storageData});
    }, POLLING_INTERVAL);
}

function getCpuUsage() {
    return new Promise(resolve => {
        osUtils.cpuUsage(resolve)
    });
}

function getRamUsage() {
    return 1 - osUtils.freememPercentage();
}

function getStorageData( ){
    const stats = fs.statfsSync(process.platform === 'win32' ? 'C://' : '/');
    const total = stats.bsize * stats.blocks;
    const free = stats.bsize * stats.bfree;

    return {
        total: Math.floor(total / 1_000_000_000),
        usage: 1 - free / total
    }
}