import { ArrowRight } from "lucide-react";
import type { ComponentProps, ReactNode } from "react";

import { cn } from "~/lib/cn";

import { focusRing } from "./focus-ring";
import { IconTile, type Tint } from "./icon-tile";

/** A navigation shortcut with an icon and a short description, as on Home. */
export function OverviewActionCard({
  title,
  detail,
  icon,
  tint,
  trailing,
  className,
  ...props
}: Omit<ComponentProps<"button">, "title"> & {
  title: string;
  detail: string;
  icon: ReactNode;
  tint: Tint;
  /** After the title, such as a `PreviewTag`. */
  trailing?: ReactNode;
}) {
  return (
    <button
      type="button"
      className={cn(
        "group flex min-h-[78px] min-w-0 items-start gap-3 rounded-card border border-hairline bg-card p-4 text-left shadow-card",
        "transition-[border-color,box-shadow,transform] duration-150 hover:-translate-y-px hover:border-line-strong active:translate-y-0",
        "disabled:pointer-events-none disabled:opacity-50",
        focusRing,
        className,
      )}
      {...props}
    >
      <IconTile tint={tint} size="lg">
        {icon}
      </IconTile>
      <span className="flex min-w-0 flex-1 flex-col gap-0.5">
        <span className="flex min-w-0 items-center gap-2">
          <span className="truncate text-body font-semibold tracking-[-0.01em] text-fg">
            {title}
          </span>
          {trailing}
        </span>
        <span className="text-small text-fg-secondary">{detail}</span>
      </span>
      <ArrowRight
        aria-hidden
        className="mt-0.5 size-3.5 shrink-0 -translate-x-0.5 text-fg-tertiary opacity-0 transition-[opacity,transform] duration-150 group-hover:translate-x-0 group-hover:opacity-100 group-focus-visible:opacity-100"
      />
    </button>
  );
}
