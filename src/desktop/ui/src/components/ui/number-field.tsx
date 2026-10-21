import { Minus, Plus } from "lucide-react";
import { type ComponentProps, type KeyboardEvent, useState } from "react";

import { cn } from "~/lib/cn";

import { focusRing } from "./focus-ring";
import { parseNumberDraft, stepNumber } from "./number";

type NumberFieldProps = Omit<ComponentProps<"input">, "value" | "onChange" | "min" | "max"> & {
  value: number;
  min: number;
  max: number;
  decimals?: number;
  onValueChange: (value: number) => void;
};

/**
 * A boxed field for typing an exact number. It commits on Return or blur;
 * anything unparseable snaps back rather than writing a zero to a live
 * daemon setting.
 */
function NumberField({
  className,
  value,
  min,
  max,
  decimals = 0,
  onValueChange,
  onBlur,
  onKeyDown,
  ...props
}: NumberFieldProps) {
  const [draft, setDraft] = useState<string | null>(null);
  const formatted = value.toFixed(decimals);

  function commit() {
    if (draft === null) return;
    setDraft(null);
    const next = parseNumberDraft(draft, { min, max, decimals });
    if (next !== null && next !== value) onValueChange(next);
  }

  return (
    <input
      type="text"
      inputMode="decimal"
      data-slot="number-field"
      value={draft ?? formatted}
      onChange={(event) => setDraft(event.currentTarget.value)}
      onBlur={(event) => {
        commit();
        onBlur?.(event);
      }}
      onKeyDown={(event) => {
        if (event.key === "Enter") commit();
        if (event.key === "Escape") setDraft(null);
        onKeyDown?.(event);
      }}
      className={cn(
        "h-[26px] w-11 rounded-small border border-hairline bg-side text-center font-mono text-meta text-fg tabular-nums outline-none",
        "transition-[border-color,box-shadow] focus:border-accent focus:ring-[3px] focus:ring-accent-soft disabled:opacity-50",
        className,
      )}
      {...props}
    />
  );
}

/**
 * Minus, value and plus for a small whole number, such as a gap in pixels.
 * Arrow keys on either button also step, and the value is announced.
 */
function Stepper({
  label,
  value,
  min,
  max,
  step = 1,
  unit,
  disabled,
  onValueChange,
  className,
}: {
  /** Names the group and both buttons: "Decrease gap". */
  label: string;
  value: number;
  min: number;
  max: number;
  step?: number;
  /** Read after the value by VoiceOver, such as "px". */
  unit?: string;
  disabled?: boolean;
  onValueChange: (value: number) => void;
  className?: string;
}) {
  const bounds = { min, max };
  const move = (direction: 1 | -1) => {
    const next = stepNumber(value, direction, step, bounds);
    if (next !== value) onValueChange(next);
  };
  const button = cn(
    "grid size-7 place-items-center text-fg-secondary transition-colors hover:bg-hover hover:text-fg",
    "disabled:pointer-events-none disabled:opacity-40",
    focusRing,
    "focus-visible:ring-offset-0 focus-visible:ring-inset",
  );
  const onKeyDown = (event: KeyboardEvent) => {
    if (event.key === "ArrowUp" || event.key === "ArrowRight") {
      event.preventDefault();
      move(1);
    } else if (event.key === "ArrowDown" || event.key === "ArrowLeft") {
      event.preventDefault();
      move(-1);
    }
  };
  return (
    <div
      role="group"
      aria-label={label}
      data-slot="stepper"
      className={cn(
        "inline-flex shrink-0 items-center overflow-hidden rounded-control border border-hairline bg-card shadow-card",
        disabled && "opacity-50",
        className,
      )}
    >
      <button
        type="button"
        aria-label={`Decrease ${label.toLowerCase()}`}
        disabled={disabled || value <= min}
        onClick={() => move(-1)}
        onKeyDown={onKeyDown}
        className={button}
      >
        <Minus aria-hidden className="size-3" />
      </button>
      <output
        aria-live="polite"
        className="min-w-8 border-x border-hairline px-1 text-center text-detail leading-7 font-medium text-fg tabular-nums"
      >
        {value}
        {unit ? <span className="sr-only"> {unit}</span> : null}
      </output>
      <button
        type="button"
        aria-label={`Increase ${label.toLowerCase()}`}
        disabled={disabled || value >= max}
        onClick={() => move(1)}
        onKeyDown={onKeyDown}
        className={button}
      >
        <Plus aria-hidden className="size-3" />
      </button>
    </div>
  );
}

export { NumberField, Stepper };
