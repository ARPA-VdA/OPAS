// Merges N independent per-series point lists into the single shared-data-array
// shape Recharts needs for a multi-<Line> chart (one row per x value, one key
// per series, missing values left undefined so Recharts just skips that point).
//
// Each point's own full (second-precision) timestamp is used as the merge key
// as-is - hourly ("medie") points are already aligned to the exact hour
// (output_broker.py always flushes on the hour boundary), and raw ("letture")
// points keep whatever second they were actually read at. Previously raw
// points were bucketed to the minute here, which silently dropped every
// reading but the last one within the same minute for any instrument polling
// faster than 60s - every real reading now gets its own row instead.
export function mergeHistorySeries(results: HistoryResult[]): Record<string, number | string | null>[] {
    const rows = new Map<string, Record<string, number | string | null>>()

    for (const result of results) {
        for (const point of result.points) {
            const key = point.timestamp
            let row = rows.get(key)
            if (!row) {
                row = { timestamp: key }
                rows.set(key, row)
            }
            row[result.seriesId] = point.value
        }
    }

    return Array.from(rows.values()).sort((a, b) => (a.timestamp as string).localeCompare(b.timestamp as string))
}
