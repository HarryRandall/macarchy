import { Popover } from "@base-ui/react/popover";
import { cva, type VariantProps } from "class-variance-authority";

import { type ColourFormat, cssColour, formatColour, parseColour } from "~/lib/colour";
import { cn } from "~/lib/cn";

import { ColourPicker } from "./colour-picker";
import { Tooltip } from "./tooltip";

const wellVariants = cva(
  "inline-flex shrink-0 items-center gap-2 rounded-control bg-well transition-[background-color,opacity] select-none hover:bg-hover active:opacity-75 disabled:pointer-events-none disabled:opacity-45 data-popup-open:bg-hover",
  {
    variants: {
      size: {
        /** In a settings row. */
        default: "h-7 pr-1 pl-2",
        /** A bare swatch, where the hex is shown elsewhere. */
        swatch: "size-7 justify-center",
      },
    },
    defaultVariants: { size: "default" },
  },
);

type ColourWellProps = VariantProps<typeof wellVariants> & {
  /** As stored. Null means the theme leaves it unset. */
  value: string | null;
  format: ColourFormat;
  /** Every change, continuously while dragging. Not called until the person edits. */
  onValueChange: (value: string) => void;
  /** Once a change settles. Save to disk or apply to a daemon here. */
  onValueCommit?: (value: string) => void;
  /** Names the colour, such as "Active border colour". */
  label: string;
  /** Help on hover. Defaults to "Edit" and the label. */
  tooltip?: string;
  swatches?: readonly string[];
  disabled?: boolean;
  className?: string;
};

/**
 * A swatch with its hex beside it, opening `ColourPicker` in a popover. The
 * hex is shown rather than hidden behind the swatch, because these values
 * are also read and diffed as text in theme.json. The value is passed
 * through untouched until it is edited; unreadable text is shown as it is.
 */
function ColourWell({
  value,
  format,
  onValueChange,
  onValueCommit,
  label,
  tooltip,
  swatches,
  disabled,
  size,
  className,
}: ColourWellProps) {
  const parsed = parseColour(value);
  const unset = value === null || value.trim() === "";
  const shown = unset ? "not set" : parsed ? formatColour(parsed, format) : value;

  return (
    <Popover.Root>
      <Tooltip content={tooltip ?? `Edit ${label.toLowerCase()}`} describe={false}>
        <Popover.Trigger
          disabled={disabled}
          aria-label={`${label}, ${unset ? "not set" : shown}`}
          data-slot="colour-well"
          className={cn(wellVariants({ size }), className)}
        >
          {size === "swatch" ? null : (
            <span
              className={cn(
                "font-mono text-mono-detail",
                unset ? "text-fg-meta" : "text-fg-secondary",
              )}
            >
              {shown}
            </span>
          )}
          <span
            aria-hidden
            className={cn(
              "relative size-5 shrink-0 overflow-hidden rounded-small border border-hairline",
              parsed ? "bg-checkerboard" : "border-dashed border-fg-secondary/60",
            )}
          >
            {parsed ? (
              <span className="absolute inset-0" style={{ background: cssColour(parsed) }} />
            ) : null}
          </span>
        </Popover.Trigger>
      </Tooltip>
      <Popover.Portal>
        <Popover.Positioner side="bottom" sideOffset={6} collisionPadding={12} className="z-50">
          <Popover.Popup
            aria-label={label}
            className={cn(
              "rounded-card border border-hairline bg-popover/95 p-3 shadow-[0_8px_24px_rgb(0_0_0/0.28)] backdrop-blur-xl outline-none",
              "origin-(--transform-origin) transition-[opacity,scale] duration-140 data-ending-style:opacity-0 data-starting-style:scale-97 data-starting-style:opacity-0",
            )}
          >
            <ColourPicker
              value={value}
              format={format}
              label={label}
              swatches={swatches}
              onValueChange={onValueChange}
              onValueCommit={onValueCommit}
            />
          </Popover.Popup>
        </Popover.Positioner>
      </Popover.Portal>
    </Popover.Root>
  );
}

export { ColourWell };
