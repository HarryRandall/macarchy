/** The Menu Bar page part of the bridge contract; see `../protocol.ts`. */

export type BarZone = "left" | "centre" | "right";

/** Items made on the page; the bar's own items have no kind. */
export type BarItemKind = "text" | "spacer" | "command";

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
}

export interface MenuBarState {
  items: MenuBarItemState[];
  bar: MenuBarSettings;
  /** Why the bar could not be read, such as SketchyBar not running. */
  unavailableReason: string | null;
}

export interface MenuBarMethods {
  /** Reads the bar afresh from SketchyBar and the saved configuration. */
  "menuBar.getState": { params: Record<string, never>; result: MenuBarState };
  /**
   * Makes the bar match: the order and zones of `items`, each item's
   * visibility and the bar settings. Made items not listed are removed; the
   * bar's own items cannot be. Rejects when the change does not finish.
   */
  "menuBar.apply": {
    params: { items: MenuBarItemEdit[]; bar: MenuBarSettings };
    result: MenuBarState;
  };
}
