/** The activity log the browser mock host serves; see `mock.ts`. */
import type { LogEntry } from "./protocol";

type LogSeed = Omit<LogEntry, "id" | "at">;

/** The host keeps this many entries, dropping the oldest. */
export const logLimit = 200;

const seeds: LogSeed[] = [
  {
    command: "health check",
    detail: "18 checks completed",
    ok: true,
    status: null,
    category: "System",
  },
  {
    command: "/opt/homebrew/bin/yabai -m config window_gap 8",
    detail: "",
    ok: true,
    status: 0,
    category: "Layout",
  },
  {
    command: "/opt/homebrew/bin/yabai -m config layout bsp",
    detail: "",
    ok: true,
    status: 0,
    category: "Layout",
  },
  {
    command: "theme lumon",
    detail: "",
    ok: true,
    status: 0,
    category: "Themes",
  },
  {
    command: "/opt/homebrew/bin/sketchybar --reload",
    detail: "Standard error:\nsketchybar: could not find the configuration at ~/.config/sketchybar",
    ok: false,
    status: 1,
    category: "Menu Bar",
  },
  {
    command: "borders appearance",
    detail: "",
    ok: true,
    status: 0,
    category: "Borders",
  },
  {
    command: "window rules",
    detail: "",
    ok: true,
    status: 0,
    category: "Window Rules",
  },
  {
    command: "open skhdrc",
    detail: "~/Library/Application Support/Macarchy/config/skhdrc",
    ok: true,
    status: null,
    category: "Shortcuts",
  },
  {
    command: "/opt/homebrew/bin/skhd --reload",
    detail: "",
    ok: true,
    status: 0,
    category: "Shortcuts",
  },
  {
    command: "restore backup",
    detail: "Completed",
    ok: true,
    status: null,
    category: "Backups",
  },
  {
    command: "read layout",
    detail: "yabai-msg: failed to connect",
    ok: false,
    status: null,
    category: "Layout",
  },
  {
    command: "/bin/launchctl kickstart -k gui/501/com.koekeishiya.yabai",
    detail: "",
    ok: true,
    status: 0,
    category: "Layout",
  },
];

/**
 * A log seeded with a dozen entries spread over the last few minutes, oldest
 * first, as `shell.getLog` returns them. `changed` runs after every edit, as
 * the host sends `shell.logChanged`.
 */
export function createLogMock(now: () => number, changed: () => void) {
  let count = 0;
  function entry(seed: LogSeed, at: number): LogEntry {
    count += 1;
    return { ...seed, id: `mock-log-${count}`, at };
  }

  const start = now();
  let entries = seeds.map((seed, index) => entry(seed, start - (seeds.length - index) * 45));

  return {
    entries: (): LogEntry[] => entries,
    append(seed: LogSeed) {
      entries = [...entries, entry(seed, now())].slice(-logLimit);
      changed();
    },
    clear() {
      entries = [];
      changed();
    },
  };
}
