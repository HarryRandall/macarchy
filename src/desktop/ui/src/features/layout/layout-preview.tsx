import { useRef } from "react";

import type { LayoutMode } from "~/bridge/protocol";
import { cn } from "~/lib/cn";
import { useElementSize } from "~/lib/use-element-size";

const descriptions: Record<LayoutMode, string> = {
  bsp: "tiled",
  stack: "stacked",
  float: "freeform",
};

/**
 * An illustration of the desktop, not a live mirror. Gap and padding are
 * scaled from a 700 pt reference screen so small previews still show them.
 */
export function LayoutPreview({
  mode,
  gap,
  padding,
  wallpaper,
}: {
  mode: LayoutMode;
  gap: number;
  padding: number;
  wallpaper: string | null;
}) {
  const ref = useRef<HTMLDivElement>(null);
  const { width, height } = useElementSize(ref);
  const inset = Math.max(8, (padding * width) / 700);
  const spacing = Math.max(3, (gap * width) / 700);

  return (
    <div
      ref={ref}
      role="img"
      aria-label={`Illustrative ${descriptions[mode]} window layout`}
      className="relative size-full overflow-hidden rounded-[9px] bg-well"
    >
      {wallpaper ? (
        <img
          src={wallpaper}
          alt=""
          draggable={false}
          className="absolute inset-0 size-full object-cover"
        />
      ) : null}
      {width === 0 ? null : mode === "bsp" ? (
        <div className="absolute inset-0 flex" style={{ padding: inset, gap: spacing }}>
          <PreviewWindow title="Main" active className="flex-1" />
          <div
            className="flex shrink-0 flex-col"
            style={{ gap: spacing, width: Math.max(20, width * 0.35 - inset) }}
          >
            <PreviewWindow title="Notes" className="flex-1" />
            <PreviewWindow title="Browser" className="flex-1" />
          </div>
        </div>
      ) : (
        <div className="absolute inset-0 flex items-center justify-center">
          <div
            className="relative"
            style={{
              width: width * (mode === "stack" ? 0.8 : 0.58),
              height: height * 0.66,
            }}
          >
            <PreviewWindow
              title={mode === "stack" ? "" : "Notes"}
              className="absolute inset-0 translate-x-5 -translate-y-2.5"
            />
            <PreviewWindow
              title={mode === "stack" ? "Current window" : "Main"}
              active
              className="absolute inset-0 -translate-x-3 translate-y-2.5"
            />
          </div>
        </div>
      )}
    </div>
  );
}

function PreviewWindow({
  title,
  active = false,
  className,
}: {
  title: string;
  active?: boolean;
  className?: string;
}) {
  return (
    <div
      className={cn(
        "relative min-h-0 min-w-0 rounded-small bg-card/95 shadow-[0_2px_4px_rgb(0_0_0/0.12)]",
        active ? "border-2 border-accent-stroke" : "border border-hairline",
        className,
      )}
    >
      <div className="absolute top-[9px] left-[9px] flex gap-[3px]">
        <span className="size-1 rounded-full bg-fg-secondary/40" />
        <span className="size-1 rounded-full bg-fg-secondary/40" />
        <span className="size-1 rounded-full bg-fg-secondary/40" />
      </div>
      <span className="absolute inset-0 flex items-center justify-center text-[10px] font-medium text-fg-secondary">
        {title}
      </span>
    </div>
  );
}
