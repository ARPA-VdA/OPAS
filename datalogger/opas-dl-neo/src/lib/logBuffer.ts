// getLogLines/getDriverLogLines only ever return the current tail of a log
// file (last N lines on disk). Replacing the client buffer with that window
// on every poll made a paused/scrolled-back view silently "scroll" forward
// on its own: the window slides with the file, so the same DOM row indices
// end up showing newer text even though scrollTop never moved.
//
// Instead, only the lines genuinely new since the last poll are appended to
// the existing buffer, so a reader scrolled away from the bottom keeps
// looking at exactly the rows they're on. Trimming to the target size only
// happens while pinned to the bottom, where it's invisible; while paused the
// buffer is still capped, just at a much larger ceiling, purely to bound
// memory if left paused a long time.
const UNPINNED_CAP_MULTIPLIER = 10

export function mergeLogLines(prev: string[], fresh: string[], pinned: boolean, targetBuffer: number): string[] {
  if (fresh.length === 0) return prev
  if (prev.length === 0) return fresh.slice(-targetBuffer)

  const overlapIndex = fresh.lastIndexOf(prev[prev.length - 1])
  const merged = overlapIndex === -1 ? prev.concat(fresh) : prev.concat(fresh.slice(overlapIndex + 1))

  return pinned ? merged.slice(-targetBuffer) : merged.slice(-targetBuffer * UNPINNED_CAP_MULTIPLIER)
}
