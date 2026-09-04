import fs from 'fs';
import { getLettureCsvFilePath, getMedieCsvFilePath } from './pathResolver.js';

// "dd/MM/yyyy HH:mm:ss" -> ISO 8601, no timezone conversion (wall-clock station
// time, same convention as parseInstantTimestamp in resourceManager.ts).
function parseItalianTimestamp(ts: string): string | null {
    const m = ts.trim().match(/^(\d{2})\/(\d{2})\/(\d{4}) (\d{2}):(\d{2}):(\d{2})$/);
    if (!m) return null;
    const [, dd, MM, yyyy, HH, mm, ss] = m;
    return `${yyyy}-${MM}-${dd}T${HH}:${mm}:${ss}`;
}

// "dd/MM/yyyy HH:mm:ss;value" (raw) or "dd/MM/yyyy HH:mm:ss;value;pCod" (hourly),
// decimal comma. Mirrors resourceManager.ts's parseInstantFile row-splitting style.
function parseCsvLine(line: string, kind: HistoryKind): HistoryPoint | null {
    const parts = line.split(';');
    if (parts.length < 2) return null;
    const [tsStr, valueStr, pCodStr] = parts;
    const timestamp = parseItalianTimestamp(tsStr);
    if (!timestamp) return null;

    const parsedValue = valueStr === '' ? null : parseFloat(valueStr.replace(',', '.'));
    const value = parsedValue !== null && Number.isNaN(parsedValue) ? null : parsedValue;
    const point: HistoryPoint = { timestamp, value };

    if (kind === 'hourly') {
        const pCod = parseInt(pCodStr, 10) || 0;
        point.isMissing = (pCod & 128) !== 0;
    }
    return point;
}

function readDayFile(channelName: string, kind: HistoryKind, date: Date): HistoryPoint[] {
    const filePath = kind === 'raw'
        ? getLettureCsvFilePath(channelName, date)
        : getMedieCsvFilePath(channelName, date);
    if (!fs.existsSync(filePath)) return [];
    const content = fs.readFileSync(filePath, 'utf-8');
    const lines = content.split(/\r?\n/).filter(l => l.trim().length > 0);
    const points: HistoryPoint[] = [];
    for (const line of lines) {
        const point = parseCsvLine(line, kind);
        if (point) points.push(point);
    }
    return points;
}

// Walks calendar days regardless of month boundaries, so a range spanning e.g.
// 2026-07-31 -> 2026-08-01 correctly reads from both the 202607 and 202608 folders.
function eachDate(fromDate: string, toDate: string): Date[] {
    const out: Date[] = [];
    const from = new Date(`${fromDate}T00:00:00`);
    const to = new Date(`${toDate}T00:00:00`);
    for (let d = from; d <= to; d = new Date(d.getFullYear(), d.getMonth(), d.getDate() + 1)) {
        out.push(new Date(d));
    }
    return out;
}

function readOneSeries(req: HistoryRequest): HistoryResult {
    try {
        const points = eachDate(req.fromDate, req.toDate)
            .flatMap(d => readDayFile(req.channelName, req.kind, d))
            .sort((a, b) => a.timestamp.localeCompare(b.timestamp));
        return { seriesId: req.seriesId, channelName: req.channelName, kind: req.kind, points };
    } catch (err) {
        return {
            seriesId: req.seriesId, channelName: req.channelName, kind: req.kind, points: [],
            error: err instanceof Error ? err.message : String(err),
        };
    }
}

// Batch reader: one call carries every series a chart needs, since mixing
// channels from multiple instruments is the common case here. Each request is
// independent - a missing/corrupt file for one series doesn't blank the others.
export function getChannelHistory(requests: HistoryRequest[]): HistoryResult[] {
    return requests.map(readOneSeries);
}
