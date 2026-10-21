import {
  type ComponentProps,
  type FocusEvent,
  type KeyboardEvent,
  type ReactNode,
  useState,
} from "react";

import { focusRing } from "~/components/ui/focus-ring";
import { cn } from "~/lib/cn";

import { type CursorKeys, stepIndex } from "./scale";

interface CursorOptions extends CursorKeys {
  /** Enter or Space on the current point, such as filtering a list to that day. */
  onActivate?: (index: number) => void;
  /** Escape, such as clearing that filter. */
  onClear?: () => void;
}

/**
 * The point a chart is showing, from the pointer or the keyboard. Arrow keys
 * move it, Home and End jump, and it clears when focus or the pointer leaves.
 * `keyboard` is true while the keys drive it, so only then is the value
 * announced; a sweeping pointer would otherwise flood VoiceOver.
 */
function useChartCursor(count: number, options: CursorOptions = {}) {
  const { onActivate, onClear, ...keys } = options;
  const [state, setState] = useState<{ index: number | null; keyboard: boolean }>({
    index: null,
    keyboard: false,
  });
  const index = state.index !== null && state.index < count ? state.index : null;

  const point = (next: number | null) => setState({ index: next, keyboard: false });

  const frameProps = {
    tabIndex: count > 0 ? 0 : -1,
    onFocus(event: FocusEvent<HTMLElement>) {
      if (event.target !== event.currentTarget) return;
      if (!event.currentTarget.matches(":focus-visible")) return;
      const start = keys.start ?? count - 1;
      setState((current) => ({ index: current.index ?? start, keyboard: true }));
    },
    onBlur() {
      setState({ index: null, keyboard: false });
    },
    onMouseLeave() {
      setState((current) => (current.keyboard ? current : { index: null, keyboard: false }));
    },
    onKeyDown(event: KeyboardEvent<HTMLElement>) {
      const next = stepIndex(index, event.key, count, keys);
      if (next !== undefined) {
        event.preventDefault();
        setState({ index: next, keyboard: true });
      } else if ((event.key === "Enter" || event.key === " ") && index !== null && onActivate) {
        event.preventDefault();
        onActivate(index);
      } else if (event.key === "Escape" && (index !== null || onClear)) {
        // Clears the chart first; a second Escape reaches the dialog or popover around it.
        event.stopPropagation();
        setState({ index: null, keyboard: false });
        onClear?.();
      }
    },
  };

  return { index, keyboard: state.keyboard, point, frameProps };
}

/**
 * A chart's focusable box. VoiceOver reads `label` on arrival and
 * `announce` (the current point in words) as the arrow keys move.
 */
function ChartFrame({
  label,
  announce,
  className,
  children,
  ...props
}: Omit<ComponentProps<"div">, "children"> & {
  /** What the chart shows and how to use it: "Snapshots per day. Arrow keys move between days." */
  label: string;
  announce?: string | null;
  children: ReactNode;
}) {
  return (
    <div
      role="group"
      aria-roledescription="chart"
      aria-label={label}
      data-slot="chart"
      className={cn(
        "relative rounded-small",
        focusRing,
        "focus-visible:ring-offset-card",
        className,
      )}
      {...props}
    >
      {children}
      <span aria-live="polite" className="sr-only">
        {announce ?? ""}
      </span>
    </div>
  );
}

export { ChartFrame, useChartCursor };
