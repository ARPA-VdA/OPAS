'use client';

import { useEffect, useState } from 'react';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select';

interface AppSettings {
  opasDlPath?: string;
  version?: string;
  lastModified?: string;
  rawValueMaxDecimals?: number;
}

const DEFAULT_RAW_VALUE_MAX_DECIMALS = 3;

const LOG_LEVELS = ['DEBUG', 'INFO', 'WARNING', 'ERROR'];

export function SettingsContent() {
  const [settings, setSettings] = useState<AppSettings>({});
  const [isSaved, setIsSaved] = useState(false);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [logLevel, setLogLevelState] = useState<string | null>(null);

  // Load settings on component mount
  useEffect(() => {
    const loadSettings = async () => {
      try {
        setIsLoading(true);
        setError(null);
        const appSettings = await window.electron.getSettings?.();
        if (appSettings) {
          setSettings(appSettings);
        }
      } catch (err) {
        const errorMsg = err instanceof Error ? err.message : 'Errore nel caricamento delle impostazioni';
        setError(errorMsg);
        console.error('[Settings UI] Error loading settings:', err);
      } finally {
        setIsLoading(false);
      }
    };

    loadSettings();
  }, []);

  // Livello di log di stazione: config separata da AppSettings (vive nella
  // config di stazione, non in app-settings.json), quindi caricamento e
  // salvataggio indipendenti dal resto della pagina - si applica subito al
  // cambio, non tramite il bottone "Salva Impostazioni".
  useEffect(() => {
    window.electron.getLogLevel?.().then(result => {
      if (result) setLogLevelState(result.level);
    });
  }, []);

  const handleLogLevelChange = async (level: string) => {
    const previous = logLevel;
    setLogLevelState(level);
    try {
      const result = await window.electron.setLogLevel?.(level);
      if (!result?.success) {
        setError('Errore nel salvataggio del livello di log');
        setLogLevelState(previous);
      }
    } catch (err) {
      const errorMsg = err instanceof Error ? err.message : 'Errore nel salvataggio del livello di log';
      setError(errorMsg);
      setLogLevelState(previous);
    }
  };

  const handleSelectFolder = async () => {
    try {
      setError(null);
      const selectedPath = await window.electron.selectFolder?.();
      if (selectedPath) {
        setSettings(prev => ({ ...prev, opasDlPath: selectedPath }));
        setIsSaved(false);
      }
    } catch (err) {
      const errorMsg = err instanceof Error ? err.message : 'Errore nella selezione della cartella';
      setError(errorMsg);
      console.error('Error selecting folder:', err);
    }
  };

  const handleExportSettings = async () => {
    try {
      setError(null);
      const result = await window.electron.exportSettings?.();
      if (result?.success) {
        setIsSaved(true);
        setTimeout(() => setIsSaved(false), 3000);
      } else if (result && !result.canceled) {
        setError('Errore nell\'esportazione delle impostazioni');
      }
    } catch (err) {
      const errorMsg = err instanceof Error ? err.message : 'Errore nell\'esportazione delle impostazioni';
      setError(errorMsg);
      console.error('Error exporting settings:', err);
    }
  };

  const handleImportSettings = async () => {
    try {
      setError(null);
      const result = await window.electron.importSettings?.();
      if (result?.success) {
        if (result.settings) setSettings(result.settings);
        window.dispatchEvent(new Event('settings-saved'));
        setIsSaved(true);
        setTimeout(() => setIsSaved(false), 3000);
      } else if (result) {
        setError('Errore nell\'importazione delle impostazioni');
      }
    } catch (err) {
      const errorMsg = err instanceof Error ? err.message : 'Errore nell\'importazione delle impostazioni';
      setError(errorMsg);
      console.error('Error importing settings:', err);
    }
  };

  const handleSaveSettings = async () => {
    try {
      setError(null);
      await window.electron.saveSettings?.(settings);
      window.dispatchEvent(new Event('settings-saved'));
      setIsSaved(true);
      // Hide success message after 3 seconds
      setTimeout(() => setIsSaved(false), 3000);
    } catch (err) {
      const errorMsg = err instanceof Error ? err.message : 'Errore nel salvataggio delle impostazioni';
      setError(errorMsg);
      console.error('Error saving settings:', err);
    }
  };

  if (isLoading) {
    return (
      <div className="flex flex-1 flex-col gap-4 p-4">
        <p className="text-muted-foreground">Caricamento impostazioni...</p>
      </div>
    );
  }

  return (
    <div className="flex flex-1 flex-col gap-6 p-4 pb-24">
      {/* Alerts */}
      {error && (
        <div className="bg-destructive/10 border border-destructive/30 text-destructive px-4 py-3 rounded-lg">
          {error}
        </div>
      )}

      {isSaved && (
        <div className="bg-green-50 dark:bg-green-950/20 border border-green-200 dark:border-green-800 text-green-700 dark:text-green-400 px-4 py-3 rounded-lg">
          Impostazioni salvate con successo
        </div>
      )}

      {/* Settings Sections */}
      <div className="space-y-6 max-w-4xl">
        {/* Servizio Output */}
        <div className="space-y-4">
          <div className="flex items-center gap-4">
            <Label htmlFor="opasDlPath" className="text-sm font-medium whitespace-nowrap">
              Cartella Opas DL
            </Label>
            <div className="flex-1 bg-muted px-3 py-2 rounded-md border border-input text-sm">
              {settings.opasDlPath || <span className="text-muted-foreground">Nessuna cartella selezionata</span>}
            </div>
            <Button
              onClick={handleSelectFolder}
              variant="outline"
              className="whitespace-nowrap"
            >
              Sfoglia...
            </Button>
          </div>
          {settings.lastModified && (
            <div className="text-xs text-muted-foreground pt-2">
              Ultimo aggiornamento: {new Date(settings.lastModified).toLocaleString('it-IT')}
            </div>
          )}
        </div>

        {/* Decimali valore raw */}
        <div className="space-y-2">
          <div className="flex items-center gap-4">
            <Label htmlFor="rawValueMaxDecimals" className="text-sm font-medium whitespace-nowrap">
              Decimali massimi valore raw
            </Label>
            <Input
              id="rawValueMaxDecimals"
              type="number"
              min={0}
              max={10}
              className="w-24"
              value={settings.rawValueMaxDecimals ?? DEFAULT_RAW_VALUE_MAX_DECIMALS}
              onChange={(e) => {
                const parsed = parseInt(e.target.value, 10);
                setSettings(prev => ({ ...prev, rawValueMaxDecimals: Number.isNaN(parsed) ? undefined : parsed }));
                setIsSaved(false);
              }}
            />
          </div>
          <p className="text-xs text-muted-foreground">
            Numero massimo di decimali mostrati per il valore raw (non convertito) dello strumento,
            nella pagina di dettaglio.
          </p>
        </div>

        {/* Backup impostazioni */}
        <div className="space-y-2">
          <Label className="text-sm font-medium">Backup impostazioni</Label>
          <div className="flex items-center gap-2">
            <Button onClick={handleExportSettings} variant="outline">
              Esporta impostazioni
            </Button>
            <Button onClick={handleImportSettings} variant="outline">
              Importa impostazioni
            </Button>
          </div>
          <p className="text-xs text-muted-foreground">
            Esporta la cartella Opas DL e i decimali del valore raw su file, per farne un
            backup o riportarli su un'altra installazione.
          </p>
        </div>

        {/* Livello di log */}
        <div className="space-y-2">
          <div className="flex items-center gap-4">
            <Label htmlFor="logLevel" className="text-sm font-medium whitespace-nowrap">
              Livello di log
            </Label>
            <Select value={logLevel ?? undefined} onValueChange={handleLogLevelChange}>
              <SelectTrigger id="logLevel" className="w-48">
                <SelectValue placeholder="—" />
              </SelectTrigger>
              <SelectContent>
                {LOG_LEVELS.map(level => (
                  <SelectItem key={level} value={level}>{level}</SelectItem>
                ))}
              </SelectContent>
            </Select>
          </div>
          <p className="text-xs text-muted-foreground">
            Default per tutti gli strumenti. Si applica subito al log del servizio; ogni
            strumento può avere un livello proprio, impostabile nella sua pagina di modifica.
          </p>
        </div>
      </div>

      {/* Fixed Save Button */}
      <div className="fixed bottom-4 right-4">
        <Button
          onClick={handleSaveSettings}
          size="lg"
        >
          Salva Impostazioni
        </Button>
      </div>
    </div>
  );
}
