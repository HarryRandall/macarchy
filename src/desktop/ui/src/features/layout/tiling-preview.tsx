import { type CSSProperties, useState } from "react";

import type { LayoutMode, SplitType, WindowPlacement } from "~/bridge/protocol";
import { focusRing } from "~/components/ui/focus-ring";
import { cn } from "~/lib/cn";

import { bspRects, type Monitor, splitsSideBySide } from "./tiling";

const apps = ["Ghostty", "Safari", "Zed", "Notes"];
const workspaces = [1, 2, 3, 4, 5];
/** Points on the desktop to pixels in the preview, so real gaps stay legible. */
const scale = 0.8;

/**
 * A sketch of one display, redrawn from the page's values: not a mirror of
 * the real desktop. Clicking a window or a workspace only moves the sketch's
 * own focus.
 */
export function TilingPreview({
  mode,
  split,
  placement,
  gap,
  padding,
  monitor,
  windows,
}: {
  mode: LayoutMode;
  split: SplitType;
  placement: WindowPlacement;
  gap: number;
  padding: number;
  monitor: Monitor;
  windows: number;
}) {
  const [focus, setFocus] = useState(0);
  const [workspace, setWorkspace] = useState(1);
  const focused = Math.min(focus, windows - 1);
  const inset = padding * scale;
  const half = (gap * scale) / 2;

  const drawWindow = (index: number, style: CSSProperties, extra?: string) => {
    const on = index === focused;
    return (
      <button
        key={apps[index]}
        type="button"
        aria-label={apps[index]}
        aria-pressed={on}
        onClick={() => setFocus(index)}
        className={cn(
          "flex min-h-0 min-w-0 flex-col overflow-hidden rounded-[5px] border text-left transition-[left,top,right,bottom,width,height,flex-basis,border-color,background-color] duration-200 motion-reduce:transition-none",
          focusRing,
          on
            ? "border-accent bg-card shadow-[0_0_0_2px_var(--color-accent-soft)]"
            : "border-line-strong bg-card/80",
          extra,
        )}
        style={style}
      >
        <span
          className={cn(
            "flex h-4 shrink-0 items-center gap-1 border-b px-1.5 text-[8.5px] font-medium",
            on ? "border-accent/30 text-accent-text" : "border-hairline text-fg-tertiary",
          )}
        >
          <span className={cn("size-1 rounded-full", on ? "bg-accent" : "bg-fg-tertiary")} />
          {apps[index]}
        </span>
        <span className="flex flex-1 flex-col gap-1 p-1.5">
          {[70, 50, 60].map((width) => (
            <span
              key={width}
              className="h-[3px] rounded-full bg-fg-tertiary/40"
              style={{ width: `${width}%` }}
            />
          ))}
        </span>
      </button>
    );
  };

  const tiles = bspRects(windows, splitsSideBySide(split, monitor), placement);

  return (
    <div
      className="grid h-[248px] place-items-center bg-canvas p-4"
      style={{
        backgroundImage: "radial-gradient(var(--color-hairline) 1px, transparent 1px)",
        backgroundSize: "14px 14px",
      }}
    >
      <div
        role="group"
        aria-label="Layout preview"
        className="flex h-full flex-col overflow-hidden rounded-tile border border-line-strong bg-side shadow-card transition-[width] duration-300 motion-reduce:transition-none"
        style={{ width: monitor === "landscape" ? "100%" : 150 }}
      >
        <div className="flex h-5 shrink-0 items-center gap-0.5 border-b border-hairline bg-card px-1.5">
          {workspaces.map((number) => (
            <button
              key={number}
              type="button"
              aria-label={`Workspace ${number}`}
              aria-pressed={number === workspace}
              onClick={() => setWorkspace(number)}
              className={cn(
                "grid h-3 min-w-3 place-items-center rounded-[3px] px-0.5 text-[8px] font-semibold transition-colors",
                focusRing,
                number === workspace
                  ? "bg-accent text-accent-fg"
                  : "text-fg-tertiary hover:text-fg",
              )}
            >
              {number}
            </button>
          ))}
        </div>
        <div className="relative min-h-0 flex-1" style={{ padding: inset }}>
          <div
            aria-hidden
            className="pointer-events-none absolute rounded-[3px] border border-dashed border-accent/55 transition-all duration-200 motion-reduce:transition-none"
            style={{ inset: inset / 2, opacity: padding > 0 ? 1 : 0 }}
          />
          {mode === "bsp" ? (
            <div className="relative size-full">
              {/* Each tile pads half a gap and the box grows by as much, so gaps show only between neighbours. */}
              <div className="absolute" style={{ inset: -half }}>
                {tiles.map((rect, index) => (
                  <div
                    key={apps[index]}
                    className="absolute flex transition-all duration-200 motion-reduce:transition-none"
                    style={{
                      left: `${rect.x * 100}%`,
                      top: `${rect.y * 100}%`,
                      width: `${rect.width * 100}%`,
                      height: `${rect.height * 100}%`,
                      padding: half,
                    }}
                  >
                    {drawWindow(index, {}, "flex-1")}
                  </div>
                ))}
              </div>
            </div>
          ) : mode === "stack" ? (
            <div className="relative size-full">
              {Array.from({ length: windows }, (_, index) =>
                drawWindow(
                  index,
                  {
                    position: "absolute",
                    inset: 0,
                    top: index * 5,
                    zIndex: index === focused ? 10 : index,
                  },
                  index === focused ? undefined : "opacity-70",
                ),
              )}
            </div>
          ) : (
            <div className="relative size-full">
              {Array.from({ length: windows }, (_, index) =>
                drawWindow(
                  index,
                  {
                    position: "absolute",
                    left: `${6 + index * 12}%`,
                    top: `${6 + index * 11}%`,
                    width: monitor === "landscape" ? "48%" : "72%",
                    height: "52%",
                    zIndex: index === focused ? 10 : index,
                  },
                  "shadow-lg",
                ),
              )}
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
