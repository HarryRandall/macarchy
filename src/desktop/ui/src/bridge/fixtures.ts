/**
 * Example messages for every bridge method and event, typed against the
 * contract so `tsc` fails when one has no fixture or a fixture stops fitting.
 * `fixtures.test.ts` keeps `tests/fixtures/bridge` in step with these, and
 * the Swift tests decode and re-encode that JSON with the host's own types,
 * so a field, enum value or explicit null changed on one side fails a test.
 *
 * Across the cases for each type, every nullable field is null at least once
 * and set at least once, and every string-literal union value appears.
 */
import type {
  AdvancedState,
  BorderAppearance,
  BordersState,
  BridgeEvent,
  BridgeMethod,
  CustomWindowRule,
  HealthState,
  HomeState,
  LayoutState,
  MenuBarItemState,
  MenuBarState,
  LogEntry,
  ParamsOf,
  ResultOf,
  RulesState,
  SetupReport,
  SetupState,
  ShellState,
  ShortcutBinding,
  ShortcutsState,
  SwitcherState,
  ThemeDetail,
  ThemesState,
  ThemeSummary,
  WidgetInfo,
} from "./protocol";

type Cases<T> = [T, ...T[]];

export interface MethodCase<M extends BridgeMethod> {
  params: ParamsOf<M>;
  result: ResultOf<M>;
}

export type EventOf<T extends BridgeEvent["type"]> = Extract<BridgeEvent, { type: T }>;

export type MethodFixtures = { [M in BridgeMethod]: Cases<MethodCase<M>> };
export type EventFixtures = { [T in BridgeEvent["type"]]: Cases<EventOf<T>> };

const icon =
  "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==";
const wallpaper = "macarchy-app://media/wallpaper?max=1400&v=3fa2c19e";

const shell: ShellState = {
  selectedPane: "home",
  sidebarVisible: true,
  setupRequired: false,
  appearance: { accent: "#61afef", mode: "system" },
  services: { running: 4, total: 4 },
  version: "0.9.2",
  serviceList: [
    { id: "yabai", name: "yabai", state: "running" },
    { id: "borders", name: "borders", state: "running" },
    { id: "sketchybar", name: "SketchyBar", state: "running" },
    { id: "skhd", name: "skhd", state: "running" },
  ],
};

const shellBeforeSetup: ShellState = {
  selectedPane: "layout",
  sidebarVisible: false,
  setupRequired: true,
  appearance: { accent: "#0a84ff", mode: "dark" },
  services: { running: 0, total: 4 },
  version: "development build",
  serviceList: [
    { id: "yabai", name: "yabai", state: "stopped" },
    { id: "borders", name: "borders", state: "stopped" },
    { id: "sketchybar", name: "SketchyBar", state: "unknown" },
    { id: "skhd", name: "skhd", state: "stopped" },
  ],
};

const log: LogEntry[] = [
  {
    id: "3B2F1A0E-5C4D-4E6F-8A9B-0C1D2E3F4A5B",
    command: "/opt/homebrew/bin/sketchybar --reload",
    detail: "",
    ok: true,
    at: 1792570500,
    status: 0,
    category: "Menu Bar",
  },
  {
    id: "4C3A2B1F-6D5E-4F7A-9B0C-1D2E3F4A5B6C",
    command: "borders appearance",
    detail: "",
    ok: true,
    at: 1792570502,
    status: 0,
    category: "Borders",
  },
  {
    id: "5D4B3C2A-7E6F-4A8B-8C1D-2E3F4A5B6C7D",
    command: "theme lumon",
    detail: "Standard error:\nThe wallpaper could not be set.",
    ok: false,
    at: 1792570504,
    status: 1,
    category: "Themes",
  },
  {
    id: "6E5C4D3B-8F7A-4B9C-9D2E-3F4A5B6C7D8E",
    command: "open skhdrc",
    detail: "~/.config/skhd/skhdrc",
    ok: true,
    at: 1792570506,
    status: null,
    category: "Shortcuts",
  },
  {
    id: "7F6D5E4C-9A8B-4C0D-8E3F-4A5B6C7D8E9F",
    command: "window rules",
    detail: "",
    ok: true,
    at: 1792570508,
    status: 0,
    category: "Window Rules",
  },
  {
    id: "8A7E6F5D-0B9C-4D1E-9F4A-5B6C7D8E9F0A",
    command: "read layout",
    detail: "yabai-msg: failed to connect",
    ok: false,
    at: 1792570510,
    status: null,
    category: "Layout",
  },
  {
    id: "9B8F7A6E-1C0D-4E2F-8A5B-6C7D8E9F0A1B",
    command: "restore backup",
    detail: "Completed",
    ok: true,
    at: 1792570512,
    status: null,
    category: "Backups",
  },
  {
    id: "0C9A8B7F-2D1E-4F3A-9B6C-7D8E9F0A1B2C",
    command: "health check",
    detail: "18 checks completed",
    ok: true,
    at: 1792570514,
    status: null,
    category: "System",
  },
];

const layoutFromDaemon: LayoutState = {
  values: {
    layout: "bsp",
    splitType: "auto",
    windowPlacement: "second_child",
    autoBalance: false,
    windowGap: 8,
    padding: 8,
    mouseModifier: "ctrl",
    mouseFollowsFocus: false,
    mouseDropAction: "stack",
  },
  source: "daemon",
  unavailableReason: null,
  wallpaper,
};

const layoutFromSettings: LayoutState = {
  values: {
    layout: "stack",
    splitType: "vertical",
    windowPlacement: "first_child",
    autoBalance: true,
    windowGap: 12,
    padding: 20,
    mouseModifier: "alt",
    mouseFollowsFocus: true,
    mouseDropAction: "swap",
  },
  source: "saved",
  unavailableReason:
    "yabai is not running, so these are your saved settings. Start yabai from Advanced to change them.",
  wallpaper: null,
};

const clock: MenuBarItemState = {
  id: "calendar",
  title: "Clock",
  zone: "right",
  visible: true,
  kind: null,
  text: "",
  icon: "",
  command: null,
  interval: null,
  widget: null,
  settings: {},
  style: null,
  click: null,
  reading: "Thu 23 Oct 14:05",
};

const uptime: MenuBarItemState = {
  id: "macarchy.uptime-1",
  title: "Uptime",
  zone: "centre",
  visible: true,
  kind: "command",
  text: "",
  icon: "↑",
  command: "uptime | cut -d, -f1",
  interval: 60,
  widget: null,
  settings: {},
  style: null,
  click: null,
  reading: "",
};

const cpuWidget: MenuBarItemState = {
  id: "macarchy.cpu",
  title: "CPU",
  zone: "right",
  visible: true,
  kind: "widget",
  text: "",
  icon: "",
  command: null,
  interval: null,
  widget: "cpu",
  settings: { temperature: false },
  style: { box: "fill", radius: 6 },
  click: { open: "Activity Monitor" },
  reading: "12.0%",
};

const clockInfo: WidgetInfo = {
  id: "clock",
  name: "Clock",
  description: "The date and time, in any format.",
  author: "Macarchy",
  version: "1.0.0",
  icon: "􀧞",
  origin: "builtIn",
  scripted: false,
  folder: "/Applications/Macarchy.app/Contents/Resources/widgets/clock",
  files: ["widget.json"],
  manifest: '{\n  "schema": 1,\n  "id": "clock"\n}\n',
  label: "{date}",
  source: "date",
  settings: [
    { key: "seconds", type: "toggle", label: "Seconds", default: false, hint: "Every second" },
    {
      key: "order",
      type: "choice",
      label: "Date order",
      options: ["day-month", "month-day"],
      default: "day-month",
    },
    { key: "size", type: "number", label: "Size", min: 1, max: 9, step: 1, unit: "pt" },
  ],
  style: { box: "none", size: 13 },
  click: {
    dropdown: [
      { type: "heading", label: "{weekday.long} {day}" },
      { type: "reading", label: "London", value: "{time:Europe/London}" },
      { type: "divider" },
      { type: "toggle", label: "Seconds", setting: "seconds" },
      { type: "choice", label: "Order", setting: "order", options: ["day-month", "month-day"] },
      { type: "action", label: "Open Calendar", open: "Calendar" },
    ],
  },
  update: { every: "minute", events: ["system_woke"] },
  samples: { widest: "Wed 30 Sep 12:59 PM", unavailable: "--" },
};

const uptimeInfo: WidgetInfo = {
  id: "uptime",
  name: "Uptime",
  version: "0.1.0",
  origin: "user",
  scripted: true,
  folder: "~/.config/macarchy/widgets/uptime",
  files: ["provider.sh", "widget.json"],
  manifest: '{ "schema": 1, "id": "uptime" }\n',
  provider: "provider.sh",
  settings: [],
  update: { every: "1m" },
};

const menuBar: MenuBarState = {
  items: [clock, uptime, cpuWidget],
  bar: { height: 35, position: "top", padding: 10 },
  widgets: [clockInfo, uptimeInfo],
  unavailableReason: null,
};

const menuBarStopped: MenuBarState = {
  items: [],
  bar: { height: 35, position: "top", padding: 10 },
  widgets: [],
  unavailableReason: "sketchybar is not running.",
};

const awakening: ThemeSummary = {
  name: "awakening",
  title: "Awakening",
  isDark: true,
  ring: "#61afef",
  colours: {
    background: "#11131a",
    foreground: "#d7dae0",
    red: "#e06c75",
    green: "#98c379",
    blue: "#61afef",
    cyan: "#56b6c2",
  },
  currentBackground: "backgrounds/1-first-light.png",
  preview: "macarchy-app://media/theme/awakening/backgrounds/1-first-light.png?max=1400",
  backgrounds: [
    {
      path: "backgrounds/1-first-light.png",
      name: "First Light",
      thumbnail: "macarchy-app://media/theme/awakening/backgrounds/1-first-light.png?max=700",
    },
    {
      path: "backgrounds/2-hand-of-adam.png",
      name: "Hand Of Adam",
      thumbnail: "macarchy-app://media/theme/awakening/backgrounds/2-hand-of-adam.png?max=700",
    },
  ],
};

/** An imported theme with no Ghostty palette and no images. */
const paper: ThemeSummary = {
  name: "paper",
  title: "Paper",
  isDark: false,
  ring: "#0a84ff",
  colours: null,
  currentBackground: null,
  preview: null,
  backgrounds: [],
};

const switcher: SwitcherState = { themes: [awakening, paper], current: "awakening" };
const switcherWithoutTheme: SwitcherState = { themes: [paper], current: null };

const finderRule: CustomWindowRule = {
  id: "6F1C2A3B-4D5E-4F60-8A7B-9C0D1E2F3A4B",
  app: "Finder",
  title: "^Copy$",
};

const rules: RulesState = {
  floatingApps: ["Calculator", "Messages"],
  customRules: [finderRule],
  externalRules: [{ app: "System Settings", title: "" }],
  icons: { Calculator: icon, Messages: icon },
  unavailableReason: null,
};

const savedRules: RulesState = {
  floatingApps: ["Messages"],
  customRules: [],
  externalRules: [],
  icons: { Messages: icon },
  unavailableReason:
    "yabai isn't responding, so these are your saved rules. Editing is off because rules apply through yabai.",
};

const advanced: AdvancedState = {
  services: [
    { id: "yabai", state: "running" },
    { id: "borders", state: "running" },
    { id: "sketchybar", state: "stopped" },
    { id: "skhd", state: "unknown" },
  ],
  snapshots: [
    { id: "20261021-081500", created: 1792570500000, files: 3, reason: "Before applying Lumon" },
  ],
  theme: "lumon",
  installedThemes: 8,
  addition: "active",
  additionExplanation: "The scripting addition is loaded.",
  wakeHelpers: true,
  backupsDirectory: "~/.config/macarchy/backups",
};

const advancedBeforeSetup: AdvancedState = {
  services: [
    { id: "yabai", state: "stopped" },
    { id: "borders", state: "stopped" },
    { id: "sketchybar", state: "stopped" },
    { id: "skhd", state: "stopped" },
  ],
  snapshots: [],
  theme: "None",
  installedThemes: 0,
  addition: "missing",
  additionExplanation: "yabai is not installed, so there is no scripting addition to load.",
  wakeHelpers: false,
  backupsDirectory: "~/.config/macarchy/backups",
};

const tools: SetupState["tools"] = [
  {
    id: "yabai",
    name: "yabai",
    role: "Tiles windows",
    installed: true,
    installCommand: "brew install koekeishiya/formulae/yabai",
  },
  {
    id: "borders",
    name: "JankyBorders",
    role: "Draws window borders",
    installed: true,
    installCommand: "brew install FelixKratz/formulae/borders",
  },
  {
    id: "sketchybar",
    name: "SketchyBar",
    role: "Shows the menu bar",
    installed: false,
    installCommand: "brew install FelixKratz/formulae/sketchybar",
  },
  {
    id: "skhd",
    name: "skhd",
    role: "Runs keyboard shortcuts",
    installed: false,
    installCommand: "brew install koekeishiya/formulae/skhd",
  },
];

const keepPlan: SetupState = {
  tools,
  changes: [
    {
      path: "~/.config/yabai/yabairc",
      action: "create",
      detail: "Starts tiling with Macarchy's layout and rules",
    },
    {
      path: "~/.config/skhd/skhdrc",
      action: "adopt",
      detail: "Keeps your shortcuts and adds Macarchy's",
    },
  ],
  hasExisting: true,
  canClose: true,
};

const replacePlan: SetupState = {
  tools,
  changes: [
    {
      path: "~/.config/skhd/skhdrc",
      action: "replace",
      detail: "Backs up your shortcuts and starts from Macarchy's defaults",
    },
  ],
  hasExisting: true,
  canClose: false,
};

const setupCompleted: SetupReport = {
  lines: ["Installed themes", "Prepared startup files"],
  failures: [],
  failure: null,
};

const setupStopped: SetupReport = {
  lines: ["Installed themes", "Installed default shortcuts"],
  failures: ["sketchybar --reload exited with status 1"],
  failure:
    "Setup did not finish; some files may already have changed. The menu bar file could not be written.",
};

const borderAppearance: BorderAppearance = {
  width: 6,
  visible: true,
  excludedApps: ["iPhone Mirroring"],
  radius: null,
  activeColour: "0xff45e8ff",
  inactiveColour: null,
};

const borders: BordersState = {
  appearance: borderAppearance,
  applicationIcons: { "iPhone Mirroring": icon },
  theme: "awakening",
  defaults: {
    width: 4,
    visible: true,
    excludedApps: [],
    radius: 10,
    activeColour: "0xff61afef",
    inactiveColour: "0xff3b4048",
  },
  unavailableReason: null,
  wallpaper,
};

const bordersStopped: BordersState = {
  appearance: {
    width: 8,
    visible: false,
    excludedApps: [],
    radius: 12,
    activeColour: null,
    inactiveColour: "0x66494d64",
  },
  applicationIcons: {},
  theme: null,
  defaults: null,
  unavailableReason: "borders is not running.",
  wallpaper: null,
};

const home: HomeState = {
  theme: "lumon",
  themeCount: 8,
  shortcutsCount: 24,
  layout: "bsp",
  running: 3,
  total: 4,
  lastChange: 1792570500,
  wallpaper,
  subtitle: "A space that works for you.",
};

const homeBeforeSetup: HomeState = {
  theme: null,
  themeCount: 0,
  shortcutsCount: 0,
  layout: "float",
  running: 0,
  total: 4,
  lastChange: null,
  wallpaper: null,
  subtitle: "A space that works for you.",
};

const health: HealthState = {
  checks: [
    {
      id: "Dependencies/yabai",
      group: "Dependencies",
      title: "yabai",
      status: "passed",
      detail: "yabai 7.1.25 at /opt/homebrew/bin/yabai",
      fix: null,
    },
    {
      id: "Services/borders",
      group: "Services",
      title: "borders",
      status: "warning",
      detail: "Installed but not running",
      fix: "macarchy apply",
    },
    {
      id: "Configuration/Setup",
      group: "Configuration",
      title: "Setup",
      status: "failed",
      detail: "Macarchy has not been set up",
      fix: "Open Macarchy, or run: macarchy setup",
    },
    {
      id: "Optional/Scripting addition",
      group: "Optional",
      title: "Scripting addition",
      status: "unknown",
      detail: "The sudoers rule could not be read",
      fix: null,
    },
  ],
  environment: {
    model: "Mac15,6",
    architecture: "Apple Silicon",
    macOS: "26.1",
    app: "1.4.0 (142)",
    settingsFolder: "~/.config/macarchy",
  },
  checkedAt: 1792570500,
};

const awakeningDetail: ThemeDetail = {
  summary: awakening,
  values: {
    dark: true,
    borderActive: "0xff61afef",
    borderInactive: "0xff3b4048",
    sketchybarBar: "0xf011131a",
    sketchybarText: "0xffd7dae0",
    firefoxAccent: "#61afef",
    nvimColorscheme: "tokyonight",
  },
  modified: true,
  hasDefault: true,
  defaultColourscheme: "habamax",
  terminal: {
    background: "#11131a",
    foreground: "#d7dae0",
    cursor: "#d7dae0",
    ansi: [
      "#11131a",
      "#e06c75",
      "#98c379",
      "#e5c07b",
      "#61afef",
      "#c678dd",
      "#56b6c2",
      "#d7dae0",
      "#5c6370",
      "#e06c75",
      "#98c379",
      "#e5c07b",
      "#61afef",
      "#c678dd",
      "#56b6c2",
      "#ffffff",
    ],
  },
};

const paperDetail: ThemeDetail = {
  summary: paper,
  values: {
    dark: false,
    borderActive: null,
    borderInactive: null,
    sketchybarBar: null,
    sketchybarText: null,
    firefoxAccent: null,
    nvimColorscheme: null,
  },
  modified: false,
  hasDefault: false,
  defaultColourscheme: "default",
  terminal: null,
};

const themes: ThemesState = {
  themes: [awakeningDetail, paperDetail],
  current: "awakening",
  colourschemes: ["catppuccin", "habamax", "tokyonight"],
  warnings: [],
};

const paperThemes: ThemesState = {
  themes: [paperDetail],
  current: null,
  colourschemes: ["habamax"],
  warnings: ["broken-theme has no readable theme.json, so it is not listed."],
};

const terminalBinding: ShortcutBinding = {
  id: 1,
  modifiers: ["ctrl", "alt"],
  key: "return",
  caps: ["⌃", "⌥", "↩"],
  command: "open -na Ghostty",
  section: "Open a terminal",
  passthrough: false,
  appOverrides: [],
};

const focusBinding: ShortcutBinding = {
  id: 3,
  modifiers: ["ctrl", "alt"],
  key: "h",
  caps: ["⌃", "⌥", "H"],
  command: "yabai -m window --focus west",
  section: null,
  passthrough: true,
  appOverrides: [{ app: "Ghostty", command: "skhd -k 'ctrl + alt - h'" }],
};

const shortcuts: ShortcutsState = {
  revision: "5d41402abc4b2a76",
  bindings: [terminalBinding, focusBinding],
};

const shortcutsAfterEdit: ShortcutsState = {
  revision: "7d793037a0760186",
  bindings: [terminalBinding],
};

export const methodFixtures: MethodFixtures = {
  "app.ready": [
    { params: { surface: "settings" }, result: null },
    { params: { surface: "switcher" }, result: null },
  ],

  "shell.getState": [
    { params: {}, result: shell },
    { params: {}, result: shellBeforeSetup },
  ],
  "shell.setPreferences": [
    { params: { selectedPane: "borders", sidebarVisible: true }, result: null },
    { params: { selectedPane: "rules" }, result: null },
    { params: { selectedPane: "shortcuts" }, result: null },
    { params: { selectedPane: "health" }, result: null },
    { params: { selectedPane: "advanced" }, result: null },
    { params: { selectedPane: "report", sidebarVisible: false }, result: null },
    { params: { selectedPane: "menuBar", appearance: "light" }, result: null },
    { params: { appearance: "dark" }, result: null },
    { params: { appearance: "system" }, result: null },
    { params: {}, result: null },
  ],
  "shell.openClassic": [
    { params: { pane: "workshop", show: "search" }, result: null },
    { params: { pane: "plugins", show: "console" }, result: null },
    { params: { pane: "menuBar" }, result: null },
    { params: {}, result: null },
  ],
  "shell.setTitlebar": [
    {
      params: {
        height: 44,
        controls: [
          { x: 0, y: 0, width: 78, height: 44 },
          { x: 912, y: 6, width: 72, height: 32 },
        ],
      },
      result: null,
    },
  ],
  "shell.getLog": [
    { params: {}, result: { entries: log } },
    { params: {}, result: { entries: [] } },
  ],
  "shell.clearLog": [{ params: {}, result: null }],
  "shell.restartAll": [
    { params: {}, result: { outcome: "Restarted all 4 services." } },
    { params: {}, result: { outcome: "Restarted 3 of 4 services; skhd did not restart." } },
  ],
  "shell.revealSettings": [{ params: {}, result: null }],
  "shell.quit": [{ params: {}, result: null }],

  "layout.getState": [
    { params: {}, result: layoutFromDaemon },
    { params: {}, result: layoutFromSettings },
  ],
  "layout.apply": [
    {
      params: {
        changes: {
          layout: "float",
          splitType: "horizontal",
          windowPlacement: "first_child",
          autoBalance: true,
          windowGap: 16,
          padding: 12,
          mouseModifier: "shift",
          mouseFollowsFocus: true,
          mouseDropAction: "swap",
        },
        linkPadding: true,
      },
      result: null,
    },
    { params: { changes: { windowGap: 20 }, linkPadding: false }, result: null },
  ],

  "menuBar.getState": [
    { params: {}, result: menuBar },
    { params: {}, result: menuBarStopped },
  ],
  "menuBar.apply": [
    {
      params: {
        items: [
          {
            id: "calendar",
            title: "Clock",
            zone: "right",
            visible: false,
            kind: null,
            text: "",
            icon: "",
            command: null,
            interval: null,
            widget: null,
            settings: {},
            style: null,
            click: null,
          },
          {
            id: "macarchy.note-2",
            title: "Text",
            zone: "left",
            visible: true,
            kind: "text",
            text: "Hello",
            icon: "",
            command: null,
            interval: null,
            widget: null,
            settings: {},
            style: null,
            click: null,
          },
          {
            id: "macarchy.clock",
            title: "Clock",
            zone: "right",
            visible: true,
            kind: "widget",
            text: "",
            icon: "",
            command: null,
            interval: null,
            widget: "clock",
            settings: { seconds: true, order: "month-day" },
            style: { textColour: "accent", paddingLeft: 4 },
            click: { dropdown: [{ type: "text", label: "Hi" }] },
          },
        ],
        bar: { height: 30, position: "bottom", padding: 6 },
      },
      result: menuBar,
    },
  ],
  "menuBar.revealWidget": [
    { params: { widget: "clock" }, result: null },
    { params: { widget: null }, result: null },
  ],
  "menuBar.openWidgetFile": [{ params: { widget: "uptime", file: "provider.sh" }, result: null }],
  "menuBar.duplicateWidget": [
    { params: { widget: "clock" }, result: { state: menuBar, widget: "clock-copy" } },
  ],

  "switcher.getState": [{ params: {}, result: switcher }],
  "switcher.refresh": [{ params: {}, result: switcherWithoutTheme }],
  "switcher.applyTheme": [{ params: { theme: "awakening" }, result: null }],
  "switcher.useBackground": [
    { params: { theme: "awakening", path: "backgrounds/2-hand-of-adam.png" }, result: null },
  ],
  "switcher.openSettings": [{ params: {}, result: null }],
  "switcher.close": [{ params: {}, result: null }],

  "rules.getState": [
    { params: {}, result: rules },
    { params: {}, result: savedRules },
  ],
  "rules.addApplication": [{ params: {}, result: null }],
  "rules.removeFloating": [{ params: { app: "Calculator" }, result: null }],
  "rules.saveCustom": [
    { params: { rule: finderRule, existing: true }, result: null },
    {
      params: {
        rule: { id: "0B7E4C1D-2A3F-4E5B-9C6D-7E8F9A0B1C2D", app: "Preview", title: "" },
        existing: false,
      },
      result: null,
    },
  ],
  "rules.removeCustom": [{ params: { id: finderRule.id }, result: null }],

  "advanced.getState": [
    { params: {}, result: advanced },
    { params: {}, result: advancedBeforeSetup },
    {
      params: {},
      result: {
        ...advanced,
        addition: "unavailable",
        additionExplanation: "Development runs never change the real sudoers rule.",
      },
    },
  ],
  "advanced.restartService": [
    { params: { daemon: "yabai" }, result: null },
    { params: { daemon: "borders" }, result: null },
  ],
  "advanced.stopService": [
    { params: { daemon: "sketchybar" }, result: null },
    { params: { daemon: "skhd" }, result: null },
  ],
  "advanced.rebuild": [
    { params: { file: "bordersrc" }, result: { outcome: "Rebuilt" } },
    { params: { file: "yabairc" }, result: { outcome: "Up to date" } },
    { params: { file: "sketchybarrc" }, result: { outcome: "Edits backed up" } },
  ],
  "advanced.restoreSnapshot": [{ params: { id: "20261021-081500" }, result: null }],
  "advanced.repairAddition": [{ params: {}, result: null }],
  "advanced.restoreOriginals": [
    { params: {}, result: { lines: ["Restored original files"], failures: [], failure: null } },
  ],
  "setup.getPlan": [
    { params: { existing: "keep" }, result: keepPlan },
    { params: { existing: "replace" }, result: replacePlan },
  ],
  "setup.run": [
    { params: { existing: "keep" }, result: setupCompleted },
    { params: { existing: "replace" }, result: setupStopped },
  ],
  "setup.openAccessibility": [{ params: {}, result: null }],

  "borders.getState": [
    { params: {}, result: borders },
    { params: {}, result: bordersStopped },
  ],
  "borders.apply": [
    {
      params: { appearance: borderAppearance, theme: "awakening" },
      result: null,
    },
  ],
  "borders.pickApplication": [
    { params: {}, result: { name: "Zoom", icon } },
    { params: {}, result: { name: "Steam", icon: null } },
    { params: {}, result: null },
  ],

  "home.getState": [
    { params: {}, result: home },
    { params: {}, result: homeBeforeSetup },
  ],

  "health.getState": [{ params: {}, result: health }],
  "health.copyFix": [{ params: { id: "Configuration/Setup" }, result: null }],
  "health.revealSettings": [{ params: {}, result: null }],

  "report.prepare": [
    {
      params: { description: "Borders vanish after waking from sleep.", refresh: true },
      result: {
        body: "## What happened\n\nBorders vanish after waking from sleep.\n\n## Environment\n\nMac15,6, macOS 26.1",
        token: "2C1D7F5E-8A4B-4C3D-9E2F-1A0B3C4D5E6F",
      },
    },
    {
      params: { description: "", refresh: false },
      result: {
        body: "## What happened\n\n_Not described_\n\n## Environment\n\nMac15,6, macOS 26.1",
        token: "9A8B7C6D-5E4F-4A3B-8C2D-1E0F9A8B7C6D",
      },
    },
  ],
  "report.copy": [{ params: { token: "2C1D7F5E-8A4B-4C3D-9E2F-1A0B3C4D5E6F" }, result: null }],
  "report.openIssue": [
    {
      params: {
        token: "2C1D7F5E-8A4B-4C3D-9E2F-1A0B3C4D5E6F",
        title: "Borders vanish after sleep",
      },
      result: { copied: false },
    },
    {
      params: { token: "9A8B7C6D-5E4F-4A3B-8C2D-1E0F9A8B7C6D", title: "Setup stops early" },
      result: { copied: true },
    },
  ],
  "report.openIssues": [{ params: {}, result: null }],

  "themes.getState": [{ params: {}, result: themes }],
  "themes.setDark": [{ params: { theme: "paper", dark: true }, result: paperThemes }],
  "themes.setColour": [
    {
      params: { theme: "paper", colour: "borderActive", value: "0xff2f6f9f" },
      result: paperThemes,
    },
    {
      params: { theme: "paper", colour: "borderInactive", value: "0xff8a8a8d" },
      result: paperThemes,
    },
    {
      params: { theme: "paper", colour: "sketchybarBar", value: "0xf0e8ecef" },
      result: paperThemes,
    },
    {
      params: { theme: "paper", colour: "sketchybarText", value: "0xff1f2a33" },
      result: paperThemes,
    },
    {
      params: { theme: "paper", colour: "firefoxAccent", value: "#2f6f9f" },
      result: paperThemes,
    },
  ],
  "themes.setColourscheme": [
    { params: { theme: "paper", value: "habamax" }, result: paperThemes },
    { params: { theme: "paper", value: null }, result: paperThemes },
  ],
  "themes.reset": [{ params: { theme: "paper" }, result: paperThemes }],
  "themes.apply": [{ params: { theme: "paper" }, result: paperThemes }],
  "themes.chooseWallpaper": [
    { params: { theme: "awakening", path: "backgrounds/1-first-light.png" }, result: themes },
  ],
  "themes.importFolder": [{ params: {}, result: paperThemes }],
  "themes.exportFolder": [{ params: { theme: "awakening" }, result: null }],
  "themes.reveal": [{ params: { theme: "awakening" }, result: null }],

  "shortcuts.getState": [{ params: {}, result: shortcuts }],
  "shortcuts.validate": [
    {
      params: { id: 3, chord: { modifiers: ["ctrl", "alt"], key: "j" } },
      result: { spec: "ctrl + alt - j", caps: ["⌃", "⌥", "J"], conflicts: [] },
    },
    {
      params: { id: 3, chord: { modifiers: ["ctrl", "alt"], key: "return" } },
      result: { spec: "ctrl + alt - return", caps: ["⌃", "⌥", "↩"], conflicts: [1] },
    },
  ],
  "shortcuts.rebind": [
    {
      params: {
        id: 3,
        revision: "5d41402abc4b2a76",
        chord: { modifiers: ["ctrl", "alt"], key: "j" },
      },
      result: { state: shortcutsAfterEdit, warning: "" },
    },
  ],
  "shortcuts.disable": [
    {
      params: { id: 3, revision: "5d41402abc4b2a76" },
      result: { state: shortcutsAfterEdit, warning: "skhd: could not reload the configuration" },
    },
  ],
  "shortcuts.reset": [
    { params: { revision: "7d793037a0760186" }, result: { state: shortcuts, warning: "" } },
  ],
  "shortcuts.openConfiguration": [{ params: {}, result: null }],
};

export const eventFixtures: EventFixtures = {
  "shell.changed": [
    {
      type: "shell.changed",
      state: {
        ...shell,
        selectedPane: "themes",
        appearance: { accent: "#61afef", mode: "light" },
      },
    },
  ],
  "shell.logChanged": [{ type: "shell.logChanged" }],
  "shell.shortcut": [
    { type: "shell.shortcut", state: { shortcut: "palette" } },
    { type: "shell.shortcut", state: { shortcut: "back" } },
  ],
  "layout.changed": [
    {
      type: "layout.changed",
      state: {
        values: {
          layout: "float",
          splitType: "horizontal",
          windowPlacement: "second_child",
          autoBalance: false,
          windowGap: 0,
          padding: 40,
          mouseModifier: "cmd",
          mouseFollowsFocus: false,
          mouseDropAction: "stack",
        },
        source: "daemon",
        unavailableReason: null,
        wallpaper,
      },
    },
  ],
  "themes.changed": [
    { type: "themes.changed", state: switcher },
    { type: "themes.changed", state: switcherWithoutTheme },
  ],
  "switcher.willOpen": [
    { type: "switcher.willOpen", state: { ...switcher, error: null } },
    {
      type: "switcher.willOpen",
      state: {
        ...switcherWithoutTheme,
        error: {
          title: "Could not apply Awakening",
          reason: "yabai-msg: failed to connect",
        },
      },
    },
  ],
  "switcher.didClose": [{ type: "switcher.didClose" }],
  "rules.changed": [{ type: "rules.changed", state: rules }],
  "rules.unavailable": [
    {
      type: "rules.unavailable",
      state: { message: "Your saved rules could not be read: settings.json is not valid JSON." },
    },
  ],
  "advanced.changed": [
    {
      type: "advanced.changed",
      state: {
        ...advanced,
        addition: "repair",
        additionExplanation: "yabai was updated, so its sudoers rule needs repairing.",
      },
    },
  ],
  "advanced.invalidated": [{ type: "advanced.invalidated" }],
  "borders.changed": [{ type: "borders.changed", state: borders }],
  "home.changed": [{ type: "home.changed" }],
  "health.changed": [{ type: "health.changed" }],
  "shortcuts.changed": [{ type: "shortcuts.changed", state: shortcutsAfterEdit }],
  "shortcuts.unavailable": [
    {
      type: "shortcuts.unavailable",
      state: "Your shortcuts could not be read: skhdrc is missing.",
    },
  ],
};
