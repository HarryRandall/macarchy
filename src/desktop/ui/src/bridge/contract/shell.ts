/** The settings window shell part of the bridge contract; see `../protocol.ts`. */

import type { PaneId, Rect } from "../protocol";

export interface ShellState {
  /** The React page the sidebar last selected. The classic window keeps its own. */
  selectedPane: PaneId;
  sidebarVisible: boolean;
  /** Settings have never been written; the classic window runs setup. */
  setupRequired: boolean;
  appearance: Appearance;
  services: { running: number; total: number };
}

export interface Appearance {
  /** `#rrggbb`: the active theme's accent, or the system accent. */
  accent: string;
}

export interface ShellMethods {
  "shell.getState": { params: Record<string, never>; result: ShellState };
  "shell.setPreferences": {
    params: { selectedPane?: PaneId; sidebarVisible?: boolean };
    result: null;
  };
  /**
   * Opens the SwiftUI window at a pane that has not moved to React yet,
   * optionally with its search palette or console showing.
   */
  "shell.openClassic": {
    params: { pane?: PaneId; show?: "search" | "console" };
    result: null;
  };
  /**
   * Where the top bar is and which parts of it are controls. Mouse-downs in
   * the bar outside those rects drag the window; double-clicks zoom it.
   */
  "shell.setTitlebar": { params: { height: number; controls: Rect[] }; result: null };
}

export type ShellEvent = { type: "shell.changed"; state: ShellState };
