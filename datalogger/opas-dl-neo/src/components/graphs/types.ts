export type SeriesDef = {
    // Opaque, CSS-custom-property-safe id (e.g. "s0", "s1", ...) - instrument/channel
    // names can contain spaces/slashes/accents that would break the raw CSS text
    // ChartStyle (ui/chart.tsx) generates as `--color-${id}: ...;`, so the id must
    // never be derived from those names directly.
    id: string
    instrumentName: string
    channelName: string
    colorIndex: number
    // Seconds, from the owning instrument's OpasModule.pollingInterval at the
    // moment the series was added - used to pick the x-axis tick step (see
    // chart-line.tsx) so it never implies a finer cadence than this series can
    // actually produce.
    pollingInterval: number
}
