import type { ReactNode } from "react";

import { cn } from "~/lib/cn";

import { ringGeometry, ringWeight } from "./ring";

type RingSegment = "on" | "off" | "busy";

/**
 * A ring split into one arc per service, clockwise from the top in list
 * order. Running arcs are green, starting ones grey and pulsing, stopped
 * ones empty track. Each arc draws in along the ring when its service comes
 * up. `label` says the same in words, such as "3 of 4 services running".
 */
function ServiceRing({
  segments,
  size = 16,
  label,
  children,
  className,
}: {
  segments: readonly RingSegment[];
  size?: number;
  label: string;
  /** Centred inside, such as a count on the large ring. */
  children?: ReactNode;
  className?: string;
}) {
  const { stroke, gap } = ringWeight(size);
  const ring = ringGeometry(segments.length, size, stroke, gap);
  return (
    <span
      role="img"
      aria-label={label}
      data-slot="service-ring"
      className={cn("relative grid shrink-0 place-items-center", className)}
      style={{ width: size, height: size }}
    >
      <svg
        width={size}
        height={size}
        viewBox={`0 0 ${size} ${size}`}
        aria-hidden
        className="absolute inset-0 -rotate-90"
      >
        {segments.map((segment, index) => {
          const shared = {
            cx: ring.centre,
            cy: ring.centre,
            r: ring.radius,
            fill: "none",
            strokeWidth: stroke,
            strokeDasharray: `${ring.arc} ${ring.circumference}`,
            transform: `rotate(${ring.angles[index] ?? 0} ${ring.centre} ${ring.centre})`,
          };
          return (
            // Segments are positional: the nth arc is the nth service.
            <g key={index}>
              <circle {...shared} className="stroke-line-strong" />
              <circle
                {...shared}
                strokeDashoffset={segment === "off" ? ring.arc : 0}
                className={cn(
                  "transition-[stroke-dashoffset,stroke] duration-500 ease-out",
                  segment === "busy" ? "animate-status-pulse stroke-fg-tertiary" : "stroke-success",
                )}
              />
            </g>
          );
        })}
      </svg>
      {children ? <span className="relative">{children}</span> : null}
    </span>
  );
}

export { type RingSegment, ServiceRing };
