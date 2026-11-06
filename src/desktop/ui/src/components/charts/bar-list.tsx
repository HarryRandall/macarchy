import type { ReactNode } from "react";

import { focusRingInset } from "~/components/ui/focus-ring";
import { cn } from "~/lib/cn";

import { type ChartTone, toneBackground } from "./axis";

interface BarListItem {
  key: string;
  label: ReactNode;
  value: number;
  /** Shown after the value, quieter: "12 files", "3h 20m". */
  detail?: ReactNode;
  tone?: ChartTone;
}

/**
 * Horizontal bars, one per thing, sized against the largest: focus time per
 * app, files per tool, most-used shortcuts. Built from text and boxes, so
 * every value is already on screen and read in order. `inline` sets the
 * label, bar and value on one line; `stacked` puts the label and value above
 * a thin bar. With `onSelect` each row is a button.
 */
function BarList({
  label,
  items,
  layout = "inline",
  format = String,
  max,
  selected,
  onSelect,
  labelWidth = 96,
  className,
}: {
  /** Names the list: "Focus time by app". */
  label: string;
  items: readonly BarListItem[];
  layout?: "inline" | "stacked";
  format?: (value: number) => string;
  /** The value that fills the track. The largest item by default. */
  max?: number;
  selected?: string | null;
  onSelect?: (key: string) => void;
  /** The label column's width in `inline` layout. */
  labelWidth?: number;
  className?: string;
}) {
  const top = max ?? Math.max(0, ...items.map((item) => item.value));
  const share = (value: number) => (top > 0 ? Math.min(1, value / top) : 0);

  return (
    <ul aria-label={label} data-slot="bar-list" className={cn("flex flex-col", className)}>
      {items.map((item) => {
        const chosen = selected === item.key;
        const dim = selected !== undefined && selected !== null && !chosen;
        const bar = (
          <span
            aria-hidden
            className={cn(
              "relative block overflow-hidden rounded-full bg-muted",
              layout === "inline" ? "h-2.5 flex-1" : "mt-1.5 h-1.5 w-full",
            )}
          >
            <span
              className={cn(
                "absolute inset-y-0 left-0 min-w-0.5 rounded-full transition-[width,opacity] duration-300 ease-out",
                toneBackground[item.tone ?? "accent"],
                dim && "opacity-45",
              )}
              style={{ width: `${share(item.value) * 100}%` }}
            />
          </span>
        );
        const value = (
          <span className="shrink-0 text-meta text-fg-secondary tabular-nums">
            <span className={cn("font-medium", chosen ? "text-fg" : "text-fg-secondary")}>
              {format(item.value)}
            </span>
            {item.detail ? <span className="ml-1 text-fg-tertiary">{item.detail}</span> : null}
          </span>
        );
        const body =
          layout === "inline" ? (
            <span className="flex min-w-0 items-center gap-3">
              <span
                className="shrink-0 truncate text-small text-fg-secondary"
                style={{ width: labelWidth }}
              >
                {item.label}
              </span>
              {bar}
              {value}
            </span>
          ) : (
            <span className="block min-w-0">
              <span className="flex items-baseline justify-between gap-3">
                <span className="min-w-0 truncate text-small font-medium text-fg">
                  {item.label}
                </span>
                {value}
              </span>
              {bar}
            </span>
          );
        return (
          <li key={item.key}>
            {onSelect ? (
              <button
                type="button"
                aria-pressed={chosen}
                onClick={() => onSelect(item.key)}
                className={cn(
                  "block w-full rounded-small px-1.5 py-1.5 text-left transition-colors hover:bg-hover",
                  chosen && "bg-muted",
                  focusRingInset,
                )}
              >
                {body}
              </button>
            ) : (
              <div className="px-1.5 py-1.5">{body}</div>
            )}
          </li>
        );
      })}
    </ul>
  );
}

export { BarList, type BarListItem };
