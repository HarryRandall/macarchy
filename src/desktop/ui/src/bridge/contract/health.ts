export interface HealthState {
  checks: {
    id: string;
    group: "Dependencies" | "Services" | "Configuration" | "Optional";
    title: string;
    status: "passed" | "warning" | "failed" | "unknown";
    detail: string;
    /** What to do, in words. Shown as text, never copied. */
    advice: string | null;
    /** A shell command to paste into Terminal. */
    command: string | null;
    /** The file to correct by hand, as a home-relative path. */
    file: string | null;
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
  "health.copyCommand": { params: { id: string }; result: null };
  "health.openFile": { params: { id: string }; result: null };
  "health.revealSettings": { params: Record<string, never>; result: null };
}
export type HealthEvent = { type: "health.changed" };
