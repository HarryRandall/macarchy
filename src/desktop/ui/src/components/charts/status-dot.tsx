import { cn } from "~/lib/cn";

type StatusDotTone = "ok" | "warn" | "error" | "idle";

const tones: Record<StatusDotTone, string> = {
  ok: "bg-success shadow-[0_0_0_3px_var(--status-success-soft)]",
  warn: "bg-warning shadow-[0_0_0_3px_var(--status-warning-soft)]",
  error: "bg-danger shadow-[0_0_0_3px_var(--status-danger-soft)]",
  idle: "bg-fg-tertiary shadow-[0_0_0_3px_var(--surface-muted)]",
};

/**
 * A 7px state dot with a soft halo. Decorative: the word beside it carries
 * the meaning. `pulse` is one CSS animation on the dot itself, so a list of
 * busy rows never stacks timers, and it holds still under Reduce Motion.
 */
function StatusDot({
  tone,
  pulse = false,
  className,
}: {
  tone: StatusDotTone;
  pulse?: boolean;
  className?: string;
}) {
  return (
    <span
      aria-hidden
      data-slot="status-dot"
      data-tone={tone}
      className={cn(
        "inline-block size-[7px] shrink-0 rounded-full",
        tones[tone],
        pulse && "animate-status-pulse",
        className,
      )}
    />
  );
}

export { StatusDot, type StatusDotTone };
