import { sanitizeInstrumentName } from "@/lib/instrumentName"
import type { MergedInstrument } from "@/components/instruments/instrument-card"

export function mergeInstruments(
  instrumentValues: { id: string; value: number; lastModified: any; sourceId?: string; isMissing?: boolean }[],
  drivers: Record<string, Omit<DriverInfo, 'id'>> | null,
  modules: OpasModule[],
  resolvedModuleIds: Set<number>,
): MergedInstrument[] {
  return [...modules].sort((a, b) => a.position - b.position).map(module => {
    const safeName = sanitizeInstrumentName(module.name)
    const iv = instrumentValues.find(v => v.id === safeName)

    let driverKey: string | null = null
    let driverInfo: Omit<DriverInfo, 'id'> | null = null
    if (drivers) {
      const entry = Object.entries(drivers).find(([, d]) => d.name === module.name)
      if (entry) {
        driverKey = entry[0]
        driverInfo = entry[1]
      }
    }

    return {
      id: module.name,
      lastModified: iv?.lastModified ? new Date(iv.lastModified) : null,
      lastValue: iv?.value ?? null,
      isMissing: iv?.isMissing ?? false,
      alive: driverInfo?.alive ?? false,
      pid: driverInfo?.pid ?? null,
      model: driverInfo?.model ?? null,
      brand: driverInfo?.brand ?? null,
      driverVersion: driverInfo?.driverVersion ?? null,
      startTime: driverInfo?.startTime ?? null,
      uptimeSeconds: driverInfo?.uptimeSeconds ?? null,
      driverFile: driverInfo?.driverFile ?? null,
      sharedComPort: driverInfo?.sharedComPort ?? null,
      sharedWith: (driverInfo?.sharedWith ?? []).map(otherId => {
        const otherModule = modules.find(m => String(m.id) === otherId)
        return otherModule?.name ?? otherId
      }),
      driverKey,
      driverExists: resolvedModuleIds.has(module.id),
      moduleConfig: module,
    }
  })
}
