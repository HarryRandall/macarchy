import type { ComponentProps, ReactNode } from "react";

import { cn } from "~/lib/cn";

type ChoiceCardProps = Omit<ComponentProps<"button">, "children"> & {
  label: string;
  selected: boolean;
  /** Height of the picture, in points. */
  previewHeight?: number;
  preview: ReactNode;
  /** A short line under the name, such as what the layout does. */
  detail?: ReactNode;
};

/**
 * A picture-first option with its name underneath. The selection ring sits
 * just outside the picture so it never crops what it describes; keyboard
 * focus draws the same ring in the accent.
 */
function ChoiceCard({
  label,
  selected,
  previewHeight = 104,
  preview,
  detail,
  className,
  ...props
}: ChoiceCardProps) {
  return (
    <button
      type="button"
      aria-pressed={selected}
      data-slot="choice-card"
      className={cn(
        "group flex min-w-0 flex-col gap-2 rounded-panel p-1 text-left outline-none disabled:pointer-events-none disabled:opacity-50",
        className,
      )}
      {...props}
    >
      <span
        className={cn(
          "relative block w-full rounded-card border border-hairline shadow-card transition-[border-color] duration-150 group-hover:border-line-strong",
          "after:pointer-events-none after:absolute after:-inset-[4px] after:rounded-[13px] after:border-2 after:opacity-0 after:transition-opacity after:duration-150",
          selected ? "after:border-fg after:opacity-100" : "after:border-accent",
          "group-focus-visible:after:border-accent group-focus-visible:after:opacity-100",
        )}
        style={{ height: previewHeight }}
      >
        <span className="absolute inset-0 overflow-hidden rounded-[9px]">{preview}</span>
      </span>
      <span className="flex w-full min-w-0 flex-col gap-0.5 px-0.5">
        <span
          className={cn(
            "truncate text-body font-medium transition-colors",
            selected ? "text-fg" : "text-fg-secondary group-hover:text-fg",
          )}
        >
          {label}
        </span>
        {detail ? <span className="text-small text-fg-tertiary">{detail}</span> : null}
      </span>
    </button>
  );
}

export { ChoiceCard };
