export interface ShortcutBinding {
  id: number;
  modifiers: string[];
  key: string;
  caps: string[];
  command: string;
  section: string | null;
  passthrough: boolean;
  appOverrides: { app: string; command: string }[];
}
export interface ShortcutChord {
  modifiers: string[];
  key: string;
}
export interface ShortcutsState {
  revision: string;
  bindings: ShortcutBinding[];
  /** The desktops (Spaces) yabai lists now, or null when yabai is not running. */
  desktops: number | null;
}
export interface ShortcutValidation {
  spec: string;
  caps: string[];
  conflicts: number[];
}
export interface ShortcutMutation {
  state: ShortcutsState;
  warning: string;
}
export interface ShortcutsMethods {
  "shortcuts.getState": { params: Record<string, never>; result: ShortcutsState };
  "shortcuts.validate": {
    params: { id: number; chord: ShortcutChord };
    result: ShortcutValidation;
  };
  "shortcuts.rebind": {
    params: { id: number; revision: string; chord: ShortcutChord };
    result: ShortcutMutation;
  };
  "shortcuts.disable": {
    params: { id: number; revision: string };
    result: ShortcutMutation;
  };
  "shortcuts.reset": { params: { revision: string }; result: ShortcutMutation };
  "shortcuts.openConfiguration": { params: Record<string, never>; result: null };
}
export type ShortcutsEvent =
  | { type: "shortcuts.changed"; state: ShortcutsState }
  | { type: "shortcuts.unavailable"; state: string };
