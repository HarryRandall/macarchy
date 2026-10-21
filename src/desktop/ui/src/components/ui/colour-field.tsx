import { Popover } from "@base-ui/react/popover";
import { useState } from "react";

import { cn } from "~/lib/cn";

import { ColourPicker } from "./colour-picker";
import { readHexDraft } from "./hex";
import { popupMotion } from "./surface";
import { SwatchPicker } from "./swatches";
import { Tooltip } from "./tooltip";

/**
 * A swatch and an editable hex in one box, with optional presets beside it.
 * The swatch opens the full picker. Typing commits each time the hex becomes
 * valid; an invalid draft is flagged and snaps back on blur, never written.
 */
function ColourField({
  label,
  value,
  onValueChange,
  presets,
  disabled,
  className,
}: {
  /** Names the colour: "Accent colour". */
  label: string;
  /** `#rrggbb`. */
  value: string;
  onValueChange: (hex: string) => void;
  presets?: readonly string[];
  disabled?: boolean;
  className?: string;
}) {
  const [draft, setDraft] = useState<string | null>(null);
  const shown = draft ?? value;
  const valid = draft === null || readHexDraft(draft) !== null;

  return (
    <div
      data-slot="colour-field"
      className={cn(
        "flex flex-wrap items-center gap-3",
        disabled && "pointer-events-none opacity-50",
        className,
      )}
    >
      <div
        className={cn(
          "flex h-8 items-center gap-2 rounded-control border bg-card pr-2 pl-1 shadow-card transition-[border-color,box-shadow]",
          "focus-within:ring-[3px]",
          valid
            ? "border-hairline focus-within:border-accent focus-within:ring-accent-soft"
            : "border-warning focus-within:ring-warning-soft",
        )}
      >
        <Popover.Root>
          <Tooltip content={`Pick ${label.toLowerCase()}`} describe={false}>
            <Popover.Trigger
              disabled={disabled}
              aria-label={`Pick ${label.toLowerCase()}`}
              className="relative size-6 shrink-0 overflow-hidden rounded-key shadow-[inset_0_0_0_1px_rgb(0_0_0/0.1)] outline-none focus-visible:ring-2 focus-visible:ring-accent"
              style={{ background: readHexDraft(shown) ?? value }}
            />
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
                  format="rgb"
                  label={label}
                  onValueChange={(next) => {
                    setDraft(null);
                    onValueChange(next);
                  }}
                />
              </Popover.Popup>
            </Popover.Positioner>
          </Popover.Portal>
        </Popover.Root>
        <input
          aria-label={`${label} hex value`}
          aria-invalid={!valid || undefined}
          disabled={disabled}
          spellCheck={false}
          autoCapitalize="off"
          autoCorrect="off"
          value={shown}
          onChange={(event) => {
            const text = event.currentTarget.value;
            setDraft(text);
            const hex = readHexDraft(text);
            if (hex && hex !== value) onValueChange(hex);
          }}
          onBlur={() => setDraft(null)}
          onKeyDown={(event) => {
            if (event.key === "Escape" && draft !== null) {
              event.stopPropagation();
              setDraft(null);
            }
          }}
          className="w-[72px] bg-transparent font-mono text-mono-value text-fg uppercase outline-none"
        />
      </div>
      {presets?.length ? (
        <SwatchPicker
          label={`${label} presets`}
          colours={presets}
          value={value}
          disabled={disabled}
          onValueChange={(next) => {
            setDraft(null);
            onValueChange(next);
          }}
        />
      ) : null}
    </div>
  );
}

export { ColourField };
