import type { LayoutMode } from "./layout";

export interface HomeState {
  theme: string | null;
  themeCount: number;
  shortcutsCount: number;
  layout: LayoutMode;
  running: number;
  total: number;
  /** Seconds since the Unix epoch. */
  lastChange: number | null;
  wallpaper: string | null;
  subtitle: string;
}
export interface HomeMethods {
  "home.getState": { params: Record<string, never>; result: HomeState };
}
/** Invalidation: the summary is read again through its own core operation. */
export type HomeEvent = { type: "home.changed" };
