import type { ComponentProps, ReactNode } from "react";

import { cn } from "~/lib/cn";

import { IconTile, type Tint } from "./icon-tile";

/**
 * One number, said plainly, with room for a trend underneath. Every tile is
 * the same height, and the detail band is reserved even when empty, so a row
 * of tiles reads as a row. A long value (a theme name, a relative date)
 * truncates rather than wrapping.
 */
function StatTile({
  icon,
  value,
  caption,
  tint = "accent",
  emphasis = false,
  detail,
  className,
  ...props
}: Omit<ComponentProps<"div">, "children"> & {
  /** A lucide glyph, drawn on a wash of `tint`. */
  icon: ReactNode;
  value: string;
  caption: string;
  tint?: Tint;
  /** The headline figures of a band get the larger size. */
  emphasis?: boolean;
  /** A strip under the value: a sparkline, a health strip, "8 installed". */
  detail?: ReactNode;
}) {
  return (
    <div
      data-slot="stat-tile"
      className={cn(
        "flex min-h-24 min-w-0 flex-col rounded-card border border-hairline bg-card p-3",
        className,
      )}
      {...props}
    >
      <div className="flex min-w-0 items-center gap-2">
        <IconTile tint={tint} size="sm">
          {icon}
        </IconTile>
        <p className="truncate text-meta text-fg-secondary">{caption}</p>
      </div>
      <p
        title={value}
        className={cn(
          "mt-auto truncate pt-1 text-fg tabular-nums",
          emphasis ? "text-hero-title" : "text-section-title",
        )}
      >
        {value}
      </p>
      <div className="flex min-h-[26px] items-end pt-1">{detail}</div>
    </div>
  );
}

export { StatTile };
