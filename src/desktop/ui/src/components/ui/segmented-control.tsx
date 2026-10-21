import { Toggle } from "@base-ui/react/toggle";
import { ToggleGroup } from "@base-ui/react/toggle-group";
import { cva, type VariantProps } from "class-variance-authority";

import { cn } from "~/lib/cn";

const segmentVariants = cva(
  "rounded-full whitespace-nowrap text-fg-secondary outline-none transition-[background-color,color] duration-200 select-none data-pressed:bg-well data-pressed:font-medium data-pressed:text-fg hover:text-fg",
  {
    variants: {
      size: {
        /** Inside a settings row. */
        default: "px-2 py-1 text-[12px]",
        /** Tabs heading a page. */
        prominent: "px-3 py-1.5 text-[13px]",
      },
    },
    defaultVariants: { size: "default" },
  },
);

interface SegmentedOption<V extends string> {
  value: V;
  label: string;
  count?: number;
}

/**
 * SegmentedPill: a short inline choice where only the chosen segment is
 * drawn, so a row of them reads as text until the eye reaches the one set.
 */
function SegmentedControl<V extends string>({
  label,
  value,
  options,
  onValueChange,
  size,
  disabled,
  className,
}: VariantProps<typeof segmentVariants> & {
  label: string;
  value: V;
  options: readonly SegmentedOption<V>[];
  onValueChange: (value: V) => void;
  disabled?: boolean;
  className?: string;
}) {
  return (
    <ToggleGroup
      aria-label={label}
      value={[value]}
      disabled={disabled}
      onValueChange={(next) => {
        // A pressed segment cannot be released into "nothing chosen".
        const chosen = next[0];
        if (chosen !== undefined) onValueChange(chosen as V);
      }}
      className={cn("flex gap-0.5", className)}
    >
      {options.map((option) => (
        <Toggle key={option.value} value={option.value} className={segmentVariants({ size })}>
          {option.label}
          {option.count === undefined ? null : (
            <span className="ml-1.5 text-fg-secondary tabular-nums">{option.count}</span>
          )}
        </Toggle>
      ))}
    </ToggleGroup>
  );
}

export { SegmentedControl, type SegmentedOption };
