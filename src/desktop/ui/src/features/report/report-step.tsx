import { Check } from "lucide-react";
import type { ReactNode } from "react";

import { cn } from "~/lib/cn";

/** Numbered steps joined by a rule, as in Report a problem and Setup. */
export function Steps({ className, children }: { className?: string; children: ReactNode }) {
  return <ol className={cn("flex flex-col", className)}>{children}</ol>;
}

/**
 * One step: its number, or a tick once done, on a rule down to the next.
 * Done only changes the marker; the step stays open to edit.
 */
export function Step({
  number,
  title,
  hint,
  done = false,
  optional = false,
  last = false,
  action,
  children,
}: {
  number: number;
  title: string;
  hint?: ReactNode;
  done?: boolean;
  optional?: boolean;
  last?: boolean;
  /** A control beside the title, such as Refresh. */
  action?: ReactNode;
  children: ReactNode;
}) {
  return (
    <li className={cn("relative grid grid-cols-[22px_minmax(0,1fr)] gap-3.5", !last && "pb-6")}>
      {last ? null : (
        <span aria-hidden className="absolute top-7 bottom-1 left-[10.5px] w-px bg-hairline" />
      )}
      <span
        aria-hidden
        className={cn(
          "grid size-[22px] place-items-center rounded-full text-caption font-semibold tabular-nums transition-colors motion-reduce:transition-none",
          done ? "bg-accent text-accent-fg" : "border border-line-strong bg-card text-fg-secondary",
        )}
      >
        {done ? <Check className="size-3" strokeWidth={2.5} /> : number}
      </span>
      <div className="min-w-0">
        <div className="flex min-h-[22px] items-center justify-between gap-3">
          <div className="flex min-w-0 items-baseline gap-2">
            <h2 className="text-card-title text-fg">{title}</h2>
            {optional ? <span className="text-meta text-fg-tertiary">Optional</span> : null}
          </div>
          {action ? <div className="flex shrink-0 items-center gap-1.5">{action}</div> : null}
        </div>
        {hint ? <p className="mt-0.5 text-detail text-fg-secondary">{hint}</p> : null}
        <div className="mt-3">{children}</div>
      </div>
    </li>
  );
}
