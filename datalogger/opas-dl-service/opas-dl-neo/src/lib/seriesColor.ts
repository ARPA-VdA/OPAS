// Validated 8-slot categorical palette (dataviz skill, references/palette.md):
// order chosen so every adjacent pair clears the CVD/normal-vision gates in
// both light and dark mode. Deterministic by insertion order - series keep
// their color as long as they aren't removed and re-added.
const CATEGORICAL_PALETTE: { light: string; dark: string }[] = [
    { light: '#2a78d6', dark: '#3987e5' }, // blue
    { light: '#eb6834', dark: '#d95926' }, // orange
    { light: '#1baf7a', dark: '#199e70' }, // aqua
    { light: '#eda100', dark: '#c98500' }, // yellow
    { light: '#e87ba4', dark: '#d55181' }, // magenta
    { light: '#008300', dark: '#008300' }, // green
    { light: '#4a3aa7', dark: '#9085e9' }, // violet
    { light: '#e34948', dark: '#e66767' }, // red
]

export function getSeriesColor(index: number) {
    return CATEGORICAL_PALETTE[index % CATEGORICAL_PALETTE.length]
}
