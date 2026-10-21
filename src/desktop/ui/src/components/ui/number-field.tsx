import { type ComponentProps, useState } from "react";

import { cn } from "~/lib/cn";

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
    const parsed = Number(draft.trim());
    if (draft.trim() === "" || !Number.isFinite(parsed)) return;
    const factor = 10 ** decimals;
    const clamped = Math.min(Math.max(Math.round(parsed * factor) / factor, min), max);
    if (clamped !== value) onValueChange(clamped);
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
        "h-[26px] w-[58px] rounded-control border border-hairline bg-well text-center font-mono text-[12px] text-fg tabular-nums",
        // The shared focus ring, as macOS rings a focused text field.
        "transition-colors focus:border-accent-stroke disabled:opacity-45",
        className,
      )}
      {...props}
    />
  );
}

export { NumberField };
