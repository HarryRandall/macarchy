import type { ComponentProps, ReactNode } from "react";

import { cn } from "~/lib/cn";

/**
 * A row of figures read together, divided by hairlines: a history's runs,
 * passes and failures, or a service's uptime, memory and CPU. A description
 * list, so VoiceOver pairs each label with its value.
 */
function StatStrip({ className, ...props }: ComponentProps<"dl">) {
  return (
    <dl
      data-slot="stat-strip"
      className={cn(
        "grid auto-cols-fr grid-flow-col divide-x divide-hairline [&>div]:min-w-0",
        className,
      )}
      {...props}
    />
  );
}

/**
 * One figure: a small label over the value, with an optional unit and a
 * quieter detail under it. `size="sm"` is the services popover's density.
 * A label too long for a narrow strip wraps rather than clipping, and the
 * label takes the slack so every value in the strip stays on one line.
 */
function Stat({
  label,
  value,
  unit,
  detail,
  size = "default",
  className,
}: {
  label: ReactNode;
  value: ReactNode;
  /** After the value, smaller: "MB", "%". */
  unit?: string;
  detail?: ReactNode;
  size?: "default" | "sm";
  className?: string;
}) {
  return (
    <div
      data-slot="stat"
      className={cn(
        "flex min-w-0 flex-col",
        size === "sm" ? "px-2.5 py-2" : "px-4 py-3",
        className,
      )}
    >
      <dt
        className={cn(
          "flex-1 break-words",
          size === "sm" ? "text-caption text-fg-tertiary" : "text-meta text-fg-secondary",
        )}
      >
        {label}
      </dt>
      <dd
        className={cn(
          "mt-0.5 flex items-baseline gap-1 text-fg tabular-nums",
          size === "sm" ? "text-body font-semibold tracking-[-0.01em]" : "text-stat",
        )}
      >
        <span className="truncate">{value}</span>
        {unit ? (
          <span className="text-caption font-medium tracking-normal text-fg-tertiary">{unit}</span>
        ) : null}
      </dd>
      {detail ? <dd className="mt-0.5 truncate text-meta text-fg-tertiary">{detail}</dd> : null}
    </div>
  );
}

export { Stat, StatStrip };
