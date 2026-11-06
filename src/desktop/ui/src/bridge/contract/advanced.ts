export type ServiceId = "yabai" | "borders" | "sketchybar" | "skhd";
export type GeneratedFileId = "bordersrc" | "yabairc" | "sketchybarrc";
export type ExistingSetup = "keep" | "replace";
/** Whether Macarchy opens at login. `approval` waits on System Settings; `unavailable` is a development run. */
export type LoginItemState = "on" | "off" | "approval" | "unavailable";
export interface AdvancedState {
  services: { id: ServiceId; state: "running" | "stopped" | "unknown" }[];
  snapshots: { id: string; created: number; files: number; reason: string }[];
  theme: string;
  installedThemes: number;
  /** `unavailable` is a development run, which never offers a repair. */
  addition: "active" | "missing" | "repair" | "unavailable";
  additionExplanation: string;
  wakeHelpers: boolean;
  backupsDirectory: string;
  loginItem: LoginItemState;
  /** Whether the trackpad's sideways swipe between desktops switches at once instead of sliding. */
  trackpadSwipes: boolean;
  /** Tools Macarchy installed with Homebrew and still there, which restoring may also remove. */
  removableTools: { id: string; name: string }[];
}
export interface SetupTool {
  id: ServiceId;
  name: string;
  /** One line on what it does. */
  description: string;
  installed: boolean;
  /** Ticked to begin with: chosen in the last setup, or every tool before the first. */
  chosen: boolean;
  /** The person's own config the tool can start from, home-relative. */
  ownConfig: string | null;
}
/**
 * An app setup can install, which Macarchy uses when it is there. None ship
 * at the moment, and the page hides the section while the list is empty.
 */
export type SetupExtraId = string;
export interface SetupExtra {
  id: SetupExtraId;
  name: string;
  /** One line on what it does and where it goes. */
  description: string;
  installed: boolean;
}
/** What setup is asked to do. */
export interface SetupChoices {
  /** The tools to configure and start; the others are left alone. */
  tools: ServiceId[];
  /** How each tool with a config of its own starts; `keep` for any not given. */
  existing: Partial<Record<ServiceId, ExistingSetup>>;
  /** Extras to set up, installing them first if missing; none when left out. */
  extras?: SetupExtraId[];
}
export interface SetupState {
  tools: SetupTool[];
  extras: SetupExtra[];
  /** Whether Homebrew is installed, so setup can install missing tools. */
  homebrew: boolean;
  changes: { path: string; action: string; detail: string }[];
  canClose: boolean;
}
/** One step of installing tools during `setup.run`, sent as it happens. */
export interface SetupProgress {
  /** The tool or extra being installed, or null once setup moves on to its files. */
  tool: ServiceId | SetupExtraId | null;
  status: "installing" | "output" | "installed" | "failed" | "configuring";
  /** A line of Homebrew's output, or why installing failed. */
  line: string | null;
}
export interface SetupReport {
  lines: string[];
  failures: string[];
  /** Why setup stopped early. `lines` still lists what it changed first. */
  failure: string | null;
}
export interface AdvancedMethods {
  "advanced.getState": { params: Record<string, never>; result: AdvancedState };
  "advanced.restartService": { params: { daemon: ServiceId }; result: null };
  "advanced.stopService": { params: { daemon: ServiceId }; result: null };
  "advanced.rebuild": { params: { file: GeneratedFileId }; result: { outcome: string } };
  "advanced.restoreSnapshot": { params: { id: string }; result: null };
  "advanced.repairAddition": { params: Record<string, never>; result: null };
  "advanced.restoreOriginals": { params: { removeTools: string[] }; result: SetupReport };
  "advanced.setLoginItem": { params: { enabled: boolean }; result: null };
  "advanced.setTrackpadSwipes": { params: { enabled: boolean }; result: null };
  "advanced.openLoginItems": { params: Record<string, never>; result: null };
  "setup.getPlan": { params: SetupChoices; result: SetupState };
  /** Installs chosen tools that are missing, then sets up; see `setup.progress`. */
  "setup.run": { params: SetupChoices; result: SetupReport };
  /** Opens Homebrew's own installer in Terminal, which asks for a password. */
  "setup.installHomebrew": { params: Record<string, never>; result: null };
  "setup.openAccessibility": { params: Record<string, never>; result: null };
}
export type AdvancedEvent =
  | { type: "advanced.changed"; state: AdvancedState }
  | { type: "advanced.invalidated" }
  | { type: "setup.progress"; state: SetupProgress };
