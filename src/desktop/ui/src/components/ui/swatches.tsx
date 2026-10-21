import { cn } from "~/lib/cn";

import { focusRing } from "./focus-ring";
import { sameHex } from "./hex";

/**
 * A row of colour chips, such as a terminal palette. Decorative: give the
 * row a `label` that says what the colours are, since a list of hex codes
 * read aloud helps nobody.
 */
function Swatches({
  colours,
  label,
  size = 18,
  className,
}: {
  colours: readonly string[];
  /** Names the palette for VoiceOver, such as "Tokyo Night terminal colours". */
  label?: string;
  size?: number;
  className?: string;
}) {
  return (
    <div
      role={label ? "img" : undefined}
      aria-label={label}
      aria-hidden={label ? undefined : true}
      data-slot="swatches"
      className={cn("flex items-center gap-1", className)}
    >
      {colours.map((colour, index) => (
        <span
          // A palette can repeat a colour, so position is part of the key.
          key={`${index}-${colour}`}
          className="shrink-0 rounded-[4px] shadow-[inset_0_0_0_1px_rgb(0_0_0/0.15)]"
          style={{ background: colour, width: size, height: size }}
        />
      ))}
    </div>
  );
}

/**
 * Round one-click colours beside a colour field. The chosen one carries a
 * ring in the ink colour, so it reads on any swatch.
 */
function SwatchPicker({
  label,
  colours,
  value,
  onValueChange,
  disabled,
  className,
}: {
  /** Names the group: "Accent presets". */
  label: string;
  colours: readonly string[];
  value: string;
  onValueChange: (colour: string) => void;
  disabled?: boolean;
  className?: string;
}) {
  return (
    <div
      role="group"
      aria-label={label}
      data-slot="swatch-picker"
      className={cn("flex flex-wrap items-center gap-1.5", className)}
    >
      {colours.map((colour) => {
        const chosen = sameHex(colour, value);
        return (
          <button
            key={colour}
            type="button"
            aria-label={`Use ${colour}`}
            aria-pressed={chosen}
            disabled={disabled}
            onClick={() => onValueChange(colour)}
            className={cn(
              "size-5 shrink-0 rounded-full transition-transform hover:scale-110 disabled:pointer-events-none disabled:opacity-50",
              chosen
                ? "ring-2 ring-fg ring-offset-2 ring-offset-page"
                : "shadow-[inset_0_0_0_1px_rgb(0_0_0/0.15)]",
              focusRing,
            )}
            style={{ background: colour }}
          />
        );
      })}
    </div>
  );
}

export { SwatchPicker, Swatches };
