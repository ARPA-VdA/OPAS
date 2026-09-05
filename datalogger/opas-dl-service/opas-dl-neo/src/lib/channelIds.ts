// Composite identity for a channel: OpasChannel.id is only unique within its
// own module, so addressing a channel across the whole config (e.g. as a
// React key, or a saved reference into a channel selection) needs the owning
// module's id alongside it. Same addressing convention as
// saveOpasChannel(moduleId, channelId, ...).
export function channelKey(moduleId: number, channelId: number): string {
  return `${moduleId}-${channelId}`
}

// DatabaseId must be unique station-wide within a single config. 0 is always
// flagged (placeholder/unassigned, never a real id) regardless of collisions;
// any other value shared by more than one channel across any module is a
// genuine duplicate. Computed once per config so every view (module list,
// unified ID table) highlights the exact same set.
export function computeDuplicateDatabaseIds(modules: OpasModule[]): Set<number> {
    const counts = new Map<number, number>()
    for (const module of modules) {
        for (const channel of module.channels) {
            counts.set(channel.databaseId, (counts.get(channel.databaseId) ?? 0) + 1)
        }
    }
    return new Set([...counts.entries()].filter(([id, n]) => id === 0 || n > 1).map(([id]) => id))
}
