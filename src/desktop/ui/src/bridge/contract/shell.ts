/** The settings window shell part of the bridge contract; see `../protocol.ts`. */

import type { PaneId, Rect } from "../protocol";
import type { ServiceId } from "./advanced";

export interface ShellState {
  /** The page the sidebar last selected. */
  selectedPane: PaneId;
  sidebarVisible: boolean;
  /** Settings have never been written; the setup flow runs first. */
  setupRequired: boolean;
  appearance: Appearance;
  services: { running: number; total: number };
  /** The app's version, such as "0.9.2". */
  version: string;
  /** Each desktop service and whether it is running. */
  serviceList: { id: ServiceId; name: string; state: "running" | "stopped" | "unknown" }[];
}

export type AppearanceMode = "system" | "light" | "dark";

export interface Appearance {
  /** `#rrggbb`: the active theme's accent, or the system accent. */
  accent: string;
  /** The settings window's light or dark choice; the host applies it to the window too. */
  mode: AppearanceMode;
}

export interface LogEntry {
  id: string;
  command: string;
  detail: string;
  ok: boolean;
  /** Seconds since the Unix epoch. */
  at: number;
  /** The command's exit status, or null for activity that ran no command. */
  status: number | null;
  category:
    | "Menu Bar"
    | "Borders"
    | "Themes"
    | "Shortcuts"
    | "Window Rules"
    | "Layout"
    | "Backups"
    | "System";
}

export interface ShellMethods {
  "shell.getState": { params: Record<string, never>; result: ShellState };
  "shell.setPreferences": {
    params: { selectedPane?: PaneId; sidebarVisible?: boolean; appearance?: AppearanceMode };
    result: null;
  };
  /**
   * Where the top bar is and which parts of it are controls. Mouse-downs in
   * the bar outside those rects drag the window; double-clicks zoom it.
   */
  "shell.setTitlebar": { params: { height: number; controls: Rect[] }; result: null };
  /** The session's activity, oldest first. */
  "shell.getLog": { params: Record<string, never>; result: { entries: LogEntry[] } };
  "shell.clearLog": { params: Record<string, never>; result: null };
  /** Restarts every service in turn, as the status menu does. */
  "shell.restartAll": { params: Record<string, never>; result: { outcome: string } };
  /** Shows the settings folder in Finder. */
  "shell.revealSettings": { params: Record<string, never>; result: null };
  /** Ends the app, menu bar item included. The reply may never arrive. */
  "shell.quit": { params: Record<string, never>; result: null };
}

/** The window's own shortcuts. ⌘Q is the app menu's, so it is not here. */
export type ShellShortcut =
  "palette" | "sidebar" | "back" | "forward" | "shortcuts" | "logs" | "reload" | "folder";

export type ShellEvent =
  | { type: "shell.changed"; state: ShellState }
  /** The log changed; read it again with `shell.getLog`. */
  | { type: "shell.logChanged" }
  /** A shortcut chosen from the app menu, whose key equivalents can reach AppKit first. */
  | { type: "shell.shortcut"; state: { shortcut: ShellShortcut } };
