import { cn } from "~/lib/cn";

/**
 * A colour shown as a small swatch and its hex, read-only, as in a palette
 * list or a theme's details. The hex stays selectable for copying.
 */
function HexValue({
  value,
  swatch = true,
  className,
}: {
  /** Any CSS colour; usually `#rrggbb`. */
  value: string;
  swatch?: boolean;
  className?: string;
}) {
  return (
    <span
      data-slot="hex-value"
      className={cn(
        "inline-flex min-w-0 items-center gap-1.5 font-mono text-mono-value text-fg-secondary",
        className,
      )}
    >
      {swatch ? (
        <span
          aria-hidden
          className="size-3 shrink-0 rounded-[3px] shadow-[inset_0_0_0_1px_rgb(0_0_0/0.15)]"
          style={{ background: value }}
        />
      ) : null}
      <span className="truncate uppercase select-text">{value}</span>
    </span>
  );
}

export { HexValue };
