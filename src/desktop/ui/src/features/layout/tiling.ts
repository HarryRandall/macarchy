import type { LayoutValues, SplitType, WindowPlacement } from "~/bridge/protocol";

/** A window's box as fractions of the tiling area, 0 to 1. */
export interface TileRect {
  x: number;
  y: number;
  width: number;
  height: number;
}

export type Monitor = "landscape" | "portrait";

/**
 * Whether the first split puts windows side by side. Automatic splits along
 * the longer edge, as yabai does for a fresh space.
 */
export function splitsSideBySide(split: SplitType, monitor: Monitor): boolean {
  return split === "vertical" || (split === "auto" && monitor === "landscape");
}

/**
 * BSP as yabai grows it from the first window: each new window halves the
 * newest one, alternating direction. With `second_child` the newer half is
 * right or below; with `first_child` it is left or above.
 */
export function bspRects(
  count: number,
  sideBySide: boolean,
  placement: WindowPlacement,
): TileRect[] {
  const rects: TileRect[] = [];
  let area: TileRect = { x: 0, y: 0, width: 1, height: 1 };
  let across = sideBySide;
  for (let index = 0; index < count; index++) {
    if (index === count - 1) {
      rects.push(area);
      break;
    }
    const half = across ? { ...area, width: area.width / 2 } : { ...area, height: area.height / 2 };
    const rest = across
      ? { ...half, x: area.x + half.width }
      : { ...half, y: area.y + half.height };
    const [kept, next] = placement === "second_child" ? [half, rest] : [rest, half];
    rects.push(kept);
    area = next;
    across = !across;
  }
  return rects;
}

export function splitHint(split: SplitType, monitor: Monitor): string {
  const direction = splitsSideBySide(split, monitor) ? "Side by side" : "Above and below";
  return split === "auto" ? `${direction} on this ${monitor} monitor` : direction;
}

/** The keys yabai and settings.json share for what this page edits. */
export function savedValueLines(values: LayoutValues): string[] {
  return [
    `"layout": "${values.layout}",`,
    `"split_type": "${values.splitType}",`,
    `"window_placement": "${values.windowPlacement}",`,
    `"auto_balance": ${values.autoBalance},`,
    `"window_gap": ${values.windowGap},`,
    `"top_padding": ${values.padding},`,
    `"mouse_modifier": "${values.mouseModifier}",`,
    `"mouse_drop_action": "${values.mouseDropAction}",`,
    `"mouse_follows_focus": ${values.mouseFollowsFocus}`,
  ];
}
