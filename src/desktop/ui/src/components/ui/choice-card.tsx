import type { ComponentProps, ReactNode } from "react";

import { cn } from "~/lib/cn";

type ChoiceCardProps = Omit<ComponentProps<"button">, "children"> & {
  label: string;
  selected: boolean;
  /** Height of the picture, in points. */
  previewHeight?: number;
  preview: ReactNode;
};

/**
 * A picture-first option with its name underneath. The selection ring sits
 * just outside the picture so it never crops what it describes.
 */
function ChoiceCard({
  label,
  selected,
  previewHeight = 104,
  preview,
  className,
  ...props
}: ChoiceCardProps) {
  return (
    <button
      type="button"
      aria-pressed={selected}
      data-slot="choice-card"
      className={cn(
        "group flex min-w-0 flex-col gap-2 rounded-card p-1 transition-[background-color,opacity] hover:bg-hover active:opacity-75 disabled:pointer-events-none disabled:opacity-45",
        className,
      )}
      {...props}
    >
      <span
        className={cn(
          "relative block w-full rounded-card border border-hairline",
          "after:pointer-events-none after:absolute after:-inset-[3px] after:rounded-[14px] after:border-2 after:border-accent-stroke after:opacity-0 after:transition-opacity after:duration-snappy",
          selected && "after:opacity-100",
        )}
        style={{ height: previewHeight }}
      >
        <span className="absolute inset-0 overflow-hidden rounded-card">{preview}</span>
      </span>
      <span
        className={cn(
          "w-full truncate text-row-title transition-colors",
          selected ? "text-fg" : "text-fg-secondary",
        )}
      >
        {label}
      </span>
    </button>
  );
}

export { ChoiceCard };
