import { cva, type VariantProps } from "class-variance-authority";
import type { ComponentProps } from "react";

import { cn } from "~/lib/cn";

const badgeVariants = cva(
  "inline-flex shrink-0 items-center justify-center gap-1.5 border font-medium whitespace-nowrap",
  {
    variants: {
      variant: {
        /** A word: "Current", "Read only", "Per app". */
        label: "h-[21px] rounded-small px-2 text-meta",
        /** A number beside a filter, tab or group heading. */
        count: "h-[18px] min-w-[18px] rounded-key px-1.5 text-caption tabular-nums",
      },
      tone: {
        neutral: "border-hairline text-fg-secondary",
        ok: "border-transparent bg-success-soft text-success",
        warn: "border-transparent bg-warning-soft text-warning",
        accent: "border-transparent bg-accent-soft text-accent-text",
        danger: "border-transparent bg-danger-soft text-danger",
        /** Earlier name for `ok`. */
        success: "border-transparent bg-success-soft text-success",
        /** Earlier name for `warn`. */
        warning: "border-transparent bg-warning-soft text-warning",
      },
    },
    compoundVariants: [
      { variant: "count", tone: "neutral", className: "border-transparent bg-muted" },
    ],
    defaultVariants: { variant: "label", tone: "neutral" },
  },
);

const dotTone = {
  neutral: "bg-fg-tertiary",
  ok: "bg-success",
  warn: "bg-warning",
  accent: "bg-accent",
  danger: "bg-danger",
  success: "bg-success",
  warning: "bg-warning",
} as const;

/** A short word or count describing state. Pair any tone with words, never colour alone. */
function Badge({
  className,
  variant,
  tone,
  dot = false,
  children,
  ...props
}: ComponentProps<"span"> &
  VariantProps<typeof badgeVariants> & {
    /** A small dot before the text in the tone's colour. */
    dot?: boolean;
  }) {
  return (
    <span data-slot="badge" className={cn(badgeVariants({ variant, tone }), className)} {...props}>
      {dot ? (
        <span aria-hidden className={cn("size-1.5 rounded-full", dotTone[tone ?? "neutral"])} />
      ) : null}
      {children}
    </span>
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
