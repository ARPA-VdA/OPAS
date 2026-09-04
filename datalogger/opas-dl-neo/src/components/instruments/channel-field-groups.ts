import type { FieldGroupDef } from "./field-group-form"

// Mirrors the legacy VB.NET Algorithm enum (see output_manager.Algorithm in
// opas-dl-service) - numeric values are a fixed contract with existing config
// files, do not renumber. 4/5/9 are recognized but have no aggregation logic
// yet in output_broker._HourBucket, so the service falls back to Average for
// them; labeled here so that's visible without reading the backend code.
const ALGORITHM_OPTIONS = [
  { value: 0, label: 'Media' },
  { value: 1, label: 'Totale (somma)' },
  { value: 2, label: 'Campione (ultimo valore)' },
  { value: 3, label: 'Or bit a bit' },
  { value: 4, label: 'Velocità vento vettoriale (non supportato — fallback a Media)' },
  { value: 5, label: 'Direzione vento vettoriale (non supportato — fallback a Media)' },
  { value: 6, label: 'Differenza ultimo e primo valore' },
  { value: 7, label: 'Massimo' },
  { value: 8, label: 'Minimo' },
  { value: 9, label: 'Tipo precipitazione (non supportato — fallback a Media)' },
]

export const CHANNEL_FIELD_GROUPS: FieldGroupDef<OpasChannel>[] = [
  {
    title: 'Identità',
    fields: [
      { key: 'id', label: 'ID', kind: 'number' },
      { key: 'name', label: 'Nome', kind: 'text' },
      { key: 'active', label: 'Attivo', kind: 'boolean' },
      { key: 'type', label: 'Tipo (0=parametro)', kind: 'number' },
      { key: 'position', label: 'Posizione', kind: 'number' },
    ],
  },
  {
    title: 'Misura e formula',
    fields: [
      { key: 'unit', label: 'Unità', kind: 'text' },
      { key: 'decimals', label: 'Decimali', kind: 'number' },
      { key: 'algorithm', label: 'Algoritmo', kind: 'select', options: ALGORITHM_OPTIONS },
      { key: 'formule', label: 'Formula', kind: 'text' },
      { key: 'dataFormule', label: 'Formula dati', kind: 'text' },
      { key: 'dataType', label: 'Tipo dato', kind: 'number' },
    ],
  },
  {
    title: 'Medie, soglie e limiti',
    fields: [
      { key: 'meanInterval', label: 'Intervallo media (s)', kind: 'number' },
      { key: 'readingsMinPercentage', label: '% minima letture', kind: 'number' },
      { key: 'detectionLimit', label: 'Limite rilevazione', kind: 'number' },
      { key: 'allowedMinValue', label: 'Valore minimo consentito', kind: 'number' },
      { key: 'allowedMaxValue', label: 'Valore massimo consentito', kind: 'number' },
      { key: 'allowedMinMean', label: 'Media minima consentita', kind: 'number' },
      { key: 'negativeValueSetToZero', label: 'Azzera valori negativi', kind: 'boolean' },
    ],
  },
  {
    title: 'Storage e identificativi',
    fields: [
      { key: 'storeCsv', label: 'Salva su CSV', kind: 'boolean' },
      { key: 'databaseId', label: 'ID database', kind: 'number' },
      { key: 'parameterId', label: 'ID parametro', kind: 'number' },
      { key: 'parameterNote', label: 'Nota parametro', kind: 'text' },
    ],
  },
  {
    title: 'Indirizzamento e registri',
    fields: [
      { key: 'address', label: 'Indirizzo', kind: 'text' },
      { key: 'addressCalibration', label: 'Indirizzo calibrazione', kind: 'number' },
      { key: 'regularExpression', label: 'Espressione regolare', kind: 'text' },
      { key: 'registerId', label: 'ID registro', kind: 'number' },
      { key: 'registerFunctionCode', label: 'Codice funzione registro', kind: 'number' },
      { key: 'registerOrder', label: 'Ordine registro', kind: 'number' },
      { key: 'registerType', label: 'Tipo registro', kind: 'number' },
      { key: 'registerQuantity', label: 'Quantità registro', kind: 'number' },
      { key: 'dataArrayIdx', label: 'Indice array dati', kind: 'number' },
    ],
  },
]
