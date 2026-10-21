import { Copy, ScrollText, Search, Trash2, X } from "lucide-react";
import {
  type KeyboardEvent,
  type PointerEvent,
  type RefObject,
  useEffect,
  useRef,
  useState,
} from "react";

import type { LogEntry } from "~/bridge/protocol";
import { IconButton } from "~/components/ui/icon-button";
import { SegmentedControl } from "~/components/ui/segmented-control";
import { cn } from "~/lib/cn";

import {
  clampLogHeight,
  countBySource,
  filterLog,
  type LogLevel,
  type LogSource,
  logLevel,
  logSource,
  logSources,
} from "./log-filter";

const levelStyle: Record<LogLevel, { label: string; text: string; row: string }> = {
  info: { label: "INFO", text: "text-fg-tertiary", row: "" },
  error: { label: "ERROR", text: "text-danger", row: "bg-danger-soft" },
};

const levels: { value: LogLevel | "all"; label: string }[] = [
  { value: "all", label: "All" },
  { value: "error", label: "Failures" },
];

const timeFormat = new Intl.DateTimeFormat("en-GB", {
  hour: "2-digit",
  minute: "2-digit",
  second: "2-digit",
  hour12: false,
});

export function formatLogTime(at: number): string {
  return timeFormat.format(new Date(at * 1000));
}

/**
 * The bottom panel listing what Macarchy ran and what came back. The top
 * edge drags or arrow-keys to resize; the height is kept between the
 * panel's minimum and enough room for the page above.
 */
export function LogsPanel({
  open,
  height,
  onHeight,
  entries,
  error,
  onCopy,
  onClear,
  onClose,
  containerRef,
}: {
  open: boolean;
  height: number;
  onHeight: (height: number) => void;
  entries: readonly LogEntry[];
  error: string | null;
  onCopy: (entries: LogEntry[]) => void;
  onClear: () => void;
  onClose: () => void;
  /** The column the panel shares with the page, which bounds its height. */
  containerRef: RefObject<HTMLElement | null>;
}) {
  const [source, setSource] = useState<LogSource | "all">("all");
  const [level, setLevel] = useState<LogLevel | "all">("all");
  const [query, setQuery] = useState("");
  const [dragging, setDragging] = useState(false);
  const body = useRef<HTMLDivElement>(null);
  const shown = filterLog(entries, { source, level, query });
  const counts = countBySource(entries);
  const failures = entries.filter((entry) => !entry.ok).length;
  const available = () => containerRef.current?.clientHeight ?? window.innerHeight;

  useEffect(() => {
    const element = body.current;
    if (open && element) element.scrollTo({ top: element.scrollHeight });
  }, [open, shown.length]);

  // A height saved in a taller window may no longer leave the page any room.
  useEffect(() => {
    if (!open) return;
    const fitted = clampLogHeight(height, containerRef.current?.clientHeight ?? window.innerHeight);
    if (fitted !== height) onHeight(fitted);
  }, [open, height, onHeight, containerRef]);

  const startDrag = (event: PointerEvent<HTMLDivElement>) => {
    event.preventDefault();
    const handle = event.currentTarget;
    handle.setPointerCapture(event.pointerId);
    const startY = event.clientY;
    const startHeight = height;
    setDragging(true);
    const move = (next: globalThis.PointerEvent) =>
      onHeight(clampLogHeight(startHeight + startY - next.clientY, available()));
    const end = () => {
      setDragging(false);
      handle.removeEventListener("pointermove", move);
      handle.removeEventListener("pointerup", end);
      handle.removeEventListener("pointercancel", end);
    };
    handle.addEventListener("pointermove", move);
    handle.addEventListener("pointerup", end);
    handle.addEventListener("pointercancel", end);
  };

  const resizeByKey = (event: KeyboardEvent<HTMLDivElement>) => {
    const step = event.shiftKey ? 64 : 16;
    const next =
      event.key === "ArrowUp"
        ? height + step
        : event.key === "ArrowDown"
          ? height - step
          : event.key === "Home"
            ? 0
            : event.key === "End"
              ? Number.POSITIVE_INFINITY
              : null;
    if (next === null) return;
    event.preventDefault();
    onHeight(clampLogHeight(next, available()));
  };

  const chip = (id: LogSource | "all", label: string, count: number) => (
    <button
      key={id}
      type="button"
      aria-pressed={source === id}
      onClick={() => setSource(id)}
      className={cn(
        "flex h-6 shrink-0 items-center gap-1.5 rounded-[6px] px-2 text-[11.5px] font-medium transition-colors focus-visible:ring-2 focus-visible:ring-accent focus-visible:outline-none",
        source === id
          ? "bg-card text-fg shadow-card ring-1 ring-hairline"
          : "text-fg-secondary hover:bg-hover hover:text-fg",
      )}
    >
      {label}
      <span className="text-fg-tertiary tabular-nums">{count}</span>
    </button>
  );

  return (
    <div
      inert={!open}
      className={cn(
        "relative shrink-0 overflow-hidden border-t",
        open ? "border-hairline" : "border-transparent",
        !dragging && "transition-[height,border-color] duration-200 ease-out",
      )}
      style={{ height: open ? height : 0 }}
    >
      {/* oxlint-disable jsx-a11y/no-noninteractive-tabindex, jsx-a11y/no-noninteractive-element-interactions -- a focusable separator is the ARIA window splitter, and the log scrolls, so both take focus. */}
      <div
        role="separator"
        aria-orientation="horizontal"
        aria-label="Resize logs"
        aria-valuenow={height}
        aria-valuemin={140}
        aria-valuemax={Math.max(140, available() - 160)}
        tabIndex={0}
        onPointerDown={startDrag}
        onKeyDown={resizeByKey}
        className="absolute inset-x-0 top-0 z-10 h-1.5 cursor-row-resize outline-none hover:bg-accent/30 focus-visible:bg-accent/50"
      />
      <section aria-label="Logs" className="flex flex-col bg-side" style={{ height: height - 1 }}>
        <div className="flex min-h-11 shrink-0 flex-wrap items-center gap-x-3 gap-y-1.5 border-b border-hairline py-1.5 pr-2 pl-4">
          <div className="flex items-center gap-2 text-[13px] font-medium text-fg">
            <ScrollText aria-hidden size={14} strokeWidth={1.75} className="text-fg-secondary" />
            Logs
            {failures > 0 ? (
              <span className="inline-flex h-5 items-center rounded-[6px] bg-danger-soft px-1.5 text-[11px] font-medium text-danger">
                {failures} failed
              </span>
            ) : null}
          </div>
          <span aria-hidden className="h-4 w-px bg-hairline" />
          <div
            role="group"
            aria-label="Filter by source"
            className="flex min-w-0 items-center gap-1 overflow-x-auto [scrollbar-width:none]"
          >
            {chip("all", "All", entries.length)}
            {logSources.map((id) => chip(id, id, counts[id]))}
          </div>
          <div className="ml-auto flex items-center gap-1.5">
            <SegmentedControl
              label="Filter by result"
              value={level}
              options={levels}
              onValueChange={setLevel}
            />
            <label className="flex h-6 w-40 items-center gap-1.5 rounded-[6px] border border-hairline bg-card px-2 text-fg-tertiary focus-within:border-accent focus-within:ring-2 focus-within:ring-accent-soft">
              <Search aria-hidden size={12} className="shrink-0" />
              <input
                type="search"
                aria-label="Search logs"
                placeholder="Search logs"
                value={query}
                onChange={(event) => setQuery(event.target.value)}
                className="min-w-0 flex-1 bg-transparent text-[12px] text-fg outline-none placeholder:text-fg-tertiary"
              />
            </label>
            <IconButton
              label="Copy shown lines"
              size="sm"
              disabled={shown.length === 0}
              onClick={() => onCopy(shown)}
            >
              <Copy aria-hidden strokeWidth={1.75} />
            </IconButton>
            <IconButton
              label="Clear logs"
              tone="danger"
              size="sm"
              disabled={entries.length === 0}
              onClick={onClear}
            >
              <Trash2 aria-hidden strokeWidth={1.75} />
            </IconButton>
            <span aria-hidden className="mx-0.5 h-4 w-px bg-hairline" />
            <IconButton label="Close logs" keys="Esc" size="sm" onClick={onClose}>
              <X aria-hidden strokeWidth={1.75} />
            </IconButton>
          </div>
        </div>
        <div
          ref={body}
          role="log"
          aria-label="Command log"
          tabIndex={0}
          className="min-h-0 flex-1 overflow-y-auto bg-card py-1.5 font-mono text-[11.5px] leading-[18px] select-text"
        >
          {error && entries.length === 0 ? (
            <div className="grid h-full place-items-center px-4 text-center font-sans text-[12.5px] text-danger">
              {error}
            </div>
          ) : shown.length === 0 ? (
            <div className="grid h-full place-items-center font-sans text-[12.5px] text-fg-tertiary">
              {entries.length === 0 ? "Nothing logged yet" : "No lines match"}
            </div>
          ) : (
            shown.map((entry) => {
              const style = levelStyle[logLevel(entry)];
              const ran = entry.status !== null;
              return (
                <div
                  key={entry.id}
                  className={cn(
                    "grid grid-cols-[64px_44px_80px_minmax(0,1fr)] gap-3 px-4 py-0.5 hover:bg-hover",
                    style.row,
                  )}
                >
                  <time
                    dateTime={new Date(entry.at * 1000).toISOString()}
                    className="text-fg-tertiary tabular-nums"
                  >
                    {formatLogTime(entry.at)}
                  </time>
                  <span className={cn("font-semibold", style.text)}>{style.label}</span>
                  <span className="truncate text-fg-secondary">{logSource(entry)}</span>
                  <span className="min-w-0 break-words whitespace-pre-wrap">
                    <span className={entry.ok ? (ran ? "text-fg" : "text-fg-secondary") : "text-danger"}>
                      {ran ? <span className="text-fg-tertiary select-none">$ </span> : null}
                      {entry.command}
                      {entry.status !== null && entry.status !== 0 ? (
                        <span className="text-fg-tertiary"> (exit {entry.status})</span>
                      ) : null}
                    </span>
                    {entry.detail.trim() ? (
                      <span className="block text-fg-tertiary">{entry.detail.trim()}</span>
                    ) : null}
                  </span>
                </div>
              );
            })
          )}
        </div>
        {/* oxlint-enable jsx-a11y/no-noninteractive-tabindex, jsx-a11y/no-noninteractive-element-interactions */}
      </section>
    </div>
  );
}
