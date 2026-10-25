import { LayoutGrid, Moon, Sun } from "lucide-react";
import { type KeyboardEvent, useLayoutEffect, useRef } from "react";

import { Notice } from "~/components/ui/notice";
import { useStore } from "~/lib/store";

import { BackgroundGrid, tileId } from "./background-grid";
import { SwitcherActions, actionId } from "./switcher-actions";
import { Divider, Footer, SearchBar, SwitcherRow } from "./switcher-chrome";
import {
  actionItems,
  activeTheme,
  buildRows,
  plural,
  findTheme,
  primaryTitle,
  type Row,
  rowKey,
  selectedRow,
  visibleTiles,
} from "./switcher-model";
import { SwitcherPreview } from "./switcher-preview";
import type { SwitcherStore } from "./switcher-store";

const LIST_ID = "switcher-list";
const GRID_ID = "switcher-grid";
const ACTIONS_ID = "switcher-actions";
const rowId = (index: number) => `switcher-row-${index}`;

/**
 * The switcher's contents, laid out like the Raycast command it replaces.
 * The search field never loses focus: every key arrives there and is routed
 * to the list, the grid or the actions menu.
 */
export function SwitcherView({ store }: { store: SwitcherStore }) {
  const { model, generation, error } = useStore(store);
  const inputRef = useRef<HTMLInputElement>(null);
  const rootRef = useRef<HTMLDivElement>(null);

  // Runs inside the host's willOpen commit, before the panel is shown.
  useLayoutEffect(() => {
    inputRef.current?.focus();
    for (const element of rootRef.current?.querySelectorAll("[data-scroll-reset]") ?? []) {
      element.scrollTop = 0;
    }
    // oxlint-disable-next-line react/exhaustive-effect-dependencies -- every open and close resets.
  }, [generation]);

  const rows = model ? buildRows(model.data, model.ui.search) : [];
  const tiles = model ? visibleTiles(model) : [];
  const items = model ? actionItems(model) : [];
  const inGrid = model?.ui.mode.kind === "backgrounds";
  const selectedIndex = model ? rows.findIndex((row) => rowKey(row) === model.ui.selection) : -1;
  const tileIndex = model ? tiles.findIndex((tile) => tile.path === model.ui.tile) : -1;

  const activeId = !model
    ? undefined
    : model.ui.actionsOpen
      ? actionId(model.ui.action)
      : inGrid
        ? tileIndex >= 0
          ? tileId(tileIndex)
          : undefined
        : selectedIndex >= 0
          ? rowId(selectedIndex)
          : undefined;

  // After a reset the active row may be unchanged but scrolled away, so the
  // generation re-runs this too.
  useLayoutEffect(() => {
    if (activeId) document.getElementById(activeId)?.scrollIntoView({ block: "nearest" });
    // oxlint-disable-next-line react/exhaustive-effect-dependencies -- see above.
  }, [activeId, generation]);

  if (!model) return null;
  const { data, ui } = model;
  const gridTheme = ui.mode.kind === "backgrounds" ? findTheme(data, ui.mode.theme) : undefined;
  const active = activeTheme(data);
  const row = selectedRow(model);
  const previewTheme = row?.kind === "theme" ? findTheme(data, row.name) : active;

  function onKeyDown(event: KeyboardEvent<HTMLInputElement>) {
    if (event.nativeEvent.isComposing) return;
    const command = event.metaKey && !event.ctrlKey && !event.altKey;
    const key = event.key;
    let handled = true;
    if (key === "ArrowUp" || key === "ArrowDown") {
      store.dispatch({ type: "step", delta: key === "ArrowUp" ? -1 : 1 });
    } else if ((key === "ArrowLeft" || key === "ArrowRight") && inGrid && !ui.actionsOpen) {
      store.dispatch({ type: "gridStep", delta: key === "ArrowLeft" ? -1 : 1 });
    } else if (key === "Enter") {
      store.run(ui.actionsOpen ? (items[ui.action]?.command ?? "primary") : "primary");
    } else if (key === "Escape") {
      store.escape();
    } else if (command && key.toLowerCase() === "k") {
      store.dispatch({ type: "toggleActions" });
    } else if (command && key.toLowerCase() === "b") {
      store.run("switchBackground");
    } else if (command && key.toLowerCase() === "r") {
      store.run("refresh");
    } else if (command && key === ",") {
      store.run("openSettings");
    } else {
      handled = false;
    }
    if (handled) event.preventDefault();
  }

  function renderRow(entry: Row, index: number) {
    const key = rowKey(entry);
    const selected = key === ui.selection;
    const common = {
      id: rowId(index),
      selected,
      onClick: () => store.dispatch({ type: "select", key }),
      onDoubleClick: () => {
        store.dispatch({ type: "select", key });
        store.run("primary");
      },
    };
    if (entry.kind === "backgrounds") {
      return (
        <SwitcherRow
          key={key}
          {...common}
          icon={<LayoutGrid aria-hidden className="size-[17px]" strokeWidth={2.25} />}
          title="Switch Background"
          accessories={
            <span className="text-fg-secondary">
              {plural(active?.backgrounds.length ?? 0, "option")}
            </span>
          }
        />
      );
    }
    const theme = findTheme(data, entry.name);
    if (!theme) return null;
    const ThemeMode = theme.isDark ? Moon : Sun;
    return (
      <SwitcherRow
        key={key}
        {...common}
        icon={
          <span
            aria-hidden
            className="size-[18px] rounded-full border-[2.2px]"
            style={{ borderColor: theme.ring }}
          />
        }
        title={theme.title}
        accessories={
          <>
            {theme.name === data.current ? (
              <span className="rounded-[5px] bg-success/16 px-[7px] py-0.5 text-[13px] font-medium text-success">
                active
              </span>
            ) : null}
            <ThemeMode
              role="img"
              aria-label={theme.isDark ? "Dark" : "Light"}
              className="size-4 text-fg-secondary"
              strokeWidth={2}
            />
            {theme.backgrounds.length > 0 ? (
              <span className="text-fg-secondary">
                <span aria-hidden>{theme.backgrounds.length} bg</span>
                <span className="sr-only">{plural(theme.backgrounds.length, "background")}</span>
              </span>
            ) : null}
          </>
        }
      />
    );
  }

  const emptyMessage = error
    ? `Could not load themes: ${error}`
    : data.themes.length === 0
      ? "No themes installed"
      : "No matching themes";

  return (
    <div
      ref={rootRef}
      className="relative flex h-full flex-col overflow-hidden rounded-card bg-black/55 text-fg after:pointer-events-none after:absolute after:inset-0 after:rounded-card after:border after:border-white/10"
    >
      {ui.failure ? (
        <Notice.Root variant="error" className="m-2 mb-0">
          <div className="flex items-start gap-2">
            <div className="flex min-w-0 flex-1 flex-col gap-0.5">
              <Notice.Title>{ui.failure.title}</Notice.Title>
              <Notice.Description>{ui.failure.reason}</Notice.Description>
            </div>
            <Notice.Dismiss onClick={() => store.dispatch({ type: "dismissFailure" })} />
          </div>
        </Notice.Root>
      ) : null}
      {ui.notice ? (
        <Notice.Root className="m-2 mb-0">
          <div className="flex items-start gap-2">
            <Notice.Title className="min-w-0 flex-1">{ui.notice}</Notice.Title>
            <Notice.Dismiss onClick={() => store.dispatch({ type: "dismissNotice" })} />
          </div>
        </Notice.Root>
      ) : null}
      <SearchBar
        inputRef={inputRef}
        role="combobox"
        aria-label={inGrid ? "Search backgrounds" : "Search themes"}
        aria-expanded
        aria-controls={ui.actionsOpen ? ACTIONS_ID : inGrid ? GRID_ID : LIST_ID}
        aria-activedescendant={activeId}
        placeholder={inGrid ? "Search backgrounds..." : "Search themes..."}
        value={ui.search}
        onChange={(event) => store.dispatch({ type: "search", search: event.currentTarget.value })}
        onKeyDown={onKeyDown}
        onBlur={() => requestAnimationFrame(() => inputRef.current?.focus())}
        onBack={() => store.escape()}
      />
      <Divider />

      <div className="flex min-h-0 flex-1">
        {gridTheme ? (
          <BackgroundGrid
            id={GRID_ID}
            theme={gridTheme}
            tiles={tiles}
            selected={ui.tile}
            onSelect={(path) => store.dispatch({ type: "selectTile", path })}
            onUse={(path) => {
              store.dispatch({ type: "selectTile", path });
              store.run("primary");
            }}
          />
        ) : (
          <div className="flex min-w-0 flex-1">
            <div className="relative flex w-[340px] shrink-0">
              <div
                id={LIST_ID}
                role="listbox"
                aria-label="Themes"
                data-scroll-reset
                className="flex min-w-0 flex-1 flex-col gap-0.5 overflow-y-auto p-2"
              >
                {rows.map(renderRow)}
              </div>
              {/* Over the list it empties: centred across both panes it sat on
                  the preview's wallpaper, where it could not be read. */}
              {rows.length === 0 ? (
                <div className="absolute inset-0 flex items-center justify-center px-6 text-center text-[13px] text-fg-secondary">
                  {emptyMessage}
                </div>
              ) : null}
            </div>
            <Divider vertical />
            <SwitcherPreview theme={previewTheme} details={row?.kind !== "backgrounds"} />
          </div>
        )}
      </div>

      <Divider />
      <Footer
        primary={primaryTitle(model)}
        mode={ui.mode.kind}
        actionsOpen={ui.actionsOpen}
        onActions={() => store.dispatch({ type: "toggleActions" })}
      />

      {ui.actionsOpen ? (
        <SwitcherActions
          id={ACTIONS_ID}
          items={items}
          highlighted={ui.action}
          onHighlight={(index) => store.dispatch({ type: "highlightAction", index })}
          onRun={(command) => store.run(command)}
        />
      ) : null}
    </div>
  );
}
