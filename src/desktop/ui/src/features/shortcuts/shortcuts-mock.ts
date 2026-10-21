import type {
  BridgeEvent,
  BridgeMethods,
  ShortcutChord,
  ShortcutsMethods,
  ShortcutsState,
} from "~/bridge/protocol";

type Handlers = {
  [M in keyof ShortcutsMethods]: (params: BridgeMethods[M]["params"]) => BridgeMethods[M]["result"];
};

function caps(chord: ShortcutChord) {
  const symbols: Record<string, string> = {
    ctrl: "⌃",
    alt: "⌥",
    shift: "⇧",
    cmd: "⌘",
    return: "↩",
  };
  return [...chord.modifiers, chord.key].map((key) => symbols[key] ?? key.toUpperCase());
}

/** Browser development only. Native validation remains authoritative in the app. */
export function shortcutsMock(
  deliver: (event: BridgeEvent) => void,
  failures: Set<string>,
): Handlers {
  const original: ShortcutsState = {
    revision: "mock-1",
    bindings: [
      {
        id: 1,
        modifiers: ["ctrl", "alt"],
        key: "return",
        caps: ["⌃", "⌥", "↩"],
        section: "Open a terminal",
        command: "open -na Ghostty",
        passthrough: false,
        appOverrides: [],
      },
      {
        id: 3,
        modifiers: ["ctrl", "alt"],
        key: "h",
        caps: ["⌃", "⌥", "H"],
        section: "Focus windows",
        command: "yabai -m window --focus west",
        passthrough: false,
        appOverrides: [],
      },
      {
        id: 4,
        modifiers: ["ctrl", "alt"],
        key: "l",
        caps: ["⌃", "⌥", "L"],
        section: "Focus windows",
        command: "yabai -m window --focus east",
        passthrough: false,
        appOverrides: [],
      },
    ],
  };
  let state = structuredClone(original);
  let revisionCounter = 1;
  function apply(expected: string, update: () => void) {
    if (failures.has("shortcuts")) throw new Error("The configuration could not be saved.");
    if (expected !== state.revision)
      throw new Error("skhdrc changed since it was read. Refresh shortcuts and try again.");
    update();
    state = { ...state, revision: `mock-${++revisionCounter}` };
    deliver({ type: "shortcuts.changed", state });
    return { state, warning: "" };
  }
  return {
    "shortcuts.getState": () => {
      if (failures.has("shortcuts-state")) throw new Error("Your shortcuts could not be read.");
      return state;
    },
    "shortcuts.validate": ({ id, chord }) => ({
      spec: `${chord.modifiers.join(" + ")} - ${chord.key}`,
      caps: caps(chord),
      conflicts: state.bindings
        .filter(
          (binding) =>
            binding.id !== id &&
            binding.key === chord.key &&
            binding.modifiers.toSorted().join() === chord.modifiers.toSorted().join(),
        )
        .map((binding) => binding.id),
    }),
    "shortcuts.rebind": ({ id, chord, revision }) =>
      apply(revision, () => {
        state = {
          ...state,
          bindings: state.bindings.map((binding) =>
            binding.id === id ? { ...binding, ...chord, caps: caps(chord) } : binding,
          ),
        };
      }),
    "shortcuts.disable": ({ id, revision }) =>
      apply(revision, () => {
        state = { ...state, bindings: state.bindings.filter((binding) => binding.id !== id) };
      }),
    "shortcuts.reset": ({ revision }) =>
      apply(revision, () => {
        state = structuredClone(original);
      }),
    "shortcuts.openConfiguration": () => null,
  };
}
