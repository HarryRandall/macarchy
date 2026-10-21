import {
  type ComponentProps,
  type CSSProperties,
  type KeyboardEvent,
  type PointerEvent,
  useState,
} from "react";

import {
  type ColourFormat,
  cssColour,
  formatColour,
  type Hsva,
  hsvaToRgba,
  parseColour,
  rgbaToHsva,
} from "~/lib/colour";
import { cn } from "~/lib/cn";

import { inputVariants } from "./text-field";

type ColourPickerProps = {
  /** As stored: `#rrggbb` or `0xAARRGGBB`. Null or unreadable starts from black. */
  value: string | null;
  /** The notation to write. `argb` adds the opacity strip. */
  format: ColourFormat;
  /** Every change, continuously while dragging. */
  onValueChange: (value: string) => void;
  /** Once a change settles: pointer up, a key step, a hex entered. Save here. */
  onValueCommit?: (value: string) => void;
  /** Names the controls for assistive technology, such as "Active border colour". */
  label: string;
  /** Colours to offer as one-click swatches, such as the theme's palette. */
  swatches?: readonly string[];
  className?: string;
};

const clamp = (value: number) => Math.min(Math.max(value, 0), 1);
const percent = (value: number) => `${Math.round(value * 100)}%`;
const black: Hsva = { h: 0, s: 0, v: 0, a: 1 };

function hsvaFrom(value: string | null): Hsva {
  const parsed = parseColour(value);
  return parsed ? rgbaToHsva(parsed) : black;
}

/**
 * A saturation and brightness square, a hue strip, an opacity strip for
 * `0xAARRGGBB` values, and the hex in the notation the file uses. The hex
 * field is authoritative: a value typed or pasted there is written exactly,
 * never rounded through the sliders.
 */
function ColourPicker({
  value,
  format,
  onValueChange,
  onValueCommit,
  label,
  swatches,
  className,
}: ColourPickerProps) {
  // The hue is kept here rather than derived, so dragging to grey or black
  // does not throw away the hue the person was working in.
  const [state, setState] = useState(() => ({ hsva: hsvaFrom(value), value }));
  const [draft, setDraft] = useState<string | null>(null);
  if (state.value !== value) setState({ hsva: hsvaFrom(value), value });

  const { hsva } = state;
  const opacity = format === "argb";
  const rgba = hsvaToRgba(hsva);
  const formatted = formatColour(rgba, format);
  const opaque = cssColour({ ...rgba, a: 255 });

  function emit(next: Hsva, commit: boolean) {
    const written = formatColour(hsvaToRgba({ ...next, a: opacity ? next.a : 1 }), format);
    setState({ hsva: next, value: written });
    if (written !== value) onValueChange(written);
    if (commit) onValueCommit?.(written);
  }

  function commitCurrent() {
    onValueCommit?.(formatted);
  }

  function applyHex(text: string) {
    setDraft(null);
    const parsed = parseColour(text);
    if (!parsed) return;
    const written = formatColour(parsed, format);
    setState({ hsva: rgbaToHsva(parsed), value: written });
    if (written !== value) onValueChange(written);
    onValueCommit?.(written);
  }

  return (
    <div data-slot="colour-picker" className={cn("flex w-[232px] flex-col gap-3", className)}>
      <SaturationField
        hsva={hsva}
        label={label}
        onChange={(next) => emit(next, false)}
        onCommit={commitCurrent}
      />
      <GradientStrip
        aria-label={`${label} hue`}
        min={0}
        max={359}
        value={Math.round(hsva.h * 360) % 360}
        aria-valuetext={`${Math.round(hsva.h * 360) % 360} degrees`}
        track="linear-gradient(to right, #f00, #ff0, #0f0, #0ff, #00f, #f0f, #f00)"
        onValueChange={(degrees) => emit({ ...hsva, h: degrees / 360 }, false)}
        onCommit={commitCurrent}
      />
      {opacity ? (
        <GradientStrip
          aria-label={`${label} opacity`}
          min={0}
          max={100}
          value={Math.round(hsva.a * 100)}
          aria-valuetext={percent(hsva.a)}
          checkerboard
          track={`linear-gradient(to right, transparent, ${opaque})`}
          onValueChange={(alpha) => emit({ ...hsva, a: alpha / 100 }, false)}
          onCommit={commitCurrent}
        />
      ) : null}
      {swatches?.length ? (
        <div role="group" aria-label={`${label} swatches`} className="flex flex-wrap gap-1.5">
          {swatches.map((swatch) => {
            const parsed = parseColour(swatch);
            if (!parsed) return null;
            const written = formatColour(parsed, format);
            return (
              <button
                key={swatch}
                type="button"
                aria-label={written}
                aria-pressed={written === formatted}
                onClick={() => applyHex(swatch)}
                className="relative size-5 overflow-hidden rounded-[5px] border border-hairline bg-checkerboard aria-pressed:outline-2 aria-pressed:outline-offset-1 aria-pressed:outline-accent-stroke"
              >
                <span className="absolute inset-0" style={{ background: cssColour(parsed) }} />
              </button>
            );
          })}
        </div>
      ) : null}
      <div className="flex items-center gap-2">
        <span
          aria-hidden
          className="relative size-[22px] shrink-0 overflow-hidden rounded-small border border-hairline bg-checkerboard"
        >
          <span className="absolute inset-0" style={{ background: cssColour(rgba) }} />
        </span>
        <input
          aria-label={`${label} hex value`}
          value={draft ?? formatted}
          spellCheck={false}
          autoCapitalize="off"
          autoCorrect="off"
          onChange={(event) => setDraft(event.currentTarget.value)}
          onBlur={() => {
            if (draft !== null) applyHex(draft);
          }}
          onKeyDown={(event) => {
            if (event.key === "Enter" && draft !== null) applyHex(draft);
            if (event.key === "Escape" && draft !== null) {
              // Abandons the edit without closing the popover around it.
              event.stopPropagation();
              setDraft(null);
            }
          }}
          className={inputVariants({ variant: "mono", size: "default" })}
        />
      </div>
    </div>
  );
}

/** The square. Saturation runs left to right, brightness bottom to top. */
function SaturationField({
  hsva,
  label,
  onChange,
  onCommit,
}: {
  hsva: Hsva;
  label: string;
  onChange: (next: Hsva) => void;
  onCommit: () => void;
}) {
  function track(event: PointerEvent<HTMLDivElement>) {
    const rect = event.currentTarget.getBoundingClientRect();
    onChange({
      ...hsva,
      s: clamp((event.clientX - rect.left) / rect.width),
      v: 1 - clamp((event.clientY - rect.top) / rect.height),
    });
  }

  function step(event: KeyboardEvent<HTMLDivElement>) {
    const amount = event.shiftKey ? 0.1 : 0.01;
    const moves: Record<string, Partial<Hsva>> = {
      ArrowLeft: { s: clamp(hsva.s - amount) },
      ArrowRight: { s: clamp(hsva.s + amount) },
      ArrowDown: { v: clamp(hsva.v - amount) },
      ArrowUp: { v: clamp(hsva.v + amount) },
    };
    const move = moves[event.key];
    if (!move) return;
    event.preventDefault();
    onChange({ ...hsva, ...move });
  }

  return (
    <div
      role="slider"
      tabIndex={0}
      aria-label={`${label} saturation and brightness`}
      aria-valuemin={0}
      aria-valuemax={100}
      aria-valuenow={Math.round(hsva.s * 100)}
      aria-valuetext={`Saturation ${percent(hsva.s)}, brightness ${percent(hsva.v)}`}
      className="relative h-[172px] w-full touch-none rounded-control"
      style={{
        background: `linear-gradient(to top, #000, transparent), linear-gradient(to right, #fff, transparent), hsl(${hsva.h * 360} 100% 50%)`,
      }}
      onPointerDown={(event) => {
        event.currentTarget.setPointerCapture(event.pointerId);
        track(event);
      }}
      onPointerMove={(event) => {
        if (event.currentTarget.hasPointerCapture(event.pointerId)) track(event);
      }}
      onPointerUp={onCommit}
      onKeyDown={step}
      onKeyUp={(event) => {
        if (stepKeys.has(event.key)) onCommit();
      }}
    >
      <span
        aria-hidden
        className="pointer-events-none absolute size-3.5 -translate-1/2 rounded-full border border-black/20 bg-white shadow-[0_1px_3px_rgb(0_0_0/0.4)]"
        style={{ left: percent(hsva.s), top: percent(1 - hsva.v) }}
      />
    </div>
  );
}

const stepKeys = new Set([
  "ArrowLeft",
  "ArrowRight",
  "ArrowUp",
  "ArrowDown",
  "Home",
  "End",
  "PageUp",
  "PageDown",
]);

/**
 * A native range on a painted track, so keyboard steps and VoiceOver come
 * from WebKit, as `Slider` does.
 */
function GradientStrip({
  track,
  checkerboard = false,
  onValueChange,
  onCommit,
  className,
  ...props
}: Omit<ComponentProps<"input">, "type" | "onChange"> & {
  value: number;
  track: string;
  checkerboard?: boolean;
  onValueChange: (value: number) => void;
  onCommit: () => void;
}) {
  return (
    <input
      type="range"
      step={1}
      onChange={(event) => onValueChange(event.currentTarget.valueAsNumber)}
      onPointerUp={onCommit}
      onKeyUp={(event) => {
        if (stepKeys.has(event.key)) onCommit();
      }}
      style={{ "--track": track } as CSSProperties}
      className={cn(
        "h-3.5 w-full cursor-default appearance-none rounded-full bg-transparent",
        checkerboard && "bg-checkerboard",
        "[&::-webkit-slider-runnable-track]:h-3.5 [&::-webkit-slider-runnable-track]:rounded-full [&::-webkit-slider-runnable-track]:bg-(image:--track)",
        "[&::-webkit-slider-thumb]:size-3.5 [&::-webkit-slider-thumb]:appearance-none [&::-webkit-slider-thumb]:rounded-full [&::-webkit-slider-thumb]:border [&::-webkit-slider-thumb]:border-black/20",
        "[&::-webkit-slider-thumb]:bg-white [&::-webkit-slider-thumb]:shadow-[0_1px_3px_rgb(0_0_0/0.4)]",
        "[&::-moz-range-track]:h-3.5 [&::-moz-range-track]:rounded-full [&::-moz-range-track]:bg-(image:--track)",
        "[&::-moz-range-thumb]:size-3.5 [&::-moz-range-thumb]:rounded-full [&::-moz-range-thumb]:bg-white",
        className,
      )}
      {...props}
    />
  );
}

export { ColourPicker };
