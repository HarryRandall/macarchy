/** The Menu Bar page part of the bridge contract; see `../protocol.ts`. */

export type BarZone = "left" | "centre" | "right";

/** Items made on the page, and widgets; the bar's own items have no kind. */
export type BarItemKind = "text" | "spacer" | "command" | "widget";

/** A widget setting's value, as `widget.json` writes it. */
export type SettingValue = string | number | boolean;

/**
 * How a widget is drawn. On a widget it is the widget's own; on a bar item
 * it holds only the fields the person changed. Fields left out are unset.
 */
export interface WidgetStyle {
  box?: "none" | "outline" | "fill";
  /** Points, 8 to 24. */
  size?: number;
  showIcon?: boolean;
  /** `text`, `accent`, `muted` or a `#rrggbb` colour. */
  iconColour?: string;
  textColour?: string;
  /** Points, 0 to 20. */
  radius?: number;
  /** Points, 0 to 40. */
  paddingLeft?: number;
  paddingRight?: number;
  /** 2 stacks the label's two lines beside the icon. */
  lines?: 1 | 2;
  /** Draws a row of up to this many items, as Spaces draws one per Space. */
  row?: number;
}

export type WidgetRowType =
  | "heading"
  | "text"
  | "reading"
  | "action"
  | "toggle"
  | "choice"
  | "graph"
  | "mirror"
  | "map"
  | "status"
  | "cores"
  | "apps"
  | "divider";

/** One row of a widget's dropdown. Labels and values take `{readings}`. */
export interface WidgetMenuRow {
  type: WidgetRowType;
  label?: string;
  value?: string;
  /** A command an action runs, as the person. */
  run?: string;
  /** An app name or URL an action opens. */
  open?: string;
  /** The setting a toggle or choice changes. */
  setting?: string;
  options?: string[];
  /** SF Symbol names, one per option. */
  icons?: string[];
  /** For a graph: the reading drawn large in its corner, which makes it a card. */
  current?: string;
  /** For a graph: `accent`, `temperature` or a hex colour; a mirror or map takes one per part, split by `|`. */
  colour?: string;
  /** For a graph, mirror or map: what its numbers are in, such as `%`, `°`, `W` or `GB`. */
  unit?: string;
  /** A reading that has to be filled in, and not `false` or `0`, for the row to show. */
  when?: string;
  /** For a graph or map: the bottom and top of its scale, as readings. */
  min?: string;
  max?: string;
  /** For a map: how many blocks it is drawn with. */
  cells?: number;
}

/** What a click does: one of the three. */
export interface WidgetClick {
  open?: string;
  run?: string;
  dropdown?: WidgetMenuRow[];
}

export interface WidgetUpdate {
  /** Such as `2s`, `5m`, `second` or `minute`. */
  every?: string;
  events?: string[];
}

export interface WidgetSettingInfo {
  /** The name a bar item's `settings` uses. */
  key: string;
  type: "text" | "number" | "toggle" | "choice" | "colour" | "format";
  label: string;
  default?: SettingValue;
  options?: string[];
  min?: number;
  max?: number;
  step?: number;
  unit?: string;
  hint?: string;
}

/** A widget that can go on the bar. Fields its `widget.json` leaves out are left out. */
export interface WidgetInfo {
  id: string;
  name: string;
  description?: string;
  author?: string;
  version: string;
  /** A glyph drawn before the label. */
  icon?: string;
  origin: "builtIn" | "user";
  /** Whether anything in it runs a command as the person. */
  scripted: boolean;
  /** Its folder, with the home folder as `~`. */
  folder: string;
  /** The files in its folder, by name. */
  files: string[];
  /** `widget.json` as written. */
  manifest: string;
  /** What the bar shows, with readings and settings in braces. */
  label?: string;
  /** A reading Macarchy provides, such as `date`. */
  source?: string;
  /** A script in the folder that prints the label. */
  provider?: string;
  /** In the order `widget.json` writes them. */
  settings: WidgetSettingInfo[];
  style?: WidgetStyle;
  click?: WidgetClick;
  update?: WidgetUpdate;
  samples?: { widest?: string; unavailable?: string };
}

export interface MenuBarItemState {
  /** A SketchyBar component id; new items are `macarchy.` and a lower-case suffix. */
  id: string;
  title: string;
  zone: BarZone;
  visible: boolean;
  kind: BarItemKind | null;
  /** What a text item shows. */
  text: string;
  /** A glyph shown before a made item's label. */
  icon: string;
  /** What a command item runs through `sh`; its output becomes the label. */
  command: string | null;
  /** Seconds between runs of `command`, 1 to 86400. */
  interval: number | null;
  /** The widget a widget item shows. */
  widget: string | null;
  /** A widget item's settings that differ from the widget's defaults. */
  settings: Record<string, SettingValue>;
  /** A widget item's changes to the widget's look. */
  style: WidgetStyle | null;
  /** What clicking a widget item does instead of what the widget says. */
  click: WidgetClick | null;
  /** What the item shows on the bar now, for the preview. */
  reading: string;
}

export type MenuBarItemEdit = Omit<MenuBarItemState, "reading">;

export interface MenuBarSettings {
  /** Points, 16 to 64. */
  height: number;
  position: "top" | "bottom";
  /** Points at each end of the bar, 0 to 64. */
  padding: number;
  /** Whether the page offers the centre zone, for displays without a notch. */
  centre: boolean;
  widgetGap?: number;
  widgetInset?: number;
  widgetHeight?: number;
  offset?: number;
}

export interface MenuBarState {
  items: MenuBarItemState[];
  bar: MenuBarSettings;
  /** Every widget that can go on the bar, built-in and the person's own. */
  widgets: WidgetInfo[];
  /** Widget folders that could not be read, by folder name, with what is wrong. */
  widgetProblems: { folder: string; problems: string[] }[];
  /** Why the bar could not be read, such as SketchyBar not running. */
  unavailableReason: string | null;
}

export type MenuBarEvent = { type: "menuBar.changed" };

export interface MenuBarMethods {
  "menuBar.previewWidget": {
    params: { widget: string; settings: Record<string, SettingValue> };
    result: string;
  };
  /** Reads the bar afresh from SketchyBar and the saved configuration. */
  "menuBar.getState": { params: Record<string, never>; result: MenuBarState };
  /**
   * Makes the bar match: the order and zones of `items`, each item's
   * visibility, widget items' widget, settings and edits, and the bar settings.
   * Made items and widgets not listed are removed; the bar's own items
   * cannot be. Rejects when the change does not finish, or a widget item's
   * edits do not suit its widget.
   */
  "menuBar.apply": {
    params: { items: MenuBarItemEdit[]; bar: MenuBarSettings };
    result: MenuBarState;
  };
  /** Shows a widget's folder in Finder, or with null the folder of the person's own. */
  "menuBar.revealWidget": { params: { widget: string | null }; result: null };
  /** Opens one of a widget's files in the text editor. */
  "menuBar.openWidgetFile": { params: { widget: string; file: string }; result: null };
  /** Copies a widget into the person's own to edit, and returns the copy's id. */
  "menuBar.duplicateWidget": {
    params: { widget: string };
    result: { state: MenuBarState; widget: string };
  };
}
