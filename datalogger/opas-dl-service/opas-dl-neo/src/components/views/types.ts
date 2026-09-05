import type { ResolvedViewChannel } from "@/lib/viewResolution"

// A resolved channel merged with its current instant value, polled via
// getInstrumentReadings() - see view-detail.tsx.
export type ViewChannelData = ResolvedViewChannel & {
  value: number | null
  rawValue: number | null
  timestamp: string | null
}

// Per-instrument identity/status not carried by OpasModule itself - sourced
// from getDrivers() (brand/model/alive), see view-detail.tsx.
export type ViewInstrumentInfo = {
  alive: boolean
  brand: string | null
  model: string | null
}
