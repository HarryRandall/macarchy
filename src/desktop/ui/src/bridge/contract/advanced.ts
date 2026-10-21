export type ServiceId = "yabai" | "borders" | "sketchybar" | "skhd";
export type GeneratedFileId = "bordersrc" | "yabairc" | "sketchybarrc";
export type ExistingSetup = "keep" | "replace";
export interface AdvancedState {
  services: { id: ServiceId; state: "running" | "stopped" | "unknown" }[];
  snapshots: { id: string; created: number; files: number; reason: string }[];
  theme: string;
  installedThemes: number;
  addition: "active" | "missing" | "repair";
  additionExplanation: string;
  wakeHelpers: boolean;
  backupsDirectory: string;
}
export interface SetupState {
  tools: {
    id: ServiceId;
    name: string;
    role: string;
    installed: boolean;
    installCommand: string;
  }[];
  changes: { path: string; action: string; detail: string }[];
  hasExisting: boolean;
  canClose: boolean;
}
export interface SetupReport {
  lines: string[];
  failures: string[];
}
export interface AdvancedMethods {
  "advanced.getState": { params: Record<string, never>; result: AdvancedState };
  "advanced.restartService": { params: { daemon: ServiceId }; result: null };
  "advanced.stopService": { params: { daemon: ServiceId }; result: null };
  "advanced.rebuild": { params: { file: GeneratedFileId }; result: { outcome: string } };
  "advanced.restoreSnapshot": { params: { id: string }; result: null };
  "advanced.repairAddition": { params: Record<string, never>; result: null };
  "advanced.restoreOriginals": { params: Record<string, never>; result: SetupReport };
  "setup.getPlan": { params: { existing: ExistingSetup }; result: SetupState };
  "setup.run": { params: { existing: ExistingSetup }; result: SetupReport };
  "setup.openAccessibility": { params: Record<string, never>; result: null };
}
export type AdvancedEvent =
  { type: "advanced.changed"; state: AdvancedState } | { type: "advanced.invalidated" };
