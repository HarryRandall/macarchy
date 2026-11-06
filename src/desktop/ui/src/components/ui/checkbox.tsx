import { Checkbox as CheckboxPrimitive } from "@base-ui/react/checkbox";
import { Check } from "lucide-react";

import { cn } from "~/lib/cn";

import { focusRing } from "./focus-ring";

/**
 * A tick box for choosing items from a list, such as the tools setup
 * configures. For a setting that applies at once, use `Switch`. Give it an
 * accessible name with `aria-label`, or wrap it in a label with its words.
 */
function Checkbox({ className, ...props }: CheckboxPrimitive.Root.Props) {
  return (
    <CheckboxPrimitive.Root
      data-slot="checkbox"
      className={cn(
        "flex size-4 shrink-0 items-center justify-center rounded-key border border-line-strong bg-card shadow-card",
        "transition-colors data-checked:border-transparent data-checked:bg-accent data-disabled:opacity-50",
        focusRing,
        className,
      )}
      {...props}
    >
      <CheckboxPrimitive.Indicator className="text-white">
        <Check aria-hidden strokeWidth={3} className="size-3" />
      </CheckboxPrimitive.Indicator>
    </CheckboxPrimitive.Root>
  );
}

export { Checkbox };
