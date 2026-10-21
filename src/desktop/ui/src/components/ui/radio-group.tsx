import { Radio } from "@base-ui/react/radio";
import { RadioGroup as RadioGroupPrimitive } from "@base-ui/react/radio-group";
import { type ReactNode, useId } from "react";

import { cn } from "~/lib/cn";

interface RadioOption<V extends string> {
  value: V;
  label: string;
  /** A line under the label saying what the choice means. */
  description?: ReactNode;
  disabled?: boolean;
}

/**
 * A short list of exclusive choices that need their words, as setup's "Keep
 * mine and add Macarchy" or "Start fresh". For terse choices in a row, use
 * `SegmentedControl` or `Select`.
 */
function RadioGroup<V extends string>({
  label,
  value,
  options,
  onValueChange,
  disabled,
  className,
}: {
  /** The accessible name of the group. */
  label: string;
  value: V;
  options: readonly RadioOption<V>[];
  onValueChange: (value: V) => void;
  disabled?: boolean;
  className?: string;
}) {
  const id = useId();
  return (
    <RadioGroupPrimitive
      aria-label={label}
      value={value}
      disabled={disabled}
      onValueChange={(next) => onValueChange(next as V)}
      data-slot="radio-group"
      className={cn("flex flex-col gap-2.5", className)}
    >
      {options.map((option) => {
        const labelId = `${id}-${option.value}`;
        const descriptionId = `${labelId}-description`;
        return (
          // A label, so a click on the words chooses the option.
          <label key={option.value} className="flex items-start gap-2">
            <Radio.Root
              value={option.value}
              disabled={option.disabled}
              aria-labelledby={labelId}
              aria-describedby={option.description ? descriptionId : undefined}
              className={cn(
                "mt-px flex size-4 shrink-0 items-center justify-center rounded-full border border-hairline bg-well shadow-[inset_0_1px_1px_rgb(0_0_0/0.08)]",
                "transition-colors data-checked:border-transparent data-checked:bg-accent data-checked:shadow-[inset_0_0_0_1px_var(--accent-stroke)] data-disabled:opacity-45",
              )}
            >
              <Radio.Indicator className="size-1.5 rounded-full bg-accent-fg" />
            </Radio.Root>
            <div className="flex min-w-0 flex-col gap-0.5">
              <span id={labelId} className="text-row-title text-fg">
                {option.label}
              </span>
              {option.description ? (
                <span id={descriptionId} className="text-row-detail text-fg-secondary">
                  {option.description}
                </span>
              ) : null}
            </div>
          </label>
        );
      })}
    </RadioGroupPrimitive>
  );
}

export { RadioGroup, type RadioOption };
