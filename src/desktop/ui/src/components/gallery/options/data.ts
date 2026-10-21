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

/** Shared mock content so every direction shows the same settings. */
export type Appearance = "light" | "dark";
export interface OptionProps {
  appearance: Appearance;
  /** Lets a mockup's own controls, such as an app menu, switch the appearance. */
  onAppearanceChange?: (appearance: Appearance) => void;
}

export type MockPaneId =
  | "home"
  | "workshop"
  | "plugins"
  | "themes"
  | "borders"
  | "menuBar"
  | "layout"
  | "rules"
  | "shortcuts"
  | "health"
  | "advanced"
  | "report";

export const panes: Record<MockPaneId, { title: string; icon: LucideIcon }> = {
  home: { title: "Home", icon: House },
  workshop: { title: "Workshop", icon: LayoutGrid },
  plugins: { title: "Plugins", icon: Puzzle },
  themes: { title: "Themes", icon: Palette },
  borders: { title: "Borders", icon: SquareDashed },
  menuBar: { title: "Menu Bar", icon: PanelTop },
  layout: { title: "Layout", icon: LayoutPanelLeft },
  rules: { title: "Rules", icon: Flag },
  shortcuts: { title: "Shortcuts", icon: Command },
  health: { title: "Setup health", icon: Stethoscope },
  advanced: { title: "Advanced", icon: Settings },
  report: { title: "Report a problem", icon: Bug },
};

export const overview: MockPaneId[] = ["home", "workshop", "plugins"];
export const groups: { title: string; panes: MockPaneId[] }[] = [
  { title: "Appearance", panes: ["themes", "borders", "menuBar"] },
  { title: "Behaviour", panes: ["layout", "rules", "shortcuts"] },
  { title: "System", panes: ["health", "advanced", "report"] },
];

/** Panes every direction mocks in full; the rest show a short placeholder. */
export const mocked: MockPaneId[] = [
  "home",
  "themes",
  "borders",
  "layout",
  "rules",
  "shortcuts",
  "health",
];

export const themes = [
  {
    name: "Tokyo Night",
    accent: "#7aa2f7",
    bg: "#1a1b26",
    fg: "#c0caf5",
    swatches: ["#f7768e", "#9ece6a", "#e0af68", "#7aa2f7", "#bb9af7"],
  },
  {
    name: "Catppuccin",
    accent: "#cba6f7",
    bg: "#1e1e2e",
    fg: "#cdd6f4",
    swatches: ["#f38ba8", "#a6e3a1", "#f9e2af", "#89b4fa", "#cba6f7"],
  },
  {
    name: "Gruvbox",
    accent: "#d79921",
    bg: "#282828",
    fg: "#ebdbb2",
    swatches: ["#cc241d", "#98971a", "#d79921", "#458588", "#b16286"],
  },
  {
    name: "Nord",
    accent: "#88c0d0",
    bg: "#2e3440",
    fg: "#eceff4",
    swatches: ["#bf616a", "#a3be8c", "#ebcb8b", "#81a1c1", "#b48ead"],
  },
  {
    name: "Rosé Pine",
    accent: "#ebbcba",
    bg: "#191724",
    fg: "#e0def4",
    swatches: ["#eb6f92", "#31748f", "#f6c177", "#9ccfd8", "#c4a7e7"],
  },
  {
    name: "Everforest",
    accent: "#a7c080",
    bg: "#2d353b",
    fg: "#d3c6aa",
    swatches: ["#e67e80", "#a7c080", "#dbbc7f", "#7fbbb3", "#d699b6"],
  },
  {
    name: "Kanagawa",
    accent: "#7e9cd8",
    bg: "#1f1f28",
    fg: "#dcd7ba",
    swatches: ["#c34043", "#76946a", "#c0a36e", "#7e9cd8", "#957fb8"],
  },
  {
    name: "Matte Black",
    accent: "#e68e0d",
    bg: "#121212",
    fg: "#bebebe",
    swatches: ["#d35f5f", "#a4a4a4", "#e68e0d", "#8a8a8d", "#bebebe"],
  },
];

export const services = [
  { name: "AeroSpace", detail: "Tiling window manager", state: "running" as const },
  { name: "SketchyBar", detail: "Menu bar", state: "running" as const },
  { name: "JankyBorders", detail: "Window borders", state: "running" as const },
  { name: "skhd", detail: "Hotkey daemon", state: "stopped" as const },
];

export const rules = [
  { app: "Finder", bundle: "com.apple.finder", action: "Float", workspace: "Any" },
  {
    app: "Slack",
    bundle: "com.tinyspeck.slackmacgap",
    action: "Move to workspace",
    workspace: "3",
  },
  { app: "Spotify", bundle: "com.spotify.client", action: "Move to workspace", workspace: "9" },
  {
    app: "System Settings",
    bundle: "com.apple.systempreferences",
    action: "Float",
    workspace: "Any",
  },
  { app: "Ghostty", bundle: "com.mitchellh.ghostty", action: "Tile", workspace: "1" },
];

export const shortcuts = [
  {
    group: "Windows",
    items: [
      { action: "Focus left / right", keys: ["⌥", "H / L"] },
      { action: "Move window", keys: ["⌥", "⇧", "H J K L"] },
      { action: "Toggle floating", keys: ["⌥", "⇧", "Space"] },
      { action: "Fullscreen", keys: ["⌥", "F"] },
    ],
  },
  {
    group: "Workspaces",
    items: [
      { action: "Go to workspace", keys: ["⌥", "1–9"] },
      { action: "Send window to workspace", keys: ["⌥", "⇧", "1–9"] },
      { action: "Previous workspace", keys: ["⌥", "Tab"] },
    ],
  },
  {
    group: "Macarchy",
    items: [
      { action: "Theme switcher", keys: ["⌥", "⇧", "T"] },
      { action: "Open settings", keys: ["⌥", ","] },
      { action: "Launcher", keys: ["⌘", "Space"] },
    ],
  },
];

export const healthChecks = [
  { name: "Homebrew", detail: "4.6.2", ok: true },
  { name: "AeroSpace config", detail: "Generated, up to date", ok: true },
  { name: "Accessibility permission", detail: "Granted to AeroSpace", ok: true },
  { name: "JankyBorders", detail: "Running, version 1.8", ok: true },
  { name: "skhd", detail: "Installed but not running", ok: false },
  { name: "Login items", detail: "3 of 4 registered", ok: false },
];

export const layout = {
  gaps: { inner: 8, outer: 12 },
  modes: ["Tiles", "Accordion", "Floating"],
  orientation: ["Auto", "Horizontal", "Vertical"],
  workspaces: 9,
};

export const borders = {
  width: 5,
  radius: 11,
  active: "#7aa2f7",
  inactive: "#414868",
  styles: ["Round", "Square"],
};
