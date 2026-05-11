"use strict";
var __defProp = Object.defineProperty;
var __getOwnPropDesc = Object.getOwnPropertyDescriptor;
var __getOwnPropNames = Object.getOwnPropertyNames;
var __hasOwnProp = Object.prototype.hasOwnProperty;
var __export = (target, all) => {
  for (var name in all)
    __defProp(target, name, { get: all[name], enumerable: true });
};
var __copyProps = (to, from, except, desc) => {
  if (from && typeof from === "object" || typeof from === "function") {
    for (let key of __getOwnPropNames(from))
      if (!__hasOwnProp.call(to, key) && key !== except)
        __defProp(to, key, { get: () => from[key], enumerable: !(desc = __getOwnPropDesc(from, key)) || desc.enumerable });
  }
  return to;
};
var __toCommonJS = (mod) => __copyProps(__defProp({}, "__esModule", { value: true }), mod);

// src/switch-theme.tsx
var switch_theme_exports = {};
__export(switch_theme_exports, {
  default: () => Command
});
module.exports = __toCommonJS(switch_theme_exports);
var import_api = require("@raycast/api");
var import_fs = require("fs");
var import_os = require("os");
var import_path = require("path");
var import_child_process = require("child_process");
var import_react = require("react");
var import_jsx_runtime = require("react/jsx-runtime");
var THEMES_DIR = (0, import_path.join)((0, import_os.homedir)(), ".themes");
var THEME_BACKGROUND_STATE = (0, import_path.join)(THEMES_DIR, ".backgrounds.json");
var GHOSTTY_CONFIG = (0, import_path.join)((0, import_os.homedir)(), ".config", "ghostty", "config");
var NVIM_COLORSCHEME_FILE = (0, import_path.join)(
  (0, import_os.homedir)(),
  ".config",
  "nvim",
  "lua",
  "plugins",
  "colorscheme.lua"
);
var CODEX_CONFIG = (0, import_path.join)((0, import_os.homedir)(), ".codex", "config.toml");
var APPLY_SKETCHYBAR_THEME = (0, import_path.join)(
  (0, import_os.homedir)(),
  ".local",
  "bin",
  "apply-sketchybar-theme"
);
var THEME_SWITCH_BIN = (0, import_path.join)((0, import_os.homedir)(), ".local", "bin", "theme-switch");
var PATH = `/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin:/usr/local/bin`;
function parseThemeEnv(dir) {
  const envPath = (0, import_path.join)(dir, "theme.env");
  if (!(0, import_fs.existsSync)(envPath)) return {};
  const vars = {};
  for (const line of (0, import_fs.readFileSync)(envPath, "utf-8").split("\n")) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith("#")) continue;
    const eq = trimmed.indexOf("=");
    if (eq === -1) continue;
    const key = trimmed.slice(0, eq);
    let val = trimmed.slice(eq + 1);
    if (val.startsWith('"') && val.endsWith('"') || val.startsWith("'") && val.endsWith("'")) {
      val = val.slice(1, -1);
    }
    vars[key] = val;
  }
  return vars;
}
function getBorderHex(env) {
  const ba = env.BORDER_ACTIVE || "";
  if (ba.startsWith("0xff")) return "#" + ba.slice(4);
  return "#888888";
}
function normalizeHexColor(value) {
  if (!value) return void 0;
  if (/^#[0-9a-fA-F]{6}$/.test(value)) return value;
  if (/^0x[0-9a-fA-F]{8}$/.test(value)) return `#${value.slice(4)}`;
  if (/^0x[0-9a-fA-F]{6}$/.test(value)) return `#${value.slice(2)}`;
  if (/^[0-9a-fA-F]{6}$/.test(value)) return `#${value}`;
  return void 0;
}
function getRgb(hex) {
  return [
    Number.parseInt(hex.slice(1, 3), 16),
    Number.parseInt(hex.slice(3, 5), 16),
    Number.parseInt(hex.slice(5, 7), 16)
  ];
}
var APPLE_ACCENT_PRESETS = [
  { id: 0, name: "Red", color: "#ff3b30" },
  { id: 1, name: "Orange", color: "#ff9500" },
  { id: 2, name: "Yellow", color: "#ffcc00" },
  { id: 3, name: "Green", color: "#34c759" },
  { id: 4, name: "Blue", color: "#007aff" },
  { id: 5, name: "Purple", color: "#af52de" },
  { id: 6, name: "Pink", color: "#ff2d55" },
  { id: 7, name: "Graphite", color: "#8e8e93" }
];
function getAppleAccentNameForId(id) {
  if (id === -1) return "Multicolour";
  return APPLE_ACCENT_PRESETS.find((preset) => preset.id === id)?.name;
}
function resolveAppleAccentId(value) {
  if (!value) return void 0;
  if (/^-?\d+$/.test(value)) {
    const id = Number(value);
    return id >= -1 && id <= 7 ? id : void 0;
  }
  const key = value.toLowerCase().replace(/[\s_-]/g, "");
  const names = {
    multicolor: -1,
    multicolour: -1,
    red: 0,
    orange: 1,
    yellow: 2,
    green: 3,
    blue: 4,
    purple: 5,
    pink: 6,
    graphite: 7,
    grey: 7,
    gray: 7
  };
  return names[key];
}
function getNearestAppleAccentName(hex) {
  const [r, g, b] = getRgb(hex);
  const max = Math.max(r, g, b);
  const min = Math.min(r, g, b);
  const chroma = max - min;
  if (chroma < 24) return "Graphite";
  let hue;
  if (max === r) {
    hue = 60 * (g - b) / chroma;
    if (hue < 0) hue += 360;
  } else if (max === g) {
    hue = 120 + 60 * (b - r) / chroma;
  } else {
    hue = 240 + 60 * (r - g) / chroma;
  }
  if (hue < 15 || hue >= 345) return "Red";
  if (hue < 40) return "Orange";
  if (hue < 75) return "Yellow";
  if (hue < 165) return "Green";
  if (hue < 255) return "Blue";
  if (hue < 290) return "Purple";
  return "Pink";
}
function getGhosttyColor(dir, key, fallback) {
  const ghosttyPath = (0, import_path.join)(dir, "ghostty.conf");
  if (!(0, import_fs.existsSync)(ghosttyPath)) return fallback;
  for (const line of (0, import_fs.readFileSync)(ghosttyPath, "utf-8").split("\n")) {
    const trimmed = line.trim();
    if (!trimmed.startsWith(`${key} = `)) continue;
    const value = trimmed.slice(`${key} = `.length).trim();
    if (/^#[0-9a-fA-F]{6}$/.test(value)) return value;
  }
  return fallback;
}
function getGhosttyPalette(dir) {
  const ghosttyPath = (0, import_path.join)(dir, "ghostty.conf");
  if (!(0, import_fs.existsSync)(ghosttyPath)) return [];
  const palette = [];
  for (const line of (0, import_fs.readFileSync)(ghosttyPath, "utf-8").split("\n")) {
    const trimmed = line.trim();
    const match = trimmed.match(/^palette\s*=\s*(\d+)=\s*(#[0-9a-fA-F]{6})$/);
    if (!match) continue;
    palette[Number(match[1])] = match[2];
  }
  return palette;
}
function getThemeAccent(dir, env) {
  const palette = getGhosttyPalette(dir);
  return palette[4] || getBorderHex(env);
}
function getSystemAccentHex(dir, env) {
  return normalizeHexColor(env.SYSTEM_ACCENT_COLOR) || normalizeHexColor(env.FIREFOX_ACCENT) || normalizeHexColor(env.BORDER_ACTIVE) || getThemeAccent(dir, env);
}
function getAppleAccentName(dir, env) {
  return "Multicolour";
}
function getHighlightColor(dir, env) {
  return "System";
}
function getBackgroundState() {
  if (!(0, import_fs.existsSync)(THEME_BACKGROUND_STATE)) return {};
  try {
    const parsed = JSON.parse((0, import_fs.readFileSync)(THEME_BACKGROUND_STATE, "utf-8"));
    return parsed && typeof parsed === "object" && !Array.isArray(parsed) ? parsed : {};
  } catch {
    return {};
  }
}
function writeBackgroundState(state) {
  (0, import_fs.writeFileSync)(THEME_BACKGROUND_STATE, `${JSON.stringify(state, null, 2)}
`);
}
function isImageFile(fileName) {
  return [".jpg", ".jpeg", ".png", ".webp", ".heic"].includes(
    (0, import_path.extname)(fileName).toLowerCase()
  );
}
function prettifyBackgroundName(fileName) {
  return (0, import_path.basename)(fileName, (0, import_path.extname)(fileName)).replace(/^\d+[-_.\s]*/, "").replace(/[-_.]+/g, " ").replace(/\b\w/g, (letter) => letter.toUpperCase());
}
function getThemeBackgrounds(theme) {
  const bgDir = (0, import_path.join)(THEMES_DIR, theme.name, "backgrounds");
  if (!(0, import_fs.existsSync)(bgDir)) return [];
  return (0, import_fs.readdirSync)(bgDir, { withFileTypes: true }).filter((entry) => entry.isFile() && !entry.name.startsWith(".")).filter((entry) => isImageFile(entry.name)).map((entry) => {
    const relativePath = `backgrounds/${entry.name}`;
    const previewPath = (0, import_path.join)(
      bgDir,
      ".raycast-blur",
      `${(0, import_path.basename)(entry.name, (0, import_path.extname)(entry.name))}.jpg`
    );
    const path = (0, import_path.join)(bgDir, entry.name);
    return {
      themeName: theme.name,
      relativePath,
      path,
      previewPath: (0, import_fs.existsSync)(previewPath) ? previewPath : path,
      displayName: prettifyBackgroundName(entry.name)
    };
  }).sort((a, b) => a.relativePath.localeCompare(b.relativePath));
}
function getSelectedBackground(theme) {
  const backgrounds = getThemeBackgrounds(theme);
  const state = getBackgroundState();
  const selectedRelative = state[theme.name] || theme.env.WALLPAPER;
  return backgrounds.find(
    (background) => background.relativePath === selectedRelative
  ) || backgrounds[0];
}
function getSketchybarAccent(dir, env) {
  const palette = getGhosttyPalette(dir);
  return palette[4] || getBorderHex(env);
}
function getThemes() {
  if (!(0, import_fs.existsSync)(THEMES_DIR)) return [];
  return (0, import_fs.readdirSync)(THEMES_DIR, { withFileTypes: true }).filter((d) => d.isDirectory()).map((d) => {
    const dir = (0, import_path.join)(THEMES_DIR, d.name);
    const env = parseThemeEnv(dir);
    const bgDir = (0, import_path.join)(dir, "backgrounds");
    const bgCount = (0, import_fs.existsSync)(bgDir) ? (0, import_fs.readdirSync)(bgDir, { withFileTypes: true }).filter(
      (entry) => entry.isFile() && isImageFile(entry.name)
    ).length : 0;
    const selectedWallpaper = getBackgroundState()[d.name] || env.WALLPAPER || "";
    return {
      name: d.name,
      displayName: d.name.split("-").map((w) => w.charAt(0).toUpperCase() + w.slice(1)).join(" "),
      env,
      hasWallpaper: (0, import_fs.existsSync)((0, import_path.join)(dir, selectedWallpaper)),
      wallpaperPath: (0, import_fs.existsSync)((0, import_path.join)(dir, selectedWallpaper)) ? (0, import_path.join)(dir, selectedWallpaper) : void 0,
      accentColor: getThemeAccent(dir, env),
      sketchybarAccentColor: getSketchybarAccent(dir, env),
      textColor: getGhosttyColor(
        dir,
        "foreground",
        env.DARK_MODE === "true" ? "#ffffff" : "#000000"
      ),
      palette: getGhosttyPalette(dir),
      isDark: env.DARK_MODE === "true",
      bgCount,
      appleAccentName: getAppleAccentName(dir, env),
      highlightColor: getHighlightColor(dir, env)
    };
  }).sort((a, b) => a.name.localeCompare(b.name));
}
function getCurrentTheme() {
  const path = (0, import_path.join)(THEMES_DIR, ".current");
  if (!(0, import_fs.existsSync)(path)) return "";
  return (0, import_fs.readFileSync)(path, "utf-8").trim();
}
function spawnThemeApplyWorker(theme) {
  const workerSource = String.raw`
const { existsSync } = require("fs");
const { homedir } = require("os");
const { join } = require("path");
const { spawn } = require("child_process");

const theme = JSON.parse(process.argv[1]);
const THEME_SWITCH_BIN = join(homedir(), ".local", "bin", "theme-switch");
const PATH = ${JSON.stringify(PATH)};

function runThemeSwitch(args) {
  return new Promise((resolve, reject) => {
    const child = spawn(THEME_SWITCH_BIN, args, {
      env: { ...process.env, HOME: homedir(), PATH },
      stdio: "ignore",
    });
    child.on("error", reject);
    child.on("exit", (code) => {
      if (code === 0) resolve();
      else reject(new Error("theme-switch exited " + code));
    });
  });
}

async function main() {
  const { name } = theme;
  if (!existsSync(THEME_SWITCH_BIN)) process.exit(1);
  // Run synchronously: theme-switch writes ~/.themes/.current only after Ghostty/Raycast/etc. finish.
  // (Backgrounding with & caused the UI to show "active" before emulators actually reloaded.)
  await runThemeSwitch([name]);
}

main().catch(() => process.exit(1));
`;
  const worker = (0, import_child_process.spawn)(
    process.execPath,
    ["-e", workerSource, JSON.stringify(theme)],
    {
      detached: true,
      stdio: "ignore"
    }
  );
  worker.unref();
}
function spawnBackgroundApplyWorker(theme, background) {
  const workerSource = String.raw`
const { homedir } = require("os");
const { join } = require("path");
const { spawn } = require("child_process");

const themeName = process.argv[1];
const backgroundPath = process.argv[2];
const THEME_SWITCH_BIN = join(homedir(), ".local", "bin", "theme-switch");
const PATH = ${JSON.stringify(PATH)};

const child = spawn(THEME_SWITCH_BIN, ["--background", themeName, backgroundPath], {
  detached: true,
  env: { ...process.env, HOME: homedir(), PATH },
  stdio: "ignore",
});
child.unref();
`;
  const worker = (0, import_child_process.spawn)(
    process.execPath,
    ["-e", workerSource, theme.name, background.relativePath],
    {
      detached: true,
      stdio: "ignore"
    }
  );
  worker.unref();
}
function BackgroundPicker(props) {
  const allBackgrounds = getThemeBackgrounds(props.theme);
  const selected = getSelectedBackground(props.theme);
  const backgrounds = selected ? [
    selected,
    ...allBackgrounds.filter(
      (bg) => bg.relativePath !== selected.relativePath
    )
  ] : allBackgrounds;
  return /* @__PURE__ */ (0, import_jsx_runtime.jsx)(
    import_api.Grid,
    {
      columns: 2,
      inset: import_api.Grid.Inset.Small,
      fit: import_api.Grid.Fit.Fill,
      aspectRatio: "16/9",
      navigationTitle: `Switch Background (${props.theme.displayName})`,
      searchBarPlaceholder: "Search backgrounds...",
      children: backgrounds.map((background) => {
        const isSelected = background.relativePath === selected?.relativePath;
        return /* @__PURE__ */ (0, import_jsx_runtime.jsx)(
          import_api.Grid.Item,
          {
            title: background.displayName,
            accessory: isSelected ? { icon: import_api.Icon.CheckCircle, tooltip: "Current" } : void 0,
            content: { source: background.previewPath },
            actions: /* @__PURE__ */ (0, import_jsx_runtime.jsx)(import_api.ActionPanel, { children: /* @__PURE__ */ (0, import_jsx_runtime.jsx)(
              import_api.Action,
              {
                title: "Use Background",
                icon: import_api.Icon.Image,
                onAction: async () => {
                  const state = getBackgroundState();
                  state[props.theme.name] = background.relativePath;
                  writeBackgroundState(state);
                  props.onSelect(props.theme.name, background.relativePath);
                  spawnBackgroundApplyWorker(props.theme, background);
                  await (0, import_api.closeMainWindow)();
                }
              }
            ) })
          },
          background.relativePath
        );
      })
    }
  );
}
function Command() {
  const themes = getThemes();
  const [current, setCurrent] = (0, import_react.useState)(() => getCurrentTheme());
  const [pendingTheme, setPendingTheme] = (0, import_react.useState)(null);
  const [backgroundVersion, setBackgroundVersion] = (0, import_react.useState)(0);
  (0, import_react.useEffect)(() => {
    const syncCurrentTheme = () => {
      const next = getCurrentTheme();
      setCurrent((prev) => prev === next ? prev : next);
    };
    syncCurrentTheme();
    const interval = setInterval(syncCurrentTheme, 750);
    return () => clearInterval(interval);
  }, []);
  function getThemePreview(theme) {
    const selectedBackground = getSelectedBackground(theme);
    const wallpaperPreview = selectedBackground ? `![${theme.displayName}](${encodeURI(`file://${selectedBackground.previewPath}`)}?raycast-width=720&raycast-height=405)` : "_No wallpaper preview available_";
    const lines = [
      `# ${theme.displayName}`,
      "",
      wallpaperPreview,
      "",
      selectedBackground ? `Background \`${selectedBackground.displayName}\`` : "",
      `Accent \`${theme.accentColor}\``,
      `macOS Accent \`${theme.appleAccentName}\``,
      `Highlight \`${theme.highlightColor}\``,
      `Text \`${theme.textColor}\``
    ];
    return lines.join("\n");
  }
  function getLsPreviewColors(theme) {
    return {
      directory: theme.palette[4] || theme.accentColor,
      symlink: theme.palette[6] || theme.accentColor,
      executable: theme.palette[2] || theme.accentColor,
      archive: theme.palette[1] || theme.accentColor,
      device: theme.palette[3] || theme.accentColor,
      normal: theme.textColor
    };
  }
  const activeTheme = themes.find((theme) => theme.name === current) || themes[0];
  const activeBackground = activeTheme ? getSelectedBackground(activeTheme) : void 0;
  function getBackgroundPreviewMarkdown(theme) {
    const selected = getSelectedBackground(theme);
    if (!selected) return "_No background options available_";
    return `![${selected.displayName}](${encodeURI(`file://${selected.previewPath}`)}?raycast-width=720&raycast-height=405)`;
  }
  return /* @__PURE__ */ (0, import_jsx_runtime.jsxs)(import_api.List, { isShowingDetail: true, searchBarPlaceholder: "Search themes...", children: [
    activeTheme ? /* @__PURE__ */ (0, import_jsx_runtime.jsx)(
      import_api.List.Item,
      {
        title: "Switch Background",
        subtitle: activeTheme.displayName,
        icon: import_api.Icon.AppWindowGrid2x2,
        accessories: [{ text: `${activeTheme.bgCount} options` }],
        detail: /* @__PURE__ */ (0, import_jsx_runtime.jsx)(
          import_api.List.Item.Detail,
          {
            markdown: getBackgroundPreviewMarkdown(activeTheme)
          }
        ),
        actions: /* @__PURE__ */ (0, import_jsx_runtime.jsx)(import_api.ActionPanel, { children: /* @__PURE__ */ (0, import_jsx_runtime.jsx)(
          import_api.Action.Push,
          {
            title: "Open Backgrounds",
            icon: import_api.Icon.Folder,
            target: /* @__PURE__ */ (0, import_jsx_runtime.jsx)(
              BackgroundPicker,
              {
                theme: activeTheme,
                onSelect: () => setBackgroundVersion((version) => version + 1)
              }
            )
          }
        ) })
      },
      `switch-background-${backgroundVersion}`
    ) : null,
    themes.map((theme) => {
      const isCurrent = theme.name === (pendingTheme || current);
      const accessories = [];
      if (isCurrent)
        accessories.push({ tag: { value: "active", color: import_api.Color.Green } });
      accessories.push({ icon: theme.isDark ? import_api.Icon.Moon : import_api.Icon.Sun });
      if (theme.bgCount > 0)
        accessories.push({ text: `${theme.bgCount} bg` });
      return /* @__PURE__ */ (0, import_jsx_runtime.jsx)(
        import_api.List.Item,
        {
          title: theme.displayName,
          icon: {
            source: import_api.Icon.Circle,
            tintColor: theme.accentColor
          },
          accessories,
          detail: /* @__PURE__ */ (0, import_jsx_runtime.jsx)(
            import_api.List.Item.Detail,
            {
              markdown: getThemePreview(theme),
              metadata: /* @__PURE__ */ (0, import_jsx_runtime.jsxs)(import_api.List.Item.Detail.Metadata, { children: [
                /* @__PURE__ */ (0, import_jsx_runtime.jsx)(
                  import_api.List.Item.Detail.Metadata.Label,
                  {
                    title: "Mode",
                    text: theme.isDark ? "Dark" : "Light"
                  }
                ),
                /* @__PURE__ */ (0, import_jsx_runtime.jsx)(import_api.List.Item.Detail.Metadata.Separator, {}),
                /* @__PURE__ */ (0, import_jsx_runtime.jsx)(
                  import_api.List.Item.Detail.Metadata.Label,
                  {
                    title: "Wallpapers",
                    text: String(
                      theme.bgCount || (theme.hasWallpaper ? 1 : 0)
                    )
                  }
                ),
                /* @__PURE__ */ (0, import_jsx_runtime.jsx)(import_api.List.Item.Detail.Metadata.Separator, {}),
                /* @__PURE__ */ (0, import_jsx_runtime.jsx)(
                  import_api.List.Item.Detail.Metadata.Label,
                  {
                    title: "macOS Accent",
                    text: theme.appleAccentName
                  }
                ),
                /* @__PURE__ */ (0, import_jsx_runtime.jsx)(
                  import_api.List.Item.Detail.Metadata.Label,
                  {
                    title: "Highlight",
                    text: theme.highlightColor
                  }
                ),
                /* @__PURE__ */ (0, import_jsx_runtime.jsx)(import_api.List.Item.Detail.Metadata.Separator, {}),
                /* @__PURE__ */ (0, import_jsx_runtime.jsxs)(import_api.List.Item.Detail.Metadata.TagList, { title: "ls -la", children: [
                  /* @__PURE__ */ (0, import_jsx_runtime.jsx)(
                    import_api.List.Item.Detail.Metadata.TagList.Item,
                    {
                      text: "dir/",
                      color: getLsPreviewColors(theme).directory
                    }
                  ),
                  /* @__PURE__ */ (0, import_jsx_runtime.jsx)(
                    import_api.List.Item.Detail.Metadata.TagList.Item,
                    {
                      text: "link@",
                      color: getLsPreviewColors(theme).symlink
                    }
                  ),
                  /* @__PURE__ */ (0, import_jsx_runtime.jsx)(
                    import_api.List.Item.Detail.Metadata.TagList.Item,
                    {
                      text: "exec*",
                      color: getLsPreviewColors(theme).executable
                    }
                  ),
                  /* @__PURE__ */ (0, import_jsx_runtime.jsx)(
                    import_api.List.Item.Detail.Metadata.TagList.Item,
                    {
                      text: "archive",
                      color: getLsPreviewColors(theme).archive
                    }
                  ),
                  /* @__PURE__ */ (0, import_jsx_runtime.jsx)(
                    import_api.List.Item.Detail.Metadata.TagList.Item,
                    {
                      text: "device",
                      color: getLsPreviewColors(theme).device
                    }
                  ),
                  /* @__PURE__ */ (0, import_jsx_runtime.jsx)(
                    import_api.List.Item.Detail.Metadata.TagList.Item,
                    {
                      text: "file",
                      color: getLsPreviewColors(theme).normal
                    }
                  )
                ] })
              ] })
            }
          ),
          actions: /* @__PURE__ */ (0, import_jsx_runtime.jsxs)(import_api.ActionPanel, { children: [
            /* @__PURE__ */ (0, import_jsx_runtime.jsx)(
              import_api.Action,
              {
                title: "Apply Theme",
                icon: import_api.Icon.Brush,
                shortcut: { modifiers: [], key: "return" },
                onAction: async () => {
                  spawnThemeApplyWorker(theme);
                  await (0, import_api.closeMainWindow)();
                }
              }
            ),
            theme.bgCount > 0 ? /* @__PURE__ */ (0, import_jsx_runtime.jsx)(
              import_api.Action.Push,
              {
                title: "Switch Background",
                icon: import_api.Icon.Folder,
                shortcut: { modifiers: ["cmd"], key: "b" },
                target: /* @__PURE__ */ (0, import_jsx_runtime.jsx)(
                  BackgroundPicker,
                  {
                    theme,
                    onSelect: () => setBackgroundVersion((version) => version + 1)
                  }
                )
              }
            ) : null
          ] })
        },
        theme.name
      );
    })
  ] });
}
//# sourceMappingURL=data:application/json;base64,ewogICJ2ZXJzaW9uIjogMywKICAic291cmNlcyI6IFsiLi4vLi4vLi4vLi4vRGV2ZWxvcGVyL3RoZW1lLXN3aXRjaGVyL3NyYy9zd2l0Y2gtdGhlbWUudHN4Il0sCiAgInNvdXJjZXNDb250ZW50IjogWyJpbXBvcnQge1xuICBBY3Rpb25QYW5lbCxcbiAgQWN0aW9uLFxuICBMaXN0LFxuICBHcmlkLFxuICBJY29uLFxuICBDb2xvcixcbiAgY2xvc2VNYWluV2luZG93LFxufSBmcm9tIFwiQHJheWNhc3QvYXBpXCI7XG5pbXBvcnQgeyByZWFkZGlyU3luYywgcmVhZEZpbGVTeW5jLCBleGlzdHNTeW5jLCB3cml0ZUZpbGVTeW5jIH0gZnJvbSBcImZzXCI7XG5pbXBvcnQgeyBob21lZGlyIH0gZnJvbSBcIm9zXCI7XG5pbXBvcnQgeyBiYXNlbmFtZSwgZXh0bmFtZSwgam9pbiB9IGZyb20gXCJwYXRoXCI7XG5pbXBvcnQgeyBleGVjLCBzcGF3biwgdHlwZSBDaGlsZFByb2Nlc3MgfSBmcm9tIFwiY2hpbGRfcHJvY2Vzc1wiO1xuaW1wb3J0IHsgdXNlRWZmZWN0LCB1c2VTdGF0ZSB9IGZyb20gXCJyZWFjdFwiO1xuXG5jb25zdCBUSEVNRVNfRElSID0gam9pbihob21lZGlyKCksIFwiLnRoZW1lc1wiKTtcbmNvbnN0IFRIRU1FX0JBQ0tHUk9VTkRfU1RBVEUgPSBqb2luKFRIRU1FU19ESVIsIFwiLmJhY2tncm91bmRzLmpzb25cIik7XG5jb25zdCBHSE9TVFRZX0NPTkZJRyA9IGpvaW4oaG9tZWRpcigpLCBcIi5jb25maWdcIiwgXCJnaG9zdHR5XCIsIFwiY29uZmlnXCIpO1xuY29uc3QgTlZJTV9DT0xPUlNDSEVNRV9GSUxFID0gam9pbihcbiAgaG9tZWRpcigpLFxuICBcIi5jb25maWdcIixcbiAgXCJudmltXCIsXG4gIFwibHVhXCIsXG4gIFwicGx1Z2luc1wiLFxuICBcImNvbG9yc2NoZW1lLmx1YVwiLFxuKTtcbmNvbnN0IENPREVYX0NPTkZJRyA9IGpvaW4oaG9tZWRpcigpLCBcIi5jb2RleFwiLCBcImNvbmZpZy50b21sXCIpO1xuY29uc3QgQVBQTFlfU0tFVENIWUJBUl9USEVNRSA9IGpvaW4oXG4gIGhvbWVkaXIoKSxcbiAgXCIubG9jYWxcIixcbiAgXCJiaW5cIixcbiAgXCJhcHBseS1za2V0Y2h5YmFyLXRoZW1lXCIsXG4pO1xuY29uc3QgVEhFTUVfU1dJVENIX0JJTiA9IGpvaW4oaG9tZWRpcigpLCBcIi5sb2NhbFwiLCBcImJpblwiLCBcInRoZW1lLXN3aXRjaFwiKTtcbmNvbnN0IFJBWUNBU1RfQlVORExFX0lEID0gXCJjb20ucmF5Y2FzdC5tYWNvc1wiO1xuY29uc3QgUEFUSCA9IGAvdXNyL2JpbjovYmluOi91c3Ivc2Jpbjovc2Jpbjovb3B0L2hvbWVicmV3L2JpbjovdXNyL2xvY2FsL2JpbmA7XG5cbmludGVyZmFjZSBUaGVtZUVudiB7XG4gIERBUktfTU9ERT86IHN0cmluZztcbiAgV0FMTFBBUEVSPzogc3RyaW5nO1xuICBHSE9TVFRZX0NPTkY/OiBzdHJpbmc7XG4gIE5WSU1fQ09MT1JTQ0hFTUU/OiBzdHJpbmc7XG4gIEJPUkRFUl9BQ1RJVkU/OiBzdHJpbmc7XG4gIEJPUkRFUl9JTkFDVElWRT86IHN0cmluZztcbiAgQk9SREVSX1dJRFRIPzogc3RyaW5nO1xuICBGSVJFRk9YX0FDQ0VOVD86IHN0cmluZztcbiAgU1lTVEVNX0FDQ0VOVF9DT0xPUj86IHN0cmluZztcbiAgQVBQTEVfQUNDRU5UPzogc3RyaW5nO1xuICBBUFBMRV9ISUdITElHSFQ/OiBzdHJpbmc7XG59XG5cbmludGVyZmFjZSBUaGVtZUVudHJ5IHtcbiAgbmFtZTogc3RyaW5nO1xuICBkaXNwbGF5TmFtZTogc3RyaW5nO1xuICBlbnY6IFRoZW1lRW52O1xuICBoYXNXYWxscGFwZXI6IGJvb2xlYW47XG4gIHdhbGxwYXBlclBhdGg/OiBzdHJpbmc7XG4gIGFjY2VudENvbG9yOiBzdHJpbmc7XG4gIHNrZXRjaHliYXJBY2NlbnRDb2xvcjogc3RyaW5nO1xuICB0ZXh0Q29sb3I6IHN0cmluZztcbiAgcGFsZXR0ZTogc3RyaW5nW107XG4gIGlzRGFyazogYm9vbGVhbjtcbiAgYmdDb3VudDogbnVtYmVyO1xuICBhcHBsZUFjY2VudE5hbWU6IHN0cmluZztcbiAgaGlnaGxpZ2h0Q29sb3I6IHN0cmluZztcbn1cblxuaW50ZXJmYWNlIEJhY2tncm91bmRFbnRyeSB7XG4gIHRoZW1lTmFtZTogc3RyaW5nO1xuICByZWxhdGl2ZVBhdGg6IHN0cmluZztcbiAgcGF0aDogc3RyaW5nO1xuICBwcmV2aWV3UGF0aDogc3RyaW5nO1xuICBkaXNwbGF5TmFtZTogc3RyaW5nO1xufVxuXG50eXBlIEJhY2tncm91bmRTdGF0ZSA9IFJlY29yZDxzdHJpbmcsIHN0cmluZz47XG5cbmZ1bmN0aW9uIHBhcnNlVGhlbWVFbnYoZGlyOiBzdHJpbmcpOiBUaGVtZUVudiB7XG4gIGNvbnN0IGVudlBhdGggPSBqb2luKGRpciwgXCJ0aGVtZS5lbnZcIik7XG4gIGlmICghZXhpc3RzU3luYyhlbnZQYXRoKSkgcmV0dXJuIHt9O1xuICBjb25zdCB2YXJzOiBUaGVtZUVudiA9IHt9O1xuICBmb3IgKGNvbnN0IGxpbmUgb2YgcmVhZEZpbGVTeW5jKGVudlBhdGgsIFwidXRmLThcIikuc3BsaXQoXCJcXG5cIikpIHtcbiAgICBjb25zdCB0cmltbWVkID0gbGluZS50cmltKCk7XG4gICAgaWYgKCF0cmltbWVkIHx8IHRyaW1tZWQuc3RhcnRzV2l0aChcIiNcIikpIGNvbnRpbnVlO1xuICAgIGNvbnN0IGVxID0gdHJpbW1lZC5pbmRleE9mKFwiPVwiKTtcbiAgICBpZiAoZXEgPT09IC0xKSBjb250aW51ZTtcbiAgICBjb25zdCBrZXkgPSB0cmltbWVkLnNsaWNlKDAsIGVxKSBhcyBrZXlvZiBUaGVtZUVudjtcbiAgICBsZXQgdmFsID0gdHJpbW1lZC5zbGljZShlcSArIDEpO1xuICAgIGlmIChcbiAgICAgICh2YWwuc3RhcnRzV2l0aCgnXCInKSAmJiB2YWwuZW5kc1dpdGgoJ1wiJykpIHx8XG4gICAgICAodmFsLnN0YXJ0c1dpdGgoXCInXCIpICYmIHZhbC5lbmRzV2l0aChcIidcIikpXG4gICAgKSB7XG4gICAgICB2YWwgPSB2YWwuc2xpY2UoMSwgLTEpO1xuICAgIH1cbiAgICB2YXJzW2tleV0gPSB2YWw7XG4gIH1cbiAgcmV0dXJuIHZhcnM7XG59XG5cbmZ1bmN0aW9uIGdldEJvcmRlckhleChlbnY6IFRoZW1lRW52KTogc3RyaW5nIHtcbiAgY29uc3QgYmEgPSBlbnYuQk9SREVSX0FDVElWRSB8fCBcIlwiO1xuICAvLyAweGZmUlJHR0JCIC0+ICNSUkdHQkJcbiAgaWYgKGJhLnN0YXJ0c1dpdGgoXCIweGZmXCIpKSByZXR1cm4gXCIjXCIgKyBiYS5zbGljZSg0KTtcbiAgcmV0dXJuIFwiIzg4ODg4OFwiO1xufVxuXG5mdW5jdGlvbiBub3JtYWxpemVIZXhDb2xvcih2YWx1ZTogc3RyaW5nIHwgdW5kZWZpbmVkKTogc3RyaW5nIHwgdW5kZWZpbmVkIHtcbiAgaWYgKCF2YWx1ZSkgcmV0dXJuIHVuZGVmaW5lZDtcbiAgaWYgKC9eI1swLTlhLWZBLUZdezZ9JC8udGVzdCh2YWx1ZSkpIHJldHVybiB2YWx1ZTtcbiAgaWYgKC9eMHhbMC05YS1mQS1GXXs4fSQvLnRlc3QodmFsdWUpKSByZXR1cm4gYCMke3ZhbHVlLnNsaWNlKDQpfWA7XG4gIGlmICgvXjB4WzAtOWEtZkEtRl17Nn0kLy50ZXN0KHZhbHVlKSkgcmV0dXJuIGAjJHt2YWx1ZS5zbGljZSgyKX1gO1xuICBpZiAoL15bMC05YS1mQS1GXXs2fSQvLnRlc3QodmFsdWUpKSByZXR1cm4gYCMke3ZhbHVlfWA7XG4gIHJldHVybiB1bmRlZmluZWQ7XG59XG5cbmZ1bmN0aW9uIGdldFJnYihoZXg6IHN0cmluZyk6IFtudW1iZXIsIG51bWJlciwgbnVtYmVyXSB7XG4gIHJldHVybiBbXG4gICAgTnVtYmVyLnBhcnNlSW50KGhleC5zbGljZSgxLCAzKSwgMTYpLFxuICAgIE51bWJlci5wYXJzZUludChoZXguc2xpY2UoMywgNSksIDE2KSxcbiAgICBOdW1iZXIucGFyc2VJbnQoaGV4LnNsaWNlKDUsIDcpLCAxNiksXG4gIF07XG59XG5cbnR5cGUgQXBwbGVBY2NlbnRQcmVzZXQgPSB7XG4gIGlkOiBudW1iZXI7XG4gIG5hbWU6IHN0cmluZztcbiAgY29sb3I6IHN0cmluZztcbn07XG5cbmNvbnN0IEFQUExFX0FDQ0VOVF9QUkVTRVRTOiBBcHBsZUFjY2VudFByZXNldFtdID0gW1xuICB7IGlkOiAwLCBuYW1lOiBcIlJlZFwiLCBjb2xvcjogXCIjZmYzYjMwXCIgfSxcbiAgeyBpZDogMSwgbmFtZTogXCJPcmFuZ2VcIiwgY29sb3I6IFwiI2ZmOTUwMFwiIH0sXG4gIHsgaWQ6IDIsIG5hbWU6IFwiWWVsbG93XCIsIGNvbG9yOiBcIiNmZmNjMDBcIiB9LFxuICB7IGlkOiAzLCBuYW1lOiBcIkdyZWVuXCIsIGNvbG9yOiBcIiMzNGM3NTlcIiB9LFxuICB7IGlkOiA0LCBuYW1lOiBcIkJsdWVcIiwgY29sb3I6IFwiIzAwN2FmZlwiIH0sXG4gIHsgaWQ6IDUsIG5hbWU6IFwiUHVycGxlXCIsIGNvbG9yOiBcIiNhZjUyZGVcIiB9LFxuICB7IGlkOiA2LCBuYW1lOiBcIlBpbmtcIiwgY29sb3I6IFwiI2ZmMmQ1NVwiIH0sXG4gIHsgaWQ6IDcsIG5hbWU6IFwiR3JhcGhpdGVcIiwgY29sb3I6IFwiIzhlOGU5M1wiIH0sXG5dO1xuXG5mdW5jdGlvbiBnZXRBcHBsZUFjY2VudE5hbWVGb3JJZChpZDogbnVtYmVyKTogc3RyaW5nIHwgdW5kZWZpbmVkIHtcbiAgaWYgKGlkID09PSAtMSkgcmV0dXJuIFwiTXVsdGljb2xvdXJcIjtcbiAgcmV0dXJuIEFQUExFX0FDQ0VOVF9QUkVTRVRTLmZpbmQoKHByZXNldCkgPT4gcHJlc2V0LmlkID09PSBpZCk/Lm5hbWU7XG59XG5cbmZ1bmN0aW9uIHJlc29sdmVBcHBsZUFjY2VudElkKHZhbHVlOiBzdHJpbmcgfCB1bmRlZmluZWQpOiBudW1iZXIgfCB1bmRlZmluZWQge1xuICBpZiAoIXZhbHVlKSByZXR1cm4gdW5kZWZpbmVkO1xuICBpZiAoL14tP1xcZCskLy50ZXN0KHZhbHVlKSkge1xuICAgIGNvbnN0IGlkID0gTnVtYmVyKHZhbHVlKTtcbiAgICByZXR1cm4gaWQgPj0gLTEgJiYgaWQgPD0gNyA/IGlkIDogdW5kZWZpbmVkO1xuICB9XG5cbiAgY29uc3Qga2V5ID0gdmFsdWUudG9Mb3dlckNhc2UoKS5yZXBsYWNlKC9bXFxzXy1dL2csIFwiXCIpO1xuICBjb25zdCBuYW1lczogUmVjb3JkPHN0cmluZywgbnVtYmVyPiA9IHtcbiAgICBtdWx0aWNvbG9yOiAtMSxcbiAgICBtdWx0aWNvbG91cjogLTEsXG4gICAgcmVkOiAwLFxuICAgIG9yYW5nZTogMSxcbiAgICB5ZWxsb3c6IDIsXG4gICAgZ3JlZW46IDMsXG4gICAgYmx1ZTogNCxcbiAgICBwdXJwbGU6IDUsXG4gICAgcGluazogNixcbiAgICBncmFwaGl0ZTogNyxcbiAgICBncmV5OiA3LFxuICAgIGdyYXk6IDcsXG4gIH07XG5cbiAgcmV0dXJuIG5hbWVzW2tleV07XG59XG5cbmZ1bmN0aW9uIGdldE5lYXJlc3RBcHBsZUFjY2VudE5hbWUoaGV4OiBzdHJpbmcpOiBzdHJpbmcge1xuICBjb25zdCBbciwgZywgYl0gPSBnZXRSZ2IoaGV4KTtcbiAgY29uc3QgbWF4ID0gTWF0aC5tYXgociwgZywgYik7XG4gIGNvbnN0IG1pbiA9IE1hdGgubWluKHIsIGcsIGIpO1xuICBjb25zdCBjaHJvbWEgPSBtYXggLSBtaW47XG5cbiAgaWYgKGNocm9tYSA8IDI0KSByZXR1cm4gXCJHcmFwaGl0ZVwiO1xuXG4gIGxldCBodWU6IG51bWJlcjtcbiAgaWYgKG1heCA9PT0gcikge1xuICAgIGh1ZSA9ICg2MCAqIChnIC0gYikpIC8gY2hyb21hO1xuICAgIGlmIChodWUgPCAwKSBodWUgKz0gMzYwO1xuICB9IGVsc2UgaWYgKG1heCA9PT0gZykge1xuICAgIGh1ZSA9IDEyMCArICg2MCAqIChiIC0gcikpIC8gY2hyb21hO1xuICB9IGVsc2Uge1xuICAgIGh1ZSA9IDI0MCArICg2MCAqIChyIC0gZykpIC8gY2hyb21hO1xuICB9XG5cbiAgaWYgKGh1ZSA8IDE1IHx8IGh1ZSA+PSAzNDUpIHJldHVybiBcIlJlZFwiO1xuICBpZiAoaHVlIDwgNDApIHJldHVybiBcIk9yYW5nZVwiO1xuICBpZiAoaHVlIDwgNzUpIHJldHVybiBcIlllbGxvd1wiO1xuICBpZiAoaHVlIDwgMTY1KSByZXR1cm4gXCJHcmVlblwiO1xuICBpZiAoaHVlIDwgMjU1KSByZXR1cm4gXCJCbHVlXCI7XG4gIGlmIChodWUgPCAyOTApIHJldHVybiBcIlB1cnBsZVwiO1xuICByZXR1cm4gXCJQaW5rXCI7XG59XG5cbmZ1bmN0aW9uIGdldEdob3N0dHlDb2xvcihkaXI6IHN0cmluZywga2V5OiBzdHJpbmcsIGZhbGxiYWNrOiBzdHJpbmcpOiBzdHJpbmcge1xuICBjb25zdCBnaG9zdHR5UGF0aCA9IGpvaW4oZGlyLCBcImdob3N0dHkuY29uZlwiKTtcbiAgaWYgKCFleGlzdHNTeW5jKGdob3N0dHlQYXRoKSkgcmV0dXJuIGZhbGxiYWNrO1xuICBmb3IgKGNvbnN0IGxpbmUgb2YgcmVhZEZpbGVTeW5jKGdob3N0dHlQYXRoLCBcInV0Zi04XCIpLnNwbGl0KFwiXFxuXCIpKSB7XG4gICAgY29uc3QgdHJpbW1lZCA9IGxpbmUudHJpbSgpO1xuICAgIGlmICghdHJpbW1lZC5zdGFydHNXaXRoKGAke2tleX0gPSBgKSkgY29udGludWU7XG4gICAgY29uc3QgdmFsdWUgPSB0cmltbWVkLnNsaWNlKGAke2tleX0gPSBgLmxlbmd0aCkudHJpbSgpO1xuICAgIGlmICgvXiNbMC05YS1mQS1GXXs2fSQvLnRlc3QodmFsdWUpKSByZXR1cm4gdmFsdWU7XG4gIH1cbiAgcmV0dXJuIGZhbGxiYWNrO1xufVxuXG5mdW5jdGlvbiBnZXRHaG9zdHR5UGFsZXR0ZShkaXI6IHN0cmluZyk6IHN0cmluZ1tdIHtcbiAgY29uc3QgZ2hvc3R0eVBhdGggPSBqb2luKGRpciwgXCJnaG9zdHR5LmNvbmZcIik7XG4gIGlmICghZXhpc3RzU3luYyhnaG9zdHR5UGF0aCkpIHJldHVybiBbXTtcbiAgY29uc3QgcGFsZXR0ZTogc3RyaW5nW10gPSBbXTtcbiAgZm9yIChjb25zdCBsaW5lIG9mIHJlYWRGaWxlU3luYyhnaG9zdHR5UGF0aCwgXCJ1dGYtOFwiKS5zcGxpdChcIlxcblwiKSkge1xuICAgIGNvbnN0IHRyaW1tZWQgPSBsaW5lLnRyaW0oKTtcbiAgICBjb25zdCBtYXRjaCA9IHRyaW1tZWQubWF0Y2goL15wYWxldHRlXFxzKj1cXHMqKFxcZCspPVxccyooI1swLTlhLWZBLUZdezZ9KSQvKTtcbiAgICBpZiAoIW1hdGNoKSBjb250aW51ZTtcbiAgICBwYWxldHRlW051bWJlcihtYXRjaFsxXSldID0gbWF0Y2hbMl07XG4gIH1cbiAgcmV0dXJuIHBhbGV0dGU7XG59XG5cbmZ1bmN0aW9uIGdldFRoZW1lQWNjZW50KGRpcjogc3RyaW5nLCBlbnY6IFRoZW1lRW52KTogc3RyaW5nIHtcbiAgY29uc3QgcGFsZXR0ZSA9IGdldEdob3N0dHlQYWxldHRlKGRpcik7XG4gIHJldHVybiBwYWxldHRlWzRdIHx8IGdldEJvcmRlckhleChlbnYpO1xufVxuXG5mdW5jdGlvbiBnZXRTeXN0ZW1BY2NlbnRIZXgoZGlyOiBzdHJpbmcsIGVudjogVGhlbWVFbnYpOiBzdHJpbmcge1xuICByZXR1cm4gKFxuICAgIG5vcm1hbGl6ZUhleENvbG9yKGVudi5TWVNURU1fQUNDRU5UX0NPTE9SKSB8fFxuICAgIG5vcm1hbGl6ZUhleENvbG9yKGVudi5GSVJFRk9YX0FDQ0VOVCkgfHxcbiAgICBub3JtYWxpemVIZXhDb2xvcihlbnYuQk9SREVSX0FDVElWRSkgfHxcbiAgICBnZXRUaGVtZUFjY2VudChkaXIsIGVudilcbiAgKTtcbn1cblxuZnVuY3Rpb24gZ2V0QXBwbGVBY2NlbnROYW1lKGRpcjogc3RyaW5nLCBlbnY6IFRoZW1lRW52KTogc3RyaW5nIHtcbiAgY29uc3QgZXhwbGljaXRJZCA9IHJlc29sdmVBcHBsZUFjY2VudElkKGVudi5BUFBMRV9BQ0NFTlQpO1xuICBpZiAoZXhwbGljaXRJZCAhPT0gdW5kZWZpbmVkKSB7XG4gICAgcmV0dXJuIGdldEFwcGxlQWNjZW50TmFtZUZvcklkKGV4cGxpY2l0SWQpIHx8IFwiQmx1ZVwiO1xuICB9XG5cbiAgY29uc3QgZXhwbGljaXRIZXggPSBub3JtYWxpemVIZXhDb2xvcihlbnYuQVBQTEVfQUNDRU5UKTtcbiAgcmV0dXJuIGdldE5lYXJlc3RBcHBsZUFjY2VudE5hbWUoZXhwbGljaXRIZXggfHwgZ2V0U3lzdGVtQWNjZW50SGV4KGRpciwgZW52KSk7XG59XG5cbmZ1bmN0aW9uIGdldEhpZ2hsaWdodENvbG9yKGRpcjogc3RyaW5nLCBlbnY6IFRoZW1lRW52KTogc3RyaW5nIHtcbiAgY29uc3QgYWNjZW50ID0gZ2V0U3lzdGVtQWNjZW50SGV4KGRpciwgZW52KTtcbiAgcmV0dXJuIChcbiAgICBub3JtYWxpemVIZXhDb2xvcihlbnYuQVBQTEVfSElHSExJR0hUKSB8fFxuICAgIG5vcm1hbGl6ZUhleENvbG9yKGdldEdob3N0dHlDb2xvcihkaXIsIFwic2VsZWN0aW9uLWJhY2tncm91bmRcIiwgYWNjZW50KSkgfHxcbiAgICBhY2NlbnRcbiAgKTtcbn1cblxuZnVuY3Rpb24gZ2V0QmFja2dyb3VuZFN0YXRlKCk6IEJhY2tncm91bmRTdGF0ZSB7XG4gIGlmICghZXhpc3RzU3luYyhUSEVNRV9CQUNLR1JPVU5EX1NUQVRFKSkgcmV0dXJuIHt9O1xuICB0cnkge1xuICAgIGNvbnN0IHBhcnNlZCA9IEpTT04ucGFyc2UocmVhZEZpbGVTeW5jKFRIRU1FX0JBQ0tHUk9VTkRfU1RBVEUsIFwidXRmLThcIikpO1xuICAgIHJldHVybiBwYXJzZWQgJiYgdHlwZW9mIHBhcnNlZCA9PT0gXCJvYmplY3RcIiAmJiAhQXJyYXkuaXNBcnJheShwYXJzZWQpXG4gICAgICA/IHBhcnNlZFxuICAgICAgOiB7fTtcbiAgfSBjYXRjaCB7XG4gICAgcmV0dXJuIHt9O1xuICB9XG59XG5cbmZ1bmN0aW9uIHdyaXRlQmFja2dyb3VuZFN0YXRlKHN0YXRlOiBCYWNrZ3JvdW5kU3RhdGUpIHtcbiAgd3JpdGVGaWxlU3luYyhUSEVNRV9CQUNLR1JPVU5EX1NUQVRFLCBgJHtKU09OLnN0cmluZ2lmeShzdGF0ZSwgbnVsbCwgMil9XFxuYCk7XG59XG5cbmZ1bmN0aW9uIGlzSW1hZ2VGaWxlKGZpbGVOYW1lOiBzdHJpbmcpOiBib29sZWFuIHtcbiAgcmV0dXJuIFtcIi5qcGdcIiwgXCIuanBlZ1wiLCBcIi5wbmdcIiwgXCIud2VicFwiLCBcIi5oZWljXCJdLmluY2x1ZGVzKFxuICAgIGV4dG5hbWUoZmlsZU5hbWUpLnRvTG93ZXJDYXNlKCksXG4gICk7XG59XG5cbmZ1bmN0aW9uIHByZXR0aWZ5QmFja2dyb3VuZE5hbWUoZmlsZU5hbWU6IHN0cmluZyk6IHN0cmluZyB7XG4gIHJldHVybiBiYXNlbmFtZShmaWxlTmFtZSwgZXh0bmFtZShmaWxlTmFtZSkpXG4gICAgLnJlcGxhY2UoL15cXGQrWy1fLlxcc10qLywgXCJcIilcbiAgICAucmVwbGFjZSgvWy1fLl0rL2csIFwiIFwiKVxuICAgIC5yZXBsYWNlKC9cXGJcXHcvZywgKGxldHRlcikgPT4gbGV0dGVyLnRvVXBwZXJDYXNlKCkpO1xufVxuXG5mdW5jdGlvbiBnZXRUaGVtZUJhY2tncm91bmRzKHRoZW1lOiBUaGVtZUVudHJ5KTogQmFja2dyb3VuZEVudHJ5W10ge1xuICBjb25zdCBiZ0RpciA9IGpvaW4oVEhFTUVTX0RJUiwgdGhlbWUubmFtZSwgXCJiYWNrZ3JvdW5kc1wiKTtcbiAgaWYgKCFleGlzdHNTeW5jKGJnRGlyKSkgcmV0dXJuIFtdO1xuXG4gIHJldHVybiByZWFkZGlyU3luYyhiZ0RpciwgeyB3aXRoRmlsZVR5cGVzOiB0cnVlIH0pXG4gICAgLmZpbHRlcigoZW50cnkpID0+IGVudHJ5LmlzRmlsZSgpICYmICFlbnRyeS5uYW1lLnN0YXJ0c1dpdGgoXCIuXCIpKVxuICAgIC5maWx0ZXIoKGVudHJ5KSA9PiBpc0ltYWdlRmlsZShlbnRyeS5uYW1lKSlcbiAgICAubWFwKChlbnRyeSkgPT4ge1xuICAgICAgY29uc3QgcmVsYXRpdmVQYXRoID0gYGJhY2tncm91bmRzLyR7ZW50cnkubmFtZX1gO1xuICAgICAgY29uc3QgcHJldmlld1BhdGggPSBqb2luKFxuICAgICAgICBiZ0RpcixcbiAgICAgICAgXCIucmF5Y2FzdC1ibHVyXCIsXG4gICAgICAgIGAke2Jhc2VuYW1lKGVudHJ5Lm5hbWUsIGV4dG5hbWUoZW50cnkubmFtZSkpfS5qcGdgLFxuICAgICAgKTtcbiAgICAgIGNvbnN0IHBhdGggPSBqb2luKGJnRGlyLCBlbnRyeS5uYW1lKTtcbiAgICAgIHJldHVybiB7XG4gICAgICAgIHRoZW1lTmFtZTogdGhlbWUubmFtZSxcbiAgICAgICAgcmVsYXRpdmVQYXRoLFxuICAgICAgICBwYXRoLFxuICAgICAgICBwcmV2aWV3UGF0aDogZXhpc3RzU3luYyhwcmV2aWV3UGF0aCkgPyBwcmV2aWV3UGF0aCA6IHBhdGgsXG4gICAgICAgIGRpc3BsYXlOYW1lOiBwcmV0dGlmeUJhY2tncm91bmROYW1lKGVudHJ5Lm5hbWUpLFxuICAgICAgfTtcbiAgICB9KVxuICAgIC5zb3J0KChhLCBiKSA9PiBhLnJlbGF0aXZlUGF0aC5sb2NhbGVDb21wYXJlKGIucmVsYXRpdmVQYXRoKSk7XG59XG5cbmZ1bmN0aW9uIGdldFNlbGVjdGVkQmFja2dyb3VuZCh0aGVtZTogVGhlbWVFbnRyeSk6IEJhY2tncm91bmRFbnRyeSB8IHVuZGVmaW5lZCB7XG4gIGNvbnN0IGJhY2tncm91bmRzID0gZ2V0VGhlbWVCYWNrZ3JvdW5kcyh0aGVtZSk7XG4gIGNvbnN0IHN0YXRlID0gZ2V0QmFja2dyb3VuZFN0YXRlKCk7XG4gIGNvbnN0IHNlbGVjdGVkUmVsYXRpdmUgPSBzdGF0ZVt0aGVtZS5uYW1lXSB8fCB0aGVtZS5lbnYuV0FMTFBBUEVSO1xuICByZXR1cm4gKFxuICAgIGJhY2tncm91bmRzLmZpbmQoXG4gICAgICAoYmFja2dyb3VuZCkgPT4gYmFja2dyb3VuZC5yZWxhdGl2ZVBhdGggPT09IHNlbGVjdGVkUmVsYXRpdmUsXG4gICAgKSB8fCBiYWNrZ3JvdW5kc1swXVxuICApO1xufVxuXG5mdW5jdGlvbiBnZXRTa2V0Y2h5YmFyQWNjZW50KGRpcjogc3RyaW5nLCBlbnY6IFRoZW1lRW52KTogc3RyaW5nIHtcbiAgY29uc3QgcGFsZXR0ZSA9IGdldEdob3N0dHlQYWxldHRlKGRpcik7XG4gIHJldHVybiBwYWxldHRlWzRdIHx8IGdldEJvcmRlckhleChlbnYpO1xufVxuXG5mdW5jdGlvbiB0b01hY29zQ29sb3IoaGV4OiBzdHJpbmcpOiBzdHJpbmcge1xuICByZXR1cm4gL14jWzAtOWEtZkEtRl17Nn0kLy50ZXN0KGhleCkgPyBgMHhmZiR7aGV4LnNsaWNlKDEpfWAgOiBcIjB4ZmZmZmZmZmZcIjtcbn1cblxuZnVuY3Rpb24gZ2V0UmF5Y2FzdFRoZW1lSWQodGhlbWU6IFRoZW1lRW50cnkpOiBzdHJpbmcge1xuICByZXR1cm4gdGhlbWUuaXNEYXJrID8gXCJidW5kbGVkLXJheWNhc3QtZGFya1wiIDogXCJidW5kbGVkLXJheWNhc3QtbGlnaHRcIjtcbn1cblxuZnVuY3Rpb24gZ2V0VGhlbWVzKCk6IFRoZW1lRW50cnlbXSB7XG4gIGlmICghZXhpc3RzU3luYyhUSEVNRVNfRElSKSkgcmV0dXJuIFtdO1xuICByZXR1cm4gcmVhZGRpclN5bmMoVEhFTUVTX0RJUiwgeyB3aXRoRmlsZVR5cGVzOiB0cnVlIH0pXG4gICAgLmZpbHRlcigoZCkgPT4gZC5pc0RpcmVjdG9yeSgpKVxuICAgIC5tYXAoKGQpID0+IHtcbiAgICAgIGNvbnN0IGRpciA9IGpvaW4oVEhFTUVTX0RJUiwgZC5uYW1lKTtcbiAgICAgIGNvbnN0IGVudiA9IHBhcnNlVGhlbWVFbnYoZGlyKTtcbiAgICAgIGNvbnN0IGJnRGlyID0gam9pbihkaXIsIFwiYmFja2dyb3VuZHNcIik7XG4gICAgICBjb25zdCBiZ0NvdW50ID0gZXhpc3RzU3luYyhiZ0RpcilcbiAgICAgICAgPyByZWFkZGlyU3luYyhiZ0RpciwgeyB3aXRoRmlsZVR5cGVzOiB0cnVlIH0pLmZpbHRlcihcbiAgICAgICAgICAgIChlbnRyeSkgPT4gZW50cnkuaXNGaWxlKCkgJiYgaXNJbWFnZUZpbGUoZW50cnkubmFtZSksXG4gICAgICAgICAgKS5sZW5ndGhcbiAgICAgICAgOiAwO1xuICAgICAgY29uc3Qgc2VsZWN0ZWRXYWxscGFwZXIgPVxuICAgICAgICBnZXRCYWNrZ3JvdW5kU3RhdGUoKVtkLm5hbWVdIHx8IGVudi5XQUxMUEFQRVIgfHwgXCJcIjtcbiAgICAgIHJldHVybiB7XG4gICAgICAgIG5hbWU6IGQubmFtZSxcbiAgICAgICAgZGlzcGxheU5hbWU6IGQubmFtZVxuICAgICAgICAgIC5zcGxpdChcIi1cIilcbiAgICAgICAgICAubWFwKCh3KSA9PiB3LmNoYXJBdCgwKS50b1VwcGVyQ2FzZSgpICsgdy5zbGljZSgxKSlcbiAgICAgICAgICAuam9pbihcIiBcIiksXG4gICAgICAgIGVudixcbiAgICAgICAgaGFzV2FsbHBhcGVyOiBleGlzdHNTeW5jKGpvaW4oZGlyLCBzZWxlY3RlZFdhbGxwYXBlcikpLFxuICAgICAgICB3YWxscGFwZXJQYXRoOiBleGlzdHNTeW5jKGpvaW4oZGlyLCBzZWxlY3RlZFdhbGxwYXBlcikpXG4gICAgICAgICAgPyBqb2luKGRpciwgc2VsZWN0ZWRXYWxscGFwZXIpXG4gICAgICAgICAgOiB1bmRlZmluZWQsXG4gICAgICAgIGFjY2VudENvbG9yOiBnZXRUaGVtZUFjY2VudChkaXIsIGVudiksXG4gICAgICAgIHNrZXRjaHliYXJBY2NlbnRDb2xvcjogZ2V0U2tldGNoeWJhckFjY2VudChkaXIsIGVudiksXG4gICAgICAgIHRleHRDb2xvcjogZ2V0R2hvc3R0eUNvbG9yKFxuICAgICAgICAgIGRpcixcbiAgICAgICAgICBcImZvcmVncm91bmRcIixcbiAgICAgICAgICBlbnYuREFSS19NT0RFID09PSBcInRydWVcIiA/IFwiI2ZmZmZmZlwiIDogXCIjMDAwMDAwXCIsXG4gICAgICAgICksXG4gICAgICAgIHBhbGV0dGU6IGdldEdob3N0dHlQYWxldHRlKGRpciksXG4gICAgICAgIGlzRGFyazogZW52LkRBUktfTU9ERSA9PT0gXCJ0cnVlXCIsXG4gICAgICAgIGJnQ291bnQsXG4gICAgICAgIGFwcGxlQWNjZW50TmFtZTogZ2V0QXBwbGVBY2NlbnROYW1lKGRpciwgZW52KSxcbiAgICAgICAgaGlnaGxpZ2h0Q29sb3I6IGdldEhpZ2hsaWdodENvbG9yKGRpciwgZW52KSxcbiAgICAgIH07XG4gICAgfSlcbiAgICAuc29ydCgoYSwgYikgPT4gYS5uYW1lLmxvY2FsZUNvbXBhcmUoYi5uYW1lKSk7XG59XG5cbmZ1bmN0aW9uIGdldEN1cnJlbnRUaGVtZSgpOiBzdHJpbmcge1xuICBjb25zdCBwYXRoID0gam9pbihUSEVNRVNfRElSLCBcIi5jdXJyZW50XCIpO1xuICBpZiAoIWV4aXN0c1N5bmMocGF0aCkpIHJldHVybiBcIlwiO1xuICByZXR1cm4gcmVhZEZpbGVTeW5jKHBhdGgsIFwidXRmLThcIikudHJpbSgpO1xufVxuXG5mdW5jdGlvbiBtYXBDb2RleFRoZW1lKHRoZW1lOiBUaGVtZUVudHJ5KTogc3RyaW5nIHtcbiAgY29uc3QgbmFtZSA9IHRoZW1lLm5hbWUudG9Mb3dlckNhc2UoKTtcbiAgY29uc3QgZGlyZWN0TWFwOiBSZWNvcmQ8c3RyaW5nLCBzdHJpbmc+ID0ge1xuICAgIGNhdHBwdWNjaW46IFwiY2F0cHB1Y2Npbi1tb2NoYVwiLFxuICAgIFwiY2F0cHB1Y2Npbi1sYXR0ZVwiOiBcImNhdHBwdWNjaW4tbGF0dGVcIixcbiAgICBncnV2Ym94OiBcImdydXZib3gtZGFya1wiLFxuICAgIG5vcmQ6IFwibm9yZFwiLFxuICAgIGV2ZXJmb3Jlc3Q6IFwiemVuYnVyblwiLFxuICB9O1xuICBpZiAoZGlyZWN0TWFwW25hbWVdKSByZXR1cm4gZGlyZWN0TWFwW25hbWVdO1xuICByZXR1cm4gdGhlbWUuaXNEYXJrID8gXCJvbmUtaGFsZi1kYXJrXCIgOiBcIm9uZS1oYWxmLWxpZ2h0XCI7XG59XG5cbmZ1bmN0aW9uIHNldENvZGV4VGhlbWUodGhlbWU6IFRoZW1lRW50cnkpIHtcbiAgaWYgKCFleGlzdHNTeW5jKENPREVYX0NPTkZJRykpIHJldHVybjtcbiAgY29uc3QgY29kZXhUaGVtZSA9IG1hcENvZGV4VGhlbWUodGhlbWUpO1xuICBjb25zdCBvcmlnaW5hbCA9IHJlYWRGaWxlU3luYyhDT0RFWF9DT05GSUcsIFwidXRmLThcIik7XG4gIGNvbnN0IGxpbmVzID0gb3JpZ2luYWwuc3BsaXQoXCJcXG5cIik7XG5cbiAgbGV0IGluVHVpID0gZmFsc2U7XG4gIGxldCB0dWlIZWFkZXJJbmRleCA9IC0xO1xuICBsZXQgdGhlbWVTZXQgPSBmYWxzZTtcblxuICBmb3IgKGxldCBpID0gMDsgaSA8IGxpbmVzLmxlbmd0aDsgaSsrKSB7XG4gICAgY29uc3QgbGluZSA9IGxpbmVzW2ldO1xuICAgIGlmICgvXlxcWy4qXFxdJC8udGVzdChsaW5lLnRyaW0oKSkpIHtcbiAgICAgIGluVHVpID0gbGluZS50cmltKCkgPT09IFwiW3R1aV1cIjtcbiAgICAgIGlmIChpblR1aSkgdHVpSGVhZGVySW5kZXggPSBpO1xuICAgICAgY29udGludWU7XG4gICAgfVxuICAgIGlmIChpblR1aSAmJiAvXlxccyp0aGVtZVxccyo9Ly50ZXN0KGxpbmUpKSB7XG4gICAgICBsaW5lc1tpXSA9IGB0aGVtZSA9IFwiJHtjb2RleFRoZW1lfVwiYDtcbiAgICAgIHRoZW1lU2V0ID0gdHJ1ZTtcbiAgICAgIGJyZWFrO1xuICAgIH1cbiAgfVxuXG4gIGlmICghdGhlbWVTZXQgJiYgdHVpSGVhZGVySW5kZXggIT09IC0xKSB7XG4gICAgbGluZXMuc3BsaWNlKHR1aUhlYWRlckluZGV4ICsgMSwgMCwgYHRoZW1lID0gXCIke2NvZGV4VGhlbWV9XCJgKTtcbiAgfSBlbHNlIGlmICghdGhlbWVTZXQgJiYgdHVpSGVhZGVySW5kZXggPT09IC0xKSB7XG4gICAgaWYgKGxpbmVzLmxlbmd0aCA+IDAgJiYgbGluZXNbbGluZXMubGVuZ3RoIC0gMV0udHJpbSgpICE9PSBcIlwiKVxuICAgICAgbGluZXMucHVzaChcIlwiKTtcbiAgICBsaW5lcy5wdXNoKFwiW3R1aV1cIik7XG4gICAgbGluZXMucHVzaChgdGhlbWUgPSBcIiR7Y29kZXhUaGVtZX1cImApO1xuICB9XG5cbiAgd3JpdGVGaWxlU3luYyhDT0RFWF9DT05GSUcsIGxpbmVzLmpvaW4oXCJcXG5cIikucmVwbGFjZSgvXFxuKiQvLCBcIlxcblwiKSk7XG59XG5cbmZ1bmN0aW9uIHNwYXduVGhlbWVBcHBseVdvcmtlcih0aGVtZTogVGhlbWVFbnRyeSkge1xuICBjb25zdCB3b3JrZXJTb3VyY2UgPSBTdHJpbmcucmF3YFxuY29uc3QgeyBleGlzdHNTeW5jIH0gPSByZXF1aXJlKFwiZnNcIik7XG5jb25zdCB7IGhvbWVkaXIgfSA9IHJlcXVpcmUoXCJvc1wiKTtcbmNvbnN0IHsgam9pbiB9ID0gcmVxdWlyZShcInBhdGhcIik7XG5jb25zdCB7IHNwYXduIH0gPSByZXF1aXJlKFwiY2hpbGRfcHJvY2Vzc1wiKTtcblxuY29uc3QgdGhlbWUgPSBKU09OLnBhcnNlKHByb2Nlc3MuYXJndlsxXSk7XG5jb25zdCBUSEVNRV9TV0lUQ0hfQklOID0gam9pbihob21lZGlyKCksIFwiLmxvY2FsXCIsIFwiYmluXCIsIFwidGhlbWUtc3dpdGNoXCIpO1xuY29uc3QgUEFUSCA9ICR7SlNPTi5zdHJpbmdpZnkoUEFUSCl9O1xuXG5mdW5jdGlvbiBydW5UaGVtZVN3aXRjaChhcmdzKSB7XG4gIHJldHVybiBuZXcgUHJvbWlzZSgocmVzb2x2ZSwgcmVqZWN0KSA9PiB7XG4gICAgY29uc3QgY2hpbGQgPSBzcGF3bihUSEVNRV9TV0lUQ0hfQklOLCBhcmdzLCB7XG4gICAgICBlbnY6IHsgLi4ucHJvY2Vzcy5lbnYsIEhPTUU6IGhvbWVkaXIoKSwgUEFUSCB9LFxuICAgICAgc3RkaW86IFwiaWdub3JlXCIsXG4gICAgfSk7XG4gICAgY2hpbGQub24oXCJlcnJvclwiLCByZWplY3QpO1xuICAgIGNoaWxkLm9uKFwiZXhpdFwiLCAoY29kZSkgPT4ge1xuICAgICAgaWYgKGNvZGUgPT09IDApIHJlc29sdmUoKTtcbiAgICAgIGVsc2UgcmVqZWN0KG5ldyBFcnJvcihcInRoZW1lLXN3aXRjaCBleGl0ZWQgXCIgKyBjb2RlKSk7XG4gICAgfSk7XG4gIH0pO1xufVxuXG5hc3luYyBmdW5jdGlvbiBtYWluKCkge1xuICBjb25zdCB7IG5hbWUgfSA9IHRoZW1lO1xuICBpZiAoIWV4aXN0c1N5bmMoVEhFTUVfU1dJVENIX0JJTikpIHByb2Nlc3MuZXhpdCgxKTtcbiAgLy8gUnVuIHN5bmNocm9ub3VzbHk6IHRoZW1lLXN3aXRjaCB3cml0ZXMgfi8udGhlbWVzLy5jdXJyZW50IG9ubHkgYWZ0ZXIgR2hvc3R0eS9SYXljYXN0L2V0Yy4gZmluaXNoLlxuICAvLyAoQmFja2dyb3VuZGluZyB3aXRoICYgY2F1c2VkIHRoZSBVSSB0byBzaG93IFwiYWN0aXZlXCIgYmVmb3JlIGVtdWxhdG9ycyBhY3R1YWxseSByZWxvYWRlZC4pXG4gIGF3YWl0IHJ1blRoZW1lU3dpdGNoKFtuYW1lXSk7XG59XG5cbm1haW4oKS5jYXRjaCgoKSA9PiBwcm9jZXNzLmV4aXQoMSkpO1xuYDtcblxuICBjb25zdCB3b3JrZXIgPSBzcGF3bihcbiAgICBwcm9jZXNzLmV4ZWNQYXRoLFxuICAgIFtcIi1lXCIsIHdvcmtlclNvdXJjZSwgSlNPTi5zdHJpbmdpZnkodGhlbWUpXSxcbiAgICB7XG4gICAgICBkZXRhY2hlZDogdHJ1ZSxcbiAgICAgIHN0ZGlvOiBcImlnbm9yZVwiLFxuICAgIH0sXG4gICk7XG4gIHdvcmtlci51bnJlZigpO1xufVxuXG5mdW5jdGlvbiBzcGF3bkJhY2tncm91bmRBcHBseVdvcmtlcihcbiAgdGhlbWU6IFRoZW1lRW50cnksXG4gIGJhY2tncm91bmQ6IEJhY2tncm91bmRFbnRyeSxcbikge1xuICBjb25zdCB3b3JrZXJTb3VyY2UgPSBTdHJpbmcucmF3YFxuY29uc3QgeyBob21lZGlyIH0gPSByZXF1aXJlKFwib3NcIik7XG5jb25zdCB7IGpvaW4gfSA9IHJlcXVpcmUoXCJwYXRoXCIpO1xuY29uc3QgeyBzcGF3biB9ID0gcmVxdWlyZShcImNoaWxkX3Byb2Nlc3NcIik7XG5cbmNvbnN0IHRoZW1lTmFtZSA9IHByb2Nlc3MuYXJndlsxXTtcbmNvbnN0IGJhY2tncm91bmRQYXRoID0gcHJvY2Vzcy5hcmd2WzJdO1xuY29uc3QgVEhFTUVfU1dJVENIX0JJTiA9IGpvaW4oaG9tZWRpcigpLCBcIi5sb2NhbFwiLCBcImJpblwiLCBcInRoZW1lLXN3aXRjaFwiKTtcbmNvbnN0IFBBVEggPSAke0pTT04uc3RyaW5naWZ5KFBBVEgpfTtcblxuY29uc3QgY2hpbGQgPSBzcGF3bihUSEVNRV9TV0lUQ0hfQklOLCBbXCItLWJhY2tncm91bmRcIiwgdGhlbWVOYW1lLCBiYWNrZ3JvdW5kUGF0aF0sIHtcbiAgZGV0YWNoZWQ6IHRydWUsXG4gIGVudjogeyAuLi5wcm9jZXNzLmVudiwgSE9NRTogaG9tZWRpcigpLCBQQVRIIH0sXG4gIHN0ZGlvOiBcImlnbm9yZVwiLFxufSk7XG5jaGlsZC51bnJlZigpO1xuYDtcblxuICBjb25zdCB3b3JrZXIgPSBzcGF3bihcbiAgICBwcm9jZXNzLmV4ZWNQYXRoLFxuICAgIFtcIi1lXCIsIHdvcmtlclNvdXJjZSwgdGhlbWUubmFtZSwgYmFja2dyb3VuZC5yZWxhdGl2ZVBhdGhdLFxuICAgIHtcbiAgICAgIGRldGFjaGVkOiB0cnVlLFxuICAgICAgc3RkaW86IFwiaWdub3JlXCIsXG4gICAgfSxcbiAgKTtcbiAgd29ya2VyLnVucmVmKCk7XG59XG5cbmZ1bmN0aW9uIEJhY2tncm91bmRQaWNrZXIocHJvcHM6IHtcbiAgdGhlbWU6IFRoZW1lRW50cnk7XG4gIG9uU2VsZWN0OiAodGhlbWVOYW1lOiBzdHJpbmcsIHJlbGF0aXZlUGF0aDogc3RyaW5nKSA9PiB2b2lkO1xufSkge1xuICBjb25zdCBhbGxCYWNrZ3JvdW5kcyA9IGdldFRoZW1lQmFja2dyb3VuZHMocHJvcHMudGhlbWUpO1xuICBjb25zdCBzZWxlY3RlZCA9IGdldFNlbGVjdGVkQmFja2dyb3VuZChwcm9wcy50aGVtZSk7XG5cbiAgY29uc3QgYmFja2dyb3VuZHMgPSBzZWxlY3RlZFxuICAgID8gW1xuICAgICAgICBzZWxlY3RlZCxcbiAgICAgICAgLi4uYWxsQmFja2dyb3VuZHMuZmlsdGVyKFxuICAgICAgICAgIChiZykgPT4gYmcucmVsYXRpdmVQYXRoICE9PSBzZWxlY3RlZC5yZWxhdGl2ZVBhdGgsXG4gICAgICAgICksXG4gICAgICBdXG4gICAgOiBhbGxCYWNrZ3JvdW5kcztcblxuICByZXR1cm4gKFxuICAgIDxHcmlkXG4gICAgICBjb2x1bW5zPXsyfVxuICAgICAgaW5zZXQ9e0dyaWQuSW5zZXQuU21hbGx9XG4gICAgICBmaXQ9e0dyaWQuRml0LkZpbGx9XG4gICAgICBhc3BlY3RSYXRpbz1cIjE2LzlcIlxuICAgICAgbmF2aWdhdGlvblRpdGxlPXtgU3dpdGNoIEJhY2tncm91bmQgKCR7cHJvcHMudGhlbWUuZGlzcGxheU5hbWV9KWB9XG4gICAgICBzZWFyY2hCYXJQbGFjZWhvbGRlcj1cIlNlYXJjaCBiYWNrZ3JvdW5kcy4uLlwiXG4gICAgPlxuICAgICAge2JhY2tncm91bmRzLm1hcCgoYmFja2dyb3VuZCkgPT4ge1xuICAgICAgICBjb25zdCBpc1NlbGVjdGVkID0gYmFja2dyb3VuZC5yZWxhdGl2ZVBhdGggPT09IHNlbGVjdGVkPy5yZWxhdGl2ZVBhdGg7XG4gICAgICAgIHJldHVybiAoXG4gICAgICAgICAgPEdyaWQuSXRlbVxuICAgICAgICAgICAga2V5PXtiYWNrZ3JvdW5kLnJlbGF0aXZlUGF0aH1cbiAgICAgICAgICAgIHRpdGxlPXtiYWNrZ3JvdW5kLmRpc3BsYXlOYW1lfVxuICAgICAgICAgICAgYWNjZXNzb3J5PXtcbiAgICAgICAgICAgICAgaXNTZWxlY3RlZFxuICAgICAgICAgICAgICAgID8geyBpY29uOiBJY29uLkNoZWNrQ2lyY2xlLCB0b29sdGlwOiBcIkN1cnJlbnRcIiB9XG4gICAgICAgICAgICAgICAgOiB1bmRlZmluZWRcbiAgICAgICAgICAgIH1cbiAgICAgICAgICAgIGNvbnRlbnQ9e3sgc291cmNlOiBiYWNrZ3JvdW5kLnBhdGggfX1cbiAgICAgICAgICAgIGFjdGlvbnM9e1xuICAgICAgICAgICAgICA8QWN0aW9uUGFuZWw+XG4gICAgICAgICAgICAgICAgPEFjdGlvblxuICAgICAgICAgICAgICAgICAgdGl0bGU9XCJVc2UgQmFja2dyb3VuZFwiXG4gICAgICAgICAgICAgICAgICBpY29uPXtJY29uLkltYWdlfVxuICAgICAgICAgICAgICAgICAgb25BY3Rpb249e2FzeW5jICgpID0+IHtcbiAgICAgICAgICAgICAgICAgICAgY29uc3Qgc3RhdGUgPSBnZXRCYWNrZ3JvdW5kU3RhdGUoKTtcbiAgICAgICAgICAgICAgICAgICAgc3RhdGVbcHJvcHMudGhlbWUubmFtZV0gPSBiYWNrZ3JvdW5kLnJlbGF0aXZlUGF0aDtcbiAgICAgICAgICAgICAgICAgICAgd3JpdGVCYWNrZ3JvdW5kU3RhdGUoc3RhdGUpO1xuICAgICAgICAgICAgICAgICAgICBwcm9wcy5vblNlbGVjdChwcm9wcy50aGVtZS5uYW1lLCBiYWNrZ3JvdW5kLnJlbGF0aXZlUGF0aCk7XG4gICAgICAgICAgICAgICAgICAgIHNwYXduQmFja2dyb3VuZEFwcGx5V29ya2VyKHByb3BzLnRoZW1lLCBiYWNrZ3JvdW5kKTtcbiAgICAgICAgICAgICAgICAgICAgYXdhaXQgY2xvc2VNYWluV2luZG93KCk7XG4gICAgICAgICAgICAgICAgICB9fVxuICAgICAgICAgICAgICAgIC8+XG4gICAgICAgICAgICAgIDwvQWN0aW9uUGFuZWw+XG4gICAgICAgICAgICB9XG4gICAgICAgICAgLz5cbiAgICAgICAgKTtcbiAgICAgIH0pfVxuICAgIDwvR3JpZD5cbiAgKTtcbn1cblxuZXhwb3J0IGRlZmF1bHQgZnVuY3Rpb24gQ29tbWFuZCgpIHtcbiAgY29uc3QgdGhlbWVzID0gZ2V0VGhlbWVzKCk7XG4gIGNvbnN0IFtjdXJyZW50LCBzZXRDdXJyZW50XSA9IHVzZVN0YXRlKCgpID0+IGdldEN1cnJlbnRUaGVtZSgpKTtcbiAgY29uc3QgW3BlbmRpbmdUaGVtZSwgc2V0UGVuZGluZ1RoZW1lXSA9IHVzZVN0YXRlPHN0cmluZyB8IG51bGw+KG51bGwpO1xuICBjb25zdCBbYmFja2dyb3VuZFZlcnNpb24sIHNldEJhY2tncm91bmRWZXJzaW9uXSA9IHVzZVN0YXRlKDApO1xuXG4gIHVzZUVmZmVjdCgoKSA9PiB7XG4gICAgY29uc3Qgc3luY0N1cnJlbnRUaGVtZSA9ICgpID0+IHtcbiAgICAgIGNvbnN0IG5leHQgPSBnZXRDdXJyZW50VGhlbWUoKTtcbiAgICAgIHNldEN1cnJlbnQoKHByZXYpID0+IChwcmV2ID09PSBuZXh0ID8gcHJldiA6IG5leHQpKTtcbiAgICB9O1xuXG4gICAgc3luY0N1cnJlbnRUaGVtZSgpO1xuICAgIGNvbnN0IGludGVydmFsID0gc2V0SW50ZXJ2YWwoc3luY0N1cnJlbnRUaGVtZSwgNzUwKTtcbiAgICByZXR1cm4gKCkgPT4gY2xlYXJJbnRlcnZhbChpbnRlcnZhbCk7XG4gIH0sIFtdKTtcblxuICBmdW5jdGlvbiBnZXRUaGVtZVByZXZpZXcodGhlbWU6IFRoZW1lRW50cnkpOiBzdHJpbmcge1xuICAgIGNvbnN0IHNlbGVjdGVkQmFja2dyb3VuZCA9IGdldFNlbGVjdGVkQmFja2dyb3VuZCh0aGVtZSk7XG4gICAgY29uc3Qgd2FsbHBhcGVyUHJldmlldyA9IHNlbGVjdGVkQmFja2dyb3VuZFxuICAgICAgPyBgIVske3RoZW1lLmRpc3BsYXlOYW1lfV0oJHtlbmNvZGVVUkkoYGZpbGU6Ly8ke3NlbGVjdGVkQmFja2dyb3VuZC5wcmV2aWV3UGF0aH1gKX0/cmF5Y2FzdC13aWR0aD03MjAmcmF5Y2FzdC1oZWlnaHQ9NDA1KWBcbiAgICAgIDogXCJfTm8gd2FsbHBhcGVyIHByZXZpZXcgYXZhaWxhYmxlX1wiO1xuICAgIGNvbnN0IGxpbmVzID0gW1xuICAgICAgYCMgJHt0aGVtZS5kaXNwbGF5TmFtZX1gLFxuICAgICAgXCJcIixcbiAgICAgIHdhbGxwYXBlclByZXZpZXcsXG4gICAgICBcIlwiLFxuICAgICAgc2VsZWN0ZWRCYWNrZ3JvdW5kXG4gICAgICAgID8gYEJhY2tncm91bmQgXFxgJHtzZWxlY3RlZEJhY2tncm91bmQuZGlzcGxheU5hbWV9XFxgYFxuICAgICAgICA6IFwiXCIsXG4gICAgICBgQWNjZW50IFxcYCR7dGhlbWUuYWNjZW50Q29sb3J9XFxgYCxcbiAgICAgIGBtYWNPUyBBY2NlbnQgXFxgJHt0aGVtZS5hcHBsZUFjY2VudE5hbWV9XFxgYCxcbiAgICAgIGBIaWdobGlnaHQgXFxgJHt0aGVtZS5oaWdobGlnaHRDb2xvcn1cXGBgLFxuICAgICAgYFRleHQgXFxgJHt0aGVtZS50ZXh0Q29sb3J9XFxgYCxcbiAgICBdO1xuXG4gICAgcmV0dXJuIGxpbmVzLmpvaW4oXCJcXG5cIik7XG4gIH1cblxuICBmdW5jdGlvbiBnZXRMc1ByZXZpZXdDb2xvcnModGhlbWU6IFRoZW1lRW50cnkpIHtcbiAgICByZXR1cm4ge1xuICAgICAgZGlyZWN0b3J5OiB0aGVtZS5wYWxldHRlWzRdIHx8IHRoZW1lLmFjY2VudENvbG9yLFxuICAgICAgc3ltbGluazogdGhlbWUucGFsZXR0ZVs2XSB8fCB0aGVtZS5hY2NlbnRDb2xvcixcbiAgICAgIGV4ZWN1dGFibGU6IHRoZW1lLnBhbGV0dGVbMl0gfHwgdGhlbWUuYWNjZW50Q29sb3IsXG4gICAgICBhcmNoaXZlOiB0aGVtZS5wYWxldHRlWzFdIHx8IHRoZW1lLmFjY2VudENvbG9yLFxuICAgICAgZGV2aWNlOiB0aGVtZS5wYWxldHRlWzNdIHx8IHRoZW1lLmFjY2VudENvbG9yLFxuICAgICAgbm9ybWFsOiB0aGVtZS50ZXh0Q29sb3IsXG4gICAgfTtcbiAgfVxuXG4gIGNvbnN0IGFjdGl2ZVRoZW1lID1cbiAgICB0aGVtZXMuZmluZCgodGhlbWUpID0+IHRoZW1lLm5hbWUgPT09IGN1cnJlbnQpIHx8IHRoZW1lc1swXTtcbiAgY29uc3QgYWN0aXZlQmFja2dyb3VuZCA9IGFjdGl2ZVRoZW1lXG4gICAgPyBnZXRTZWxlY3RlZEJhY2tncm91bmQoYWN0aXZlVGhlbWUpXG4gICAgOiB1bmRlZmluZWQ7XG5cbiAgZnVuY3Rpb24gZ2V0QmFja2dyb3VuZFByZXZpZXdNYXJrZG93bih0aGVtZTogVGhlbWVFbnRyeSk6IHN0cmluZyB7XG4gICAgY29uc3Qgc2VsZWN0ZWQgPSBnZXRTZWxlY3RlZEJhY2tncm91bmQodGhlbWUpO1xuICAgIGlmICghc2VsZWN0ZWQpIHJldHVybiBcIl9ObyBiYWNrZ3JvdW5kIG9wdGlvbnMgYXZhaWxhYmxlX1wiO1xuICAgIHJldHVybiBgIVske3NlbGVjdGVkLmRpc3BsYXlOYW1lfV0oJHtlbmNvZGVVUkkoYGZpbGU6Ly8ke3NlbGVjdGVkLnByZXZpZXdQYXRofWApfT9yYXljYXN0LXdpZHRoPTcyMCZyYXljYXN0LWhlaWdodD00MDUpYDtcbiAgfVxuXG4gIHJldHVybiAoXG4gICAgPExpc3QgaXNTaG93aW5nRGV0YWlsIHNlYXJjaEJhclBsYWNlaG9sZGVyPVwiU2VhcmNoIHRoZW1lcy4uLlwiPlxuICAgICAge2FjdGl2ZVRoZW1lID8gKFxuICAgICAgICA8TGlzdC5JdGVtXG4gICAgICAgICAga2V5PXtgc3dpdGNoLWJhY2tncm91bmQtJHtiYWNrZ3JvdW5kVmVyc2lvbn1gfVxuICAgICAgICAgIHRpdGxlPVwiU3dpdGNoIEJhY2tncm91bmRcIlxuICAgICAgICAgIHN1YnRpdGxlPXthY3RpdmVUaGVtZS5kaXNwbGF5TmFtZX1cbiAgICAgICAgICBpY29uPXtJY29uLkFwcFdpbmRvd0dyaWQyeDJ9XG4gICAgICAgICAgYWNjZXNzb3JpZXM9e1t7IHRleHQ6IGAke2FjdGl2ZVRoZW1lLmJnQ291bnR9IG9wdGlvbnNgIH1dfVxuICAgICAgICAgIGRldGFpbD17XG4gICAgICAgICAgICA8TGlzdC5JdGVtLkRldGFpbFxuICAgICAgICAgICAgICBtYXJrZG93bj17Z2V0QmFja2dyb3VuZFByZXZpZXdNYXJrZG93bihhY3RpdmVUaGVtZSl9XG4gICAgICAgICAgICAvPlxuICAgICAgICAgIH1cbiAgICAgICAgICBhY3Rpb25zPXtcbiAgICAgICAgICAgIDxBY3Rpb25QYW5lbD5cbiAgICAgICAgICAgICAgPEFjdGlvbi5QdXNoXG4gICAgICAgICAgICAgICAgdGl0bGU9XCJPcGVuIEJhY2tncm91bmRzXCJcbiAgICAgICAgICAgICAgICBpY29uPXtJY29uLkZvbGRlcn1cbiAgICAgICAgICAgICAgICB0YXJnZXQ9e1xuICAgICAgICAgICAgICAgICAgPEJhY2tncm91bmRQaWNrZXJcbiAgICAgICAgICAgICAgICAgICAgdGhlbWU9e2FjdGl2ZVRoZW1lfVxuICAgICAgICAgICAgICAgICAgICBvblNlbGVjdD17KCkgPT5cbiAgICAgICAgICAgICAgICAgICAgICBzZXRCYWNrZ3JvdW5kVmVyc2lvbigodmVyc2lvbikgPT4gdmVyc2lvbiArIDEpXG4gICAgICAgICAgICAgICAgICAgIH1cbiAgICAgICAgICAgICAgICAgIC8+XG4gICAgICAgICAgICAgICAgfVxuICAgICAgICAgICAgICAvPlxuICAgICAgICAgICAgPC9BY3Rpb25QYW5lbD5cbiAgICAgICAgICB9XG4gICAgICAgIC8+XG4gICAgICApIDogbnVsbH1cbiAgICAgIHt0aGVtZXMubWFwKCh0aGVtZSkgPT4ge1xuICAgICAgICBjb25zdCBpc0N1cnJlbnQgPSB0aGVtZS5uYW1lID09PSAocGVuZGluZ1RoZW1lIHx8IGN1cnJlbnQpO1xuICAgICAgICBjb25zdCBhY2Nlc3NvcmllczogTGlzdC5JdGVtLkFjY2Vzc29yeVtdID0gW107XG4gICAgICAgIGlmIChpc0N1cnJlbnQpXG4gICAgICAgICAgYWNjZXNzb3JpZXMucHVzaCh7IHRhZzogeyB2YWx1ZTogXCJhY3RpdmVcIiwgY29sb3I6IENvbG9yLkdyZWVuIH0gfSk7XG4gICAgICAgIGFjY2Vzc29yaWVzLnB1c2goeyBpY29uOiB0aGVtZS5pc0RhcmsgPyBJY29uLk1vb24gOiBJY29uLlN1biB9KTtcbiAgICAgICAgaWYgKHRoZW1lLmJnQ291bnQgPiAwKVxuICAgICAgICAgIGFjY2Vzc29yaWVzLnB1c2goeyB0ZXh0OiBgJHt0aGVtZS5iZ0NvdW50fSBiZ2AgfSk7XG5cbiAgICAgICAgcmV0dXJuIChcbiAgICAgICAgICA8TGlzdC5JdGVtXG4gICAgICAgICAgICBrZXk9e3RoZW1lLm5hbWV9XG4gICAgICAgICAgICB0aXRsZT17dGhlbWUuZGlzcGxheU5hbWV9XG4gICAgICAgICAgICBpY29uPXt7XG4gICAgICAgICAgICAgIHNvdXJjZTogSWNvbi5DaXJjbGUsXG4gICAgICAgICAgICAgIHRpbnRDb2xvcjogdGhlbWUuYWNjZW50Q29sb3IgYXMgQ29sb3IsXG4gICAgICAgICAgICB9fVxuICAgICAgICAgICAgYWNjZXNzb3JpZXM9e2FjY2Vzc29yaWVzfVxuICAgICAgICAgICAgZGV0YWlsPXtcbiAgICAgICAgICAgICAgPExpc3QuSXRlbS5EZXRhaWxcbiAgICAgICAgICAgICAgICBtYXJrZG93bj17Z2V0VGhlbWVQcmV2aWV3KHRoZW1lKX1cbiAgICAgICAgICAgICAgICBtZXRhZGF0YT17XG4gICAgICAgICAgICAgICAgICA8TGlzdC5JdGVtLkRldGFpbC5NZXRhZGF0YT5cbiAgICAgICAgICAgICAgICAgICAgPExpc3QuSXRlbS5EZXRhaWwuTWV0YWRhdGEuTGFiZWxcbiAgICAgICAgICAgICAgICAgICAgICB0aXRsZT1cIk1vZGVcIlxuICAgICAgICAgICAgICAgICAgICAgIHRleHQ9e3RoZW1lLmlzRGFyayA/IFwiRGFya1wiIDogXCJMaWdodFwifVxuICAgICAgICAgICAgICAgICAgICAvPlxuICAgICAgICAgICAgICAgICAgICA8TGlzdC5JdGVtLkRldGFpbC5NZXRhZGF0YS5TZXBhcmF0b3IgLz5cbiAgICAgICAgICAgICAgICAgICAgPExpc3QuSXRlbS5EZXRhaWwuTWV0YWRhdGEuTGFiZWxcbiAgICAgICAgICAgICAgICAgICAgICB0aXRsZT1cIldhbGxwYXBlcnNcIlxuICAgICAgICAgICAgICAgICAgICAgIHRleHQ9e1N0cmluZyhcbiAgICAgICAgICAgICAgICAgICAgICAgIHRoZW1lLmJnQ291bnQgfHwgKHRoZW1lLmhhc1dhbGxwYXBlciA/IDEgOiAwKSxcbiAgICAgICAgICAgICAgICAgICAgICApfVxuICAgICAgICAgICAgICAgICAgICAvPlxuICAgICAgICAgICAgICAgICAgICA8TGlzdC5JdGVtLkRldGFpbC5NZXRhZGF0YS5TZXBhcmF0b3IgLz5cbiAgICAgICAgICAgICAgICAgICAgPExpc3QuSXRlbS5EZXRhaWwuTWV0YWRhdGEuTGFiZWxcbiAgICAgICAgICAgICAgICAgICAgICB0aXRsZT1cIm1hY09TIEFjY2VudFwiXG4gICAgICAgICAgICAgICAgICAgICAgdGV4dD17dGhlbWUuYXBwbGVBY2NlbnROYW1lfVxuICAgICAgICAgICAgICAgICAgICAvPlxuICAgICAgICAgICAgICAgICAgICA8TGlzdC5JdGVtLkRldGFpbC5NZXRhZGF0YS5MYWJlbFxuICAgICAgICAgICAgICAgICAgICAgIHRpdGxlPVwiSGlnaGxpZ2h0XCJcbiAgICAgICAgICAgICAgICAgICAgICB0ZXh0PXt0aGVtZS5oaWdobGlnaHRDb2xvcn1cbiAgICAgICAgICAgICAgICAgICAgLz5cbiAgICAgICAgICAgICAgICAgICAgPExpc3QuSXRlbS5EZXRhaWwuTWV0YWRhdGEuU2VwYXJhdG9yIC8+XG4gICAgICAgICAgICAgICAgICAgIDxMaXN0Lkl0ZW0uRGV0YWlsLk1ldGFkYXRhLlRhZ0xpc3QgdGl0bGU9XCJscyAtbGFcIj5cbiAgICAgICAgICAgICAgICAgICAgICA8TGlzdC5JdGVtLkRldGFpbC5NZXRhZGF0YS5UYWdMaXN0Lkl0ZW1cbiAgICAgICAgICAgICAgICAgICAgICAgIHRleHQ9XCJkaXIvXCJcbiAgICAgICAgICAgICAgICAgICAgICAgIGNvbG9yPXtnZXRMc1ByZXZpZXdDb2xvcnModGhlbWUpLmRpcmVjdG9yeX1cbiAgICAgICAgICAgICAgICAgICAgICAvPlxuICAgICAgICAgICAgICAgICAgICAgIDxMaXN0Lkl0ZW0uRGV0YWlsLk1ldGFkYXRhLlRhZ0xpc3QuSXRlbVxuICAgICAgICAgICAgICAgICAgICAgICAgdGV4dD1cImxpbmtAXCJcbiAgICAgICAgICAgICAgICAgICAgICAgIGNvbG9yPXtnZXRMc1ByZXZpZXdDb2xvcnModGhlbWUpLnN5bWxpbmt9XG4gICAgICAgICAgICAgICAgICAgICAgLz5cbiAgICAgICAgICAgICAgICAgICAgICA8TGlzdC5JdGVtLkRldGFpbC5NZXRhZGF0YS5UYWdMaXN0Lkl0ZW1cbiAgICAgICAgICAgICAgICAgICAgICAgIHRleHQ9XCJleGVjKlwiXG4gICAgICAgICAgICAgICAgICAgICAgICBjb2xvcj17Z2V0THNQcmV2aWV3Q29sb3JzKHRoZW1lKS5leGVjdXRhYmxlfVxuICAgICAgICAgICAgICAgICAgICAgIC8+XG4gICAgICAgICAgICAgICAgICAgICAgPExpc3QuSXRlbS5EZXRhaWwuTWV0YWRhdGEuVGFnTGlzdC5JdGVtXG4gICAgICAgICAgICAgICAgICAgICAgICB0ZXh0PVwiYXJjaGl2ZVwiXG4gICAgICAgICAgICAgICAgICAgICAgICBjb2xvcj17Z2V0THNQcmV2aWV3Q29sb3JzKHRoZW1lKS5hcmNoaXZlfVxuICAgICAgICAgICAgICAgICAgICAgIC8+XG4gICAgICAgICAgICAgICAgICAgICAgPExpc3QuSXRlbS5EZXRhaWwuTWV0YWRhdGEuVGFnTGlzdC5JdGVtXG4gICAgICAgICAgICAgICAgICAgICAgICB0ZXh0PVwiZGV2aWNlXCJcbiAgICAgICAgICAgICAgICAgICAgICAgIGNvbG9yPXtnZXRMc1ByZXZpZXdDb2xvcnModGhlbWUpLmRldmljZX1cbiAgICAgICAgICAgICAgICAgICAgICAvPlxuICAgICAgICAgICAgICAgICAgICAgIDxMaXN0Lkl0ZW0uRGV0YWlsLk1ldGFkYXRhLlRhZ0xpc3QuSXRlbVxuICAgICAgICAgICAgICAgICAgICAgICAgdGV4dD1cImZpbGVcIlxuICAgICAgICAgICAgICAgICAgICAgICAgY29sb3I9e2dldExzUHJldmlld0NvbG9ycyh0aGVtZSkubm9ybWFsfVxuICAgICAgICAgICAgICAgICAgICAgIC8+XG4gICAgICAgICAgICAgICAgICAgIDwvTGlzdC5JdGVtLkRldGFpbC5NZXRhZGF0YS5UYWdMaXN0PlxuICAgICAgICAgICAgICAgICAgPC9MaXN0Lkl0ZW0uRGV0YWlsLk1ldGFkYXRhPlxuICAgICAgICAgICAgICAgIH1cbiAgICAgICAgICAgICAgLz5cbiAgICAgICAgICAgIH1cbiAgICAgICAgICAgIGFjdGlvbnM9e1xuICAgICAgICAgICAgICA8QWN0aW9uUGFuZWw+XG4gICAgICAgICAgICAgICAgPEFjdGlvblxuICAgICAgICAgICAgICAgICAgdGl0bGU9XCJBcHBseSBUaGVtZVwiXG4gICAgICAgICAgICAgICAgICBpY29uPXtJY29uLkJydXNofVxuICAgICAgICAgICAgICAgICAgc2hvcnRjdXQ9e3sgbW9kaWZpZXJzOiBbXSwga2V5OiBcInJldHVyblwiIH19XG4gICAgICAgICAgICAgICAgICBvbkFjdGlvbj17YXN5bmMgKCkgPT4ge1xuICAgICAgICAgICAgICAgICAgICBzcGF3blRoZW1lQXBwbHlXb3JrZXIodGhlbWUpO1xuICAgICAgICAgICAgICAgICAgICBhd2FpdCBjbG9zZU1haW5XaW5kb3coKTtcbiAgICAgICAgICAgICAgICAgIH19XG4gICAgICAgICAgICAgICAgLz5cbiAgICAgICAgICAgICAgICB7dGhlbWUuYmdDb3VudCA+IDAgPyAoXG4gICAgICAgICAgICAgICAgICA8QWN0aW9uLlB1c2hcbiAgICAgICAgICAgICAgICAgICAgdGl0bGU9XCJTd2l0Y2ggQmFja2dyb3VuZFwiXG4gICAgICAgICAgICAgICAgICAgIGljb249e0ljb24uRm9sZGVyfVxuICAgICAgICAgICAgICAgICAgICBzaG9ydGN1dD17eyBtb2RpZmllcnM6IFtcImNtZFwiXSwga2V5OiBcImJcIiB9fVxuICAgICAgICAgICAgICAgICAgICB0YXJnZXQ9e1xuICAgICAgICAgICAgICAgICAgICAgIDxCYWNrZ3JvdW5kUGlja2VyXG4gICAgICAgICAgICAgICAgICAgICAgICB0aGVtZT17dGhlbWV9XG4gICAgICAgICAgICAgICAgICAgICAgICBvblNlbGVjdD17KCkgPT5cbiAgICAgICAgICAgICAgICAgICAgICAgICAgc2V0QmFja2dyb3VuZFZlcnNpb24oKHZlcnNpb24pID0+IHZlcnNpb24gKyAxKVxuICAgICAgICAgICAgICAgICAgICAgICAgfVxuICAgICAgICAgICAgICAgICAgICAgIC8+XG4gICAgICAgICAgICAgICAgICAgIH1cbiAgICAgICAgICAgICAgICAgIC8+XG4gICAgICAgICAgICAgICAgKSA6IG51bGx9XG4gICAgICAgICAgICAgIDwvQWN0aW9uUGFuZWw+XG4gICAgICAgICAgICB9XG4gICAgICAgICAgLz5cbiAgICAgICAgKTtcbiAgICAgIH0pfVxuICAgIDwvTGlzdD5cbiAgKTtcbn1cbiJdLAogICJtYXBwaW5ncyI6ICI7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7O0FBQUE7QUFBQTtBQUFBO0FBQUE7QUFBQTtBQUFBLGlCQVFPO0FBQ1AsZ0JBQXFFO0FBQ3JFLGdCQUF3QjtBQUN4QixrQkFBd0M7QUFDeEMsMkJBQStDO0FBQy9DLG1CQUFvQztBQTJoQnBCO0FBemhCaEIsSUFBTSxpQkFBYSxzQkFBSyxtQkFBUSxHQUFHLFNBQVM7QUFDNUMsSUFBTSw2QkFBeUIsa0JBQUssWUFBWSxtQkFBbUI7QUFDbkUsSUFBTSxxQkFBaUIsc0JBQUssbUJBQVEsR0FBRyxXQUFXLFdBQVcsUUFBUTtBQUNyRSxJQUFNLDRCQUF3QjtBQUFBLE1BQzVCLG1CQUFRO0FBQUEsRUFDUjtBQUFBLEVBQ0E7QUFBQSxFQUNBO0FBQUEsRUFDQTtBQUFBLEVBQ0E7QUFDRjtBQUNBLElBQU0sbUJBQWUsc0JBQUssbUJBQVEsR0FBRyxVQUFVLGFBQWE7QUFDNUQsSUFBTSw2QkFBeUI7QUFBQSxNQUM3QixtQkFBUTtBQUFBLEVBQ1I7QUFBQSxFQUNBO0FBQUEsRUFDQTtBQUNGO0FBQ0EsSUFBTSx1QkFBbUIsc0JBQUssbUJBQVEsR0FBRyxVQUFVLE9BQU8sY0FBYztBQUV4RSxJQUFNLE9BQU87QUEwQ2IsU0FBUyxjQUFjLEtBQXVCO0FBQzVDLFFBQU0sY0FBVSxr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QVE7QUFBQSxvQkFBbEM7QUFBQSxzQkFDQyxNQUFLO0FBQUEsc0JBQ0wsT0FBTyxtQkFBbUIsS0FBSyxFQUFFO0FBQUE7QUFBQSxrQkFDbkM7QUFBQSxrQkFDQTtBQUFBLG9CQUFDLGdCQUFLLEtBQUssT0FBTyxTQUFTLFFBQVE7QUFBQSxvQkFBbEM7QUFBQSxzQkFDQyxNQUFLO0FBQUEsc0JBQ0wsT0FBTyxtQkFBbUIsS0FBSyxFQUFFO0FBQUE7QUFBQSxrQkFDbkM7QUFBQSxrQkFDQTtBQUFBLG9CQUFDLGdCQUFLLEtBQUssT0FBTyxTQUFTLFFBQVE7QUFBQSxvQkFBbEM7QUFBQSxzQkFDQyxNQUFLO0FBQUEsc0JBQ0wsT0FBTyxtQkFBbUIsS0FBSyxFQUFFO0FBQUE7QUFBQSxrQkFDbkM7QUFBQSxrQkFDQTtBQUFBLG9CQUFDLGdCQUFLLEtBQUssT0FBTyxTQUFTLFFBQVE7QUFBQSxvQkFBbEM7QUFBQSxzQkFDQyxNQUFLO0FBQUEsc0JBQ0wsT0FBTyxtQkFBbUIsS0FBSyxFQUFFO0FBQUE7QUFBQSxrQkFDbkM7QUFBQSxtQkFDRjtBQUFBLGlCQUNGO0FBQUE7QUFBQSxVQUVKO0FBQUEsVUFFRixTQUNFLDZDQUFDLDBCQUNDO0FBQUE7QUFBQSxjQUFDO0FBQUE7QUFBQSxnQkFDQyxPQUFNO0FBQUEsZ0JBQ04sTUFBTSxnQkFBSztBQUFBLGdCQUNYLFVBQVUsRUFBRSxXQUFXLENBQUMsR0FBRyxLQUFLLFNBQVM7QUFBQSxnQkFDekMsVUFBVSxZQUFZO0FBQ3BCLHdDQUFzQixLQUFLO0FBQzNCLDRCQUFNLDRCQUFnQjtBQUFBLGdCQUN4QjtBQUFBO0FBQUEsWUFDRjtBQUFBLFlBQ0MsTUFBTSxVQUFVLElBQ2Y7QUFBQSxjQUFDLGtCQUFPO0FBQUEsY0FBUDtBQUFBLGdCQUNDLE9BQU07QUFBQSxnQkFDTixNQUFNLGdCQUFLO0FBQUEsZ0JBQ1gsVUFBVSxFQUFFLFdBQVcsQ0FBQyxLQUFLLEdBQUcsS0FBSyxJQUFJO0FBQUEsZ0JBQ3pDLFFBQ0U7QUFBQSxrQkFBQztBQUFBO0FBQUEsb0JBQ0M7QUFBQSxvQkFDQSxVQUFVLE1BQ1IscUJBQXFCLENBQUMsWUFBWSxVQUFVLENBQUM7QUFBQTtBQUFBLGdCQUVqRDtBQUFBO0FBQUEsWUFFSixJQUNFO0FBQUEsYUFDTjtBQUFBO0FBQUEsUUF6RkcsTUFBTTtBQUFBLE1BMkZiO0FBQUEsSUFFSixDQUFDO0FBQUEsS0FDSDtBQUVKOyIsCiAgIm5hbWVzIjogW10KfQo=
