import { cva, type VariantProps } from "class-variance-authority";
import type { ComponentProps } from "react";

import { cn } from "~/lib/cn";

const spinnerVariants = cva("shrink-0 animate-spin text-current", {
  variants: {
    size: {
      /** Inside a small button or an icon button. */
      sm: "size-3",
      default: "size-4",
      /** Alone in an empty area while something loads. */
      lg: "size-6",
    },
  },
  defaultVariants: { size: "default" },
});

/**
 * An arc that turns while work runs: a daemon restarting, setup writing
 * files. Decorative by default, because the control beside it says what is
 * happening ("Restarting…"); give it a `label` when it stands alone. Under
 * Reduce Motion it holds still, so pair it with words.
 */
function Spinner({
  className,
  size,
  label,
  ...props
}: Omit<ComponentProps<"svg">, "children"> &
  VariantProps<typeof spinnerVariants> & { label?: string }) {
  return (
    <svg
      data-slot="spinner"
      viewBox="0 0 16 16"
      fill="none"
      {...(label ? { role: "status", "aria-label": label } : { "aria-hidden": true })}
      className={cn(spinnerVariants({ size }), className)}
      {...props}
    >
      <circle cx="8" cy="8" r="6.5" stroke="currentColor" strokeOpacity="0.25" strokeWidth="2" />
      <path
        d="M8 1.5a6.5 6.5 0 0 1 6.5 6.5"
        stroke="currentColor"
        strokeWidth="2"
        strokeLinecap="round"
      />
    </svg>
  );
}

export { Spinner };
