export type ResolvedViewChannel = {
  moduleId: number
  module: OpasModule
  channel: OpasChannel
}

// Views store lightweight (moduleId, channelId) references rather than
// copies of channel data, so edits to a channel's config (name, unit,
// decimals...) are picked up automatically. Resolved live against the
// current active config on every render; a ref whose module or channel no
// longer exists (deleted, or a completely different config activated) is
// silently dropped rather than treated as an error - same defensive spirit
// as resolvedModuleIds in instruments.tsx.
export function resolveViewChannels(refs: ViewChannelRef[], modules: OpasModule[]): ResolvedViewChannel[] {
  const resolved: ResolvedViewChannel[] = []
  for (const ref of refs) {
    const module = modules.find(m => m.id === ref.moduleId)
    if (!module) continue
    const channel = module.channels.find(c => c.id === ref.channelId)
    if (!channel) continue
    resolved.push({ moduleId: module.id, module, channel })
  }
  return resolved
}
