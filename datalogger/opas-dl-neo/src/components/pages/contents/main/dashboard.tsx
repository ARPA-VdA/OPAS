import { useCallback, useEffect, useState } from 'react';
import { StationHero } from "@/components/station/station-hero"
import { DashboardSection } from "@/components/dashboard/dashboard-section"
import { ServicesTable } from "@/components/drivers/services-table"
import { LogViewer } from "@/components/logs/log-viewer"
import { useNavigation } from "@/context/NavigationContext"

export function DashboardContent() {
  const nav = useNavigation();
  const [opasConfig, setOpasConfig] = useState<OpasConfigWithFile>(null);
  const [drivers, setDrivers] = useState<DriverInfo[]>([]);

  // Helper per accedere ai dati della configurazione Opas fortemente tipizzati
  const configData = opasConfig?.data as OpasConfigData;

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