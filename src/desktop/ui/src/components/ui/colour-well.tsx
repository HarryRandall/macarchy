import { Popover } from "@base-ui/react/popover";
import { cva, type VariantProps } from "class-variance-authority";

import { type ColourFormat, cssColour, formatColour, parseColour } from "~/lib/colour";
import { cn } from "~/lib/cn";

import { ColourPicker } from "./colour-picker";
import { focusRing } from "./focus-ring";
import { popupMotion } from "./surface";
import { Tooltip } from "./tooltip";

const wellVariants = cva(
  [
    "inline-flex shrink-0 items-center gap-2 rounded-control border border-hairline bg-card shadow-card select-none",
    "transition-[background-color,border-color,opacity] hover:bg-hover active:translate-y-px disabled:pointer-events-none disabled:opacity-50 data-popup-open:border-accent",
    focusRing,
  ],
  {
    variants: {
      size: {
        /** In a settings row. */
        default: "h-8 pr-2.5 pl-1",
        /** A bare swatch, where the hex is shown elsewhere. */
        swatch: "size-8 justify-center",
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
          <span
            aria-hidden
            className={cn(
              "relative size-6 shrink-0 overflow-hidden rounded-key",
              parsed
                ? "bg-checkerboard shadow-[inset_0_0_0_1px_rgb(0_0_0/0.1)]"
                : "border border-dashed border-line-strong",
            )}
          >
            {parsed ? (
              <span className="absolute inset-0" style={{ background: cssColour(parsed) }} />
            ) : null}
          </span>
          {size === "swatch" ? null : (
            <span
              className={cn(
                "font-mono text-mono-value",
                unset ? "text-fg-tertiary" : "text-fg",
                parsed && format === "rgb" && "uppercase",
              )}
            >
              {shown}
            </span>
          )}
        </Popover.Trigger>
      </Tooltip>
      <Popover.Portal>
        <Popover.Positioner side="bottom" sideOffset={6} collisionPadding={8} className="z-50">
          <Popover.Popup
            aria-label={label}
            className={cn(
              "rounded-panel border border-hairline bg-popover p-3 shadow-pop outline-none",
              popupMotion,
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
