// Strips characters that aren't valid in the sanitized instrument id used to
// key InstrumentValue lookups and, in add-instrument-dialog.tsx, to detect
// module-name collisions before creating a new instrument.
export function sanitizeInstrumentName(name: string): string {
  return name.replace(/[^A-Za-z0-9_\-]/g, '_').replace(/^_+|_+$/g, '')
}
