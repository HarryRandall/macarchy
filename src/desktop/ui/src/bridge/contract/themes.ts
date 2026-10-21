import type { ThemeSummary } from "./switcher";

export interface ThemeValues {
  dark: boolean;
  borderActive: string | null;
  borderInactive: string | null;
  sketchybarBar: string | null;
  sketchybarText: string | null;
  firefoxAccent: string | null;
  nvimColorscheme: string | null;
}
export type ThemeColour = Exclude<keyof ThemeValues, "dark" | "nvimColorscheme">;
export interface ThemeTerminal {
  background: string;
  foreground: string;
  cursor: string;
  ansi: string[];
}
export interface ThemeDetail {
  summary: ThemeSummary;
  values: ThemeValues;
  modified: boolean;
  hasDefault: boolean;
  defaultColourscheme: string;
  terminal: ThemeTerminal | null;
}
export interface ThemesState {
  themes: ThemeDetail[];
  current: string | null;
  colourschemes: string[];
  warnings: string[];
}
export interface ThemesMethods {
  "themes.getState": { params: Record<string, never>; result: ThemesState };
  "themes.setDark": { params: { theme: string; dark: boolean }; result: ThemesState };
  "themes.setColour": {
    params: { theme: string; colour: ThemeColour; value: string };
    result: ThemesState;
  };
  "themes.setColourscheme": {
    params: { theme: string; value: string | null };
    result: ThemesState;
  };
  "themes.reset": { params: { theme: string }; result: ThemesState };
  "themes.apply": { params: { theme: string }; result: ThemesState };
  "themes.chooseWallpaper": { params: { theme: string; path: string }; result: ThemesState };
  "themes.importFolder": { params: Record<string, never>; result: ThemesState };
  "themes.exportFolder": { params: { theme: string }; result: null };
  "themes.reveal": { params: { theme: string }; result: null };
}
