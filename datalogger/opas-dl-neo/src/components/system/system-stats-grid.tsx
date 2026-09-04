export interface SystemStat {
  id: string
  label: string
  value: string | number
  subtitle?: string
}

interface SystemStatsGridProps {
  stats: SystemStat[]
}

export function SystemStatsGrid({ stats }: SystemStatsGridProps) {
  return (
    <div className="grid grid-cols-2 gap-4">
      {stats.map((stat) => (
        <div key={stat.id}>
          <p className="text-sm text-muted-foreground">{stat.label}</p>
          <p className="font-medium">
            {stat.value}
            {stat.subtitle && <span className="text-muted-foreground font-normal"> · {stat.subtitle}</span>}
          </p>
        </div>
      ))}
    </div>
  )
}
