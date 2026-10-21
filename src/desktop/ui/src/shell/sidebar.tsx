import { ArrowUpRight } from "lucide-react";
import { type KeyboardEvent, useId } from "react";

import type { PaneId } from "~/bridge/protocol";
import { Tooltip } from "~/components/ui/tooltip";
import { Badge } from "~/components/ui/badge";
import { cn } from "~/lib/cn";

import { BrandMark } from "./brand-mark";
import { groups, overview, panes, previewPanes, reactPanes } from "./panes";
import { TITLEBAR_HEIGHT } from "./use-titlebar-report";

export const SIDEBAR_WIDTH = 210;
export const RAIL_WIDTH = 56;

/**
 * Arrow keys walk the rows the way a system sidebar does. They move focus
 * rather than selection: most rows open the classic window, and stepping
 * past one must not open it.
 */
function walk(event: KeyboardEvent<HTMLElement>) {
  const keys = ["ArrowUp", "ArrowDown", "Home", "End"];
  if (!keys.includes(event.key)) return;
  const rows = [...event.currentTarget.querySelectorAll<HTMLButtonElement>("[data-pane-row]")];
  if (rows.length === 0) return;
  event.preventDefault();
  const index = rows.findIndex((row) => row === document.activeElement);
  const next =
    event.key === "Home"
      ? 0
      : event.key === "End"
        ? rows.length - 1
        : Math.min(Math.max(index + (event.key === "ArrowUp" ? -1 : 1), 0), rows.length - 1);
  rows[index === -1 ? 0 : next]?.focus();
}

export function Sidebar({
  visible,
  selected,
  onSelect,
}: {
  visible: boolean;
  selected: PaneId;
  onSelect: (pane: PaneId) => void;
}) {
  const classicHintId = useId();
  return (
    <aside
      aria-label="Sections"
      className="relative flex h-full shrink-0 flex-col overflow-hidden bg-bar transition-[width] duration-snappy"
      style={{ width: visible ? SIDEBAR_WIDTH : RAIL_WIDTH }}
    >
      {/* Collapsed, the window buttons sit across where this line would run. */}
      <div
        aria-hidden
        className="absolute right-0 bottom-0 w-px bg-hairline transition-[top] duration-snappy"
        style={{ top: visible ? 0 : TITLEBAR_HEIGHT }}
      />
      <span id={classicHintId} className="sr-only">
        Opens in the classic window
      </span>

      <div style={{ height: TITLEBAR_HEIGHT }} className="shrink-0" />

      <div
        className={cn(
          "flex h-[34px] shrink-0 items-center gap-2 px-2",
          visible ? "justify-start" : "justify-center",
        )}
      >
        <BrandMark className="h-6 w-[30px] shrink-0 text-accent-stroke" />
        {visible ? (
          <span className="truncate text-[14px] font-semibold text-fg">Macarchy</span>
        ) : null}
      </div>

      {/* oxlint-disable-next-line jsx-a11y/no-noninteractive-element-interactions -- the handler only moves focus between the buttons inside. */}
      <nav
        aria-label="Settings sections"
        onKeyDown={walk}
        className="flex min-h-0 flex-1 flex-col gap-4 overflow-y-auto px-2 pt-3 pb-2 [scrollbar-width:none]"
      >
        <ul className="flex flex-col gap-0.5">
          {overview.map((id) => (
            <PaneRow
              key={id}
              id={id}
              visible={visible}
              selected={selected === id}
              classicHintId={classicHintId}
              onSelect={onSelect}
            />
          ))}
        </ul>
        {groups.map((group) => (
          <section key={group.title} aria-label={group.title} className="flex flex-col gap-1">
            <div aria-hidden className="relative h-3.5 px-3">
              <span
                className={cn(
                  "absolute inset-x-3 text-eyebrow whitespace-nowrap text-fg-secondary uppercase transition-opacity duration-snappy",
                  visible ? "opacity-100" : "opacity-0",
                )}
              >
                {group.title}
              </span>
              <span
                className={cn(
                  "absolute inset-x-3 top-1/2 h-px bg-hairline transition-opacity duration-snappy",
                  visible ? "opacity-0" : "opacity-100",
                )}
              />
            </div>
            <ul className="flex flex-col gap-0.5">
              {group.panes.map((id) => (
                <PaneRow
                  key={id}
                  id={id}
                  visible={visible}
                  selected={selected === id}
                  classicHintId={classicHintId}
                  onSelect={onSelect}
                />
              ))}
            </ul>
          </section>
        ))}
      </nav>
    </aside>
  );
}

function PaneRow({
  id,
  visible,
  selected,
  classicHintId,
  onSelect,
}: {
  id: PaneId;
  visible: boolean;
  selected: boolean;
  classicHintId: string;
  onSelect: (pane: PaneId) => void;
}) {
  const pane = panes[id];
  const Icon = pane.icon;
  const classic = !reactPanes.has(id);
  const preview = previewPanes.has(id);
  return (
    <li>
      <Tooltip content={pane.title} side="right" disabled={visible || selected} describe={false}>
        <button
          type="button"
          data-pane-row
          aria-label={preview ? `${pane.title}, preview` : pane.title}
          aria-current={selected ? "page" : undefined}
          aria-describedby={classic ? classicHintId : undefined}
          onClick={() => onSelect(id)}
          className={cn(
            "group flex h-[30px] w-full items-center gap-2 rounded-control px-2 transition-[background-color,opacity] active:opacity-75",
            visible ? "justify-start" : "justify-center",
            selected ? "bg-accent-stroke/20" : "hover:bg-hover",
          )}
        >
          <Icon
            aria-hidden
            strokeWidth={2}
            className={cn(
              "size-[15px] w-5 shrink-0",
              selected ? "text-accent-stroke" : "text-fg-secondary",
            )}
          />
          {visible ? (
            <>
              <span
                className={cn(
                  "min-w-0 flex-1 truncate text-left text-row-title",
                  selected ? "font-semibold text-fg" : "text-fg-secondary",
                )}
              >
                {pane.title}
              </span>
              {preview ? (
                <Badge aria-hidden tone="warning">
                  Preview
                </Badge>
              ) : null}
              {classic ? (
                <ArrowUpRight
                  aria-hidden
                  className="size-3 shrink-0 text-fg-secondary opacity-0 transition-opacity group-hover:opacity-100 group-focus-visible:opacity-100"
                />
              ) : null}
            </>
          ) : null}
        </button>
      </Tooltip>
    </li>
  );
}
