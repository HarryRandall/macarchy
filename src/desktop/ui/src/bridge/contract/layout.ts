/** The Layout page part of the bridge contract; see `../protocol.ts`. */

export type LayoutMode = "bsp" | "stack" | "float";
export type SplitType = "auto" | "vertical" | "horizontal";
export type WindowPlacement = "second_child" | "first_child";
export type MouseModifier = "ctrl" | "alt" | "cmd" | "shift";
export type MouseDropAction = "stack" | "swap";

export interface LayoutValues {
  layout: LayoutMode;
  splitType: SplitType;
  windowPlacement: WindowPlacement;
  autoBalance: boolean;
  /** Points between windows, 0 to 32. */
  windowGap: number;
  /** Points at the top screen edge, 0 to 40. */
  padding: number;
  mouseModifier: MouseModifier;
  mouseFollowsFocus: boolean;
  mouseDropAction: MouseDropAction;
}

export interface LayoutState {
  values: LayoutValues;
  /**
   * `daemon`: read from the running yabai. `saved`: yabai could not be
   * reached, so these are the saved preferences and edits cannot apply.
   */
  source: "daemon" | "saved";
  /** A sentence to show when `source` is `saved`. */
  unavailableReason: string | null;
  /** Image URL for the illustrative preview, or null for a plain well. */
  wallpaper: string | null;
}

export interface LayoutApplyParams {
  changes: Partial<LayoutValues>;
  /** When true a padding change sets every screen edge, otherwise only the top. */
  linkPadding: boolean;
}

export interface LayoutMethods {
  "layout.getState": { params: Record<string, never>; result: LayoutState };
  /** Applies to yabai, then saves. Rejects with `operation_failed` if either fails. */
  "layout.apply": { params: LayoutApplyParams; result: null };
}

/** Layout changed somewhere else: the CLI, a reload. */
export type LayoutEvent = { type: "layout.changed"; state: LayoutState };
