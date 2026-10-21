import { ArrowUpRight } from "lucide-react";
import type { ComponentProps, ReactNode } from "react";
import { cn } from "~/lib/cn";
import { IconTile, type Tint } from "./icon-tile";

/** A navigation shortcut with an icon and a short description. */
export function OverviewActionCard({
  title,
  detail,
  icon,
  tint,
  className,
  ...props
}: Omit<ComponentProps<"button">, "title"> & {
  title: string;
  detail: string;
  icon: ReactNode;
  tint: Tint;
}) {
  return (
    <button
      type="button"
      className={cn(
        "group flex min-h-[78px] items-start gap-3 rounded-card border border-hairline bg-card p-4 text-left transition-colors hover:border-accent-stroke hover:bg-hover active:opacity-75 disabled:pointer-events-none disabled:opacity-45",
        className,
      )}
      {...props}
    >
      <IconTile tint={tint}>{icon}</IconTile>
      <span className="flex min-w-0 flex-1 flex-col gap-0.5">
        <span className="text-card-title text-fg">{title}</span>
        <span className="text-row-detail text-fg-secondary">{detail}</span>
      </span>
      <ArrowUpRight aria-hidden className="mt-1 size-3 shrink-0 text-fg-secondary" />
    </button>
  );
}
