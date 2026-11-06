/**
 * The item a key moves roving focus to in a row of items such as tabs, or
 * undefined when the key does not move it. Arrows wrap at the ends and skip
 * disabled items; Home and End go to the first and last enabled item.
 */
export function rovingIndex(
  current: number,
  key: string,
  enabled: readonly boolean[],
  orientation: "horizontal" | "vertical" = "horizontal",
): number | undefined {
  const count = enabled.length;
  if (!enabled.some(Boolean)) return undefined;
  const back = orientation === "horizontal" ? "ArrowLeft" : "ArrowUp";
  const forward = orientation === "horizontal" ? "ArrowRight" : "ArrowDown";
  const scan = (start: number, step: 1 | -1) => {
    for (let offset = 0; offset < count; offset++) {
      const index = (((start + step * offset) % count) + count) % count;
      if (enabled[index]) return index;
    }
    return undefined;
  };
  if (key === "Home") return scan(0, 1);
  if (key === "End") return scan(count - 1, -1);
  if (key === forward) return scan(current + 1, 1);
  if (key === back) return scan(current - 1, -1);
  return undefined;
}
