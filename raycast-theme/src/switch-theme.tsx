import {
  Action,
  ActionPanel,
  Color,
  Grid,
  Icon,
  Keyboard,
  List,
  Toast,
  closeMainWindow,
  getPreferenceValues,
  openExtensionPreferences,
  showToast,
} from "@raycast/api";
import { execFile } from "node:child_process";
import { readdir, readFile } from "node:fs/promises";
import { isAbsolute, join } from "node:path";
import { useCallback, useEffect, useState } from "react";
import { loadBackgrounds, type Background } from "./backgrounds";
import { DEFAULT_PATHS, resolvePreferencePath } from "./paths";
import { normaliseLegacyThemeName } from "./theme-utils";

type Preferences = {
  themeStateDirectory?: string;
  themeSwitcherPath?: string;
  themesDirectory?: string;
};

type Theme = {
  accent: string;
  backgrounds: Background[];
  foreground: string;
  isDark: boolean;
  name: string;
  palette: string[];
  selectedBackground?: Background;
  title: string;
};

type ThemeState = {
  currentTheme: string;
  themes: Theme[];
};

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

function parseGhosttyColours(contents: string): { accent: string; foreground: string; palette: string[] } {
  let accent = "#888888";
  let foreground = "#ffffff";
  const palette: string[] = [];

  for (const rawLine of contents.split("\n")) {
    const line = rawLine.trim();
    const foregroundMatch = line.match(/^foreground\s*=\s*(#[0-9a-f]{6})$/i);
    const paletteMatch = line.match(/^palette\s*=\s*(\d+)\s*=\s*(#[0-9a-f]{6})$/i);
    if (foregroundMatch) foreground = foregroundMatch[1];
    if (paletteMatch) palette[Number(paletteMatch[1])] = paletteMatch[2];
  }

  accent = palette[4] || accent;
  return { accent, foreground, palette };
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

async function loadThemeState(themesDirectory: string, themeStateDirectory: string): Promise<ThemeState> {
  let entries;
  try {
    entries = await readdir(themesDirectory, { withFileTypes: true });
  } catch (error) {
    const code = error instanceof Error && "code" in error ? error.code : undefined;
    if (code === "ENOENT") {
      throw new Error(
        `Themes directory was not found at ${themesDirectory}. Install the themes or update the extension preferences.`,
      );
    }
    if (code === "EACCES") {
      throw new Error(
        `Themes directory cannot be read at ${themesDirectory}. Check its permissions or update the extension preferences.`,
      );
    }
    throw error;
  }

  const [currentTheme, legacyCurrentTheme, backgroundStateText, legacyBackgroundStateText] = await Promise.all([
    readOptional(join(themeStateDirectory, "current")),
    readOptional(join(themesDirectory, ".current")),
    readOptional(join(themeStateDirectory, "backgrounds.json")),
    readOptional(join(themesDirectory, ".backgrounds.json")),
  ]);

  // Keep existing installations useful until a theme is next applied and its
  // state is migrated out of the theme pack.
  const selectedTheme = currentTheme || legacyCurrentTheme;
  const selectedBackgroundState = backgroundStateText || legacyBackgroundStateText;
  let backgroundState: Record<string, string> = {};
  if (selectedBackgroundState) {
    try {
      const parsed: unknown = JSON.parse(selectedBackgroundState);
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
          palette: ghostty.palette,
          selectedBackground: selectedBackground || backgrounds[0],
          title: titleFromName(entry.name),
        };
      }),
  );

  return {
    currentTheme: normaliseLegacyThemeName(selectedTheme, themes),
    themes: themes.sort((left, right) => left.name.localeCompare(right.name)),
  };
}

function runThemeSwitcher(
  executable: string,
  arguments_: string[],
  themesDirectory: string,
  themeStateDirectory: string,
): Promise<void> {
  return new Promise((resolve, reject) => {
    execFile(
      executable,
      arguments_,
      {
        env: {
          ...process.env,
          MACARCHY_THEMES_DIR: themesDirectory,
          MACARCHY_THEME_RUNTIME_DIR: themeStateDirectory,
        },
      },
      (error, stdout, stderr) => {
        if (!error) {
          resolve();
          return;
        }

        if ("code" in error && error.code === "ENOENT") {
          reject(
            new Error(`Theme switcher was not found at ${executable}. Install it or update the extension preferences.`),
          );
          return;
        }
        if ("code" in error && error.code === "EACCES") {
          reject(new Error(`Theme switcher is not executable at ${executable}. Check its permissions.`));
          return;
        }

        reject(new Error(stderr.trim() || stdout.trim() || error.message));
      },
    );
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

function themeMarkdown(theme: Theme): string {
  return [
    `# ${theme.title}`,
    "",
    wallpaperMarkdown(theme),
    "",
    theme.selectedBackground ? `Background \`${theme.selectedBackground.name}\`` : "",
    `Accent \`${theme.accent}\``,
    "macOS Accent `Multicolour`",
    "Highlight `System`",
    `Text \`${theme.foreground}\``,
  ].join("\n");
}

function lsPreviewColours(theme: Theme) {
  return {
    archive: theme.palette[1] || theme.accent,
    device: theme.palette[3] || theme.accent,
    directory: theme.palette[4] || theme.accent,
    executable: theme.palette[2] || theme.accent,
    normal: theme.foreground,
    symlink: theme.palette[6] || theme.accent,
  };
}

function BackgroundPicker(props: {
  executable: string;
  onApplied: () => Promise<void>;
  theme: Theme;
  themesDirectory: string;
  themeStateDirectory: string;
}) {
  const [selected, setSelected] = useState(props.theme.selectedBackground?.relativePath);
  const backgrounds = selected
    ? [
        ...props.theme.backgrounds.filter((background) => background.relativePath === selected),
        ...props.theme.backgrounds.filter((background) => background.relativePath !== selected),
      ]
    : props.theme.backgrounds;

  async function applyBackground(background: Background) {
    const toast = await showToast({ style: Toast.Style.Animated, title: `Applying ${background.name}` });
    try {
      await runThemeSwitcher(
        props.executable,
        ["--background", props.theme.name, background.relativePath],
        props.themesDirectory,
        props.themeStateDirectory,
      );
      setSelected(background.relativePath);
      toast.style = Toast.Style.Success;
      toast.title = `${background.name} selected`;
      await props.onApplied();
      await closeMainWindow();
    } catch (error) {
      toast.style = Toast.Style.Failure;
      toast.title = "Could not change the wallpaper";
      toast.message = errorMessage(error);
    }
  }

  return (
    <Grid
      columns={2}
      inset={Grid.Inset.Small}
      aspectRatio="16/9"
      fit={Grid.Fit.Fill}
      navigationTitle={`Switch Background (${props.theme.title})`}
      searchBarPlaceholder="Search backgrounds..."
    >
      {backgrounds.map((background) => (
        <Grid.Item
          key={background.relativePath}
          title={background.name}
          content={{ source: background.path }}
          accessory={selected === background.relativePath ? { icon: Icon.CheckCircle, tooltip: "Current" } : undefined}
          actions={
            <ActionPanel>
              <Action title="Use Background" icon={Icon.Image} onAction={() => applyBackground(background)} />
            </ActionPanel>
          }
        />
      ))}
    </Grid>
  );
}

export default function Command() {
  const preferences = getPreferenceValues<Preferences>();
  const themesDirectory = resolvePreferencePath(preferences.themesDirectory, DEFAULT_PATHS.themesDirectory);
  const themeStateDirectory = resolvePreferencePath(preferences.themeStateDirectory, DEFAULT_PATHS.themeStateDirectory);
  const executable = resolvePreferencePath(preferences.themeSwitcherPath, DEFAULT_PATHS.themeSwitcherPath);
  const [state, setState] = useState<ThemeState>({ currentTheme: "", themes: [] });
  const [loadError, setLoadError] = useState<string>();
  const [isLoading, setIsLoading] = useState(true);

  const refresh = useCallback(async () => {
    setIsLoading(true);
    setLoadError(undefined);
    try {
      setState(await loadThemeState(themesDirectory, themeStateDirectory));
    } catch (error) {
      setState({ currentTheme: "", themes: [] });
      setLoadError(errorMessage(error));
    } finally {
      setIsLoading(false);
    }
  }, [themesDirectory, themeStateDirectory]);

  useEffect(() => {
    void refresh();
  }, [refresh]);

  async function applyTheme(theme: Theme) {
    const toast = await showToast({ style: Toast.Style.Animated, title: `Applying ${theme.title}` });
    try {
      await runThemeSwitcher(executable, [theme.name], themesDirectory, themeStateDirectory);
      toast.style = Toast.Style.Success;
      toast.title = `${theme.title} applied`;
      await refresh();
      await closeMainWindow();
    } catch (error) {
      toast.style = Toast.Style.Failure;
      toast.title = `Could not apply ${theme.title}`;
      toast.message = errorMessage(error);
    }
  }

  const activeTheme = state.themes.find((theme) => theme.name === state.currentTheme) || state.themes[0];

  return (
    <List isLoading={isLoading} isShowingDetail searchBarPlaceholder="Search themes...">
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
      {activeTheme ? (
        <List.Item
          title="Switch Background"
          subtitle={activeTheme.title}
          icon={Icon.AppWindowGrid2x2}
          accessories={[{ text: `${activeTheme.backgrounds.length} options` }]}
          detail={<List.Item.Detail markdown={wallpaperMarkdown(activeTheme)} />}
          actions={
            <ActionPanel>
              <Action.Push
                title="Open Backgrounds"
                icon={Icon.Folder}
                target={
                  <BackgroundPicker
                    executable={executable}
                    theme={activeTheme}
                    themesDirectory={themesDirectory}
                    themeStateDirectory={themeStateDirectory}
                    onApplied={refresh}
                  />
                }
              />
            </ActionPanel>
          }
        />
      ) : null}
      {state.themes.map((theme) => {
        const isCurrent = theme.name === state.currentTheme;
        return (
          <List.Item
            key={theme.name}
            icon={{ source: Icon.Circle, tintColor: theme.accent as Color }}
            title={theme.title}
            accessories={[
              ...(isCurrent ? [{ tag: { value: "active", color: Color.Green } }] : []),
              { icon: theme.isDark ? Icon.Moon : Icon.Sun },
              ...(theme.backgrounds.length > 0 ? [{ text: `${theme.backgrounds.length} bg` }] : []),
            ]}
            detail={
              <List.Item.Detail
                markdown={themeMarkdown(theme)}
                metadata={
                  <List.Item.Detail.Metadata>
                    <List.Item.Detail.Metadata.Label title="Mode" text={theme.isDark ? "Dark" : "Light"} />
                    <List.Item.Detail.Metadata.Separator />
                    <List.Item.Detail.Metadata.Label title="Wallpapers" text={String(theme.backgrounds.length)} />
                    <List.Item.Detail.Metadata.Separator />
                    <List.Item.Detail.Metadata.Label title="macOS Accent" text="Multicolour" />
                    <List.Item.Detail.Metadata.Label title="Highlight" text="System" />
                    <List.Item.Detail.Metadata.Separator />
                    <List.Item.Detail.Metadata.TagList title="ls -la">
                      <List.Item.Detail.Metadata.TagList.Item text="dir/" color={lsPreviewColours(theme).directory} />
                      <List.Item.Detail.Metadata.TagList.Item text="link@" color={lsPreviewColours(theme).symlink} />
                      <List.Item.Detail.Metadata.TagList.Item text="exec*" color={lsPreviewColours(theme).executable} />
                      <List.Item.Detail.Metadata.TagList.Item text="archive" color={lsPreviewColours(theme).archive} />
                      <List.Item.Detail.Metadata.TagList.Item text="device" color={lsPreviewColours(theme).device} />
                      <List.Item.Detail.Metadata.TagList.Item text="file" color={lsPreviewColours(theme).normal} />
                    </List.Item.Detail.Metadata.TagList>
                  </List.Item.Detail.Metadata>
                }
              />
            }
            actions={
              <ActionPanel>
                <Action title="Apply Theme" icon={Icon.Brush} onAction={() => applyTheme(theme)} />
                {theme.backgrounds.length > 0 ? (
                  <Action.Push
                    title="Switch Background"
                    icon={Icon.Folder}
                    shortcut={{ modifiers: ["cmd"], key: "b" }}
                    target={
                      <BackgroundPicker
                        executable={executable}
                        theme={theme}
                        themesDirectory={themesDirectory}
                        themeStateDirectory={themeStateDirectory}
                        onApplied={refresh}
                      />
                    }
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
