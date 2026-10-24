export interface ShortcutBinding {
  id: number;
  modifiers: string[];
  key: string;
  caps: string[];
  command: string;
  section: string | null;
  passthrough: boolean;
  appOverrides: { app: string; command: string }[];
  /** The modes named before `<`; empty for skhd's default mode. */
  modes: string[];
  /** The mode a `; mode` binding switches to; it runs no command. */
  activatesMode: string | null;
  /** Commented out by Disable; skhd does not see it until it is enabled. */
  disabled: boolean;
}
export interface ShortcutChord {
  modifiers: string[];
  key: string;
}
export interface ShortcutsState {
  revision: string;
  bindings: ShortcutBinding[];
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
  "shortcuts.enable": {
    params: { id: number; revision: string };
    result: ShortcutMutation;
  };
  "shortcuts.reset": { params: { revision: string }; result: ShortcutMutation };
  "shortcuts.openConfiguration": { params: Record<string, never>; result: null };
}
export type ShortcutsEvent =
  | { type: "shortcuts.changed"; state: ShortcutsState }
  | { type: "shortcuts.unavailable"; state: string };
