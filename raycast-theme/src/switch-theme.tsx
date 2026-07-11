import {
  Action,
  ActionPanel,
  Color,
  Grid,
  Icon,
  Keyboard,
  List,
  Toast,
  getPreferenceValues,
  openExtensionPreferences,
  showToast,
} from "@raycast/api";
import { execFile } from "node:child_process";
import { readdir, readFile } from "node:fs/promises";
import { homedir } from "node:os";
import { basename, extname, isAbsolute, join } from "node:path";
import { useCallback, useEffect, useState } from "react";

type Preferences = {
  themeSwitcherPath: string;
  themesDirectory: string;
};

type Background = {
  name: string;
  path: string;
  relativePath: string;
};

type Theme = {
  accent: string;
  backgrounds: Background[];
  foreground: string;
  isDark: boolean;
  name: string;
  selectedBackground?: Background;
  title: string;
};

type ThemeState = {
  currentTheme: string;
  themes: Theme[];
};

const IMAGE_EXTENSIONS = new Set([".heic", ".jpeg", ".jpg", ".png", ".webp"]);

function expandHome(value: string): string {
  const path = value.trim();

  if (path === "~" || path === "$HOME") return homedir();
  if (path.startsWith("~/")) return join(homedir(), path.slice(2));
  if (path.startsWith("$HOME/")) return join(homedir(), path.slice(6));
  return path;
}

function titleFromName(name: string): string {
  return name
    .split(/[-_\s]+/)
    .filter(Boolean)
    .map((word) => word.charAt(0).toUpperCase() + word.slice(1))
    .join(" ");
}

function isSafeRelativePath(path: string): boolean {
  return path.length > 0 && !isAbsolute(path) && !path.split("/").includes("..");
}

function parseThemeEnvironment(contents: string): Record<string, string> {
  const values: Record<string, string> = {};

  for (const rawLine of contents.split("\n")) {
    const line = rawLine.trim();
    if (!line || line.startsWith("#")) continue;

    const separator = line.indexOf("=");
    if (separator === -1) continue;

    const key = line.slice(0, separator).trim();
    let value = line.slice(separator + 1).trim();
    if ((value.startsWith('"') && value.endsWith('"')) || (value.startsWith("'") && value.endsWith("'"))) {
      value = value.slice(1, -1);
    }
    values[key] = value;
  }

  return values;
}

function parseGhosttyColours(contents: string): { accent: string; foreground: string } {
  let accent = "#888888";
  let foreground = "#ffffff";

  for (const rawLine of contents.split("\n")) {
    const line = rawLine.trim();
    const foregroundMatch = line.match(/^foreground\s*=\s*(#[0-9a-f]{6})$/i);
    const accentMatch = line.match(/^palette\s*=\s*4\s*=\s*(#[0-9a-f]{6})$/i);
    if (foregroundMatch) foreground = foregroundMatch[1];
    if (accentMatch) accent = accentMatch[1];
  }

  return { accent, foreground };
}

function borderColour(value: string | undefined): string | undefined {
  const match = value?.match(/^0xff([0-9a-f]{6})$/i);
  return match ? `#${match[1]}` : undefined;
}

async function readOptional(path: string): Promise<string> {
  try {
    return await readFile(path, "utf8");
  } catch (error) {
    const code = error instanceof Error && "code" in error ? error.code : undefined;
    if (code === "ENOENT") return "";
    throw error;
  }
}

async function loadBackgrounds(themeDirectory: string): Promise<Background[]> {
  const backgrounds: Background[] = [];

  for (const directory of ["", "backgrounds"]) {
    let entries;
    try {
      entries = await readdir(join(themeDirectory, directory), { withFileTypes: true });
    } catch (error) {
      const code = error instanceof Error && "code" in error ? error.code : undefined;
      if (code === "ENOENT") continue;
      throw error;
    }

    for (const entry of entries) {
      if (!entry.isFile() || entry.name.startsWith(".") || !IMAGE_EXTENSIONS.has(extname(entry.name).toLowerCase())) {
        continue;
      }

      const relativePath = directory ? `${directory}/${entry.name}` : entry.name;
      backgrounds.push({
        name: titleFromName(basename(entry.name, extname(entry.name))),
        path: join(themeDirectory, relativePath),
        relativePath,
      });
    }
  }

  return backgrounds.sort((left, right) => left.relativePath.localeCompare(right.relativePath));
}

async function loadThemeState(themesDirectory: string): Promise<ThemeState> {
  const [entries, currentTheme, backgroundStateText] = await Promise.all([
    readdir(themesDirectory, { withFileTypes: true }),
    readOptional(join(themesDirectory, ".current")),
    readOptional(join(themesDirectory, ".backgrounds.json")),
  ]);

  let backgroundState: Record<string, string> = {};
  if (backgroundStateText) {
    try {
      const parsed: unknown = JSON.parse(backgroundStateText);
      if (parsed && typeof parsed === "object" && !Array.isArray(parsed)) {
        backgroundState = Object.fromEntries(
          Object.entries(parsed).filter((entry): entry is [string, string] => typeof entry[1] === "string"),
        );
      }
    } catch {
      // A damaged preference file should not hide otherwise valid themes.
    }
  }

  const themes = await Promise.all(
    entries
      .filter((entry) => !entry.name.startsWith(".") && (entry.isDirectory() || entry.isSymbolicLink()))
      .map(async (entry): Promise<Theme> => {
        const directory = join(themesDirectory, entry.name);
        const [environmentText, ghosttyText, backgrounds] = await Promise.all([
          readOptional(join(directory, "theme.env")),
          readOptional(join(directory, "ghostty.conf")),
          loadBackgrounds(directory),
        ]);
        const environment = parseThemeEnvironment(environmentText);
        const ghostty = parseGhosttyColours(ghosttyText);
        const selectedPath = backgroundState[entry.name] || environment.WALLPAPER || "";
        const selectedBackground = isSafeRelativePath(selectedPath)
          ? backgrounds.find((background) => background.relativePath === selectedPath)
          : undefined;

        return {
          accent:
            ghostty.accent === "#888888" ? borderColour(environment.BORDER_ACTIVE) || ghostty.accent : ghostty.accent,
          backgrounds,
          foreground: ghostty.foreground,
          isDark: environment.DARK_MODE !== "false",
          name: entry.name,
          selectedBackground: selectedBackground || backgrounds[0],
          title: titleFromName(entry.name),
        };
      }),
  );

  return {
    currentTheme: currentTheme.trim(),
    themes: themes.sort((left, right) => left.name.localeCompare(right.name)),
  };
}

function runThemeSwitcher(executable: string, arguments_: string[]): Promise<void> {
  return new Promise((resolve, reject) => {
    execFile(executable, arguments_, (error, stdout, stderr) => {
      if (!error) {
        resolve();
        return;
      }

      reject(new Error(stderr.trim() || stdout.trim() || error.message));
    });
  });
}

function errorMessage(error: unknown): string {
  return error instanceof Error ? error.message : String(error);
}

function wallpaperMarkdown(theme: Theme): string {
  if (!theme.selectedBackground) return "_No wallpaper is included with this theme._";
  const image = encodeURI(`file://${theme.selectedBackground.path}`);
  return `![${theme.selectedBackground.name}](${image}?raycast-width=720&raycast-height=405)`;
}

function BackgroundPicker(props: { executable: string; onApplied: () => Promise<void>; theme: Theme }) {
  const [selected, setSelected] = useState(props.theme.selectedBackground?.relativePath);

  async function applyBackground(background: Background) {
    const toast = await showToast({ style: Toast.Style.Animated, title: `Applying ${background.name}` });
    try {
      await runThemeSwitcher(props.executable, ["--background", props.theme.name, background.relativePath]);
      setSelected(background.relativePath);
      toast.style = Toast.Style.Success;
      toast.title = `${background.name} selected`;
      await props.onApplied();
    } catch (error) {
      toast.style = Toast.Style.Failure;
      toast.title = "Could not change the wallpaper";
      toast.message = errorMessage(error);
    }
  }

  return (
    <Grid columns={2} aspectRatio="16/9" fit={Grid.Fit.Fill} searchBarPlaceholder="Search wallpapers">
      {props.theme.backgrounds.map((background) => (
        <Grid.Item
          key={background.relativePath}
          title={background.name}
          content={{ source: background.path }}
          accessory={selected === background.relativePath ? { icon: Icon.CheckCircle, tooltip: "Selected" } : undefined}
          actions={
            <ActionPanel>
              <Action title="Use Wallpaper" icon={Icon.Image} onAction={() => applyBackground(background)} />
            </ActionPanel>
          }
        />
      ))}
    </Grid>
  );
}

export default function Command() {
  const preferences = getPreferenceValues<Preferences>();
  const themesDirectory = expandHome(preferences.themesDirectory);
  const executable = expandHome(preferences.themeSwitcherPath);
  const [state, setState] = useState<ThemeState>({ currentTheme: "", themes: [] });
  const [loadError, setLoadError] = useState<string>();
  const [isLoading, setIsLoading] = useState(true);

  const refresh = useCallback(async () => {
    setIsLoading(true);
    setLoadError(undefined);
    try {
      setState(await loadThemeState(themesDirectory));
    } catch (error) {
      setState({ currentTheme: "", themes: [] });
      setLoadError(errorMessage(error));
    } finally {
      setIsLoading(false);
    }
  }, [themesDirectory]);

  useEffect(() => {
    void refresh();
  }, [refresh]);

  async function applyTheme(theme: Theme) {
    const toast = await showToast({ style: Toast.Style.Animated, title: `Applying ${theme.title}` });
    try {
      await runThemeSwitcher(executable, [theme.name]);
      toast.style = Toast.Style.Success;
      toast.title = `${theme.title} applied`;
      await refresh();
    } catch (error) {
      toast.style = Toast.Style.Failure;
      toast.title = `Could not apply ${theme.title}`;
      toast.message = errorMessage(error);
    }
  }

  return (
    <List isLoading={isLoading} isShowingDetail searchBarPlaceholder="Search themes">
      <List.EmptyView
        icon={loadError ? Icon.Warning : Icon.Brush}
        title={loadError ? "Could Not Load Themes" : "No Themes Found"}
        description={loadError || `Add themes to ${themesDirectory}`}
        actions={
          <ActionPanel>
            <Action title="Refresh Themes" icon={Icon.ArrowClockwise} onAction={refresh} />
            <Action title="Open Extension Preferences" icon={Icon.Gear} onAction={openExtensionPreferences} />
          </ActionPanel>
        }
      />
      {state.themes.map((theme) => {
        const isCurrent = theme.name === state.currentTheme;
        return (
          <List.Item
            key={theme.name}
            icon={{ source: Icon.Circle, tintColor: theme.accent as Color }}
            title={theme.title}
            subtitle={theme.name}
            accessories={[
              ...(isCurrent ? [{ tag: { value: "active", color: Color.Green } }] : []),
              { icon: theme.isDark ? Icon.Moon : Icon.Sun },
              { text: `${theme.backgrounds.length} wallpaper${theme.backgrounds.length === 1 ? "" : "s"}` },
            ]}
            detail={
              <List.Item.Detail
                markdown={wallpaperMarkdown(theme)}
                metadata={
                  <List.Item.Detail.Metadata>
                    <List.Item.Detail.Metadata.Label title="Mode" text={theme.isDark ? "Dark" : "Light"} />
                    <List.Item.Detail.Metadata.Label title="Accent" text={theme.accent} />
                    <List.Item.Detail.Metadata.Label title="Text" text={theme.foreground} />
                  </List.Item.Detail.Metadata>
                }
              />
            }
            actions={
              <ActionPanel>
                <Action
                  title={isCurrent ? "Reapply Theme" : "Apply Theme"}
                  icon={Icon.Brush}
                  onAction={() => applyTheme(theme)}
                />
                {theme.backgrounds.length > 0 ? (
                  <Action.Push
                    title="Choose Wallpaper"
                    icon={Icon.Image}
                    shortcut={{ modifiers: ["cmd"], key: "b" }}
                    target={<BackgroundPicker executable={executable} theme={theme} onApplied={refresh} />}
                  />
                ) : null}
                <Action
                  title="Refresh Themes"
                  icon={Icon.ArrowClockwise}
                  shortcut={Keyboard.Shortcut.Common.Refresh}
                  onAction={refresh}
                />
                <Action title="Open Extension Preferences" icon={Icon.Gear} onAction={openExtensionPreferences} />
              </ActionPanel>
            }
          />
        );
      })}
    </List>
  );
}
