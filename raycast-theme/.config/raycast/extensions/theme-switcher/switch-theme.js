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
var GHOSTTY_CONFIG = (0, import_path.join)((0, import_os.homedir)(), ".config", "ghostty", "config");
var NVIM_COLORSCHEME_FILE = (0, import_path.join)((0, import_os.homedir)(), ".config", "nvim", "lua", "plugins", "colorscheme.lua");
var CODEX_CONFIG = (0, import_path.join)((0, import_os.homedir)(), ".codex", "config.toml");
var SKETCHYBAR_THEME_FILE = (0, import_path.join)((0, import_os.homedir)(), ".config", "sketchybar", "theme.sh");
var PATH = `/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin:/usr/local/bin`;
var CancelledThemeApplyError = class extends Error {
  constructor() {
    super("Theme switch cancelled");
    this.name = "CancelledThemeApplyError";
  }
};
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
function toMacosColor(hex) {
  return /^#[0-9a-fA-F]{6}$/.test(hex) ? `0xff${hex.slice(1)}` : "0xffffffff";
}
function getThemes() {
  if (!(0, import_fs.existsSync)(THEMES_DIR)) return [];
  return (0, import_fs.readdirSync)(THEMES_DIR, { withFileTypes: true }).filter((d) => d.isDirectory()).map((d) => {
    const dir = (0, import_path.join)(THEMES_DIR, d.name);
    const env = parseThemeEnv(dir);
    const bgDir = (0, import_path.join)(dir, "backgrounds");
    const bgCount = (0, import_fs.existsSync)(bgDir) ? (0, import_fs.readdirSync)(bgDir).length : 0;
    return {
      name: d.name,
      displayName: d.name.split("-").map((w) => w.charAt(0).toUpperCase() + w.slice(1)).join(" "),
      env,
      hasWallpaper: (0, import_fs.existsSync)((0, import_path.join)(dir, env.WALLPAPER || "")),
      wallpaperPath: (0, import_fs.existsSync)((0, import_path.join)(dir, env.WALLPAPER || "")) ? (0, import_path.join)(dir, env.WALLPAPER || "") : void 0,
      accentColor: getThemeAccent(dir, env),
      textColor: getGhosttyColor(dir, "foreground", env.DARK_MODE === "true" ? "#ffffff" : "#000000"),
      palette: getGhosttyPalette(dir),
      isDark: env.DARK_MODE === "true",
      bgCount
    };
  }).sort((a, b) => a.name.localeCompare(b.name));
}
function getCurrentTheme() {
  const path = (0, import_path.join)(THEMES_DIR, ".current");
  if (!(0, import_fs.existsSync)(path)) return "";
  return (0, import_fs.readFileSync)(path, "utf-8").trim();
}
function mapCodexTheme(theme) {
  const name = theme.name.toLowerCase();
  const directMap = {
    catppuccin: "catppuccin-mocha",
    "catppuccin-latte": "catppuccin-latte",
    gruvbox: "gruvbox-dark",
    nord: "nord",
    everforest: "zenburn"
  };
  if (directMap[name]) return directMap[name];
  return theme.isDark ? "one-half-dark" : "one-half-light";
}
function setCodexTheme(theme) {
  if (!(0, import_fs.existsSync)(CODEX_CONFIG)) return;
  const codexTheme = mapCodexTheme(theme);
  const original = (0, import_fs.readFileSync)(CODEX_CONFIG, "utf-8");
  const lines = original.split("\n");
  let inTui = false;
  let tuiHeaderIndex = -1;
  let themeSet = false;
  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    if (/^\[.*\]$/.test(line.trim())) {
      inTui = line.trim() === "[tui]";
      if (inTui) tuiHeaderIndex = i;
      continue;
    }
    if (inTui && /^\s*theme\s*=/.test(line)) {
      lines[i] = `theme = "${codexTheme}"`;
      themeSet = true;
      break;
    }
  }
  if (!themeSet && tuiHeaderIndex !== -1) {
    lines.splice(tuiHeaderIndex + 1, 0, `theme = "${codexTheme}"`);
  } else if (!themeSet && tuiHeaderIndex === -1) {
    if (lines.length > 0 && lines[lines.length - 1].trim() !== "") lines.push("");
    lines.push("[tui]");
    lines.push(`theme = "${codexTheme}"`);
  }
  (0, import_fs.writeFileSync)(CODEX_CONFIG, lines.join("\n").replace(/\n*$/, "\n"));
}
function createThemeCommandRunner() {
  const children = /* @__PURE__ */ new Set();
  let cancelled = false;
  const checkCancelled = () => {
    if (cancelled) throw new CancelledThemeApplyError();
  };
  return {
    cancel: () => {
      cancelled = true;
      for (const child of children) {
        child.kill("SIGTERM");
        setTimeout(() => child.kill("SIGKILL"), 250);
      }
      children.clear();
    },
    checkCancelled,
    run: (cmd, options) => new Promise((resolve, reject) => {
      checkCancelled();
      const child = (0, import_child_process.exec)(cmd, { env: { ...process.env, HOME: (0, import_os.homedir)(), PATH } }, (err, stdout) => {
        children.delete(child);
        if (cancelled) {
          reject(new CancelledThemeApplyError());
          return;
        }
        if (err) {
          if (options?.allowFailure) {
            resolve(stdout || "");
            return;
          }
          reject(err);
          return;
        }
        resolve(stdout || "");
      });
      children.add(child);
    })
  };
}
async function applyTheme(theme, runner) {
  const { env, name } = theme;
  const themeDir = (0, import_path.join)(THEMES_DIR, name);
  runner.checkCancelled();
  if (env.DARK_MODE) {
    await runner.run(`/usr/bin/osascript -e 'tell application "System Events" to tell appearance preferences to set dark mode to ${env.DARK_MODE}'`, { allowFailure: true });
  }
  const wallPath = (0, import_path.join)(themeDir, env.WALLPAPER || "");
  if (env.WALLPAPER && (0, import_fs.existsSync)(wallPath)) {
    const setWallpaper = (0, import_path.join)((0, import_os.homedir)(), ".local", "bin", "set-wallpaper");
    await runner.run(`"${setWallpaper}" "${wallPath}"`);
  }
  const ghosttyConf = (0, import_path.join)(themeDir, "ghostty.conf");
  if ((0, import_fs.existsSync)(ghosttyConf) && (0, import_fs.existsSync)(GHOSTTY_CONFIG)) {
    const palette = (0, import_fs.readFileSync)(ghosttyConf, "utf-8");
    const config = (0, import_fs.readFileSync)(GHOSTTY_CONFIG, "utf-8");
    const lines = config.split("\n").filter(
      (l) => !l.startsWith("background ") && !l.startsWith("foreground ") && !l.startsWith("cursor-color ") && !l.startsWith("selection-background ") && !l.startsWith("selection-foreground ") && !l.startsWith("palette ") && !l.startsWith("theme ") && !l.match(/^config-file.*\.themes\//) && !l.startsWith("# --- THEME COLORS")
    );
    lines.push("");
    lines.push(`# --- THEME COLORS (${name}) ---`);
    lines.push(palette.trim());
    (0, import_fs.writeFileSync)(GHOSTTY_CONFIG, lines.join("\n") + "\n");
    runner.checkCancelled();
    await runner.run(`/bin/bash -c '
      /usr/bin/pkill -USR2 -x ghostty 2>/dev/null || /usr/bin/pkill -USR2 -x Ghostty 2>/dev/null || true
      sleep 0.2
      /usr/bin/osascript -e '"'"'
      tell application "System Events"
        if exists process "ghostty" then
          tell process "ghostty"
            click menu item "Reload Configuration" of menu "Ghostty" of menu bar 1
          end tell
        end if
      end tell'"'"' 2>/dev/null || true
      '`, { allowFailure: true });
  }
  if (env.NVIM_COLORSCHEME) {
    (0, import_fs.writeFileSync)(NVIM_COLORSCHEME_FILE, `return {
  { "LazyVim/LazyVim", opts = { colorscheme = "${env.NVIM_COLORSCHEME}" } },
}
`);
    runner.checkCancelled();
    await runner.run(`/bin/bash -c 'for sock in /tmp/nvim.*/0; do [ -S "$sock" ] && /opt/homebrew/bin/nvim --server "$sock" --remote-send "<Cmd>colorscheme ${env.NVIM_COLORSCHEME}<CR>" 2>/dev/null || true; done'`, { allowFailure: true });
  }
  if (env.BORDER_ACTIVE) {
    await runner.run(`/usr/bin/pkill -x borders 2>/dev/null; sleep 0.1; /opt/homebrew/bin/borders active_color=${env.BORDER_ACTIVE} inactive_color=${env.BORDER_INACTIVE || "0x00000000"} width=${env.BORDER_WIDTH || "6.0"} &`, { allowFailure: true });
  }
  (0, import_fs.writeFileSync)(
    SKETCHYBAR_THEME_FILE,
    `#!/usr/bin/env bash

ACCENT_COLOR="${toMacosColor(theme.accentColor)}"
TEXT_COLOR="${toMacosColor(theme.textColor)}"
`
  );
  runner.checkCancelled();
  await runner.run(
    `/bin/bash -c '
      /usr/bin/pkill -x sketchybar 2>/dev/null || true
      sleep 0.35
      /bin/launchctl kickstart -k "gui/$(id -u)/homebrew.mxcl.sketchybar" 2>/dev/null || true
      sleep 0.35
      /opt/homebrew/bin/sketchybar --reload 2>/dev/null || true
      /opt/homebrew/bin/sketchybar --update 2>/dev/null || true
    '`,
    { allowFailure: true }
  );
  runner.checkCancelled();
  setCodexTheme(theme);
  (0, import_fs.writeFileSync)((0, import_path.join)(THEMES_DIR, ".current"), name);
}
function Command() {
  const themes = getThemes();
  const [current, setCurrent] = (0, import_react.useState)(() => getCurrentTheme());
  const [selectedTheme, setSelectedTheme] = (0, import_react.useState)(() => getCurrentTheme());
  const [pendingTheme, setPendingTheme] = (0, import_react.useState)(null);
  const applyIdRef = (0, import_react.useRef)(0);
  const activeToastRef = (0, import_react.useRef)(null);
  const activeRunnerRef = (0, import_react.useRef)(null);
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
    const wallpaperPreview = theme.wallpaperPath ? `![${theme.displayName}](${encodeURI(`file://${theme.wallpaperPath}`)})` : "_No wallpaper preview available_";
    const lines = [
      `# ${theme.displayName}`,
      "",
      wallpaperPreview,
      "",
      `Accent \`${theme.accentColor}\``,
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
  return /* @__PURE__ */ (0, import_jsx_runtime.jsx)(
    import_api.List,
    {
      isShowingDetail: true,
      searchBarPlaceholder: "Search themes...",
      selectedItemId: selectedTheme,
      onSelectionChange: (id) => {
        if (id) setSelectedTheme(id);
      },
      children: themes.map((theme) => {
        const isCurrent = theme.name === (pendingTheme || current);
        const accessories = [];
        if (isCurrent) accessories.push({ tag: { value: "active", color: import_api.Color.Green } });
        accessories.push({ icon: theme.isDark ? import_api.Icon.Moon : import_api.Icon.Sun });
        if (theme.bgCount > 0) accessories.push({ text: `${theme.bgCount} bg` });
        return /* @__PURE__ */ (0, import_jsx_runtime.jsx)(
          import_api.List.Item,
          {
            title: theme.displayName,
            icon: { source: import_api.Icon.Circle, tintColor: theme.accentColor },
            accessories,
            detail: /* @__PURE__ */ (0, import_jsx_runtime.jsx)(
              import_api.List.Item.Detail,
              {
                markdown: getThemePreview(theme),
                metadata: /* @__PURE__ */ (0, import_jsx_runtime.jsxs)(import_api.List.Item.Detail.Metadata, { children: [
                  /* @__PURE__ */ (0, import_jsx_runtime.jsx)(import_api.List.Item.Detail.Metadata.Label, { title: "Mode", text: theme.isDark ? "Dark" : "Light" }),
                  /* @__PURE__ */ (0, import_jsx_runtime.jsx)(import_api.List.Item.Detail.Metadata.Separator, {}),
                  /* @__PURE__ */ (0, import_jsx_runtime.jsx)(import_api.List.Item.Detail.Metadata.Label, { title: "Wallpapers", text: String(theme.bgCount || (theme.hasWallpaper ? 1 : 0)) }),
                  /* @__PURE__ */ (0, import_jsx_runtime.jsx)(import_api.List.Item.Detail.Metadata.Separator, {}),
                  /* @__PURE__ */ (0, import_jsx_runtime.jsxs)(import_api.List.Item.Detail.Metadata.TagList, { title: "ls -la", children: [
                    /* @__PURE__ */ (0, import_jsx_runtime.jsx)(import_api.List.Item.Detail.Metadata.TagList.Item, { text: "dir/", color: getLsPreviewColors(theme).directory }),
                    /* @__PURE__ */ (0, import_jsx_runtime.jsx)(import_api.List.Item.Detail.Metadata.TagList.Item, { text: "link@", color: getLsPreviewColors(theme).symlink }),
                    /* @__PURE__ */ (0, import_jsx_runtime.jsx)(import_api.List.Item.Detail.Metadata.TagList.Item, { text: "exec*", color: getLsPreviewColors(theme).executable }),
                    /* @__PURE__ */ (0, import_jsx_runtime.jsx)(import_api.List.Item.Detail.Metadata.TagList.Item, { text: "archive", color: getLsPreviewColors(theme).archive }),
                    /* @__PURE__ */ (0, import_jsx_runtime.jsx)(import_api.List.Item.Detail.Metadata.TagList.Item, { text: "device", color: getLsPreviewColors(theme).device }),
                    /* @__PURE__ */ (0, import_jsx_runtime.jsx)(import_api.List.Item.Detail.Metadata.TagList.Item, { text: "file", color: getLsPreviewColors(theme).normal })
                  ] })
                ] })
              }
            ),
            actions: /* @__PURE__ */ (0, import_jsx_runtime.jsx)(import_api.ActionPanel, { children: /* @__PURE__ */ (0, import_jsx_runtime.jsx)(
              import_api.Action,
              {
                title: "Apply Theme",
                icon: import_api.Icon.Brush,
                shortcut: { modifiers: [], key: "return" },
                onAction: async () => {
                  const applyId = ++applyIdRef.current;
                  activeRunnerRef.current?.cancel();
                  if (activeToastRef.current) {
                    await activeToastRef.current.hide().catch(() => {
                    });
                  }
                  const runner = createThemeCommandRunner();
                  activeRunnerRef.current = runner;
                  setPendingTheme(theme.name);
                  setCurrent(theme.name);
                  setSelectedTheme(theme.name);
                  const toast = await (0, import_api.showToast)({ style: import_api.Toast.Style.Animated, title: `Switching to ${theme.displayName}...` });
                  activeToastRef.current = toast;
                  try {
                    await applyTheme(theme, runner);
                    if (applyId !== applyIdRef.current) return;
                    setCurrent(theme.name);
                    setSelectedTheme(theme.name);
                    setPendingTheme(null);
                    await toast.hide();
                    if (activeToastRef.current === toast) activeToastRef.current = null;
                    if (activeRunnerRef.current === runner) activeRunnerRef.current = null;
                    await (0, import_api.showHUD)(`Switched to ${theme.displayName}`);
                  } catch (e) {
                    if (applyId !== applyIdRef.current) return;
                    if (e instanceof CancelledThemeApplyError) return;
                    setPendingTheme(null);
                    setCurrent(getCurrentTheme());
                    toast.style = import_api.Toast.Style.Failure;
                    toast.title = "Failed";
                    toast.message = String(e);
                    if (activeToastRef.current === toast) activeToastRef.current = null;
                    if (activeRunnerRef.current === runner) activeRunnerRef.current = null;
                  }
                }
              }
            ) })
          },
          theme.name
        );
      })
    }
  );
}
//# sourceMappingURL=data:application/json;base64,ewogICJ2ZXJzaW9uIjogMywKICAic291cmNlcyI6IFsiLi4vLi4vLi4vLi4vRGV2ZWxvcGVyL3RoZW1lLXN3aXRjaGVyL3NyYy9zd2l0Y2gtdGhlbWUudHN4Il0sCiAgInNvdXJjZXNDb250ZW50IjogWyJpbXBvcnQgeyBBY3Rpb25QYW5lbCwgQWN0aW9uLCBMaXN0LCBzaG93VG9hc3QsIFRvYXN0LCBJY29uLCBDb2xvciwgc2hvd0hVRCB9IGZyb20gXCJAcmF5Y2FzdC9hcGlcIjtcbmltcG9ydCB7IHJlYWRkaXJTeW5jLCByZWFkRmlsZVN5bmMsIGV4aXN0c1N5bmMsIHdyaXRlRmlsZVN5bmMgfSBmcm9tIFwiZnNcIjtcbmltcG9ydCB7IGhvbWVkaXIgfSBmcm9tIFwib3NcIjtcbmltcG9ydCB7IGpvaW4gfSBmcm9tIFwicGF0aFwiO1xuaW1wb3J0IHsgZXhlYywgdHlwZSBDaGlsZFByb2Nlc3MgfSBmcm9tIFwiY2hpbGRfcHJvY2Vzc1wiO1xuaW1wb3J0IHsgdXNlRWZmZWN0LCB1c2VSZWYsIHVzZVN0YXRlIH0gZnJvbSBcInJlYWN0XCI7XG5cbmNvbnN0IFRIRU1FU19ESVIgPSBqb2luKGhvbWVkaXIoKSwgXCIudGhlbWVzXCIpO1xuY29uc3QgR0hPU1RUWV9DT05GSUcgPSBqb2luKGhvbWVkaXIoKSwgXCIuY29uZmlnXCIsIFwiZ2hvc3R0eVwiLCBcImNvbmZpZ1wiKTtcbmNvbnN0IE5WSU1fQ09MT1JTQ0hFTUVfRklMRSA9IGpvaW4oaG9tZWRpcigpLCBcIi5jb25maWdcIiwgXCJudmltXCIsIFwibHVhXCIsIFwicGx1Z2luc1wiLCBcImNvbG9yc2NoZW1lLmx1YVwiKTtcbmNvbnN0IENPREVYX0NPTkZJRyA9IGpvaW4oaG9tZWRpcigpLCBcIi5jb2RleFwiLCBcImNvbmZpZy50b21sXCIpO1xuY29uc3QgU0tFVENIWUJBUl9USEVNRV9GSUxFID0gam9pbihob21lZGlyKCksIFwiLmNvbmZpZ1wiLCBcInNrZXRjaHliYXJcIiwgXCJ0aGVtZS5zaFwiKTtcbmNvbnN0IFBBVEggPSBgL3Vzci9iaW46L2JpbjovdXNyL3NiaW46L3NiaW46L29wdC9ob21lYnJldy9iaW46L3Vzci9sb2NhbC9iaW5gO1xuXG5jbGFzcyBDYW5jZWxsZWRUaGVtZUFwcGx5RXJyb3IgZXh0ZW5kcyBFcnJvciB7XG4gIGNvbnN0cnVjdG9yKCkge1xuICAgIHN1cGVyKFwiVGhlbWUgc3dpdGNoIGNhbmNlbGxlZFwiKTtcbiAgICB0aGlzLm5hbWUgPSBcIkNhbmNlbGxlZFRoZW1lQXBwbHlFcnJvclwiO1xuICB9XG59XG5cbmludGVyZmFjZSBUaGVtZUVudiB7XG4gIERBUktfTU9ERT86IHN0cmluZztcbiAgV0FMTFBBUEVSPzogc3RyaW5nO1xuICBHSE9TVFRZX0NPTkY/OiBzdHJpbmc7XG4gIE5WSU1fQ09MT1JTQ0hFTUU/OiBzdHJpbmc7XG4gIEJPUkRFUl9BQ1RJVkU/OiBzdHJpbmc7XG4gIEJPUkRFUl9JTkFDVElWRT86IHN0cmluZztcbiAgQk9SREVSX1dJRFRIPzogc3RyaW5nO1xufVxuXG5pbnRlcmZhY2UgVGhlbWVFbnRyeSB7XG4gIG5hbWU6IHN0cmluZztcbiAgZGlzcGxheU5hbWU6IHN0cmluZztcbiAgZW52OiBUaGVtZUVudjtcbiAgaGFzV2FsbHBhcGVyOiBib29sZWFuO1xuICB3YWxscGFwZXJQYXRoPzogc3RyaW5nO1xuICBhY2NlbnRDb2xvcjogc3RyaW5nO1xuICB0ZXh0Q29sb3I6IHN0cmluZztcbiAgcGFsZXR0ZTogc3RyaW5nW107XG4gIGlzRGFyazogYm9vbGVhbjtcbiAgYmdDb3VudDogbnVtYmVyO1xufVxuXG5mdW5jdGlvbiBwYXJzZVRoZW1lRW52KGRpcjogc3RyaW5nKTogVGhlbWVFbnYge1xuICBjb25zdCBlbnZQYXRoID0gam9pbihkaXIsIFwidGhlbWUuZW52XCIpO1xuICBpZiAoIWV4aXN0c1N5bmMoZW52UGF0aCkpIHJldHVybiB7fTtcbiAgY29uc3QgdmFyczogVGhlbWVFbnYgPSB7fTtcbiAgZm9yIChjb25zdCBsaW5lIG9mIHJlYWRGaWxlU3luYyhlbnZQYXRoLCBcInV0Zi04XCIpLnNwbGl0KFwiXFxuXCIpKSB7XG4gICAgY29uc3QgdHJpbW1lZCA9IGxpbmUudHJpbSgpO1xuICAgIGlmICghdHJpbW1lZCB8fCB0cmltbWVkLnN0YXJ0c1dpdGgoXCIjXCIpKSBjb250aW51ZTtcbiAgICBjb25zdCBlcSA9IHRyaW1tZWQuaW5kZXhPZihcIj1cIik7XG4gICAgaWYgKGVxID09PSAtMSkgY29udGludWU7XG4gICAgY29uc3Qga2V5ID0gdHJpbW1lZC5zbGljZSgwLCBlcSkgYXMga2V5b2YgVGhlbWVFbnY7XG4gICAgbGV0IHZhbCA9IHRyaW1tZWQuc2xpY2UoZXEgKyAxKTtcbiAgICBpZiAoKHZhbC5zdGFydHNXaXRoKCdcIicpICYmIHZhbC5lbmRzV2l0aCgnXCInKSkgfHwgKHZhbC5zdGFydHNXaXRoKFwiJ1wiKSAmJiB2YWwuZW5kc1dpdGgoXCInXCIpKSkge1xuICAgICAgdmFsID0gdmFsLnNsaWNlKDEsIC0xKTtcbiAgICB9XG4gICAgdmFyc1trZXldID0gdmFsO1xuICB9XG4gIHJldHVybiB2YXJzO1xufVxuXG5mdW5jdGlvbiBnZXRCb3JkZXJIZXgoZW52OiBUaGVtZUVudik6IHN0cmluZyB7XG4gIGNvbnN0IGJhID0gZW52LkJPUkRFUl9BQ1RJVkUgfHwgXCJcIjtcbiAgLy8gMHhmZlJSR0dCQiAtPiAjUlJHR0JCXG4gIGlmIChiYS5zdGFydHNXaXRoKFwiMHhmZlwiKSkgcmV0dXJuIFwiI1wiICsgYmEuc2xpY2UoNCk7XG4gIHJldHVybiBcIiM4ODg4ODhcIjtcbn1cblxuZnVuY3Rpb24gZ2V0R2hvc3R0eUNvbG9yKGRpcjogc3RyaW5nLCBrZXk6IHN0cmluZywgZmFsbGJhY2s6IHN0cmluZyk6IHN0cmluZyB7XG4gIGNvbnN0IGdob3N0dHlQYXRoID0gam9pbihkaXIsIFwiZ2hvc3R0eS5jb25mXCIpO1xuICBpZiAoIWV4aXN0c1N5bmMoZ2hvc3R0eVBhdGgpKSByZXR1cm4gZmFsbGJhY2s7XG4gIGZvciAoY29uc3QgbGluZSBvZiByZWFkRmlsZVN5bmMoZ2hvc3R0eVBhdGgsIFwidXRmLThcIikuc3BsaXQoXCJcXG5cIikpIHtcbiAgICBjb25zdCB0cmltbWVkID0gbGluZS50cmltKCk7XG4gICAgaWYgKCF0cmltbWVkLnN0YXJ0c1dpdGgoYCR7a2V5fSA9IGApKSBjb250aW51ZTtcbiAgICBjb25zdCB2YWx1ZSA9IHRyaW1tZWQuc2xpY2UoYCR7a2V5fSA9IGAubGVuZ3RoKS50cmltKCk7XG4gICAgaWYgKC9eI1swLTlhLWZBLUZdezZ9JC8udGVzdCh2YWx1ZSkpIHJldHVybiB2YWx1ZTtcbiAgfVxuICByZXR1cm4gZmFsbGJhY2s7XG59XG5cbmZ1bmN0aW9uIGdldEdob3N0dHlQYWxldHRlKGRpcjogc3RyaW5nKTogc3RyaW5nW10ge1xuICBjb25zdCBnaG9zdHR5UGF0aCA9IGpvaW4oZGlyLCBcImdob3N0dHkuY29uZlwiKTtcbiAgaWYgKCFleGlzdHNTeW5jKGdob3N0dHlQYXRoKSkgcmV0dXJuIFtdO1xuICBjb25zdCBwYWxldHRlOiBzdHJpbmdbXSA9IFtdO1xuICBmb3IgKGNvbnN0IGxpbmUgb2YgcmVhZEZpbGVTeW5jKGdob3N0dHlQYXRoLCBcInV0Zi04XCIpLnNwbGl0KFwiXFxuXCIpKSB7XG4gICAgY29uc3QgdHJpbW1lZCA9IGxpbmUudHJpbSgpO1xuICAgIGNvbnN0IG1hdGNoID0gdHJpbW1lZC5tYXRjaCgvXnBhbGV0dGVcXHMqPVxccyooXFxkKyk9XFxzKigjWzAtOWEtZkEtRl17Nn0pJC8pO1xuICAgIGlmICghbWF0Y2gpIGNvbnRpbnVlO1xuICAgIHBhbGV0dGVbTnVtYmVyKG1hdGNoWzFdKV0gPSBtYXRjaFsyXTtcbiAgfVxuICByZXR1cm4gcGFsZXR0ZTtcbn1cblxuZnVuY3Rpb24gZ2V0VGhlbWVBY2NlbnQoZGlyOiBzdHJpbmcsIGVudjogVGhlbWVFbnYpOiBzdHJpbmcge1xuICBjb25zdCBwYWxldHRlID0gZ2V0R2hvc3R0eVBhbGV0dGUoZGlyKTtcbiAgcmV0dXJuIHBhbGV0dGVbNF0gfHwgZ2V0Qm9yZGVySGV4KGVudik7XG59XG5cbmZ1bmN0aW9uIHRvTWFjb3NDb2xvcihoZXg6IHN0cmluZyk6IHN0cmluZyB7XG4gIHJldHVybiAvXiNbMC05YS1mQS1GXXs2fSQvLnRlc3QoaGV4KSA/IGAweGZmJHtoZXguc2xpY2UoMSl9YCA6IFwiMHhmZmZmZmZmZlwiO1xufVxuXG5mdW5jdGlvbiBnZXRUaGVtZXMoKTogVGhlbWVFbnRyeVtdIHtcbiAgaWYgKCFleGlzdHNTeW5jKFRIRU1FU19ESVIpKSByZXR1cm4gW107XG4gIHJldHVybiByZWFkZGlyU3luYyhUSEVNRVNfRElSLCB7IHdpdGhGaWxlVHlwZXM6IHRydWUgfSlcbiAgICAuZmlsdGVyKChkKSA9PiBkLmlzRGlyZWN0b3J5KCkpXG4gICAgLm1hcCgoZCkgPT4ge1xuICAgICAgY29uc3QgZGlyID0gam9pbihUSEVNRVNfRElSLCBkLm5hbWUpO1xuICAgICAgY29uc3QgZW52ID0gcGFyc2VUaGVtZUVudihkaXIpO1xuICAgICAgY29uc3QgYmdEaXIgPSBqb2luKGRpciwgXCJiYWNrZ3JvdW5kc1wiKTtcbiAgICAgIGNvbnN0IGJnQ291bnQgPSBleGlzdHNTeW5jKGJnRGlyKSA/IHJlYWRkaXJTeW5jKGJnRGlyKS5sZW5ndGggOiAwO1xuICAgICAgcmV0dXJuIHtcbiAgICAgICAgbmFtZTogZC5uYW1lLFxuICAgICAgICBkaXNwbGF5TmFtZTogZC5uYW1lLnNwbGl0KFwiLVwiKS5tYXAoKHcpID0+IHcuY2hhckF0KDApLnRvVXBwZXJDYXNlKCkgKyB3LnNsaWNlKDEpKS5qb2luKFwiIFwiKSxcbiAgICAgICAgZW52LFxuICAgICAgICBoYXNXYWxscGFwZXI6IGV4aXN0c1N5bmMoam9pbihkaXIsIGVudi5XQUxMUEFQRVIgfHwgXCJcIikpLFxuICAgICAgICB3YWxscGFwZXJQYXRoOiBleGlzdHNTeW5jKGpvaW4oZGlyLCBlbnYuV0FMTFBBUEVSIHx8IFwiXCIpKSA/IGpvaW4oZGlyLCBlbnYuV0FMTFBBUEVSIHx8IFwiXCIpIDogdW5kZWZpbmVkLFxuICAgICAgICBhY2NlbnRDb2xvcjogZ2V0VGhlbWVBY2NlbnQoZGlyLCBlbnYpLFxuICAgICAgICB0ZXh0Q29sb3I6IGdldEdob3N0dHlDb2xvcihkaXIsIFwiZm9yZWdyb3VuZFwiLCBlbnYuREFSS19NT0RFID09PSBcInRydWVcIiA/IFwiI2ZmZmZmZlwiIDogXCIjMDAwMDAwXCIpLFxuICAgICAgICBwYWxldHRlOiBnZXRHaG9zdHR5UGFsZXR0ZShkaXIpLFxuICAgICAgICBpc0Rhcms6IGVudi5EQVJLX01PREUgPT09IFwidHJ1ZVwiLFxuICAgICAgICBiZ0NvdW50LFxuICAgICAgfTtcbiAgICB9KVxuICAgIC5zb3J0KChhLCBiKSA9PiBhLm5hbWUubG9jYWxlQ29tcGFyZShiLm5hbWUpKTtcbn1cblxuZnVuY3Rpb24gZ2V0Q3VycmVudFRoZW1lKCk6IHN0cmluZyB7XG4gIGNvbnN0IHBhdGggPSBqb2luKFRIRU1FU19ESVIsIFwiLmN1cnJlbnRcIik7XG4gIGlmICghZXhpc3RzU3luYyhwYXRoKSkgcmV0dXJuIFwiXCI7XG4gIHJldHVybiByZWFkRmlsZVN5bmMocGF0aCwgXCJ1dGYtOFwiKS50cmltKCk7XG59XG5cbmZ1bmN0aW9uIG1hcENvZGV4VGhlbWUodGhlbWU6IFRoZW1lRW50cnkpOiBzdHJpbmcge1xuICBjb25zdCBuYW1lID0gdGhlbWUubmFtZS50b0xvd2VyQ2FzZSgpO1xuICBjb25zdCBkaXJlY3RNYXA6IFJlY29yZDxzdHJpbmcsIHN0cmluZz4gPSB7XG4gICAgY2F0cHB1Y2NpbjogXCJjYXRwcHVjY2luLW1vY2hhXCIsXG4gICAgXCJjYXRwcHVjY2luLWxhdHRlXCI6IFwiY2F0cHB1Y2Npbi1sYXR0ZVwiLFxuICAgIGdydXZib3g6IFwiZ3J1dmJveC1kYXJrXCIsXG4gICAgbm9yZDogXCJub3JkXCIsXG4gICAgZXZlcmZvcmVzdDogXCJ6ZW5idXJuXCIsXG4gIH07XG4gIGlmIChkaXJlY3RNYXBbbmFtZV0pIHJldHVybiBkaXJlY3RNYXBbbmFtZV07XG4gIHJldHVybiB0aGVtZS5pc0RhcmsgPyBcIm9uZS1oYWxmLWRhcmtcIiA6IFwib25lLWhhbGYtbGlnaHRcIjtcbn1cblxuZnVuY3Rpb24gc2V0Q29kZXhUaGVtZSh0aGVtZTogVGhlbWVFbnRyeSkge1xuICBpZiAoIWV4aXN0c1N5bmMoQ09ERVhfQ09ORklHKSkgcmV0dXJuO1xuICBjb25zdCBjb2RleFRoZW1lID0gbWFwQ29kZXhUaGVtZSh0aGVtZSk7XG4gIGNvbnN0IG9yaWdpbmFsID0gcmVhZEZpbGVTeW5jKENPREVYX0NPTkZJRywgXCJ1dGYtOFwiKTtcbiAgY29uc3QgbGluZXMgPSBvcmlnaW5hbC5zcGxpdChcIlxcblwiKTtcblxuICBsZXQgaW5UdWkgPSBmYWxzZTtcbiAgbGV0IHR1aUhlYWRlckluZGV4ID0gLTE7XG4gIGxldCB0aGVtZVNldCA9IGZhbHNlO1xuXG4gIGZvciAobGV0IGkgPSAwOyBpIDwgbGluZXMubGVuZ3RoOyBpKyspIHtcbiAgICBjb25zdCBsaW5lID0gbGluZXNbaV07XG4gICAgaWYgKC9eXFxbLipcXF0kLy50ZXN0KGxpbmUudHJpbSgpKSkge1xuICAgICAgaW5UdWkgPSBsaW5lLnRyaW0oKSA9PT0gXCJbdHVpXVwiO1xuICAgICAgaWYgKGluVHVpKSB0dWlIZWFkZXJJbmRleCA9IGk7XG4gICAgICBjb250aW51ZTtcbiAgICB9XG4gICAgaWYgKGluVHVpICYmIC9eXFxzKnRoZW1lXFxzKj0vLnRlc3QobGluZSkpIHtcbiAgICAgIGxpbmVzW2ldID0gYHRoZW1lID0gXCIke2NvZGV4VGhlbWV9XCJgO1xuICAgICAgdGhlbWVTZXQgPSB0cnVlO1xuICAgICAgYnJlYWs7XG4gICAgfVxuICB9XG5cbiAgaWYgKCF0aGVtZVNldCAmJiB0dWlIZWFkZXJJbmRleCAhPT0gLTEpIHtcbiAgICBsaW5lcy5zcGxpY2UodHVpSGVhZGVySW5kZXggKyAxLCAwLCBgdGhlbWUgPSBcIiR7Y29kZXhUaGVtZX1cImApO1xuICB9IGVsc2UgaWYgKCF0aGVtZVNldCAmJiB0dWlIZWFkZXJJbmRleCA9PT0gLTEpIHtcbiAgICBpZiAobGluZXMubGVuZ3RoID4gMCAmJiBsaW5lc1tsaW5lcy5sZW5ndGggLSAxXS50cmltKCkgIT09IFwiXCIpIGxpbmVzLnB1c2goXCJcIik7XG4gICAgbGluZXMucHVzaChcIlt0dWldXCIpO1xuICAgIGxpbmVzLnB1c2goYHRoZW1lID0gXCIke2NvZGV4VGhlbWV9XCJgKTtcbiAgfVxuXG4gIHdyaXRlRmlsZVN5bmMoQ09ERVhfQ09ORklHLCBsaW5lcy5qb2luKFwiXFxuXCIpLnJlcGxhY2UoL1xcbiokLywgXCJcXG5cIikpO1xufVxuXG50eXBlIFRoZW1lQ29tbWFuZFJ1bm5lciA9IHtcbiAgY2FuY2VsOiAoKSA9PiB2b2lkO1xuICBjaGVja0NhbmNlbGxlZDogKCkgPT4gdm9pZDtcbiAgcnVuOiAoY21kOiBzdHJpbmcsIG9wdGlvbnM/OiB7IGFsbG93RmFpbHVyZT86IGJvb2xlYW4gfSkgPT4gUHJvbWlzZTxzdHJpbmc+O1xufTtcblxuZnVuY3Rpb24gY3JlYXRlVGhlbWVDb21tYW5kUnVubmVyKCk6IFRoZW1lQ29tbWFuZFJ1bm5lciB7XG4gIGNvbnN0IGNoaWxkcmVuID0gbmV3IFNldDxDaGlsZFByb2Nlc3M+KCk7XG4gIGxldCBjYW5jZWxsZWQgPSBmYWxzZTtcblxuICBjb25zdCBjaGVja0NhbmNlbGxlZCA9ICgpID0+IHtcbiAgICBpZiAoY2FuY2VsbGVkKSB0aHJvdyBuZXcgQ2FuY2VsbGVkVGhlbWVBcHBseUVycm9yKCk7XG4gIH07XG5cbiAgcmV0dXJuIHtcbiAgICBjYW5jZWw6ICgpID0+IHtcbiAgICAgIGNhbmNlbGxlZCA9IHRydWU7XG4gICAgICBmb3IgKGNvbnN0IGNoaWxkIG9mIGNoaWxkcmVuKSB7XG4gICAgICAgIGNoaWxkLmtpbGwoXCJTSUdURVJNXCIpO1xuICAgICAgICBzZXRUaW1lb3V0KCgpID0+IGNoaWxkLmtpbGwoXCJTSUdLSUxMXCIpLCAyNTApO1xuICAgICAgfVxuICAgICAgY2hpbGRyZW4uY2xlYXIoKTtcbiAgICB9LFxuICAgIGNoZWNrQ2FuY2VsbGVkLFxuICAgIHJ1bjogKGNtZDogc3RyaW5nLCBvcHRpb25zPzogeyBhbGxvd0ZhaWx1cmU/OiBib29sZWFuIH0pID0+XG4gICAgICBuZXcgUHJvbWlzZSgocmVzb2x2ZSwgcmVqZWN0KSA9PiB7XG4gICAgICAgIGNoZWNrQ2FuY2VsbGVkKCk7XG4gICAgICAgIGNvbnN0IGNoaWxkID0gZXhlYyhjbWQsIHsgZW52OiB7IC4uLnByb2Nlc3MuZW52LCBIT01FOiBob21lZGlyKCksIFBBVEggfSB9LCAoZXJyLCBzdGRvdXQpID0+IHtcbiAgICAgICAgICBjaGlsZHJlbi5kZWxldGUoY2hpbGQpO1xuICAgICAgICAgIGlmIChjYW5jZWxsZWQpIHtcbiAgICAgICAgICAgIHJlamVjdChuZXcgQ2FuY2VsbGVkVGhlbWVBcHBseUVycm9yKCkpO1xuICAgICAgICAgICAgcmV0dXJuO1xuICAgICAgICAgIH1cbiAgICAgICAgICBpZiAoZXJyKSB7XG4gICAgICAgICAgICBpZiAob3B0aW9ucz8uYWxsb3dGYWlsdXJlKSB7XG4gICAgICAgICAgICAgIHJlc29sdmUoc3Rkb3V0IHx8IFwiXCIpO1xuICAgICAgICAgICAgICByZXR1cm47XG4gICAgICAgICAgICB9XG4gICAgICAgICAgICByZWplY3QoZXJyKTtcbiAgICAgICAgICAgIHJldHVybjtcbiAgICAgICAgICB9XG4gICAgICAgICAgcmVzb2x2ZShzdGRvdXQgfHwgXCJcIik7XG4gICAgICAgIH0pO1xuICAgICAgICBjaGlsZHJlbi5hZGQoY2hpbGQpO1xuICAgICAgfSksXG4gIH07XG59XG5cbmFzeW5jIGZ1bmN0aW9uIGFwcGx5VGhlbWUodGhlbWU6IFRoZW1lRW50cnksIHJ1bm5lcjogVGhlbWVDb21tYW5kUnVubmVyKSB7XG4gIGNvbnN0IHsgZW52LCBuYW1lIH0gPSB0aGVtZTtcbiAgY29uc3QgdGhlbWVEaXIgPSBqb2luKFRIRU1FU19ESVIsIG5hbWUpO1xuICBydW5uZXIuY2hlY2tDYW5jZWxsZWQoKTtcblxuICAvLyBEYXJrL2xpZ2h0IG1vZGVcbiAgaWYgKGVudi5EQVJLX01PREUpIHtcbiAgICBhd2FpdCBydW5uZXIucnVuKGAvdXNyL2Jpbi9vc2FzY3JpcHQgLWUgJ3RlbGwgYXBwbGljYXRpb24gXCJTeXN0ZW0gRXZlbnRzXCIgdG8gdGVsbCBhcHBlYXJhbmNlIHByZWZlcmVuY2VzIHRvIHNldCBkYXJrIG1vZGUgdG8gJHtlbnYuREFSS19NT0RFfSdgLCB7IGFsbG93RmFpbHVyZTogdHJ1ZSB9KTtcbiAgfVxuXG4gIC8vIFdhbGxwYXBlciAoYWxsIHNjcmVlbnMgKyBhbGwgc3BhY2VzKVxuICBjb25zdCB3YWxsUGF0aCA9IGpvaW4odGhlbWVEaXIsIGVudi5XQUxMUEFQRVIgfHwgXCJcIik7XG4gIGlmIChlbnYuV0FMTFBBUEVSICYmIGV4aXN0c1N5bmMod2FsbFBhdGgpKSB7XG4gICAgY29uc3Qgc2V0V2FsbHBhcGVyID0gam9pbihob21lZGlyKCksIFwiLmxvY2FsXCIsIFwiYmluXCIsIFwic2V0LXdhbGxwYXBlclwiKTtcbiAgICBhd2FpdCBydW5uZXIucnVuKGBcIiR7c2V0V2FsbHBhcGVyfVwiIFwiJHt3YWxsUGF0aH1cImApO1xuICB9XG5cbiAgLy8gR2hvc3R0eSBcdTIwMTQgaW5saW5lIHBhbGV0dGUgaW50byBtYWluIGNvbmZpZywgdGhlbiByZWxvYWQgYWxsIHdpbmRvd3NcbiAgY29uc3QgZ2hvc3R0eUNvbmYgPSBqb2luKHRoZW1lRGlyLCBcImdob3N0dHkuY29uZlwiKTtcbiAgaWYgKGV4aXN0c1N5bmMoZ2hvc3R0eUNvbmYpICYmIGV4aXN0c1N5bmMoR0hPU1RUWV9DT05GSUcpKSB7XG4gICAgY29uc3QgcGFsZXR0ZSA9IHJlYWRGaWxlU3luYyhnaG9zdHR5Q29uZiwgXCJ1dGYtOFwiKTtcbiAgICBjb25zdCBjb25maWcgPSByZWFkRmlsZVN5bmMoR0hPU1RUWV9DT05GSUcsIFwidXRmLThcIik7XG4gICAgY29uc3QgbGluZXMgPSBjb25maWcuc3BsaXQoXCJcXG5cIikuZmlsdGVyKChsKSA9PlxuICAgICAgIWwuc3RhcnRzV2l0aChcImJhY2tncm91bmQgXCIpICYmXG4gICAgICAhbC5zdGFydHNXaXRoKFwiZm9yZWdyb3VuZCBcIikgJiZcbiAgICAgICFsLnN0YXJ0c1dpdGgoXCJjdXJzb3ItY29sb3IgXCIpICYmXG4gICAgICAhbC5zdGFydHNXaXRoKFwic2VsZWN0aW9uLWJhY2tncm91bmQgXCIpICYmXG4gICAgICAhbC5zdGFydHNXaXRoKFwic2VsZWN0aW9uLWZvcmVncm91bmQgXCIpICYmXG4gICAgICAhbC5zdGFydHNXaXRoKFwicGFsZXR0ZSBcIikgJiZcbiAgICAgICFsLnN0YXJ0c1dpdGgoXCJ0aGVtZSBcIikgJiZcbiAgICAgICFsLm1hdGNoKC9eY29uZmlnLWZpbGUuKlxcLnRoZW1lc1xcLy8pICYmXG4gICAgICAhbC5zdGFydHNXaXRoKFwiIyAtLS0gVEhFTUUgQ09MT1JTXCIpXG4gICAgKTtcbiAgICBsaW5lcy5wdXNoKFwiXCIpO1xuICAgIGxpbmVzLnB1c2goYCMgLS0tIFRIRU1FIENPTE9SUyAoJHtuYW1lfSkgLS0tYCk7XG4gICAgbGluZXMucHVzaChwYWxldHRlLnRyaW0oKSk7XG4gICAgd3JpdGVGaWxlU3luYyhHSE9TVFRZX0NPTkZJRywgbGluZXMuam9pbihcIlxcblwiKSArIFwiXFxuXCIpO1xuICAgIHJ1bm5lci5jaGVja0NhbmNlbGxlZCgpO1xuICAgIGF3YWl0IHJ1bm5lci5ydW4oYC9iaW4vYmFzaCAtYyAnXG4gICAgICAvdXNyL2Jpbi9wa2lsbCAtVVNSMiAteCBnaG9zdHR5IDI+L2Rldi9udWxsIHx8IC91c3IvYmluL3BraWxsIC1VU1IyIC14IEdob3N0dHkgMj4vZGV2L251bGwgfHwgdHJ1ZVxuICAgICAgc2xlZXAgMC4yXG4gICAgICAvdXNyL2Jpbi9vc2FzY3JpcHQgLWUgJ1wiJ1wiJ1xuICAgICAgdGVsbCBhcHBsaWNhdGlvbiBcIlN5c3RlbSBFdmVudHNcIlxuICAgICAgICBpZiBleGlzdHMgcHJvY2VzcyBcImdob3N0dHlcIiB0aGVuXG4gICAgICAgICAgdGVsbCBwcm9jZXNzIFwiZ2hvc3R0eVwiXG4gICAgICAgICAgICBjbGljayBtZW51IGl0ZW0gXCJSZWxvYWQgQ29uZmlndXJhdGlvblwiIG9mIG1lbnUgXCJHaG9zdHR5XCIgb2YgbWVudSBiYXIgMVxuICAgICAgICAgIGVuZCB0ZWxsXG4gICAgICAgIGVuZCBpZlxuICAgICAgZW5kIHRlbGwnXCInXCInIDI+L2Rldi9udWxsIHx8IHRydWVcbiAgICAgICdgLCB7IGFsbG93RmFpbHVyZTogdHJ1ZSB9KTtcbiAgfVxuXG4gIC8vIE5lb3ZpbVxuICBpZiAoZW52Lk5WSU1fQ09MT1JTQ0hFTUUpIHtcbiAgICB3cml0ZUZpbGVTeW5jKE5WSU1fQ09MT1JTQ0hFTUVfRklMRSwgYHJldHVybiB7XFxuICB7IFwiTGF6eVZpbS9MYXp5VmltXCIsIG9wdHMgPSB7IGNvbG9yc2NoZW1lID0gXCIke2Vudi5OVklNX0NPTE9SU0NIRU1FfVwiIH0gfSxcXG59XFxuYCk7XG4gICAgcnVubmVyLmNoZWNrQ2FuY2VsbGVkKCk7XG4gICAgYXdhaXQgcnVubmVyLnJ1bihgL2Jpbi9iYXNoIC1jICdmb3Igc29jayBpbiAvdG1wL252aW0uKi8wOyBkbyBbIC1TIFwiJHNvY2tcIiBdICYmIC9vcHQvaG9tZWJyZXcvYmluL252aW0gLS1zZXJ2ZXIgXCIkc29ja1wiIC0tcmVtb3RlLXNlbmQgXCI8Q21kPmNvbG9yc2NoZW1lICR7ZW52Lk5WSU1fQ09MT1JTQ0hFTUV9PENSPlwiIDI+L2Rldi9udWxsIHx8IHRydWU7IGRvbmUnYCwgeyBhbGxvd0ZhaWx1cmU6IHRydWUgfSk7XG4gIH1cblxuICAvLyBKYW5reUJvcmRlcnNcbiAgaWYgKGVudi5CT1JERVJfQUNUSVZFKSB7XG4gICAgYXdhaXQgcnVubmVyLnJ1bihgL3Vzci9iaW4vcGtpbGwgLXggYm9yZGVycyAyPi9kZXYvbnVsbDsgc2xlZXAgMC4xOyAvb3B0L2hvbWVicmV3L2Jpbi9ib3JkZXJzIGFjdGl2ZV9jb2xvcj0ke2Vudi5CT1JERVJfQUNUSVZFfSBpbmFjdGl2ZV9jb2xvcj0ke2Vudi5CT1JERVJfSU5BQ1RJVkUgfHwgXCIweDAwMDAwMDAwXCJ9IHdpZHRoPSR7ZW52LkJPUkRFUl9XSURUSCB8fCBcIjYuMFwifSAmYCwgeyBhbGxvd0ZhaWx1cmU6IHRydWUgfSk7XG4gIH1cblxuICB3cml0ZUZpbGVTeW5jKFxuICAgIFNLRVRDSFlCQVJfVEhFTUVfRklMRSxcbiAgICBgIyEvdXNyL2Jpbi9lbnYgYmFzaFxuXG5BQ0NFTlRfQ09MT1I9XCIke3RvTWFjb3NDb2xvcih0aGVtZS5hY2NlbnRDb2xvcil9XCJcblRFWFRfQ09MT1I9XCIke3RvTWFjb3NDb2xvcih0aGVtZS50ZXh0Q29sb3IpfVwiXG5gLFxuICApO1xuICBydW5uZXIuY2hlY2tDYW5jZWxsZWQoKTtcbiAgYXdhaXQgcnVubmVyLnJ1bihcbiAgICBgL2Jpbi9iYXNoIC1jICdcbiAgICAgIC91c3IvYmluL3BraWxsIC14IHNrZXRjaHliYXIgMj4vZGV2L251bGwgfHwgdHJ1ZVxuICAgICAgc2xlZXAgMC4zNVxuICAgICAgL2Jpbi9sYXVuY2hjdGwga2lja3N0YXJ0IC1rIFwiZ3VpLyQoaWQgLXUpL2hvbWVicmV3Lm14Y2wuc2tldGNoeWJhclwiIDI+L2Rldi9udWxsIHx8IHRydWVcbiAgICAgIHNsZWVwIDAuMzVcbiAgICAgIC9vcHQvaG9tZWJyZXcvYmluL3NrZXRjaHliYXIgLS1yZWxvYWQgMj4vZGV2L251bGwgfHwgdHJ1ZVxuICAgICAgL29wdC9ob21lYnJldy9iaW4vc2tldGNoeWJhciAtLXVwZGF0ZSAyPi9kZXYvbnVsbCB8fCB0cnVlXG4gICAgJ2AsXG4gICAgeyBhbGxvd0ZhaWx1cmU6IHRydWUgfSxcbiAgKTtcblxuICBydW5uZXIuY2hlY2tDYW5jZWxsZWQoKTtcbiAgc2V0Q29kZXhUaGVtZSh0aGVtZSk7XG4gIHdyaXRlRmlsZVN5bmMoam9pbihUSEVNRVNfRElSLCBcIi5jdXJyZW50XCIpLCBuYW1lKTtcbn1cblxuZXhwb3J0IGRlZmF1bHQgZnVuY3Rpb24gQ29tbWFuZCgpIHtcbiAgY29uc3QgdGhlbWVzID0gZ2V0VGhlbWVzKCk7XG4gIGNvbnN0IFtjdXJyZW50LCBzZXRDdXJyZW50XSA9IHVzZVN0YXRlKCgpID0+IGdldEN1cnJlbnRUaGVtZSgpKTtcbiAgY29uc3QgW3NlbGVjdGVkVGhlbWUsIHNldFNlbGVjdGVkVGhlbWVdID0gdXNlU3RhdGUoKCkgPT4gZ2V0Q3VycmVudFRoZW1lKCkpO1xuICBjb25zdCBbcGVuZGluZ1RoZW1lLCBzZXRQZW5kaW5nVGhlbWVdID0gdXNlU3RhdGU8c3RyaW5nIHwgbnVsbD4obnVsbCk7XG4gIGNvbnN0IGFwcGx5SWRSZWYgPSB1c2VSZWYoMCk7XG4gIGNvbnN0IGFjdGl2ZVRvYXN0UmVmID0gdXNlUmVmPFRvYXN0IHwgbnVsbD4obnVsbCk7XG4gIGNvbnN0IGFjdGl2ZVJ1bm5lclJlZiA9IHVzZVJlZjxUaGVtZUNvbW1hbmRSdW5uZXIgfCBudWxsPihudWxsKTtcblxuICB1c2VFZmZlY3QoKCkgPT4ge1xuICAgIGNvbnN0IHN5bmNDdXJyZW50VGhlbWUgPSAoKSA9PiB7XG4gICAgICBjb25zdCBuZXh0ID0gZ2V0Q3VycmVudFRoZW1lKCk7XG4gICAgICBzZXRDdXJyZW50KChwcmV2KSA9PiAocHJldiA9PT0gbmV4dCA/IHByZXYgOiBuZXh0KSk7XG4gICAgfTtcblxuICAgIHN5bmNDdXJyZW50VGhlbWUoKTtcbiAgICBjb25zdCBpbnRlcnZhbCA9IHNldEludGVydmFsKHN5bmNDdXJyZW50VGhlbWUsIDc1MCk7XG4gICAgcmV0dXJuICgpID0+IGNsZWFySW50ZXJ2YWwoaW50ZXJ2YWwpO1xuICB9LCBbXSk7XG5cbiAgZnVuY3Rpb24gZ2V0VGhlbWVQcmV2aWV3KHRoZW1lOiBUaGVtZUVudHJ5KTogc3RyaW5nIHtcbiAgICBjb25zdCB3YWxscGFwZXJQcmV2aWV3ID0gdGhlbWUud2FsbHBhcGVyUGF0aCA/IGAhWyR7dGhlbWUuZGlzcGxheU5hbWV9XSgke2VuY29kZVVSSShgZmlsZTovLyR7dGhlbWUud2FsbHBhcGVyUGF0aH1gKX0pYCA6IFwiX05vIHdhbGxwYXBlciBwcmV2aWV3IGF2YWlsYWJsZV9cIjtcbiAgICBjb25zdCBsaW5lcyA9IFtcbiAgICAgIGAjICR7dGhlbWUuZGlzcGxheU5hbWV9YCxcbiAgICAgIFwiXCIsXG4gICAgICB3YWxscGFwZXJQcmV2aWV3LFxuICAgICAgXCJcIixcbiAgICAgIGBBY2NlbnQgXFxgJHt0aGVtZS5hY2NlbnRDb2xvcn1cXGBgLFxuICAgICAgYFRleHQgXFxgJHt0aGVtZS50ZXh0Q29sb3J9XFxgYCxcbiAgICBdO1xuXG4gICAgcmV0dXJuIGxpbmVzLmpvaW4oXCJcXG5cIik7XG4gIH1cblxuICBmdW5jdGlvbiBnZXRMc1ByZXZpZXdDb2xvcnModGhlbWU6IFRoZW1lRW50cnkpIHtcbiAgICByZXR1cm4ge1xuICAgICAgZGlyZWN0b3J5OiB0aGVtZS5wYWxldHRlWzRdIHx8IHRoZW1lLmFjY2VudENvbG9yLFxuICAgICAgc3ltbGluazogdGhlbWUucGFsZXR0ZVs2XSB8fCB0aGVtZS5hY2NlbnRDb2xvcixcbiAgICAgIGV4ZWN1dGFibGU6IHRoZW1lLnBhbGV0dGVbMl0gfHwgdGhlbWUuYWNjZW50Q29sb3IsXG4gICAgICBhcmNoaXZlOiB0aGVtZS5wYWxldHRlWzFdIHx8IHRoZW1lLmFjY2VudENvbG9yLFxuICAgICAgZGV2aWNlOiB0aGVtZS5wYWxldHRlWzNdIHx8IHRoZW1lLmFjY2VudENvbG9yLFxuICAgICAgbm9ybWFsOiB0aGVtZS50ZXh0Q29sb3IsXG4gICAgfTtcbiAgfVxuXG4gIHJldHVybiAoXG4gICAgPExpc3RcbiAgICAgIGlzU2hvd2luZ0RldGFpbFxuICAgICAgc2VhcmNoQmFyUGxhY2Vob2xkZXI9XCJTZWFyY2ggdGhlbWVzLi4uXCJcbiAgICAgIHNlbGVjdGVkSXRlbUlkPXtzZWxlY3RlZFRoZW1lfVxuICAgICAgb25TZWxlY3Rpb25DaGFuZ2U9eyhpZCkgPT4ge1xuICAgICAgICBpZiAoaWQpIHNldFNlbGVjdGVkVGhlbWUoaWQpO1xuICAgICAgfX1cbiAgICA+XG4gICAgICB7dGhlbWVzLm1hcCgodGhlbWUpID0+IHtcbiAgICAgICAgY29uc3QgaXNDdXJyZW50ID0gdGhlbWUubmFtZSA9PT0gKHBlbmRpbmdUaGVtZSB8fCBjdXJyZW50KTtcbiAgICAgICAgY29uc3QgYWNjZXNzb3JpZXM6IExpc3QuSXRlbS5BY2Nlc3NvcnlbXSA9IFtdO1xuICAgICAgICBpZiAoaXNDdXJyZW50KSBhY2Nlc3Nvcmllcy5wdXNoKHsgdGFnOiB7IHZhbHVlOiBcImFjdGl2ZVwiLCBjb2xvcjogQ29sb3IuR3JlZW4gfSB9KTtcbiAgICAgICAgYWNjZXNzb3JpZXMucHVzaCh7IGljb246IHRoZW1lLmlzRGFyayA/IEljb24uTW9vbiA6IEljb24uU3VuIH0pO1xuICAgICAgICBpZiAodGhlbWUuYmdDb3VudCA+IDApIGFjY2Vzc29yaWVzLnB1c2goeyB0ZXh0OiBgJHt0aGVtZS5iZ0NvdW50fSBiZ2AgfSk7XG5cbiAgICAgICAgcmV0dXJuIChcbiAgICAgICAgICA8TGlzdC5JdGVtXG4gICAgICAgICAgICBrZXk9e3RoZW1lLm5hbWV9XG4gICAgICAgICAgICB0aXRsZT17dGhlbWUuZGlzcGxheU5hbWV9XG4gICAgICAgICAgICBpY29uPXt7IHNvdXJjZTogSWNvbi5DaXJjbGUsIHRpbnRDb2xvcjogdGhlbWUuYWNjZW50Q29sb3IgYXMgQ29sb3IgfX1cbiAgICAgICAgICAgIGFjY2Vzc29yaWVzPXthY2Nlc3Nvcmllc31cbiAgICAgICAgICAgIGRldGFpbD17XG4gICAgICAgICAgICAgIDxMaXN0Lkl0ZW0uRGV0YWlsXG4gICAgICAgICAgICAgICAgbWFya2Rvd249e2dldFRoZW1lUHJldmlldyh0aGVtZSl9XG4gICAgICAgICAgICAgICAgbWV0YWRhdGE9e1xuICAgICAgICAgICAgICAgICAgPExpc3QuSXRlbS5EZXRhaWwuTWV0YWRhdGE+XG4gICAgICAgICAgICAgICAgICAgIDxMaXN0Lkl0ZW0uRGV0YWlsLk1ldGFkYXRhLkxhYmVsIHRpdGxlPVwiTW9kZVwiIHRleHQ9e3RoZW1lLmlzRGFyayA/IFwiRGFya1wiIDogXCJMaWdodFwifSAvPlxuICAgICAgICAgICAgICAgICAgICA8TGlzdC5JdGVtLkRldGFpbC5NZXRhZGF0YS5TZXBhcmF0b3IgLz5cbiAgICAgICAgICAgICAgICAgICAgPExpc3QuSXRlbS5EZXRhaWwuTWV0YWRhdGEuTGFiZWwgdGl0bGU9XCJXYWxscGFwZXJzXCIgdGV4dD17U3RyaW5nKHRoZW1lLmJnQ291bnQgfHwgKHRoZW1lLmhhc1dhbGxwYXBlciA/IDEgOiAwKSl9IC8+XG4gICAgICAgICAgICAgICAgICAgIDxMaXN0Lkl0ZW0uRGV0YWlsLk1ldGFkYXRhLlNlcGFyYXRvciAvPlxuICAgICAgICAgICAgICAgICAgICA8TGlzdC5JdGVtLkRldGFpbC5NZXRhZGF0YS5UYWdMaXN0IHRpdGxlPVwibHMgLWxhXCI+XG4gICAgICAgICAgICAgICAgICAgICAgPExpc3QuSXRlbS5EZXRhaWwuTWV0YWRhdGEuVGFnTGlzdC5JdGVtIHRleHQ9XCJkaXIvXCIgY29sb3I9e2dldExzUHJldmlld0NvbG9ycyh0aGVtZSkuZGlyZWN0b3J5fSAvPlxuICAgICAgICAgICAgICAgICAgICAgIDxMaXN0Lkl0ZW0uRGV0YWlsLk1ldGFkYXRhLlRhZ0xpc3QuSXRlbSB0ZXh0PVwibGlua0BcIiBjb2xvcj17Z2V0THNQcmV2aWV3Q29sb3JzKHRoZW1lKS5zeW1saW5rfSAvPlxuICAgICAgICAgICAgICAgICAgICAgIDxMaXN0Lkl0ZW0uRGV0YWlsLk1ldGFkYXRhLlRhZ0xpc3QuSXRlbSB0ZXh0PVwiZXhlYypcIiBjb2xvcj17Z2V0THNQcmV2aWV3Q29sb3JzKHRoZW1lKS5leGVjdXRhYmxlfSAvPlxuICAgICAgICAgICAgICAgICAgICAgIDxMaXN0Lkl0ZW0uRGV0YWlsLk1ldGFkYXRhLlRhZ0xpc3QuSXRlbSB0ZXh0PVwiYXJjaGl2ZVwiIGNvbG9yPXtnZXRMc1ByZXZpZXdDb2xvcnModGhlbWUpLmFyY2hpdmV9IC8+XG4gICAgICAgICAgICAgICAgICAgICAgPExpc3QuSXRlbS5EZXRhaWwuTWV0YWRhdGEuVGFnTGlzdC5JdGVtIHRleHQ9XCJkZXZpY2VcIiBjb2xvcj17Z2V0THNQcmV2aWV3Q29sb3JzKHRoZW1lKS5kZXZpY2V9IC8+XG4gICAgICAgICAgICAgICAgICAgICAgPExpc3QuSXRlbS5EZXRhaWwuTWV0YWRhdGEuVGFnTGlzdC5JdGVtIHRleHQ9XCJmaWxlXCIgY29sb3I9e2dldExzUHJldmlld0NvbG9ycyh0aGVtZSkubm9ybWFsfSAvPlxuICAgICAgICAgICAgICAgICAgICA8L0xpc3QuSXRlbS5EZXRhaWwuTWV0YWRhdGEuVGFnTGlzdD5cbiAgICAgICAgICAgICAgICAgIDwvTGlzdC5JdGVtLkRldGFpbC5NZXRhZGF0YT5cbiAgICAgICAgICAgICAgICB9XG4gICAgICAgICAgICAgIC8+XG4gICAgICAgICAgICB9XG4gICAgICAgICAgICBhY3Rpb25zPXtcbiAgICAgICAgICAgICAgPEFjdGlvblBhbmVsPlxuICAgICAgICAgICAgICAgIDxBY3Rpb25cbiAgICAgICAgICAgICAgICAgIHRpdGxlPVwiQXBwbHkgVGhlbWVcIlxuICAgICAgICAgICAgICAgICAgaWNvbj17SWNvbi5CcnVzaH1cbiAgICAgICAgICAgICAgICAgIHNob3J0Y3V0PXt7IG1vZGlmaWVyczogW10sIGtleTogXCJyZXR1cm5cIiB9fVxuICAgICAgICAgICAgICAgICAgb25BY3Rpb249e2FzeW5jICgpID0+IHtcbiAgICAgICAgICAgICAgICAgICAgY29uc3QgYXBwbHlJZCA9ICsrYXBwbHlJZFJlZi5jdXJyZW50O1xuICAgICAgICAgICAgICAgICAgICBhY3RpdmVSdW5uZXJSZWYuY3VycmVudD8uY2FuY2VsKCk7XG4gICAgICAgICAgICAgICAgICAgIGlmIChhY3RpdmVUb2FzdFJlZi5jdXJyZW50KSB7XG4gICAgICAgICAgICAgICAgICAgICAgYXdhaXQgYWN0aXZlVG9hc3RSZWYuY3VycmVudC5oaWRlKCkuY2F0Y2goKCkgPT4ge30pO1xuICAgICAgICAgICAgICAgICAgICB9XG4gICAgICAgICAgICAgICAgICAgIGNvbnN0IHJ1bm5lciA9IGNyZWF0ZVRoZW1lQ29tbWFuZFJ1bm5lcigpO1xuICAgICAgICAgICAgICAgICAgICBhY3RpdmVSdW5uZXJSZWYuY3VycmVudCA9IHJ1bm5lcjtcbiAgICAgICAgICAgICAgICAgICAgc2V0UGVuZGluZ1RoZW1lKHRoZW1lLm5hbWUpO1xuICAgICAgICAgICAgICAgICAgICBzZXRDdXJyZW50KHRoZW1lLm5hbWUpO1xuICAgICAgICAgICAgICAgICAgICBzZXRTZWxlY3RlZFRoZW1lKHRoZW1lLm5hbWUpO1xuICAgICAgICAgICAgICAgICAgICBjb25zdCB0b2FzdCA9IGF3YWl0IHNob3dUb2FzdCh7IHN0eWxlOiBUb2FzdC5TdHlsZS5BbmltYXRlZCwgdGl0bGU6IGBTd2l0Y2hpbmcgdG8gJHt0aGVtZS5kaXNwbGF5TmFtZX0uLi5gIH0pO1xuICAgICAgICAgICAgICAgICAgICBhY3RpdmVUb2FzdFJlZi5jdXJyZW50ID0gdG9hc3Q7XG4gICAgICAgICAgICAgICAgICAgIHRyeSB7XG4gICAgICAgICAgICAgICAgICAgICAgYXdhaXQgYXBwbHlUaGVtZSh0aGVtZSwgcnVubmVyKTtcbiAgICAgICAgICAgICAgICAgICAgICBpZiAoYXBwbHlJZCAhPT0gYXBwbHlJZFJlZi5jdXJyZW50KSByZXR1cm47XG4gICAgICAgICAgICAgICAgICAgICAgc2V0Q3VycmVudCh0aGVtZS5uYW1lKTtcbiAgICAgICAgICAgICAgICAgICAgICBzZXRTZWxlY3RlZFRoZW1lKHRoZW1lLm5hbWUpO1xuICAgICAgICAgICAgICAgICAgICAgIHNldFBlbmRpbmdUaGVtZShudWxsKTtcbiAgICAgICAgICAgICAgICAgICAgICBhd2FpdCB0b2FzdC5oaWRlKCk7XG4gICAgICAgICAgICAgICAgICAgICAgaWYgKGFjdGl2ZVRvYXN0UmVmLmN1cnJlbnQgPT09IHRvYXN0KSBhY3RpdmVUb2FzdFJlZi5jdXJyZW50ID0gbnVsbDtcbiAgICAgICAgICAgICAgICAgICAgICBpZiAoYWN0aXZlUnVubmVyUmVmLmN1cnJlbnQgPT09IHJ1bm5lcikgYWN0aXZlUnVubmVyUmVmLmN1cnJlbnQgPSBudWxsO1xuICAgICAgICAgICAgICAgICAgICAgIGF3YWl0IHNob3dIVUQoYFN3aXRjaGVkIHRvICR7dGhlbWUuZGlzcGxheU5hbWV9YCk7XG4gICAgICAgICAgICAgICAgICAgIH0gY2F0Y2ggKGUpIHtcbiAgICAgICAgICAgICAgICAgICAgICBpZiAoYXBwbHlJZCAhPT0gYXBwbHlJZFJlZi5jdXJyZW50KSByZXR1cm47XG4gICAgICAgICAgICAgICAgICAgICAgaWYgKGUgaW5zdGFuY2VvZiBDYW5jZWxsZWRUaGVtZUFwcGx5RXJyb3IpIHJldHVybjtcbiAgICAgICAgICAgICAgICAgICAgICBzZXRQZW5kaW5nVGhlbWUobnVsbCk7XG4gICAgICAgICAgICAgICAgICAgICAgc2V0Q3VycmVudChnZXRDdXJyZW50VGhlbWUoKSk7XG4gICAgICAgICAgICAgICAgICAgICAgdG9hc3Quc3R5bGUgPSBUb2FzdC5TdHlsZS5GYWlsdXJlO1xuICAgICAgICAgICAgICAgICAgICAgIHRvYXN0LnRpdGxlID0gXCJGYWlsZWRcIjtcbiAgICAgICAgICAgICAgICAgICAgICB0b2FzdC5tZXNzYWdlID0gU3RyaW5nKGUpO1xuICAgICAgICAgICAgICAgICAgICAgIGlmIChhY3RpdmVUb2FzdFJlZi5jdXJyZW50ID09PSB0b2FzdCkgYWN0aXZlVG9hc3RSZWYuY3VycmVudCA9IG51bGw7XG4gICAgICAgICAgICAgICAgICAgICAgaWYgKGFjdGl2ZVJ1bm5lclJlZi5jdXJyZW50ID09PSBydW5uZXIpIGFjdGl2ZVJ1bm5lclJlZi5jdXJyZW50ID0gbnVsbDtcbiAgICAgICAgICAgICAgICAgICAgfVxuICAgICAgICAgICAgICAgICAgfX1cbiAgICAgICAgICAgICAgICAvPlxuICAgICAgICAgICAgICA8L0FjdGlvblBhbmVsPlxuICAgICAgICAgICAgfVxuICAgICAgICAgIC8+XG4gICAgICAgICk7XG4gICAgICB9KX1cbiAgICA8L0xpc3Q+XG4gICk7XG59XG4iXSwK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
