import { IconGauge, IconStethoscope, IconBell, IconHelp } from "@tabler/icons-react"

// 0 = parametro, 1 = diagnostico, 2 = allarme (vedi Config-Plouves.json per
// esempi reali di canali Type 2 come "Porta aperta"/"Alimentatore").
export function channelTypeInfo(type: number): { icon: typeof IconGauge; label: string } {
    switch (type) {
        case 0: return { icon: IconGauge, label: "Parametro" }
        case 1: return { icon: IconStethoscope, label: "Diagnostico" }
        case 2: return { icon: IconBell, label: "Allarme" }
        default: return { icon: IconHelp, label: `Tipo ${type}` }
    }
}

// Plural form, for group/column headers (channelTypeInfo's label stays
// singular, used to describe a single channel).
export function channelTypeLabelPlural(type: number): string {
    switch (type) {
        case 0: return "Parametri"
        case 1: return "Diagnostici"
        case 2: return "Allarmi"
        default: return channelTypeInfo(type).label
    }
}
