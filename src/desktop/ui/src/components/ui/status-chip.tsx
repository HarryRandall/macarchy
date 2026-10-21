import { cva, type VariantProps } from "class-variance-authority";
import type { ComponentProps } from "react";

import { cn } from "~/lib/cn";

type Tone = "success" | "warning" | "danger" | "neutral";

const dotColours: Record<Tone, string> = {
  success: "bg-success",
  warning: "bg-warning",
  danger: "bg-danger",
  neutral: "bg-fg-secondary",
};

/**
 * A coloured dot. `live` rings it three times when it turns on and then
 * stays still: a ring repeating forever keeps the window redrawing.
 */
function StatusDot({
  tone = "neutral",
  live = false,
  className,
}: {
  tone?: Tone;
  live?: boolean;
  className?: string;
}) {
  return (
    <span
      aria-hidden
      data-slot="status-dot"
      className={cn("relative inline-flex size-2 shrink-0 items-center justify-center", className)}
    >
      {live ? (
        <span
          className={cn(
            "absolute size-1.5 rounded-full opacity-70 animate-[ping_1.6s_ease-out_3]",
            dotColours[tone],
          )}
        />
      ) : null}
      <span className={cn("size-1.5 rounded-full", dotColours[tone])} />
    </span>
  );
}

const chipVariants = cva(
  "inline-flex shrink-0 items-center gap-1.5 text-meta whitespace-nowrap text-fg-secondary",
  {
    variants: {
      variant: {
        /** In a well, as the service rows and cards show it. */
        well: "rounded-full bg-well px-2 py-[3px]",
        /** Bare, for a summary line that is already set apart. */
        plain: "",
      },
    },
    defaultVariants: { variant: "well" },
  },
);

/**
 * A state in one glance: a dot, a word, one colour. The word carries the
 * meaning, so the colour is never the only signal.
 */
function StatusChip({
  tone = "neutral",
  label,
  live = false,
  variant,
  className,
  ...props
}: Omit<ComponentProps<"span">, "children"> &
  VariantProps<typeof chipVariants> & {
    tone?: Tone;
    label: string;
    /** A running service gets a short pulse when it starts. */
    live?: boolean;
  }) {
  return (
    <span
      data-slot="status-chip"
      data-tone={tone}
      className={cn(chipVariants({ variant }), className)}
      {...props}
    >
      {/* Keyed on `live`, so the pulse plays again each time it turns on. */}
      <StatusDot key={String(live)} tone={tone} live={live} />
      {label}
    </span>
  );
}

export { StatusChip, StatusDot, type Tone as StatusTone };
