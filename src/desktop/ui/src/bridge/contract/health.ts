export interface HealthState {
  checks: {
    id: string;
    group: "Dependencies" | "Services" | "Configuration" | "Optional";
    title: string;
    status: "passed" | "warning" | "failed" | "unknown";
    detail: string;
    fix: string | null;
  }[];
  environment: {
    model: string;
    architecture: string;
    macOS: string;
    app: string;
    settingsFolder: string;
  };
  checkedAt: number;
}
export interface HealthMethods {
  "health.getState": { params: Record<string, never>; result: HealthState };
  "health.copyFix": { params: { id: string }; result: null };
  "health.revealSettings": { params: Record<string, never>; result: null };
}
export type HealthEvent = { type: "health.changed" };
