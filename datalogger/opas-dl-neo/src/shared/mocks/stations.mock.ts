import type { StationConfig } from "../types/config.js";
export function createStationMock(
  overrides: Partial<StationConfig> = {}
): StationConfig {
  return {
    id: Math.floor(Math.random() * 1000),
    name: 'Stazione demo',
    desc: 'Mock station',
    lat: 0,
    long: 0,
    ...overrides
  };
}
