"use strict";

const { Action, ActionPanel, Color, Icon, List, showHUD, showToast, Toast } = require("@raycast/api");
const { execFile } = require("child_process");
const { existsSync, readFileSync, readdirSync } = require("fs");
const { homedir } = require("os");
const { join } = require("path");
const React = require("react");

const THEMES_DIR = join(homedir(), ".themes");
const CURRENT_THEME_FILE = join(THEMES_DIR, ".current");
const THEME_SWITCH = join(homedir(), ".local", "bin", "theme-switch");
const PATH = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin";

function parseThemeEnv(dir) {
  const envPath = join(dir, "theme.env");
  if (!existsSync(envPath)) return {};

  const env = {};
  for (const line of readFileSync(envPath, "utf8").split("\n")) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith("#")) continue;
    const eq = trimmed.indexOf("=");
    if (eq === -1) continue;

    const key = trimmed.slice(0, eq);
    let value = trimmed.slice(eq + 1);
    if ((value.startsWith('"') && value.endsWith('"')) || (value.startsWith("'") && value.endsWith("'"))) {
      value = value.slice(1, -1);
    }
    env[key] = value;
  }
  return env;
}

function getGhosttyColor(dir, key, fallback) {
  const ghosttyPath = join(dir, "ghostty.conf");
  if (!existsSync(ghosttyPath)) return fallback;

  for (const line of readFileSync(ghosttyPath, "utf8").split("\n")) {
    const match = line.trim().match(new RegExp(`^${key}\\s*=\\s*(#[0-9a-fA-F]{6})$`));
    if (match) return match[1];
  }
  return fallback;
}

function getGhosttyPalette(dir) {
  const ghosttyPath = join(dir, "ghostty.conf");
  if (!existsSync(ghosttyPath)) return [];

  const palette = [];
  for (const line of readFileSync(ghosttyPath, "utf8").split("\n")) {
    const match = line.trim().match(/^palette\s*=\s*(\d+)=\s*(#[0-9a-fA-F]{6})$/);
    if (match) palette[Number(match[1])] = match[2];
  }
  return palette;
}

function displayName(name) {
  return name
    .split("-")
    .map((part) => part.charAt(0).toUpperCase() + part.slice(1))
    .join(" ");
}

function getThemes() {
  if (!existsSync(THEMES_DIR)) return [];

  return readdirSync(THEMES_DIR, { withFileTypes: true })
    .filter((entry) => entry.isDirectory())
    .map((entry) => {
      const dir = join(THEMES_DIR, entry.name);
      const env = parseThemeEnv(dir);
      const palette = getGhosttyPalette(dir);
      const wallpaperPath = env.WALLPAPER ? join(dir, env.WALLPAPER) : "";
      const backgroundDir = join(dir, "backgrounds");
      const accentColor = palette[4] || (env.BORDER_ACTIVE?.startsWith("0xff") ? `#${env.BORDER_ACTIVE.slice(4)}` : "#888888");
      const textColor = getGhosttyColor(dir, "foreground", env.DARK_MODE === "false" ? "#000000" : "#ffffff");

      return {
        name: entry.name,
        displayName: displayName(entry.name),
        accentColor,
        textColor,
        isDark: env.DARK_MODE !== "false",
        wallpaperPath: existsSync(wallpaperPath) ? wallpaperPath : "",
        backgroundCount: existsSync(backgroundDir) ? readdirSync(backgroundDir).length : 0,
      };
    })
    .sort((a, b) => a.name.localeCompare(b.name));
}

function getCurrentTheme() {
  try {
    return readFileSync(CURRENT_THEME_FILE, "utf8").trim();
  } catch {
    return "";
  }
}

function runThemeSwitch(themeName) {
  return new Promise((resolve, reject) => {
    execFile(THEME_SWITCH, [themeName], { env: { ...process.env, HOME: homedir(), PATH } }, (error, stdout, stderr) => {
      if (error) {
        error.message = stderr || stdout || error.message;
        reject(error);
        return;
      }
      resolve();
    });
  });
}

function Command() {
  const [current, setCurrent] = React.useState(getCurrentTheme);
  const [pending, setPending] = React.useState("");
  const themes = getThemes();

  React.useEffect(() => {
    const interval = setInterval(() => setCurrent(getCurrentTheme()), 750);
    return () => clearInterval(interval);
  }, []);

  return React.createElement(
    List,
    { isShowingDetail: true, searchBarPlaceholder: "Search themes" },
    themes.map((theme) => {
      const isActive = theme.name === (pending || current);
      const accessories = [
        { icon: theme.isDark ? Icon.Moon : Icon.Sun },
        ...(theme.backgroundCount ? [{ text: `${theme.backgroundCount} bg` }] : []),
        ...(isActive ? [{ tag: { value: "active", color: Color.Green } }] : []),
      ];
      const preview = [
        `# ${theme.displayName}`,
        "",
        theme.wallpaperPath ? `![${theme.displayName}](file://${encodeURI(theme.wallpaperPath)})` : "_No wallpaper preview available_",
        "",
        `Accent \`${theme.accentColor}\``,
        `Text \`${theme.textColor}\``,
      ].join("\n");

      return React.createElement(List.Item, {
        key: theme.name,
        id: theme.name,
        title: theme.displayName,
        icon: { source: Icon.Circle, tintColor: theme.accentColor },
        accessories,
        detail: React.createElement(List.Item.Detail, { markdown: preview }),
        actions: React.createElement(
          ActionPanel,
          null,
          React.createElement(Action, {
            title: "Apply Theme",
            icon: Icon.Brush,
            onAction: async () => {
              const toast = await showToast({ style: Toast.Style.Animated, title: `Switching to ${theme.displayName}` });
              setPending(theme.name);
              try {
                await runThemeSwitch(theme.name);
                setCurrent(theme.name);
                setPending("");
                await toast.hide();
                await showHUD(`Switched to ${theme.displayName}`);
              } catch (error) {
                setPending("");
                toast.style = Toast.Style.Failure;
                toast.title = "Theme switch failed";
                toast.message = error instanceof Error ? error.message : String(error);
              }
            },
          }),
        ),
      });
    }),
  );
}

module.exports = { default: Command };
