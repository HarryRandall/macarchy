import { useId } from "react";

import { NumberField } from "./number-field";
import { Slider } from "./slider";
import { Tooltip } from "./tooltip";

/**
 * Drag when you want to feel the change, type when you already know the
 * number. Both halves report through `onValueChange`, continuously while
 * dragging, so callers that talk to a daemon must debounce.
 */
function ValueSlider({
  label,
  id,
  value,
  min,
  max,
  step = 1,
  unit,
  disabled,
  onValueChange,
}: {
  label: string;
  /** Lets a row title label the slider. */
  id?: string;
  value: number;
  min: number;
  max: number;
  step?: number;
  unit?: string;
  disabled?: boolean;
  onValueChange: (value: number) => void;
}) {
  const fallbackId = useId();
  return (
    <div className="flex items-center gap-2.5">
      <Tooltip content="Drag to adjust, or type an exact value">
        <Slider
          id={id ?? fallbackId}
          className="w-37"
          value={value}
          min={min}
          max={max}
          step={step}
          disabled={disabled}
          aria-valuetext={unit ? `${value} ${unit}` : undefined}
          onValueChange={onValueChange}
        />
      </Tooltip>
      <div className="flex items-center gap-1.5">
        <NumberField
          aria-label={`${label}${unit ? ` in ${unit}` : ""}`}
          value={value}
          min={min}
          max={max}
          disabled={disabled}
          onValueChange={onValueChange}
        />
        {unit ? <span className="text-[12px] text-fg-secondary tabular-nums">{unit}</span> : null}
      </div>
    </div>
  );
}

export { ValueSlider };
