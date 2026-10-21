/**
 * Placeholder usage figures for the service-status panel. The host reports
 * whether each service runs, but not how long it has run or what it costs,
 * so these stand in until it does. Each use is marked `Mock:`.
 */
import type { ServiceId } from "~/bridge/protocol";

interface ServiceUsage {
  /** Minutes since the service started. */
  uptime: number;
  /** Resident memory in MB. */
  memory: number;
  /** CPU percentage every two minutes over the last hour, oldest first. */
  cpu: (number | null)[];
}

const points = 31;

function noise(seed: number, index: number) {
  const x = Math.sin(seed * 12.9898 + index * 78.233) * 43758.5453;
  return x - Math.floor(x);
}

function series(seed: number, base: number, swing: number, spikes: Record<number, number>) {
  return Array.from({ length: points }, (_, index) => {
    const value =
      base +
      swing * (0.6 * noise(seed, index) + 0.4 * noise(seed, index - 1)) +
      (spikes[index] ?? 0);
    return Math.round(value * 10) / 10;
  });
}

export const serviceUsage: Record<ServiceId, ServiceUsage> = {
  yabai: { uptime: 3124, memory: 42, cpu: series(1, 0.9, 1.3, { 14: 2.1, 29: 4.4 }) },
  sketchybar: { uptime: 3121, memory: 78, cpu: series(2, 1.8, 1.6, { 8: 2.6, 29: 7.4 }) },
  borders: { uptime: 372, memory: 38, cpu: series(3, 0.3, 0.5, { 22: 0.6, 29: 1.5 }) },
  skhd: {
    uptime: 12,
    memory: 9,
    cpu: Array.from({ length: points }, (_, index) =>
      index === points - 2 ? 0.8 : index === points - 1 ? 0.2 : null,
    ),
  },
};

/** Clock labels for the samples, ending at `now`. */
export function usageTimes(now: Date): string[] {
  return Array.from({ length: points }, (_, index) => {
    const at = new Date(now.getTime() - (points - 1 - index) * 2 * 60_000);
    return `${String(at.getHours()).padStart(2, "0")}:${String(at.getMinutes()).padStart(2, "0")}`;
  });
}

export function formatUptime(minutes: number): string {
  if (minutes < 1) return "just now";
  const days = Math.floor(minutes / 1440);
  const hours = Math.floor((minutes % 1440) / 60);
  const rest = minutes % 60;
  return days ? `${days}d ${hours}h` : hours ? `${hours}h ${rest}m` : `${rest}m`;
}
