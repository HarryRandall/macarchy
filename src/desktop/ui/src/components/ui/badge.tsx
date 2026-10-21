import { cva, type VariantProps } from "class-variance-authority";
import type { ComponentProps } from "react";

import { cn } from "~/lib/cn";

const badgeVariants = cva(
  "inline-flex shrink-0 items-center justify-center rounded-full text-badge whitespace-nowrap",
  {
    variants: {
      variant: {
        /** A word: "Edited", "Read only", "Per app". */
        label: "px-2 py-[3px]",
        /** A number beside a filter, tab or group heading. */
        count: "min-w-[18px] px-[5px] py-px tabular-nums",
      },
      // The ink stays neutral so small type keeps its contrast on every
      // tint; the wash carries the tone.
      tone: {
        neutral: "bg-fg/12 text-fg-meta",
        accent: "bg-accent-stroke/18 text-fg",
        success: "bg-success/18 text-fg",
        warning: "bg-warning/20 text-fg",
        danger: "bg-danger/18 text-fg",
      },
    },
    defaultVariants: { variant: "label", tone: "neutral" },
  },
);

function Badge({
  className,
  variant,
  tone,
  ...props
}: ComponentProps<"span"> & VariantProps<typeof badgeVariants>) {
  return (
    <span
      data-slot="badge"
      className={cn(badgeVariants({ variant, tone }), className)}
      {...props}
    />
  );
}

/** A count in a soft pill. */
function CountBadge({
  count,
  ...props
}: Omit<ComponentProps<typeof Badge>, "children" | "variant"> & { count: number }) {
  return (
    <Badge variant="count" {...props}>
      {count}
    </Badge>
  );
}

export { Badge, badgeVariants, CountBadge };
