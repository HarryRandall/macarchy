import { useId } from "react";

import type { PaneId } from "~/bridge/protocol";
import { PreviewTag } from "~/components/ui/preview-tag";
import { Tooltip } from "~/components/ui/tooltip";
import { cn } from "~/lib/cn";

import { panes, previewPanes } from "./panes";

/**
 * One sidebar row. Collapsed to the rail it keeps its icon in place and
 * names itself in a tooltip.
 */
export function NavItem({
  id,
  active,
  collapsed,
  issues,
  onSelect,
}: {
  id: PaneId;
  active: boolean;
  collapsed: boolean;
  /** Setup health's count of checks to fix; zero or null hides the badge. */
  issues?: number | null;
  onSelect: (pane: PaneId) => void;
}) {
  const { title, icon: Icon } = panes[id];
  const warn = (issues ?? 0) > 0;
  const preview = previewPanes.has(id);
  // The name is always the page's title, so it stays the same expanded or
  // collapsed; the preview label and the issue count are its description.
  const detailId = useId();
  const detail = [preview ? "Preview" : null, warn ? `${issues} to fix` : null]
    .filter(Boolean)
    .join(", ");
  return (
    <li>
      <Tooltip
        content={title}
        keys={warn ? `${issues} to fix` : undefined}
        side="right"
        disabled={!collapsed}
        describe={false}
      >
        <button
          type="button"
          data-pane-row
          onClick={() => onSelect(id)}
          aria-current={active ? "page" : undefined}
          aria-label={title}
          aria-describedby={detail ? detailId : undefined}
          className={cn(
            "group relative flex h-[30px] items-center gap-2.5 overflow-hidden rounded-[8px] px-[12.5px] text-[13px] tracking-[-0.01em] whitespace-nowrap transition-[background-color,color,width] duration-200 ease-out focus-visible:ring-2 focus-visible:ring-accent focus-visible:outline-none",
            collapsed ? "w-[40px] justify-center gap-0 px-0" : "w-full",
            active
              ? "bg-card font-medium text-fg shadow-card ring-1 ring-hairline"
              : "text-fg-secondary hover:bg-hover hover:text-fg",
          )}
        >
          <span className="relative shrink-0">
            <Icon
              aria-hidden
              size={15}
              strokeWidth={1.75}
              className={cn("block", active ? "text-accent-text" : "text-fg-tertiary")}
            />
            {warn ? (
              <span
                aria-hidden
                className={cn(
                  "absolute -top-[3px] -right-[3px] size-[7px] rounded-full bg-warning ring-2 transition-opacity duration-150",
                  active ? "ring-card" : "ring-side group-hover:ring-hover",
                  collapsed ? "opacity-100" : "opacity-0",
                )}
              />
            ) : null}
          </span>
          <span
            aria-hidden={collapsed}
            className={cn(
              "flex min-w-0 flex-1 items-center gap-2 transition-opacity duration-150",
              collapsed ? "hidden" : "opacity-100",
            )}
          >
            <span className="flex-1 truncate text-left">{title}</span>
            {preview ? <PreviewTag /> : null}
            {warn ? (
              <span className="flex h-4 min-w-4 items-center justify-center rounded-full bg-warning-soft px-1 text-[10px] font-semibold tabular-nums text-warning">
                {issues}
              </span>
            ) : null}
          </span>
        </button>
      </Tooltip>
      {detail ? (
        <span id={detailId} className="sr-only">
          {detail}
        </span>
      ) : null}
    </li>
  );
}
