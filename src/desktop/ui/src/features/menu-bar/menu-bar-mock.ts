/**
 * The mock host's menu bar, for `pnpm dev` in a browser: Macarchy's bundled
 * items and widgets with sample readings. Applying keeps the list and fills
 * in readings.
 */
import type {
  MenuBarItemEdit,
  MenuBarItemState,
  MenuBarSettings,
  MenuBarState,
  WidgetInfo,
} from "~/bridge/protocol";

const blank = {
  visible: true,
  text: "",
  icon: "",
  command: null,
  interval: null,
  widget: null,
  settings: {},
  style: null,
  click: null,
} satisfies Partial<MenuBarItemState>;

const builtIn = (
  id: string,
  title: string,
  zone: "left" | "right",
  reading: string,
): MenuBarItemState => ({ ...blank, id, title, zone, kind: null, reading });

const widgetItem = (widget: string, title: string, reading: string): MenuBarItemState => ({
  ...blank,
  id: `macarchy.${widget}`,
  title,
  zone: "right",
  kind: "widget",
  widget,
  reading,
});

const resources = "/Applications/Macarchy.app/Contents/Resources/widgets";

const manifest = (fields: object) => `${JSON.stringify({ schema: 1, ...fields }, null, 2)}\n`;

export const mockWidgets: WidgetInfo[] = [
  {
    id: "clock",
    name: "Clock",
    description: "The date and time, in any format, with a dropdown of other time zones.",
    author: "Macarchy",
    version: "1.0.0",
    icon: "􀧞",
    origin: "builtIn",
    scripted: false,
    folder: `${resources}/clock`,
    files: ["widget.json"],
    manifest: manifest({ id: "clock", name: "Clock", version: "1.0.0", source: "date" }),
    label: "{date}",
    source: "date",
    settings: [
      { key: "weekday", type: "toggle", label: "Weekday", default: true },
      { key: "day", type: "toggle", label: "Day", default: true },
      { key: "month", type: "toggle", label: "Month", default: true },
      { key: "year", type: "toggle", label: "Year", default: false },
      { key: "time", type: "toggle", label: "Time", default: true },
      { key: "twentyFourHour", type: "toggle", label: "24-hour clock", default: false },
      {
        key: "leadingZero",
        type: "toggle",
        label: "Leading zero",
        default: true,
        hint: "03:41 rather than 3:41",
      },
      {
        key: "seconds",
        type: "toggle",
        label: "Seconds",
        default: false,
        hint: "Updates every second instead of on the minute",
      },
      {
        key: "order",
        type: "choice",
        label: "Date order",
        options: ["day-month", "month-day"],
        default: "day-month",
      },
      {
        key: "timeZone",
        type: "text",
        label: "Time zone",
        default: "",
        hint: "Empty for this Mac's time zone, or a name such as Europe/London",
      },
      {
        key: "format",
        type: "format",
        label: "Format",
        default: "",
        hint: "strftime codes. Empty to build it from the options above",
      },
    ],
    style: { box: "none", size: 13 },
    update: { every: "minute", events: ["system_woke", "timezone_changed"] },
    click: {
      dropdown: [
        { type: "heading", label: "{weekday.long} {day} {month.long}" },
        { type: "reading", label: "Here", value: "{time}" },
        { type: "reading", label: "London", value: "{time:Europe/London}" },
        { type: "divider" },
        { type: "toggle", label: "24-hour clock", setting: "twentyFourHour" },
        { type: "action", label: "Open Calendar", open: "Calendar" },
      ],
    },
    samples: { widest: "Wed 30 Sep 12:59 PM", unavailable: "--" },
  },
  {
    id: "cpu",
    name: "CPU",
    description: "Load and temperature, stacked, with a graph of recent load.",
    author: "Macarchy",
    version: "1.0.0",
    icon: "􀫥",
    origin: "builtIn",
    scripted: false,
    folder: `${resources}/cpu`,
    files: ["widget.json"],
    manifest: manifest({ id: "cpu", name: "CPU", version: "1.0.0", source: "cpu" }),
    label: "{load}\n{temp}",
    source: "cpu",
    settings: [
      { key: "temperature", type: "toggle", label: "Temperature", default: true },
      {
        key: "warnAt",
        type: "number",
        label: "Warn at",
        default: 80,
        min: 50,
        max: 100,
        step: 5,
        unit: "%",
      },
    ],
    style: { box: "outline", lines: 2 },
    update: { every: "2s", events: ["system_woke"] },
    click: {
      dropdown: [
        { type: "heading", label: "CPU", value: "{load}" },
        { type: "graph", label: "Load", value: "12 18 9 30 22 14" },
        { type: "divider" },
        { type: "action", label: "Open Activity Monitor", open: "Activity Monitor" },
      ],
    },
    samples: { widest: "100.0%\n99.9°", unavailable: "--" },
  },
  {
    id: "battery",
    name: "Battery",
    description: "Charge, with a bolt while charging, and Energy Mode.",
    author: "Macarchy",
    version: "1.0.0",
    icon: "􀛨",
    origin: "builtIn",
    scripted: false,
    folder: `${resources}/battery`,
    files: ["widget.json"],
    manifest: manifest({ id: "battery", name: "Battery", version: "1.0.0", source: "battery" }),
    label: "{percent}",
    source: "battery",
    settings: [{ key: "percent", type: "toggle", label: "Show percentage", default: true }],
    style: { box: "none" },
    update: { every: "1m", events: ["power_source_changed", "system_woke"] },
    click: {
      dropdown: [
        { type: "heading", label: "Battery", value: "{percent}" },
        { type: "text", label: "Power Source: Battery" },
        { type: "divider" },
        {
          type: "action",
          label: "Battery Settings…",
          open: "x-apple.systempreferences:com.apple.Battery-Settings.extension",
        },
      ],
    },
    samples: { widest: "100%", unavailable: "--" },
  },
  {
    id: "spaces",
    name: "Spaces",
    description: "Your Spaces, each with the apps open on it. Click one to go there.",
    author: "Macarchy",
    version: "1.0.0",
    origin: "builtIn",
    scripted: false,
    folder: `${resources}/spaces`,
    files: ["app-icons.json", "widget.json"],
    manifest: manifest({ id: "spaces", name: "Spaces", version: "1.0.0", source: "spaces" }),
    source: "spaces",
    settings: [
      {
        key: "design",
        type: "choice",
        label: "Boxes",
        options: ["current", "every", "together", "none"],
        default: "current",
        hint: "A box around the current Space, every Space, all of them together, or none",
      },
      {
        key: "show",
        type: "choice",
        label: "Show",
        options: ["numbers-and-icons", "numbers", "icons"],
        default: "numbers-and-icons",
      },
      {
        key: "maxIcons",
        type: "number",
        label: "Most app icons",
        default: 0,
        min: 0,
        max: 10,
        step: 1,
        hint: "After this many, a Space shows how many more, such as +7. 0 shows them all",
      },
      { key: "hideEmpty", type: "toggle", label: "Hide empty Spaces", default: false },
      { key: "names", type: "text", label: "Names", default: "" },
      { key: "activeColour", type: "colour", label: "Current Space", default: "accent" },
      { key: "colour", type: "colour", label: "Other Spaces", default: "text" },
    ],
    style: { row: 10, size: 12, radius: 5 },
    update: {
      every: "10s",
      events: ["system_woke", "space_changed", "windows_changed", "display_changed"],
    },
    samples: { widest: "1 :safari: :code: :claude:", unavailable: "1 —" },
  },
  {
    id: "uptime",
    name: "Uptime",
    description: "How long since this Mac started.",
    author: "You",
    version: "0.1.0",
    origin: "user",
    scripted: true,
    folder: "~/.config/macarchy/widgets/uptime",
    files: ["provider.sh", "widget.json"],
    manifest: manifest({ id: "uptime", name: "Uptime", version: "0.1.0", provider: "provider.sh" }),
    provider: "provider.sh",
    settings: [],
    update: { every: "1m" },
    click: { run: "open -a Terminal" },
    samples: { widest: "up 99d 23h" },
  },
];

export function createMenuBarMock(options: { stopped: boolean }) {
  let widgets = mockWidgets;
  let state: MenuBarState = {
    items: [
      {
        ...widgetItem(
          "spaces",
          "Spaces",
          "1\t:firefox: :code:\t1\n2\t:claude:\t0\n3\t—\t0\n4\t:spotify: :slack: :notes: :mail:\t0",
        ),
        zone: "left",
      },
      builtIn("front_app", "Front App", "left", "Ghostty"),
      builtIn("memory", "Memory", "right", "61%"),
      widgetItem("cpu", "CPU", "12.0%\n52.4°"),
      widgetItem("battery", "Battery", "84%"),
      widgetItem("clock", "Clock", "Fri 23 Oct 3:41 PM"),
    ],
    bar: { height: 35, position: "top", padding: 10, centre: false },
    widgets,
    widgetProblems: [
      {
        folder: "weather",
        problems: ["Line 4: version should look like 1.0.0", "provider.sh is not executable"],
      },
    ],
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
    duplicate(id: string): { state: MenuBarState; widget: string } {
      const original = widgets.find((widget) => widget.id === id);
      if (!original) throw new Error(`There is no widget called ${id}.`);
      let copy = `${id}-copy`;
      for (let number = 2; widgets.some((widget) => widget.id === copy); number++) {
        copy = `${id}-copy-${number}`;
      }
      widgets = [
        ...widgets,
        {
          ...original,
          id: copy,
          name: `${original.name} copy`,
          origin: "user",
          folder: `~/.config/macarchy/widgets/${copy}`,
        },
      ];
      state = { ...state, widgets };
      return { state, widget: copy };
    },
  };
}
