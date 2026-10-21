import { type ComponentProps, type ReactNode, useLayoutEffect, useRef, useState } from "react";

import { cn } from "~/lib/cn";
import { observeResize } from "~/lib/observe-resize";

import { IconTile, type Tint } from "./icon-tile";
import { Tooltip } from "./tooltip";

/**
 * One number, said plainly, with room for a trend underneath. Every tile is
 * the same height, and the detail band is reserved even when empty, so a row
 * of tiles reads as a row. A long value (a theme name, a relative date)
 * truncates rather than wrapping, and shows in full in a tooltip.
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
      {/* Remounted per value: new text can overflow without the box resizing. */}
      <StatValue key={value} value={value} emphasis={emphasis} />
      <div className="flex min-h-[26px] items-end pt-1">{detail}</div>
    </div>
  );
}

function StatValue({ value, emphasis }: { value: string; emphasis: boolean }) {
  const ref = useRef<HTMLParagraphElement>(null);
  const [truncated, setTruncated] = useState(false);
  useLayoutEffect(() => {
    const element = ref.current;
    if (!element) return;
    const measure = () => setTruncated(element.scrollWidth > element.clientWidth);
    measure();
    return observeResize(element, measure);
  }, []);
  return (
    // The full text is already the accessible text; the tooltip only shows it.
    <Tooltip content={value} disabled={!truncated} describe={false}>
      <p
        ref={ref}
        // oxlint-disable-next-line jsx-a11y/no-noninteractive-tabindex -- a cut-off value must take focus, or the keyboard cannot open its tooltip.
        tabIndex={truncated ? 0 : undefined}
        className={cn(
          "mt-auto truncate pt-1 text-fg tabular-nums",
          emphasis ? "text-hero-title" : "text-section-title",
        )}
      >
        {value}
      </p>
    </Tooltip>
  );
}

export { StatTile };
