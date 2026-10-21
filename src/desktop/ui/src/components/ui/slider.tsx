import type { ComponentProps, CSSProperties } from "react";

import { cn } from "~/lib/cn";

type SliderProps = Omit<ComponentProps<"input">, "type" | "value" | "onChange"> & {
  value: number;
  min: number;
  max: number;
  step?: number;
  onValueChange: (value: number) => void;
};

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
      style={{ "--fill": `${fill}%` } as CSSProperties}
      className={cn(
        "h-5 cursor-default appearance-none bg-transparent disabled:opacity-45",
        "[&::-webkit-slider-runnable-track]:h-1 [&::-webkit-slider-runnable-track]:rounded-full",
        "[&::-webkit-slider-runnable-track]:bg-[linear-gradient(to_right,var(--accent-stroke)_var(--fill),var(--fill-well)_var(--fill))]",
        "[&::-webkit-slider-thumb]:-mt-1.5 [&::-webkit-slider-thumb]:size-4 [&::-webkit-slider-thumb]:appearance-none [&::-webkit-slider-thumb]:rounded-full",
        "[&::-webkit-slider-thumb]:bg-white [&::-webkit-slider-thumb]:shadow-[0_0_0_0.5px_rgb(0_0_0/0.25),0_1px_3px_rgb(0_0_0/0.3)]",
        "[&::-moz-range-track]:h-1 [&::-moz-range-track]:rounded-full [&::-moz-range-track]:bg-well",
        "[&::-moz-range-progress]:h-1 [&::-moz-range-progress]:rounded-full [&::-moz-range-progress]:bg-accent-stroke",
        "[&::-moz-range-thumb]:size-4 [&::-moz-range-thumb]:rounded-full [&::-moz-range-thumb]:border-0 [&::-moz-range-thumb]:bg-white",
        className,
      )}
      {...props}
    />
  );
}

export { Slider };
