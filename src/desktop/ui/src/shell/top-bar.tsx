import { ChevronLeft, ChevronRight, PanelLeft, ScrollText, Search, X } from "lucide-react";
import { type ReactNode, type RefObject, useCallback, useLayoutEffect, useState } from "react";

import type { PageSearch } from "~/components/layout/page-chrome";
import { IconButton } from "~/components/ui/icon-button";
import { PreviewTag } from "~/components/ui/preview-tag";
import { Tooltip } from "~/components/ui/tooltip";
import { cn } from "~/lib/cn";
import { observeResize } from "~/lib/observe-resize";

import { previewPanes, type Route, routeGroup, routeTitle } from "./panes";
import { RAIL_WIDTH, SIDEBAR_WIDTH } from "./sidebar";
import { type TopBarFit, topBarFit } from "./top-bar-fit";
import { TITLEBAR_HEIGHT, titlebarControl } from "./use-titlebar-report";

/** Room for the close, minimise and zoom buttons macOS draws over the corner. */
const TRAFFIC_LIGHT_GUTTER = 78;
/** Collapsed, the corner's controls run past the rail and into the bar. */
const COLLAPSED_CORNER = 176;

const field =
  "flex h-8 w-full items-center gap-2 rounded-[7px] border border-hairline bg-side px-2.5 text-[13px] text-fg-tertiary transition-colors hover:border-line-strong";

const keyChip =
  "rounded-[4px] border border-hairline bg-page px-1.5 text-[11px] font-medium text-fg-secondary";

/**
 * The strip along the top of the window, which is also its drag area: the
 * corner with the sidebar toggle and history, then the breadcrumb, search
 * and the window's status on the page's own column. Every control carries
 * `titlebarControl` so the host lets clicks through to it.
 */
export function TopBar({
  collapsed,
  onToggleSidebar,
  canBack,
  canForward,
  onBack,
  onForward,
  route,
  search,
  onPalette,
  services,
  setActionsSlot,
  logsOpen,
  logFailures,
  logsButton,
  onLogs,
}: {
  collapsed: boolean;
  onToggleSidebar: () => void;
  canBack: boolean;
  canForward: boolean;
  onBack: () => void;
  onForward: () => void;
  route: Route;
  /** The page's own filter; without one the field opens the command palette. */
  search: PageSearch | null;
  onPalette: () => void;
  services: ReactNode;
  setActionsSlot: (element: HTMLDivElement | null) => void;
  logsOpen: boolean;
  /** Failures logged since the panel was last open. */
  logFailures: number;
  logsButton: RefObject<HTMLButtonElement | null>;
  onLogs: () => void;
}) {
  const [header, setHeader] = useState<HTMLElement | null>(null);
  const [slot, setSlot] = useState<HTMLDivElement | null>(null);
  const [fit, setFit] = useState<TopBarFit>(() => topBarFit(Number.POSITIVE_INFINITY, 0));
  // Opened from the search icon when the bar is too narrow for the field.
  const [searchOpen, setSearchOpen] = useState(false);
  // Each page starts with the bar's search closed.
  const [searchRoute, setSearchRoute] = useState(route);
  if (searchRoute !== route) {
    setSearchRoute(route);
    setSearchOpen(false);
  }
  const actionsRef = useCallback(
    (element: HTMLDivElement | null) => {
      setSlot(element);
      setActionsSlot(element);
    },
    [setActionsSlot],
  );

  useLayoutEffect(() => {
    if (!header || !slot) return;
    const measure = () => {
      const next = topBarFit(header.clientWidth, slot.offsetWidth);
      setFit((current) =>
        current.group === next.group &&
        current.searchField === next.searchField &&
        current.logsLabel === next.logsLabel &&
        current.padding === next.padding
          ? current
          : next,
      );
    };
    measure();
    const stopHeader = observeResize(header, measure);
    const stopSlot = observeResize(slot, measure);
    return () => {
      stopHeader();
      stopSlot();
    };
  }, [header, slot]);

  const group = fit.group ? routeGroup(route) : null;
  const preview = route !== "changelog" && previewPanes.has(route);
  const fieldShown = fit.searchField || (search !== null && (searchOpen || search.value !== ""));
  return (
    <div
      data-titlebar-region
      className="relative z-30 flex shrink-0"
      style={{ height: TITLEBAR_HEIGHT }}
    >
      <div
        className={cn(
          "relative z-10 shrink-0 border-r border-b transition-[width,background-color,border-color] duration-200 ease-out",
          collapsed
            ? "border-r-transparent border-b-hairline bg-page"
            : "border-r-hairline border-b-transparent bg-side",
        )}
        style={{ width: collapsed ? RAIL_WIDTH : SIDEBAR_WIDTH }}
      >
        <div
          className="absolute inset-y-0 left-0 flex items-center justify-end gap-0.5 pr-2.5 transition-[width] duration-200 ease-out"
          style={{
            paddingLeft: TRAFFIC_LIGHT_GUTTER,
            width: collapsed ? COLLAPSED_CORNER : SIDEBAR_WIDTH,
          }}
        >
          <IconButton
            {...titlebarControl}
            label={collapsed ? "Show sidebar" : "Hide sidebar"}
            keys="⌘\"
            size="md"
            pressed={!collapsed}
            aria-keyshortcuts="Meta+\ Control+Meta+S"
            onClick={onToggleSidebar}
          >
            <PanelLeft aria-hidden size={15} strokeWidth={1.75} />
          </IconButton>
          <IconButton
            {...titlebarControl}
            label="Back"
            keys="⌘["
            size="md"
            disabled={!canBack}
            onClick={onBack}
          >
            <ChevronLeft aria-hidden size={16} strokeWidth={1.75} />
          </IconButton>
          <IconButton
            {...titlebarControl}
            label="Forward"
            keys="⌘]"
            size="md"
            disabled={!canForward}
            onClick={onForward}
          >
            <ChevronRight aria-hidden size={16} strokeWidth={1.75} />
          </IconButton>
        </div>
      </div>

      <header ref={setHeader} className="min-w-0 flex-1 border-b border-hairline bg-page">
        <div
          className={cn(
            "mx-auto grid h-full max-w-[900px] items-center transition-[padding] duration-200 ease-out",
            fit.searchField
              ? "grid-cols-[minmax(72px,1fr)_minmax(120px,280px)_minmax(max-content,1fr)] gap-4"
              : fieldShown
                ? "grid-cols-[minmax(0,1fr)_max-content] gap-2"
                : "grid-cols-[minmax(0,1fr)_max-content_max-content] gap-2",
          )}
          style={{
            paddingInline: fit.padding,
            ...(collapsed
              ? {
                  paddingLeft: `max(${fit.padding}px, calc(${COLLAPSED_CORNER - RAIL_WIDTH + 12}px - max(0px, (100% - 900px) / 2)))`,
                }
              : null),
          }}
        >
          <nav
            aria-label="Breadcrumb"
            className={cn(
              "min-w-0 items-center gap-1.5 text-[13px]",
              fieldShown && !fit.searchField ? "hidden" : "flex",
            )}
          >
            {group ? (
              <>
                <span className="truncate text-fg-tertiary">{group}</span>
                <ChevronRight aria-hidden size={13} className="shrink-0 text-fg-tertiary" />
              </>
            ) : null}
            <span aria-current="page" className="truncate font-medium text-fg">
              {routeTitle(route)}
            </span>
            {preview && fit.group ? <PreviewTag size="md" /> : null}
          </nav>

          {!fieldShown ? (
            <IconButton
              {...titlebarControl}
              label={search ? search.placeholder : "Search settings"}
              keys="⌘K"
              size="md"
              aria-keyshortcuts="Meta+K"
              onClick={search ? () => setSearchOpen(true) : onPalette}
            >
              <Search aria-hidden size={15} strokeWidth={1.75} />
            </IconButton>
          ) : search ? (
            <label
              {...titlebarControl}
              className={cn(
                field,
                "focus-within:border-accent focus-within:ring-[3px] focus-within:ring-accent-soft",
              )}
            >
              <Search aria-hidden size={14} className="shrink-0" />
              <input
                type="text"
                // A field opened from the narrow bar's icon is there to type in.
                // oxlint-disable-next-line jsx-a11y/no-autofocus -- it appears only because the search icon was pressed.
                autoFocus={!fit.searchField}
                onBlur={() => {
                  if (!search.value) setSearchOpen(false);
                }}
                value={search.value}
                aria-label={search.placeholder}
                placeholder={search.placeholder}
                onChange={(event) => search.onChange(event.target.value)}
                onKeyDown={(event) => {
                  if (event.key !== "Escape") return;
                  if (search.value) {
                    event.stopPropagation();
                    search.onChange("");
                  } else if (!fit.searchField) {
                    event.stopPropagation();
                    setSearchOpen(false);
                  }
                }}
                className="min-w-0 flex-1 bg-transparent text-fg outline-none placeholder:text-fg-tertiary"
              />
              {search.value ? (
                <button
                  type="button"
                  aria-label="Clear search"
                  onClick={() => search.onChange("")}
                  className="grid size-[18px] shrink-0 place-items-center rounded-full text-fg-tertiary hover:bg-hover hover:text-fg"
                >
                  <X aria-hidden size={11} />
                </button>
              ) : (
                <Tooltip content="Search all settings" keys="⌘K" describe={false}>
                  <button
                    type="button"
                    aria-label="Search all settings"
                    aria-keyshortcuts="Meta+K"
                    onClick={onPalette}
                    className={cn(keyChip, "shrink-0 hover:text-fg")}
                  >
                    ⌘K
                  </button>
                </Tooltip>
              )}
            </label>
          ) : (
            <button
              {...titlebarControl}
              type="button"
              aria-keyshortcuts="Meta+K"
              onClick={onPalette}
              className={cn(
                field,
                "hover:text-fg-secondary focus-visible:ring-2 focus-visible:ring-accent focus-visible:outline-none",
              )}
            >
              <Search aria-hidden size={14} className="shrink-0" />
              <span className="flex-1 truncate text-left">Search settings...</span>
              <span aria-hidden className={keyChip}>
                ⌘K
              </span>
            </button>
          )}

          <div className="flex items-center justify-end gap-1.5 whitespace-nowrap">
            {services}
            <div
              ref={actionsRef}
              {...titlebarControl}
              className="flex items-center gap-1.5 empty:hidden"
            />
            <Tooltip content={logsOpen ? "Hide logs" : "Show logs"} keys="⇧⌘L" describe={false}>
              <button
                ref={logsButton}
                {...titlebarControl}
                type="button"
                aria-pressed={logsOpen}
                aria-keyshortcuts="Shift+Meta+L"
                onClick={onLogs}
                className={cn(
                  "relative flex h-8 items-center gap-1.5 rounded-[7px] text-[13px] font-medium transition-colors focus-visible:ring-2 focus-visible:ring-accent focus-visible:outline-none",
                  fit.logsLabel ? "px-2.5" : "px-2",
                  logsOpen
                    ? "bg-muted text-fg ring-1 ring-hairline"
                    : "text-fg-secondary hover:bg-hover hover:text-fg",
                )}
              >
                <ScrollText aria-hidden size={14} strokeWidth={1.75} />
                <span className={fit.logsLabel ? undefined : "sr-only"}>Logs</span>
                {logFailures > 0 ? (
                  <span className="size-1.5 rounded-full bg-danger">
                    <span className="sr-only">
                      , {logFailures} {logFailures === 1 ? "new failure" : "new failures"}
                    </span>
                  </span>
                ) : null}
              </button>
            </Tooltip>
          </div>
        </div>
      </header>
    </div>
  );
}
