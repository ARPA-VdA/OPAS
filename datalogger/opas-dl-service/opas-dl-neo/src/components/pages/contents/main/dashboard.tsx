import { useCallback, useEffect, useState } from 'react';
import { StationHero } from "@/components/station/station-hero"
import { DashboardSection } from "@/components/dashboard/dashboard-section"
import { SystemAlarmsBanner } from "@/components/dashboard/system-alarms-banner"
import { ServicesTable } from "@/components/drivers/services-table"
import { LogViewer } from "@/components/logs/log-viewer"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { IconStarFilled, IconLayoutGrid, IconTable, IconChevronRight } from "@tabler/icons-react"
import { useNavigation } from "@/context/NavigationContext"
import { useViews } from "@/context/ViewsContext"

export function DashboardContent() {
  const nav = useNavigation();
  const { views, selectView } = useViews();
  const favoriteView = views.find(v => v.favorite);
  const [opasConfig, setOpasConfig] = useState<OpasConfigWithFile>(null);
  const [drivers, setDrivers] = useState<DriverInfo[]>([]);

  const configData = opasConfig?.data;

  const fetchDrivers = useCallback(async () => {
    const raw = await window.electron.getDrivers();
    if (!raw) return;
    setDrivers(Object.entries(raw).map(([id, info]) => ({ id, ...info })));
  }, []);

  const handleServiceAction = async (driverId: string, action: 'start' | 'stop' | 'restart') => {
    await window.electron.driverAction(driverId, action);
    fetchDrivers();
  };

  const loadOpasConfig = useCallback(async () => {
    try {
      const loaded = await window.electron.getOpasConfig?.();
      setOpasConfig(loaded ?? null);
    } catch (err) {
      console.error('[Dashboard] Error loading opas config:', err);
    }
  }, []);

  useEffect(() => {
    loadOpasConfig();
    window.addEventListener('settings-saved', loadOpasConfig);
    window.addEventListener('opas-config-saved', loadOpasConfig);
    return () => {
      window.removeEventListener('settings-saved', loadOpasConfig);
      window.removeEventListener('opas-config-saved', loadOpasConfig);
    };
  }, [loadOpasConfig]);

  // Polling dei driver dalla control API ogni 5 s
  useEffect(() => {
    fetchDrivers();
    const interval = setInterval(fetchDrivers, 5000);
    return () => clearInterval(interval);
  }, [fetchDrivers]);

  return (
    <div className="p-4 flex flex-col gap-6 min-h-full">
      {/* Allarmi di sistema */}
      <SystemAlarmsBanner />

      {/* Hero Stazione */}
      <StationHero
        name={configData?.name || '—'}
        location={configData?.stationLocation || '—'}
        latitude={configData?.stationLatitude ?? 0}
        longitude={configData?.stationLongitude ?? 0}
        altitude={configData?.stationAltitude ?? 0}
        fileName={opasConfig?.fileName}
        modulesCount={configData?.modules?.length ?? 0}
        dataFileHeader={configData?.dataFileHeader}
        lastUpdate={configData?.configLastUpdate}
        onConfigClick={opasConfig?.fileName ? () => nav?.navigateTo('nav.configurations', { selectFilename: opasConfig.fileName }) : undefined}
      />

      {/* Scorciatoia vista preferita */}
      {favoriteView && (
        <Card
          onClick={() => { selectView(favoriteView.id); nav?.navigateTo('nav.views'); }}
          className="cursor-pointer hover:shadow-sm hover:border-primary/50 transition-all py-0 gap-0"
        >
          <CardHeader className="p-3 pb-2">
            <div className="flex items-center gap-2">
              <IconStarFilled size={15} className="text-amber-500 shrink-0" />
              <CardTitle className="text-base truncate flex-1 min-w-0">{favoriteView.name}</CardTitle>
              <IconChevronRight size={16} className="text-muted-foreground shrink-0" />
            </div>
          </CardHeader>
          <CardContent className="px-3 pb-3 pt-0">
            <div className="flex items-center justify-between text-xs text-muted-foreground">
              <span>{favoriteView.channelCount} canali</span>
              <span className="flex items-center gap-1">
                {favoriteView.displayMode === 'cards' ? <IconLayoutGrid size={13} /> : <IconTable size={13} />}
                {favoriteView.displayMode === 'cards' ? 'Card' : 'Tabella'}
              </span>
            </div>
          </CardContent>
        </Card>
      )}

      {/* Driver */}
      <DashboardSection>
        <ServicesTable drivers={drivers} onAction={handleServiceAction} />
      </DashboardSection>

      {/* Log */}
      <DashboardSection>
        <LogViewer />
      </DashboardSection>
    </div>
  );
}