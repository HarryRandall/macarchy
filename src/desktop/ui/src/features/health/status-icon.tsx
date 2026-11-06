import { CircleAlert, CircleCheck, CircleHelp, CircleX, Loader2 } from "lucide-react";

import { cn } from "~/lib/cn";

import type { Check } from "./check-list";
import type { Result } from "./health-mock";

export type IconState = Check["status"] | "checking";

export const statusText: Record<Check["status"], string> = {
  passed: "Passed",
  warning: "Warning",
  failed: "Failed",
  unknown: "Unknown",
};

export const resultText: Record<Result, string> = {
  pass: "Passed",
  warn: "Warning",
  fail: "Failed",
};

export const resultStatus: Record<Result, Check["status"]> = {
  pass: "passed",
  warn: "warning",
  fail: "failed",
};

/** A check's state as a coloured glyph. Decorative: the words beside it say the state. */
export function StatusIcon({ state, size = 15 }: { state: IconState; size?: number }) {
  const props = { "aria-hidden": true, size, className: "shrink-0" } as const;
  switch (state) {
    case "passed":
      return <CircleCheck {...props} className={cn(props.className, "text-success")} />;
    case "warning":
      return <CircleAlert {...props} className={cn(props.className, "text-warning")} />;
    case "failed":
      return <CircleX {...props} className={cn(props.className, "text-danger")} />;
    case "unknown":
      return <CircleHelp {...props} className={cn(props.className, "text-fg-tertiary")} />;
    default:
      return (
        <Loader2
          {...props}
          className={cn(
            props.className,
            "animate-spin text-fg-tertiary motion-reduce:animate-none",
          )}
        />
      );
  }
}
