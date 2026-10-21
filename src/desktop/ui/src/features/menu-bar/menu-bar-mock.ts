/**
 * Placeholder menu bar content from the Studio design. There is no bridge
 * for SketchyBar items or bar settings yet, so the page edits these in its
 * own state and the classic editor makes the real changes. Each use is
 * marked `Mock:`.
 */

export type Zone = "left" | "centre" | "right";

export const intervals = ["1s", "5s", "30s", "1m", "5m"] as const;
export type Interval = (typeof intervals)[number];

export type BarIconName =
  | "Activity"
  | "AppWindow"
  | "BatteryMedium"
  | "Bluetooth"
  | "CalendarDays"
  | "Clock"
  | "CloudSun"
  | "Coffee"
  | "Cpu"
  | "Globe"
  | "Gpu"
  | "HardDrive"
  | "Hash"
  | "Mail"
  | "MemoryStick"
  | "Music"
  | "Palette"
  | "PanelTop"
  | "Rocket"
  | "Terminal"
  | "Volume2"
  | "Wifi"
  | "Zap"
  | "macarchy";

export interface BarItem {
  id: string;
  label: string;
  zone: Zone;
  on: boolean;
  /** What the item shows in the preview. */
  sample: string;
  icon: BarIconName;
  custom?: { command: string; interval: Interval };
}

export const libraryCategories = ["System", "Workspaces", "Media", "Info", "Macarchy"] as const;
export type LibraryCategory = (typeof libraryCategories)[number];

export interface LibraryItem {
  id: string;
  name: string;
  icon: BarIconName;
  category: LibraryCategory;
  detail?: string;
  sample: string;
}

export const library: LibraryItem[] = [
  {
    id: "calendar",
    name: "Clock",
    icon: "Clock",
    category: "System",
    detail: "Date and time",
    sample: "Tue 21 Oct 17:24",
  },
  {
    id: "battery",
    name: "Battery",
    icon: "BatteryMedium",
    category: "System",
    detail: "Bolt while charging",
    sample: "84%",
  },
  {
    id: "wifi",
    name: "Wi-Fi",
    icon: "Wifi",
    category: "System",
    detail: "Network name and signal",
    sample: "Home 5G",
  },
  {
    id: "network",
    name: "Network",
    icon: "Activity",
    category: "System",
    detail: "Upload and download speed",
    sample: "1.2 MB/s",
  },
  {
    id: "bluetooth",
    name: "Bluetooth",
    icon: "Bluetooth",
    category: "System",
    detail: "Connected devices and their battery",
    sample: "AirPods",
  },
  {
    id: "volume",
    name: "Volume",
    icon: "Volume2",
    category: "System",
    detail: "Scroll to adjust",
    sample: "60%",
  },
  {
    id: "cpu",
    name: "CPU",
    icon: "Cpu",
    category: "System",
    detail: "Load across all cores",
    sample: "12%",
  },
  {
    id: "ram",
    name: "Memory",
    icon: "MemoryStick",
    category: "System",
    detail: "In use by apps",
    sample: "9.4 GB",
  },
  { id: "gpu", name: "GPU", icon: "Gpu", category: "System", sample: "7%" },
  {
    id: "disk",
    name: "Disk",
    icon: "HardDrive",
    category: "System",
    detail: "Free space on the startup disk",
    sample: "212 GB",
  },
  {
    id: "workspaces",
    name: "Workspaces",
    icon: "Hash",
    category: "Workspaces",
    detail: "yabai spaces",
    sample: "",
  },
  {
    id: "front_app",
    name: "Front app",
    icon: "AppWindow",
    category: "Workspaces",
    sample: "Ghostty",
  },
  {
    id: "window_title",
    name: "Window title",
    icon: "PanelTop",
    category: "Workspaces",
    sample: "zsh: ~/projects",
  },
  {
    id: "now_playing",
    name: "Now playing",
    icon: "Music",
    category: "Media",
    detail: "Music or Spotify, with play and pause",
    sample: "Veridis Quo",
  },
  {
    id: "weather",
    name: "Weather",
    icon: "CloudSun",
    category: "Info",
    detail: "Temperature and conditions",
    sample: "18° Cloudy",
  },
  {
    id: "next_event",
    name: "Calendar next event",
    icon: "CalendarDays",
    category: "Info",
    detail: "Time until your next meeting",
    sample: "Standup in 20m",
  },
  {
    id: "theme_switcher",
    name: "Theme switcher",
    icon: "Palette",
    category: "Macarchy",
    sample: "Theme",
  },
  {
    id: "macarchy",
    name: "Macarchy menu",
    icon: "macarchy",
    category: "Macarchy",
    detail: "Settings, reload and themes",
    sample: "",
  },
];

/** Glyphs offered for a custom item. */
export const customIcons: BarIconName[] = [
  "Terminal",
  "Activity",
  "Globe",
  "Zap",
  "Coffee",
  "Mail",
  "Rocket",
  "Music",
  "CloudSun",
  "HardDrive",
];

/** SketchyBar's default items as settings.json lists them, in order. */
const defaultItems: { id: string; side: "left" | "right"; visible: boolean }[] = [
  { id: "workspaces", side: "left", visible: true },
  { id: "network", side: "right", visible: true },
  { id: "ram", side: "right", visible: true },
  { id: "gpu", side: "right", visible: true },
  { id: "cpu", side: "right", visible: true },
  { id: "battery", side: "right", visible: true },
  { id: "calendar", side: "right", visible: true },
  { id: "macarchy", side: "right", visible: true },
];

export const initialItems: BarItem[] = defaultItems.map((item) => {
  const known = library.find((entry) => entry.id === item.id);
  return {
    id: item.id,
    label: known?.name ?? item.id,
    zone: item.side,
    on: item.visible,
    sample: known?.sample ?? "",
    icon: known?.icon ?? "AppWindow",
  };
});

export interface BarSettings {
  centre: boolean;
  height: number;
  padding: number;
  position: "top" | "bottom";
  hideNative: boolean;
}

export const initialBar: BarSettings = {
  centre: false,
  height: 35,
  padding: 10,
  position: "top",
  hideNative: true,
};
