import { Search, SquareTerminal } from "lucide-react";

import { Button } from "~/components/ui/button";
import { Kbd } from "~/components/ui/kbd";
import { Tooltip } from "~/components/ui/tooltip";
import { cn } from "~/lib/cn";

import { TITLEBAR_HEIGHT, titlebarControl } from "./use-titlebar-report";

/**
 * The strip along the top of the pane, which is also the window's drag
 * area. Search is centred; service status and the console sit at the end.
 */
export function TopBar({
  services,
  onSearch,
  onServices,
  onConsole,
}: {
  services: { running: number; total: number };
  onSearch: () => void;
  onServices: () => void;
  onConsole: () => void;
}) {
  const allRunning = services.running === services.total;
  const summary = `${services.running} of ${services.total} services running`;
  return (
    <div
      data-titlebar-region
      className="relative flex shrink-0 items-center border-b border-hairline bg-bar"
      style={{ height: TITLEBAR_HEIGHT }}
    >
      <div className="flex flex-1 justify-center px-[120px]">
        <Tooltip content="Search themes, settings and actions">
          <button
            type="button"
            {...titlebarControl}
            aria-label="Search"
            aria-keyshortcuts="Meta+K"
            onClick={onSearch}
            className="flex h-7 w-full max-w-80 items-center gap-2 rounded-full border border-hairline bg-well px-3 text-fg-secondary transition-colors hover:bg-hover"
          >
            <Search aria-hidden className="size-3" strokeWidth={2.25} />
            <span className="text-row-title">Search</span>
            <Kbd className="ml-auto">⌘K</Kbd>
          </button>
        </Tooltip>
      </div>

      <div className="absolute inset-y-0 right-3 flex items-center gap-0.5">
        <Tooltip content={summary} describe={false}>
          <button
            type="button"
            {...titlebarControl}
            aria-label={summary}
            onClick={onServices}
            className="flex h-6 items-center gap-1.5 rounded-full bg-well px-2 transition-colors hover:bg-hover"
          >
            <span
              aria-hidden
              className={cn("size-[7px] rounded-full", allRunning ? "bg-success" : "bg-warning")}
            />
            <span className="text-meta text-fg-secondary tabular-nums">
              {services.running}/{services.total}
            </span>
          </button>
        </Tooltip>
        <Tooltip content="Show the console" describe={false}>
          <Button
            {...titlebarControl}
            variant="bar"
            size="icon-bar"
            aria-label="Show the console"
            onClick={onConsole}
          >
            <SquareTerminal aria-hidden strokeWidth={2} />
          </Button>
        </Tooltip>
      </div>
    </div>
  );
}
