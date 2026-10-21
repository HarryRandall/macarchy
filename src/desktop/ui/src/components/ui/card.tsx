import type { ComponentProps, ReactNode } from "react";

import { cn } from "~/lib/cn";

import { HelpTooltip } from "./help-tooltip";

/*
 * Rows mark themselves `data-row`, so a card or a run of rows draws the
 * hairline between neighbours and rounds the first and last row's hover
 * wash to the card's inner corner (its radius less the border).
 */
const rowEdges =
  "[&>[data-row]+[data-row]]:border-t [&>[data-row]+[data-row]]:border-hairline [&>[data-row]:first-child]:rounded-t-[9px] [&>[data-row]:last-child]:rounded-b-[9px]";

/** The card's raised surface, for a wrapper that cannot be a `Card` element. */
const cardSurface = "min-w-0 rounded-card border border-hairline bg-card shadow-card";

/** A raised surface holding a header and rows, a chart or free content. */
function Card({ className, ...props }: ComponentProps<"section">) {
  return <section data-slot="card" className={cn(cardSurface, rowEdges, className)} {...props} />;
}

/**
 * A card's title, with an optional glyph before it, a line of description
 * and an action at the trailing end, such as Reset or a segmented choice.
 */
function CardHeader({
  title,
  description,
  icon,
  action,
  help,
  level = 2,
  id,
  className,
}: {
  title: ReactNode;
  description?: ReactNode;
  /** An `IconTile` before the title. */
  icon?: ReactNode;
  action?: ReactNode;
  /** Secondary explanation behind a help glyph after the title. */
  help?: string;
  /** The heading level in the page's outline: 3 under a `SectionLabel`. */
  level?: 2 | 3 | 4;
  /** For `aria-labelledby` on the card. */
  id?: string;
  className?: string;
}) {
  const Heading = `h${level}` as const;
  return (
    <header
      data-slot="card-header"
      className={cn(
        "flex min-w-0 justify-between gap-3 px-5 pt-4 pb-3",
        description ? "items-start" : "items-center",
        className,
      )}
    >
      <div className="flex min-w-0 items-start gap-3">
        {icon}
        <div className="min-w-0">
          <div className="flex min-h-5 items-center gap-1">
            <Heading id={id} className="text-card-title text-fg">
              {title}
            </Heading>
            {help ? <HelpTooltip text={help} /> : null}
          </div>
          {description ? (
            <p className="mt-0.5 text-detail text-fg-secondary">{description}</p>
          ) : null}
        </div>
      </div>
      {action ? <div className="flex shrink-0 items-center gap-1.5">{action}</div> : null}
    </header>
  );
}

/** Free content padded to the card's text column: a chart, a form, a code block. */
function CardBody({ className, ...props }: ComponentProps<"div">) {
  return (
    <div
      data-slot="card-body"
      className={cn("min-w-0 px-5 pb-4 first:pt-4", className)}
      {...props}
    />
  );
}

/** Rows under a `CardHeader`, ruled off from it and from each other. */
function CardRows({ className, ...props }: ComponentProps<"div">) {
  return (
    <div
      data-slot="card-rows"
      className={cn(
        "border-t border-hairline first:border-t-0",
        "[&>*+*]:border-t [&>*+*]:border-hairline [&>*:last-child]:rounded-b-[9px]",
        className,
      )}
      {...props}
    />
  );
}

/**
 * One setting: a title with an optional description, and its control at the
 * trailing end. The control wraps under the title when the card is narrow.
 * Pass the control as `control` or as the children; with `control`, the
 * children are drawn under the row's first line, such as a hint or a list.
 */
function Row({
  title,
  description,
  control,
  help,
  controlId,
  leading,
  className,
  children,
  ...props
}: Omit<ComponentProps<"div">, "title"> & {
  title: ReactNode;
  /** Values or essential status, always visible. */
  description?: ReactNode;
  control?: ReactNode;
  /** Secondary explanation behind a help glyph after the title. */
  help?: string;
  /** When the control is a native input, ties the title to it as its label. */
  controlId?: string;
  /** An icon or `IconTile` before the title. */
  leading?: ReactNode;
}) {
  const Title = controlId ? "label" : "span";
  const trailing = control === undefined ? children : control;
  const below = control === undefined ? null : children;
  return (
    <div
      data-slot="row"
      data-row=""
      className={cn("flex min-w-0 flex-col gap-2.5 px-5 py-3.5", className)}
      {...props}
    >
      <div className="flex min-w-0 flex-wrap items-center gap-x-6 gap-y-2.5">
        <div className="flex min-w-0 flex-1 basis-48 items-center gap-3">
          {leading}
          <div className="min-w-0">
            <div className="flex min-w-0 items-center gap-1">
              <Title htmlFor={controlId} className="text-body font-medium text-fg">
                {title}
              </Title>
              {help ? <HelpTooltip text={help} /> : null}
            </div>
            {description ? (
              <div className="mt-0.5 text-small text-fg-secondary">{description}</div>
            ) : null}
          </div>
        </div>
        {trailing ? (
          <div className="ml-auto flex max-w-full min-w-0 shrink-0 items-center gap-2">
            {trailing}
          </div>
        ) : null}
      </div>
      {below}
    </div>
  );
}

/** Small capitals over a run of cards or a grid: Enabled, Insights, Other themes. */
function SectionLabel({
  children,
  action,
  level = 2,
  id,
  className,
}: {
  children: ReactNode;
  action?: ReactNode;
  level?: 2 | 3 | 4;
  id?: string;
  className?: string;
}) {
  const Heading = `h${level}` as const;
  return (
    <div
      data-slot="section-label"
      className={cn("mb-2.5 flex min-h-6 items-center justify-between gap-3", className)}
    >
      <Heading id={id} className="min-w-0 truncate text-label text-fg-tertiary uppercase">
        {children}
      </Heading>
      {action ? <div className="flex shrink-0 items-center gap-1.5">{action}</div> : null}
    </div>
  );
}

export { Card, CardBody, CardHeader, CardRows, cardSurface, Row, SectionLabel };
