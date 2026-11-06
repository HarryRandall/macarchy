import { cva, type VariantProps } from "class-variance-authority";
import type { ComponentProps, ReactNode } from "react";

import { cn } from "~/lib/cn";

import { CountBadge } from "./badge";
import { HelpTooltip } from "./help-tooltip";

const rowVariants = cva(
  "group/row relative flex min-w-0 items-center gap-3 transition-colors duration-150",
  {
    variants: {
      size: {
        /** Matches `Row`, for rows in a settings card. */
        default: "min-h-12 px-5 py-3",
        /** Dense lists, such as shortcuts. */
        compact: "min-h-10 px-4 py-2",
      },
    },
    defaultVariants: { size: "default" },
  },
);

type ListRowProps = Omit<ComponentProps<"div">, "title" | "onSelect"> &
  VariantProps<typeof rowVariants> & {
    title: ReactNode;
    /** A second line: a pattern, a path, a date, a count. */
    detail?: ReactNode;
    /** Sets the detail in monospace, for commands, patterns and paths. */
    detailMono?: boolean;
    /** Sets the title in monospace, for a row named by its command. */
    titleMono?: boolean;
    help?: string;
    /** An app icon, an `IconTile` or a status glyph. */
    leading?: ReactNode;
    /** Always shown: a status chip, a badge, key caps, a button. */
    trailing?: ReactNode;
    /** Buttons that act on the row. Hidden until hover or focus when `revealActions`. */
    actions?: ReactNode;
    revealActions?: boolean;
    /**
     * Makes the row's title area a button, for opening an editor or choosing
     * the row. Actions and trailing controls stay separate buttons beside it.
     */
    onSelect?: () => void;
    /** With `onSelect`, marks the row chosen and exposes it as pressed. */
    selected?: boolean;
    /** With `onSelect`, an accessible name when the title alone does not say what it does. */
    selectLabel?: string;
    disabled?: boolean;
  };

/**
 * A row in a list of things the person manages: floating apps, custom rules,
 * shortcuts, backups. Put rows in a `Card`, which draws the hairlines.
 */
function ListRow({
  title,
  detail,
  detailMono = false,
  titleMono = false,
  help,
  leading,
  trailing,
  actions,
  revealActions = false,
  onSelect,
  selected,
  selectLabel,
  disabled = false,
  size,
  className,
  ...props
}: ListRowProps) {
  const text = (
    <span className="flex min-w-0 flex-1 flex-col gap-0.5">
      <span
        className={cn(
          "truncate text-fg",
          titleMono ? "font-mono text-mono" : "text-body font-medium",
        )}
      >
        {title}
      </span>
      {detail ? (
        <span
          className={cn(
            "truncate select-text",
            detailMono ? "font-mono text-mono text-fg-tertiary" : "text-small text-fg-secondary",
          )}
        >
          {detail}
        </span>
      ) : null}
    </span>
  );

  const main = onSelect ? (
    <button
      type="button"
      data-row-primary
      disabled={disabled}
      aria-label={selectLabel}
      aria-pressed={selected}
      onClick={onSelect}
      // The button's box stretches over the whole row, under the controls,
      // so the row is one target; its focus ring is drawn on the row.
      className="flex min-w-0 flex-1 items-center gap-3 text-left outline-none after:absolute after:inset-0 after:rounded-[inherit] focus-visible:outline-none"
    >
      {leading}
      {text}
    </button>
  ) : (
    <>
      {leading}
      {text}
    </>
  );

  return (
    <div
      data-slot="list-row"
      data-row=""
      data-selected={selected || undefined}
      aria-disabled={disabled || undefined}
      className={cn(
        rowVariants({ size }),
        onSelect && "hover:bg-hover has-[[data-row-primary]:active]:bg-muted",
        onSelect &&
          "has-[[data-row-primary]:focus-visible]:ring-2 has-[[data-row-primary]:focus-visible]:ring-accent has-[[data-row-primary]:focus-visible]:ring-inset",
        selected && "bg-accent-soft hover:bg-accent-soft",
        disabled && "opacity-50",
        className,
      )}
      {...props}
    >
      {main}
      {help ? (
        <span className="relative z-10 -ml-2 flex">
          <HelpTooltip text={help} />
        </span>
      ) : null}
      {trailing || actions ? (
        // Above the stretched button, so these stay their own targets.
        <div className="relative z-10 ml-auto flex shrink-0 items-center gap-2 pl-2">
          {actions ? (
            <div
              className={cn(
                "flex items-center gap-1",
                revealActions &&
                  "opacity-0 transition-opacity group-focus-within/row:opacity-100 group-hover/row:opacity-100",
              )}
            >
              {actions}
            </div>
          ) : null}
          {trailing}
        </div>
      ) : null}
    </div>
  );
}

/** A band heading a run of rows inside a card, with how many there are: a shortcut group. */
function ListGroupHeader({
  title,
  count,
  trailing,
  level = 3,
  className,
  ...props
}: Omit<ComponentProps<"div">, "title"> & {
  title: string;
  count?: number;
  trailing?: ReactNode;
  /** The heading level in the page's outline. */
  level?: 2 | 3 | 4;
}) {
  const Heading = `h${level}` as const;
  return (
    <div
      data-slot="list-group-header"
      data-row=""
      className={cn("flex items-center gap-2 bg-side px-5 py-2", className)}
      {...props}
    >
      <Heading className="line-clamp-2 text-caption font-semibold tracking-[0.05em] text-fg-tertiary uppercase">
        {title}
      </Heading>
      {count === undefined ? null : <CountBadge count={count} />}
      {trailing ? <div className="ml-auto flex items-center gap-2">{trailing}</div> : null}
    </div>
  );
}

export { ListGroupHeader, ListRow, rowVariants as listRowVariants };
