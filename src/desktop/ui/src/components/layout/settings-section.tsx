import { RotateCcw } from "lucide-react";
import { type ComponentProps, type ReactNode, useId } from "react";

import { Button } from "~/components/ui/button";
import { Card, CardHeader, CardRows, cardSurface } from "~/components/ui/card";
import { Tooltip } from "~/components/ui/tooltip";
import { cn } from "~/lib/cn";

/**
 * A titled card of rows: a `Card` with a `CardHeader` and `CardRows`. Rows
 * are plain children; the hairlines between them are drawn here, so no
 * page can get them half right.
 */
function SettingsSection({
  title,
  help,
  action,
  disabled = false,
  children,
  className,
  ...props
}: ComponentProps<"section"> & {
  title?: string;
  help?: string;
  /** At the trailing end of the title line: a `SectionAction` such as Reset. */
  action?: ReactNode;
  /** Dims the whole card, as SwiftUI dims a disabled group. Controls still disable themselves. */
  disabled?: boolean;
}) {
  const titleId = useId();
  return (
    <Card
      aria-labelledby={title ? titleId : undefined}
      aria-disabled={disabled || undefined}
      className={cn("transition-opacity duration-snappy", disabled && "opacity-50", className)}
      {...props}
    >
      {title ? <CardHeader id={titleId} title={title} help={help} action={action} /> : null}
      <CardRows>{children}</CardRows>
    </Card>
  );
}

/** A card of rows with no header, for a list that a `SectionLabel` already names. */
function SettingsCard({ className, ...props }: ComponentProps<"div">) {
  return (
    <div
      data-slot="settings-card"
      className={cn(
        cardSurface,
        "[&>*+*]:border-t [&>*+*]:border-hairline [&>*:first-child]:rounded-t-[9px] [&>*:last-child]:rounded-b-[9px]",
        className,
      )}
      {...props}
    />
  );
}

/**
 * Free content in a card, padded to the rows' text column: a form, a radio
 * group, a code block.
 */
function CardContent({ className, ...props }: ComponentProps<"div">) {
  return (
    <div
      data-slot="card-content"
      className={cn("flex min-w-0 flex-col gap-3 px-5 py-3.5", className)}
      {...props}
    />
  );
}

/**
 * A quiet text button on a section's title line, such as "Reset" or "Clear
 * all". Name what it restores in `aria-label` when the text alone is vague.
 */
function SectionAction({
  icon = <RotateCcw aria-hidden />,
  tooltip,
  className,
  children,
  ...props
}: ComponentProps<"button"> & {
  /** Defaults to the reset arrow; pass `null` for none. */
  icon?: ReactNode;
  tooltip?: string;
}) {
  const button = (
    <Button variant="ghost" size="sm" data-slot="section-action" className={className} {...props}>
      {icon}
      {children}
    </Button>
  );
  return tooltip ? <Tooltip content={tooltip}>{button}</Tooltip> : button;
}

export { CardContent, SectionAction, SettingsCard, SettingsSection };
