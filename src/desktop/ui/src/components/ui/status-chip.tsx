import { cva, type VariantProps } from "class-variance-authority";
import type { ComponentProps } from "react";

import { StatusDot, type StatusDotTone } from "~/components/charts/status-dot";
import { cn } from "~/lib/cn";

type Tone = "success" | "warning" | "danger" | "neutral";

const dotTones: Record<Tone, StatusDotTone> = {
  success: "ok",
  warning: "warn",
  danger: "error",
  neutral: "idle",
};

const chipVariants = cva(
  "inline-flex shrink-0 items-center gap-2 text-meta font-medium whitespace-nowrap text-fg-secondary",
  {
    variants: {
      variant: {
        /** Outlined, as the service rows and cards show it. */
        well: "h-[21px] rounded-small border border-hairline bg-card px-2",
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
  busy = false,
  variant,
  className,
  ...props
}: Omit<ComponentProps<"span">, "children"> &
  VariantProps<typeof chipVariants> & {
    tone?: Tone;
    label: string;
    /** Something that just turned on: the dot pulses three times, then holds. */
    live?: boolean;
    /** Something in progress, such as a service starting: the dot pulses until it settles. */
    busy?: boolean;
  }) {
  return (
    <span
      data-slot="status-chip"
      data-tone={tone}
      className={cn(chipVariants({ variant }), className)}
      {...props}
    >
      {/* Keyed on `live`, so the pulse plays again each time it turns on. */}
      <StatusDot
        key={String(live)}
        tone={dotTones[tone]}
        pulse={busy || live}
        className={busy ? undefined : "[animation-iteration-count:3]"}
      />
      {label}
    </span>
  );
}

export { StatusChip, type Tone as StatusTone };
