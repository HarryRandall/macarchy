import type { ComponentProps, CSSProperties } from "react";

import { cn } from "~/lib/cn";

type SliderProps = Omit<ComponentProps<"input">, "type" | "value" | "onChange"> & {
  value: number;
  min: number;
  max: number;
  step?: number;
  onValueChange: (value: number) => void;
};

const glow = "0 0 0 4px var(--ui-accent-soft)";
const lift = "0 1px 3px rgb(0 0 0/0.2)";

/**
 * A native range input, so keyboard steps, VoiceOver and pointer capture come
 * from WebKit. The filled part of the track is painted from `--fill`.
 */
function Slider({ className, value, min, max, step = 1, onValueChange, ...props }: SliderProps) {
  const fill = max > min ? ((value - min) / (max - min)) * 100 : 0;
  return (
    <input
      type="range"
      data-slot="slider"
      min={min}
      max={max}
      step={step}
      value={value}
      onChange={(event) => onValueChange(event.currentTarget.valueAsNumber)}
      style={{ "--fill": `${fill}%`, "--glow": glow, "--lift": lift } as CSSProperties}
      className={cn(
        "group h-5 cursor-default appearance-none bg-transparent outline-none disabled:opacity-50",
        "[&::-webkit-slider-runnable-track]:h-[5px] [&::-webkit-slider-runnable-track]:rounded-full",
        "[&::-webkit-slider-runnable-track]:bg-[linear-gradient(to_right,var(--ui-accent)_var(--fill),var(--surface-muted)_var(--fill))]",
        "[&::-webkit-slider-runnable-track]:shadow-[inset_0_0_0_1px_var(--line-hairline)]",
        "[&::-webkit-slider-thumb]:-mt-[5px] [&::-webkit-slider-thumb]:size-[15px] [&::-webkit-slider-thumb]:appearance-none [&::-webkit-slider-thumb]:rounded-full",
        "[&::-webkit-slider-thumb]:border [&::-webkit-slider-thumb]:border-line-strong [&::-webkit-slider-thumb]:bg-white",
        "[&::-webkit-slider-thumb]:shadow-(--lift) [&::-webkit-slider-thumb]:transition-shadow",
        "hover:[&::-webkit-slider-thumb]:shadow-[var(--glow),var(--lift)]",
        "focus-visible:[&::-webkit-slider-thumb]:border-accent focus-visible:[&::-webkit-slider-thumb]:shadow-[var(--glow),var(--lift)]",
        "[&::-moz-range-track]:h-[5px] [&::-moz-range-track]:rounded-full [&::-moz-range-track]:bg-muted",
        "[&::-moz-range-progress]:h-[5px] [&::-moz-range-progress]:rounded-full [&::-moz-range-progress]:bg-accent",
        "[&::-moz-range-thumb]:size-[15px] [&::-moz-range-thumb]:rounded-full [&::-moz-range-thumb]:border [&::-moz-range-thumb]:border-line-strong [&::-moz-range-thumb]:bg-white",
        className,
      )}
      {...props}
    />
  );
}

export { Slider };
