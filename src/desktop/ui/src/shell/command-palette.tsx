import { Dialog } from "@base-ui/react/dialog";
import { CornerDownLeft, type LucideIcon, Search } from "lucide-react";
import { type KeyboardEvent, type RefObject, useEffect, useId, useRef, useState } from "react";

import { Kbd } from "~/components/ui/kbd";
import { cn } from "~/lib/cn";

import { filterPalette, groupPalette, type PaletteItem, stepIndex } from "./palette";

export interface PaletteCommand extends PaletteItem {
  icon: LucideIcon;
  run: () => void;
}

/** Keeps focus in the field while the pointer picks a row, as the switcher's rows do. */
const keepFieldFocus = {
  onMouseDown: (event: { preventDefault(): void }) => event.preventDefault(),
};

/**
 * ⌘K: pages, the window's actions and, when the page has a filter, a row
 * that filters it. The field keeps focus throughout and points at the
 * highlighted row with `aria-activedescendant`; Escape closes and focus
 * returns to wherever it was.
 */
export function CommandPalette({
  open,
  onOpenChange,
  commands,
  pageFilter,
}: {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  commands: readonly PaletteCommand[];
  /** The current page's own search, offered with whatever has been typed. */
  pageFilter: { title: string; apply: (query: string) => void } | null;
}) {
  const field = useRef<HTMLInputElement>(null);
  return (
    <Dialog.Root open={open} onOpenChange={(next) => onOpenChange(next)}>
      <Dialog.Portal>
        <Dialog.Backdrop className="fixed inset-0 z-50 bg-black/25 transition-opacity duration-150 data-ending-style:opacity-0 data-starting-style:opacity-0" />
        <Dialog.Viewport className="fixed inset-0 z-50 flex justify-center px-4 pt-[max(56px,12vh)]">
          <Dialog.Popup
            initialFocus={field}
            aria-label="Command palette"
            className="flex h-fit max-h-[min(460px,calc(100dvh-80px))] w-[560px] max-w-full flex-col overflow-hidden rounded-[12px] border border-hairline bg-popover text-fg shadow-[0_24px_60px_-12px_rgb(0_0_0/0.35)] outline-none transition-[opacity,scale] duration-150 ease-out data-ending-style:opacity-0 data-starting-style:scale-98 data-starting-style:opacity-0"
          >
            <PaletteBody
              field={field}
              commands={commands}
              pageFilter={pageFilter}
              close={() => onOpenChange(false)}
            />
          </Dialog.Popup>
        </Dialog.Viewport>
      </Dialog.Portal>
    </Dialog.Root>
  );
}

function PaletteBody({
  field,
  commands,
  pageFilter,
  close,
}: {
  field: RefObject<HTMLInputElement | null>;
  commands: readonly PaletteCommand[];
  pageFilter: { title: string; apply: (query: string) => void } | null;
  close: () => void;
}) {
  const [query, setQuery] = useState("");
  const [highlight, setHighlight] = useState(0);
  const list = useRef<HTMLDivElement>(null);
  const base = useId();
  const listId = `${base}-list`;
  const optionId = (index: number) => `${base}-option-${index}`;

  const trimmed = query.trim();
  const filterRow: PaletteCommand[] =
    pageFilter && trimmed
      ? [
          {
            id: "page-filter",
            label: `Filter ${pageFilter.title} for "${trimmed}"`,
            section: "This page",
            icon: Search,
            run: () => pageFilter.apply(trimmed),
          },
        ]
      : [];
  const results = [...filterRow, ...filterPalette(commands, query)];
  const active = Math.min(highlight, Math.max(results.length - 1, 0));
  const groups = groupPalette(results);

  useEffect(() => {
    list.current
      ?.querySelector(`[data-index="${active}"]`)
      ?.scrollIntoView({ block: "nearest" });
  }, [active]);

  const run = (command: PaletteCommand | undefined) => {
    if (!command) return;
    close();
    command.run();
  };

  const onKeyDown = (event: KeyboardEvent<HTMLInputElement>) => {
    const moves: Record<string, number> = { ArrowDown: 1, ArrowUp: -1 };
    const step = moves[event.key];
    if (step !== undefined) {
      event.preventDefault();
      setHighlight(stepIndex(active, step, results.length));
    } else if (event.key === "Home" && event.metaKey) {
      event.preventDefault();
      setHighlight(0);
    } else if (event.key === "End" && event.metaKey) {
      event.preventDefault();
      setHighlight(Math.max(results.length - 1, 0));
    } else if (event.key === "Enter") {
      event.preventDefault();
      run(results[active]);
    }
  };

  return (
    <>
      <div className="flex h-12 shrink-0 items-center gap-2.5 border-b border-hairline px-4">
        <Search aria-hidden size={15} className="shrink-0 text-fg-tertiary" />
        <input
          ref={field}
          role="combobox"
          aria-label="Search settings and commands"
          aria-expanded
          aria-controls={listId}
          aria-autocomplete="list"
          aria-activedescendant={results.length > 0 ? optionId(active) : undefined}
          value={query}
          onChange={(event) => {
            setQuery(event.target.value);
            setHighlight(0);
          }}
          onKeyDown={onKeyDown}
          placeholder="Search settings or run a command..."
          className="min-w-0 flex-1 bg-transparent text-[14px] text-fg outline-none placeholder:text-fg-tertiary"
        />
        <Kbd variant="key" className="h-5 min-w-0 px-1.5 text-[11px] text-fg-tertiary">
          Esc
        </Kbd>
      </div>
      <div
        ref={list}
        id={listId}
        role="listbox"
        aria-label="Results"
        className="min-h-0 flex-1 overflow-y-auto p-1.5"
      >
        {results.length === 0 ? (
          <div className="px-3 py-8 text-center text-[13px] text-fg-secondary">
            {`No results for "${trimmed}"`}
          </div>
        ) : (
          groups.map((group) => (
            <div key={group.section} role="group" aria-labelledby={`${base}-${group.section}`}>
              <div
                id={`${base}-${group.section}`}
                className="px-2.5 pt-2 pb-1 text-[11px] font-medium text-fg-tertiary"
              >
                {group.section}
              </div>
              {group.items.map(({ item, index }) => {
                const Icon = item.icon;
                const on = index === active;
                return (
                  // oxlint-disable-next-line jsx-a11y/click-events-have-key-events, jsx-a11y/interactive-supports-focus -- reached through the field's aria-activedescendant; the field keeps focus and handles the keys.
                  <div
                    key={item.id}
                    id={optionId(index)}
                    role="option"
                    aria-selected={on}
                    data-index={index}
                    onMouseMove={() => {
                      if (!on) setHighlight(index);
                    }}
                    onClick={() => run(item)}
                    {...keepFieldFocus}
                    className={cn(
                      "flex h-9 items-center gap-2.5 rounded-[7px] px-2.5 text-[13px]",
                      on ? "bg-muted text-fg" : "text-fg-secondary",
                    )}
                  >
                    <Icon
                      aria-hidden
                      size={15}
                      strokeWidth={1.75}
                      className={cn("shrink-0", on ? "text-fg" : "text-fg-tertiary")}
                    />
                    <span className="min-w-0 truncate font-medium">{item.label}</span>
                    <span className="min-w-0 flex-1 truncate text-[12px] text-fg-tertiary">
                      {item.hint}
                    </span>
                    {item.keys ? (
                      <span className="shrink-0 text-[11.5px] tracking-[0.04em] text-fg-tertiary">
                        {item.keys}
                      </span>
                    ) : null}
                    {on ? (
                      <CornerDownLeft aria-hidden size={13} className="shrink-0 text-fg-tertiary" />
                    ) : null}
                  </div>
                );
              })}
            </div>
          ))
        )}
      </div>
      <div className="flex shrink-0 items-center gap-4 border-t border-hairline bg-side px-4 py-2 text-[11.5px] text-fg-tertiary">
        <span aria-hidden>↑↓ to move</span>
        <span aria-hidden>↵ to run</span>
        <span role="status" className="ml-auto">
          {results.length} {results.length === 1 ? "result" : "results"}
        </span>
      </div>
    </>
  );
}
