import type { ReactNode } from "react";

import { AppIcon } from "~/components/ui/app-icon";
import { Tooltip } from "~/components/ui/tooltip";
import { TruncatedText } from "~/components/ui/truncated-text";
import { cn } from "~/lib/cn";

/**
 * One app per row: its icon, name and badges, a line under the name, and
 * controls at the trailing end. With `onOpen` the name area is a button that
 * stretches under the controls, so the whole row opens its editor.
 */
export function AppRow({
  app,
  icon,
  detail,
  detailMono = false,
  badge,
  muted = false,
  hot = false,
  onHot,
  onOpen,
  openLabel,
  disabled = false,
  children,
}: {
  app: string;
  icon?: string | null;
  detail?: string;
  detailMono?: boolean;
  badge?: ReactNode;
  /** Drawn quieter and in grey, for a paused rule. */
  muted?: boolean;
  /** Lit because the same app is pointed at in another card. */
  hot?: boolean;
  onHot?: (app: string | null) => void;
  onOpen?: () => void;
  /** The open button's name and tooltip: "Edit rule for Finder". */
  openLabel?: string;
  disabled?: boolean;
  children?: ReactNode;
}) {
  const body = (
    <>
      <AppIcon
        src={icon}
        name={app}
        size={36}
        className={cn("transition-[filter,opacity]", muted && "opacity-55 grayscale")}
      />
      <span className="flex min-w-0 flex-1 flex-col">
        <span className="flex min-w-0 items-center gap-2">
          <span
            className={cn(
              "min-w-0 truncate text-body font-medium",
              muted ? "text-fg-secondary" : "text-fg",
            )}
          >
            {app}
          </span>
          {badge}
        </span>
        {detail ? (
          <TruncatedText
            key={detail}
            text={detail}
            className={cn(
              "mt-0.5 text-fg-tertiary",
              detailMono ? "font-mono text-caption" : "text-small",
            )}
          />
        ) : null}
      </span>
    </>
  );
  return (
    <div
      data-row=""
      data-slot="app-row"
      onMouseEnter={onHot ? () => onHot(app) : undefined}
      onMouseLeave={onHot ? () => onHot(null) : undefined}
      className={cn(
        // Controls wrap under the name when the card is narrow, rather than squeezing it.
        "relative flex min-h-[60px] min-w-0 flex-wrap items-center gap-x-3 gap-y-2 px-5 py-2.5 transition-colors duration-150",
        onOpen && !disabled && "hover:bg-hover",
        onOpen &&
          "has-[[data-row-primary]:focus-visible]:ring-2 has-[[data-row-primary]:focus-visible]:ring-accent has-[[data-row-primary]:focus-visible]:ring-inset",
        hot && "bg-hover/70",
      )}
    >
      {onOpen ? (
        <Tooltip content={openLabel ?? app} describe={false}>
          <button
            type="button"
            data-row-primary
            aria-label={openLabel}
            disabled={disabled}
            onClick={onOpen}
            // The box stretches over the row, under the controls, so the row is one target.
            className="flex min-w-40 flex-1 items-center gap-3 rounded-[inherit] text-left outline-none after:absolute after:inset-0 after:rounded-[inherit]"
          >
            {body}
          </button>
        </Tooltip>
      ) : (
        <div className="flex min-w-40 flex-1 items-center gap-3">{body}</div>
      )}
      {children ? (
        <div className="relative z-10 ml-auto flex shrink-0 items-center gap-2">{children}</div>
      ) : null}
    </div>
  );
}

/** A card's empty list: a dashed tile and what is missing. */
export function CardEmpty({ icon, title }: { icon: ReactNode; title: string }) {
  return (
    <div data-row="" className="flex items-center gap-3 px-5 py-5">
      <span
        aria-hidden
        className="grid size-9 shrink-0 place-items-center rounded-tile border border-dashed border-line-strong text-fg-tertiary [&_svg]:size-4"
      >
        {icon}
      </span>
      <p className="text-body font-medium text-fg">{title}</p>
    </div>
  );
}
