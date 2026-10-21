import {
  Bug,
  Command,
  Flag,
  House,
  LayoutGrid,
  LayoutPanelLeft,
  type LucideIcon,
  Palette,
  PanelTop,
  Puzzle,
  Settings,
  SquareDashed,
  Stethoscope,
} from "lucide-react";

import type { PaneId } from "~/bridge/protocol";

import { pages } from "./pages";

export interface PaneInfo {
  id: PaneId;
  title: string;
  icon: LucideIcon;
}

/** Closest Lucide glyphs to the SF Symbols in Pane.swift. */
export const panes: Record<PaneId, PaneInfo> = {
  home: { id: "home", title: "Home", icon: House },
  workshop: { id: "workshop", title: "Workshop", icon: LayoutGrid },
  plugins: { id: "plugins", title: "Plugins", icon: Puzzle },
  themes: { id: "themes", title: "Themes", icon: Palette },
  borders: { id: "borders", title: "Borders", icon: SquareDashed },
  menuBar: { id: "menuBar", title: "Menu Bar", icon: PanelTop },
  layout: { id: "layout", title: "Layout", icon: LayoutPanelLeft },
  rules: { id: "rules", title: "Rules", icon: Flag },
  shortcuts: { id: "shortcuts", title: "Shortcuts", icon: Command },
  health: { id: "health", title: "Setup health", icon: Stethoscope },
  advanced: { id: "advanced", title: "Advanced", icon: Settings },
  report: { id: "report", title: "Report a problem", icon: Bug },
};

export const overview: PaneId[] = ["home", "workshop", "plugins"];

/** Concepts with nothing to download or install yet, labelled wherever they appear. */
export const previewPanes = new Set<PaneId>(["workshop", "plugins"]);

/** Grouped by what you are changing, not by which daemon owns it. */
export const groups: { title: string; panes: PaneId[] }[] = [
  { title: "Appearance", panes: ["themes", "borders", "menuBar"] },
  { title: "Behaviour", panes: ["layout", "rules", "shortcuts"] },
  { title: "System", panes: ["health", "advanced", "report"] },
];

/** Panes drawn by React so far; the rest open the classic window. */
export const reactPanes = new Set<PaneId>(pages.map((page) => page.id));

/** Shown when the saved pane is not, or no longer, a React page. */
const fallbackPane: PaneId = "home";

export function reactPaneFor(selected: PaneId): PaneId {
  return reactPanes.has(selected) ? selected : fallbackPane;
}
