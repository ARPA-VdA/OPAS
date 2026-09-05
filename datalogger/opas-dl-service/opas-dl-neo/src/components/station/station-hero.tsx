import { useState } from "react"
import { IconMapPin, IconCompass, IconMountain, IconX } from "@tabler/icons-react"
import * as Dialog from "@radix-ui/react-dialog"
import { Configuration } from "@/components/configuration/configuration"

interface StationHeroProps {
  name?: string
  location?: string
  latitude?: number
  longitude?: number
  altitude?: number
  fileName?: string
  modulesCount?: number
  dataFileHeader?: string
  lastUpdate?: Date | string
  onConfigClick?: () => void
}

export function StationHero({
  name = 'Mont Fleury',
  location = 'Frazione Mont Fleury - Aosta (AO)',
  latitude = 45.7369,
  longitude = 7.32372,
  altitude = 580,
  fileName,
  modulesCount = 0,
  dataFileHeader,
  lastUpdate,
  onConfigClick,
}: StationHeroProps) {
  const [mapOpen, setMapOpen] = useState(false)

  const delta = 0.02
  const osmEmbed =
    `https://www.openstreetmap.org/export/embed.html` +
    `?bbox=${longitude - delta},${latitude - delta},${longitude + delta},${latitude + delta}` +
    `&layer=mapnik&marker=${latitude},${longitude}`
  const iconSize = 20

  return (
    <div className="w-full py-2 px-0 flex flex-col lg:flex-row lg:items-center lg:justify-between gap-4">
      <div className="space-y-2">
        <h1 className="text-5xl font-bold text-foreground tracking-tight text-left">
          {name}
        </h1>
        <div className="flex items-center gap-1.5 text-muted-foreground">
          <IconMapPin size={iconSize} />
          <span className="text-lg">{location}</span>
        </div>
        <div className="flex items-center gap-2 text-muted-foreground">
          <Dialog.Root open={mapOpen} onOpenChange={setMapOpen}>
            <Dialog.Trigger asChild>
              <button
                className="flex items-center gap-1 text-muted-foreground hover:text-foreground hover:bg-muted transition-colors cursor-pointer rounded px-1.5 py-0.5 -mx-1.5"
                title="Mostra sulla mappa"
              >
                <span className="flex items-center gap-1.5">
                  <IconCompass size={iconSize} />
                  <span className="text-lg">{latitude.toFixed(4)}° N</span>
                </span>
                <span className="text-muted-foreground/50">·</span>
                <span className="flex items-center gap-1.5">
                  <IconCompass size={iconSize} className="-scale-x-100" />
                  <span className="text-lg">{longitude.toFixed(5)}° E</span>
                </span>
                <span className="text-muted-foreground/50">·</span>
                <span className="flex items-center gap-1.5">
                  <IconMountain size={iconSize} />
                  <span className="text-lg">{altitude} m s.l.m.</span>
                </span>
              </button>
            </Dialog.Trigger>
            <Dialog.Portal>
              <Dialog.Overlay className="fixed inset-0 bg-black/40 backdrop-blur-sm z-50" />
              <Dialog.Content className="fixed left-1/2 top-1/2 z-50 -translate-x-1/2 -translate-y-1/2 w-[900px] max-w-[90vw] bg-background rounded-xl shadow-2xl overflow-hidden border border-border">
                <div className="flex items-center justify-between px-4 py-3 border-b border-border">
                  <div>
                    <Dialog.Title className="font-semibold text-foreground">{name}</Dialog.Title>
                    <Dialog.Description className="text-xs text-muted-foreground mt-0.5">
                      {latitude.toFixed(4)}° N · {longitude.toFixed(5)}° E · {altitude} m s.l.m.
                    </Dialog.Description>
                  </div>
                  <Dialog.Close asChild>
                    <button className="text-muted-foreground hover:text-foreground transition-colors cursor-pointer">
                      <IconX size={18} />
                    </button>
                  </Dialog.Close>
                </div>
                <iframe
                  src={osmEmbed}
                  className="w-full h-[560px] border-0"
                  title="Posizione stazione"
                />
              </Dialog.Content>
            </Dialog.Portal>
          </Dialog.Root>
        </div>
      </div>

      <button
        type="button"
        onClick={onConfigClick}
        disabled={!onConfigClick}
        className={`text-left shrink-0 w-full lg:w-auto lg:min-w-[420px] rounded-xl border border-border bg-card p-4 transition-all ${
          onConfigClick ? 'cursor-pointer hover:shadow-sm hover:border-primary/50' : ''
        }`}
      >
        <div className="flex items-center justify-between gap-2 mb-2">
          <p className="text-sm font-semibold text-foreground">Configurazione attiva</p>
        </div>
        <Configuration
          fileName={fileName}
          modulesCount={modulesCount}
          dataFileHeader={dataFileHeader}
          lastUpdate={lastUpdate}
        />
      </button>
    </div>
  )
}
