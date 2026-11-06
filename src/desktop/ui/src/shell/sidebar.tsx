import { Sparkles } from "lucide-react";
import type { KeyboardEvent } from "react";

import type { AppearanceMode, PaneId } from "~/bridge/protocol";
import { Tooltip } from "~/components/ui/tooltip";
import { WhatsNewCard } from "~/features/changelog/whats-new-card";
import { cn } from "~/lib/cn";

import type { ShellAction } from "./actions";
import { BrandMenu } from "./brand-menu";
import { NavItem } from "./nav-item";
import { groups, overview, type Route } from "./panes";

export const SIDEBAR_WIDTH = 232;
/** Rail items centre on x = 28: an 8px inset either side of 40px buttons, plus the border. */
export const RAIL_WIDTH = 57;

/**
 * Arrow keys walk the rows the way a system sidebar does. They move focus
 * rather than selection, so stepping past a page does not open it.
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
  collapsed,
  route,
  issues,
  onSelect,
  version,
  model,
  fresh,
  cardDismissed,
  mode,
  menuOpen,
  onMenuOpenChange,
  onMode,
  onAction,
  onChangelog,
  onDismissCard,
}: {
  collapsed: boolean;
  route: Route;
  /** Setup health's checks to fix, once it has run. */
  issues: number | null;
  onSelect: (pane: PaneId) => void;
  version: string;
  model: string | null;
  /** A release the person has not opened the changelog for. */
  fresh: boolean;
  cardDismissed: boolean;
  mode: AppearanceMode;
  menuOpen: boolean;
  onMenuOpenChange: (open: boolean) => void;
  onMode: (mode: AppearanceMode) => void;
  onAction: (action: ShellAction) => void;
  onChangelog: () => void;
  onDismissCard: () => void;
}) {
  const row = (id: PaneId) => (
    <NavItem
      key={id}
      id={id}
      active={route === id}
      collapsed={collapsed}
      issues={id === "health" ? issues : null}
      onSelect={onSelect}
    />
  );

  return (
    <aside
      aria-label="Sidebar"
      className="relative z-20 flex shrink-0 flex-col border-r border-hairline bg-side transition-[width] duration-200 ease-out"
      style={{ width: collapsed ? RAIL_WIDTH : SIDEBAR_WIDTH }}
    >
      <div
        className={cn(
          "px-2 pb-2 transition-[padding] duration-200 ease-out",
          collapsed ? "px-[8px] pt-2.5" : "pt-0.5",
        )}
      >
        <BrandMenu
          collapsed={collapsed}
          subtitle={model}
          fresh={fresh}
          mode={mode}
          open={menuOpen}
          onOpenChange={onMenuOpenChange}
          onMode={onMode}
          onAction={onAction}
        />
      </div>

      {/* oxlint-disable-next-line jsx-a11y/no-noninteractive-element-interactions -- the handler only moves focus between the buttons inside. */}
      <nav
        aria-label="Settings"
        onKeyDown={walk}
        className={cn(
          "min-h-0 flex-1 overflow-x-hidden overflow-y-auto py-1 [scrollbar-width:none]",
          collapsed ? "px-[8px]" : "px-2",
        )}
      >
        <ul className="flex flex-col gap-0.5">{overview.map(row)}</ul>
        {groups.map((group) => (
          <section key={group.title} aria-label={group.title} className="mt-1">
            <div aria-hidden className="relative h-7">
              <span
                className={cn(
                  "absolute bottom-1 left-[12.5px] text-[11px] font-medium tracking-[0.01em] whitespace-nowrap text-fg-tertiary transition-opacity duration-150",
                  collapsed ? "opacity-0" : "opacity-100",
                )}
              >
                {group.title}
              </span>
              <span
                className={cn(
                  "absolute top-[10px] left-[10px] h-px w-[20px] bg-line-strong transition-opacity duration-150",
                  collapsed ? "opacity-100" : "opacity-0",
                )}
              />
            </div>
            <ul className="flex flex-col gap-0.5">{group.panes.map(row)}</ul>
          </section>
        ))}
      </nav>

      <WhatsNewCard
        visible={!collapsed && !cardDismissed}
        fresh={fresh}
        onOpen={onChangelog}
        onDismiss={onDismissCard}
      />

      <div className={cn("border-t border-hairline py-3", collapsed ? "px-[8px]" : "px-2")}>
        <Tooltip
          content={fresh ? `What's new in ${version}` : `Version ${version}, up to date`}
          side="right"
          disabled={!collapsed}
          describe={false}
        >
          <button
            type="button"
            onClick={onChangelog}
            aria-label={collapsed ? `Version ${version}, open the changelog` : undefined}
            className={cn(
              "flex h-[18px] items-center gap-2 overflow-hidden rounded-[5px] pl-[17px] text-left text-[12px] whitespace-nowrap text-fg-secondary transition-[width,color] duration-200 ease-out hover:text-fg focus-visible:ring-2 focus-visible:ring-accent focus-visible:outline-none",
              collapsed ? "w-[40px] justify-center gap-0 pl-0" : "w-full",
            )}
          >
            <span className="relative size-1.5 shrink-0 rounded-full bg-success">
              <Sparkles
                aria-hidden
                size={9}
                strokeWidth={2.25}
                className={cn(
                  "absolute -top-[7px] -right-2 text-accent transition-opacity duration-150",
                  fresh && collapsed ? "opacity-100" : "opacity-0",
                )}
              />
            </span>
            <span
              aria-hidden={collapsed}
              className={cn(
                "flex min-w-0 flex-1 items-center gap-2 transition-opacity duration-150",
                collapsed ? "hidden" : "opacity-100",
              )}
            >
              {/* Mock: "up to date" until the app can check for releases. */}
              <span className="flex-1 truncate tabular-nums">Version {version}, up to date</span>
              {fresh && cardDismissed ? (
                <span className="mr-2 size-1.5 shrink-0 rounded-full bg-accent">
                  <span className="sr-only">, what's new</span>
                </span>
              ) : null}
            </span>
          </button>
        </Tooltip>
      </div>
    </aside>
  );
}
