import { RotateCcw } from "lucide-react";
import { type ComponentProps, type ReactNode, useId } from "react";

import { Button } from "~/components/ui/button";
import { HelpTooltip } from "~/components/ui/help-tooltip";
import { Tooltip } from "~/components/ui/tooltip";
import { cn } from "~/lib/cn";

/**
 * A titled card of rows. Rows are plain children; the hairline between them
 * is drawn here, inset to the text column, so no page can get it half right.
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
    <section
      aria-labelledby={title ? titleId : undefined}
      className={cn("flex flex-col gap-2", className)}
      {...props}
    >
      {title ? (
        <div className="flex min-h-[22px] items-center gap-2 px-1">
          <h3 id={titleId} className="text-card-title text-fg-secondary">
            {title}
          </h3>
          {help ? <HelpTooltip text={help} /> : null}
          {action ? <div className="ml-auto flex items-center gap-1">{action}</div> : null}
        </div>
      ) : null}
      <SettingsCard
        aria-disabled={disabled || undefined}
        className={cn("transition-opacity duration-snappy", disabled && "opacity-50")}
      >
        {children}
      </SettingsCard>
    </section>
  );
}

function SettingsCard({ className, ...props }: ComponentProps<"div">) {
  return (
    <div
      data-slot="settings-card"
      className={cn(
        "rounded-card border border-hairline bg-card",
        "[&>*+*]:relative [&>*+*]:before:absolute [&>*+*]:before:inset-x-0 [&>*+*]:before:top-0 [&>*+*]:before:left-4 [&>*+*]:before:h-px [&>*+*]:before:bg-hairline",
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
      className={cn("flex flex-col gap-3 px-4 py-3", className)}
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
    <Button
      variant="ghost"
      size="sm"
      data-slot="section-action"
      className={cn("h-[22px] px-1.5 text-fg-secondary hover:text-fg [&_svg]:size-3", className)}
      {...props}
    >
      {icon}
      {children}
    </Button>
  );
  return tooltip ? <Tooltip content={tooltip}>{button}</Tooltip> : button;
}

export { CardContent, SectionAction, SettingsCard, SettingsSection };
