import type { SwitcherState, ThemesMethods, ThemesState, ThemeValues } from "~/bridge/protocol";

/** Browser-only theme data. Native folder panels are represented by cancellation. */
export function createThemesMock(switcher: () => SwitcherState) {
  const values = new Map<string, ThemeValues>();
  function state(): ThemesState {
    const source = switcher();
    return {
      current: source.current,
      colourschemes: ["habamax", "catppuccin"],
      warnings: [],
      themes: source.themes.map((summary) => ({
        summary,
        values: values.get(summary.name) ?? {
          dark: summary.isDark,
          borderActive: summary.ring,
          borderInactive: null,
          sketchybarBar: null,
          sketchybarText: null,
          firefoxAccent: null,
          nvimColorscheme: null,
        },
        modified: values.has(summary.name),
        hasDefault: true,
        defaultColourscheme: "habamax",
        terminal: summary.colours
          ? {
              ...summary.colours,
              cursor: summary.colours.foreground,
              ansi: Array.from(
                { length: 16 },
                (_, index) =>
                  [
                    summary.colours!.foreground,
                    summary.colours!.red,
                    summary.colours!.green,
                    summary.ring,
                  ][index % 4]!,
              ),
            }
          : null,
      })),
    };
  }
  function edit(name: string, patch: Partial<ThemeValues>) {
    const theme = state().themes.find((entry) => entry.summary.name === name);
    if (theme) values.set(name, { ...theme.values, ...patch });
    return state();
  }
  const methods: {
    [M in keyof ThemesMethods]: (params: ThemesMethods[M]["params"]) => ThemesMethods[M]["result"];
  } = {
    "themes.getState": state,
    "themes.setDark": ({ theme, dark }) => edit(theme, { dark }),
    "themes.setColour": ({ theme, colour, value }) => edit(theme, { [colour]: value }),
    "themes.setColourscheme": ({ theme, value }) => edit(theme, { nvimColorscheme: value }),
    "themes.reset": ({ theme }) => {
      values.delete(theme);
      return state();
    },
    "themes.apply": ({ theme }) => {
      switcher().current = theme;
      return state();
    },
    "themes.chooseWallpaper": ({ theme, path }) => {
      const summary = switcher().themes.find((entry) => entry.name === theme);
      if (summary) {
        summary.currentBackground = path;
        summary.preview =
          summary.backgrounds.find((entry) => entry.path === path)?.thumbnail ?? null;
      }
      return state();
    },
    "themes.importFolder": state,
    "themes.exportFolder": () => null,
    "themes.reveal": () => null,
  };
  return methods;
}
