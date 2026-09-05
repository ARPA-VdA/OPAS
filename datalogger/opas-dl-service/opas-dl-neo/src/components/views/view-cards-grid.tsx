import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { channelTypeInfo } from "@/lib/channelType"
import { formatValue, formatRawValue, DEFAULT_RAW_VALUE_MAX_DECIMALS } from "@/components/instruments/readings-section"
import type { ViewChannelData, ViewInstrumentInfo } from "./types"

interface ViewCardsGridProps {
  channels: ViewChannelData[]
  instrumentInfo: Map<number, ViewInstrumentInfo>
}

export function ViewCardsGrid({ channels, instrumentInfo }: ViewCardsGridProps) {
  const moduleIds = [...new Set(channels.map(c => c.moduleId))]

  if (moduleIds.length === 0) {
    return <p className="text-sm text-muted-foreground">Nessun canale selezionato o disponibile.</p>
  }

  return (
    <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
      {moduleIds.map(moduleId => {
        const moduleChannels = channels
          .filter(c => c.moduleId === moduleId)
          .sort((a, b) => a.channel.position - b.channel.position)
        const module = moduleChannels[0].module
        const info = instrumentInfo.get(moduleId)

        return (
          <Card key={moduleId} className="py-0 gap-0 h-full min-w-0 flex flex-col">
            <CardHeader className="p-3 pb-2">
              <div className="flex items-baseline gap-1.5 min-w-0">
                <span className="text-muted-foreground font-mono text-xs shrink-0">{module.id}</span>
                <CardTitle className="text-base font-bold truncate min-w-0">{module.name}</CardTitle>
              </div>
              {(info?.model || info?.brand) && (
                <p className="text-xs text-muted-foreground truncate mt-0.5">
                  {[info?.model, info?.brand].filter(Boolean).join(' · ')}
                </p>
              )}
            </CardHeader>
            <CardContent className="px-3 pb-3 pt-0 flex-1 flex flex-col gap-1.5">
              {moduleChannels.map(ch => {
                const { icon: TypeIcon } = channelTypeInfo(ch.channel.type)
                const hasValue = ch.value !== null && !isNaN(ch.value)
                const valueEl = (
                  <span className={`text-sm font-semibold tabular-nums ${hasValue ? '' : 'text-muted-foreground'}`}>
                    {formatValue(ch.value, ch.channel.decimals)}
                  </span>
                )
                return (
                  <div
                    key={ch.channel.id}
                    className={`flex items-start justify-between gap-2 rounded-md bg-muted/20 px-2 py-1.5 ${!ch.channel.active ? 'opacity-50' : ''}`}
                  >
                    <div className="flex flex-col min-w-0 gap-0.5">
                      <span className="flex items-center gap-1.5 min-w-0 text-xs text-muted-foreground">
                        <TypeIcon size={13} className="shrink-0" />
                        <span className="truncate">{ch.channel.name}</span>
                      </span>
                      <span className="text-[10px] text-muted-foreground truncate">
                        Raw: {formatRawValue(ch.rawValue, DEFAULT_RAW_VALUE_MAX_DECIMALS)}
                        <span className="ml-2">Formula: {ch.channel.formule || '—'}</span>
                      </span>
                    </div>
                    <span className="flex items-baseline gap-1 shrink-0">
                      {valueEl}
                      {ch.channel.unit && <span className="text-xs text-muted-foreground">{ch.channel.unit}</span>}
                    </span>
                  </div>
                )
              })}
            </CardContent>
          </Card>
        )
      })}
    </div>
  )
}
