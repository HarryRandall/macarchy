/**
 * The mock host's menu bar, for `pnpm dev` in a browser: Macarchy's bundled
 * items with sample readings. Applying keeps the list and fills in readings.
 */
import type { MenuBarItemEdit, MenuBarSettings, MenuBarState } from "~/bridge/protocol";

const builtIn = (
  id: string,
  title: string,
  zone: "left" | "right",
  reading: string,
): MenuBarState["items"][number] => ({
  id,
  title,
  zone,
  visible: true,
  kind: null,
  text: "",
  icon: "",
  command: null,
  interval: null,
  reading,
});

export function createMenuBarMock(options: { stopped: boolean }) {
  let state: MenuBarState = {
    items: [
      builtIn("workspaces", "Workspaces", "left", ""),
      builtIn("front_app", "Front App", "left", "Ghostty"),
      builtIn("cpu", "CPU", "right", "12%"),
      builtIn("memory", "Memory", "right", "61%"),
      builtIn("battery", "Battery", "right", "84%"),
      builtIn("calendar", "Clock", "right", "Thu 23 Oct 17:24"),
    ],
    bar: { height: 35, position: "top", padding: 10 },
    unavailableReason: options.stopped ? "sketchybar is not running." : null,
  };
  const readings = new Map(state.items.map((item) => [item.id, item.reading]));

  return {
    getState: () => state,
    apply(items: MenuBarItemEdit[], bar: MenuBarSettings): MenuBarState {
      state = {
        ...state,
        bar,
        items: items.map((item) => ({
          ...item,
          reading:
            item.kind === "command" ? `$ ${item.command ?? ""}` : (readings.get(item.id) ?? ""),
        })),
      };
      return state;
    },
  };
}
