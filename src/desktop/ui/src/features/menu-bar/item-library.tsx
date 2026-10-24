import { AlertTriangle, Folder } from "lucide-react";
import { useState } from "react";

import type { BarItemKind, WidgetInfo } from "~/bridge/protocol";
import { Badge } from "~/components/ui/badge";
import { Button } from "~/components/ui/button";
import { Dialog } from "~/components/ui/dialog";
import { focusRing } from "~/components/ui/focus-ring";
import { SearchField } from "~/components/ui/search-field";
import { cn } from "~/lib/cn";

import { ItemIcon } from "./menu-bar-icon";
import { type BarItem, makeable, type Zone, zoneLabels } from "./menu-bar-items";
import type { BarLook } from "./menu-bar-store";
import { WidgetChip } from "./widget-preview";

type Category = "all" | "builtIn" | "user" | "make" | "hidden";

/** One thing the library can add: a widget, a made item or one of the bar's own that is hidden. */
type Entry =
  | { type: "widget"; key: string; widget: WidgetInfo }
  | {
      type: "make";
      key: string;
      kind: Exclude<BarItemKind, "widget">;
      name: string;
      detail: string;
    }
  | { type: "hidden"; key: string; item: BarItem };

const sampleItem = (widget: WidgetInfo): BarItem => ({
  id: `sample.${widget.id}`,
  title: widget.name,
  zone: "right",
  visible: true,
  kind: "widget",
  text: "",
  icon: "",
  command: null,
  interval: null,
  widget: widget.id,
  settings: {},
  style: null,
  click: null,
  reading: "",
});

function nameOf(entry: Entry): string {
  if (entry.type === "widget") return entry.widget.name;
  if (entry.type === "make") return entry.name;
  return entry.item.title;
}

function detailOf(entry: Entry): string {
  if (entry.type === "widget") return entry.widget.description ?? "";
  if (entry.type === "make") return entry.detail;
  return `Hidden in the ${zoneLabels[entry.item.zone].toLowerCase()} zone`;
}

/**
 * What can go in one zone: a widget, a text, spacer or command item, or one
 * of the bar's own items that is hidden. Open while `zone` is set; the last
 * zone stays drawn while the dialog fades out.
 */
export function ItemLibrary({
  zone,
  widgets,
  counts,
  hidden,
  look,
  onAddWidget,
  onMake,
  onShow,
  onOpenFolder,
  onClose,
}: {
  zone: Zone | null;
  widgets: readonly WidgetInfo[];
  /** How many items on the bar show each widget. */
  counts: Map<string, number>;
  /** The bar's own items that are hidden, to show again. */
  hidden: BarItem[];
  look: BarLook;
  onAddWidget: (widget: WidgetInfo, zone: Zone) => void;
  onMake: (kind: Exclude<BarItemKind, "widget">, zone: Zone) => void;
  onShow: (id: string, zone: Zone) => void;
  onOpenFolder: () => void;
  onClose: () => void;
}) {
  const [last, setLast] = useState<Zone>("right");
  const [category, setCategory] = useState<Category>("all");
  const [query, setQuery] = useState("");
  const [picked, setPicked] = useState<string | null>(null);
  if (zone !== null && zone !== last) setLast(zone);
  const shownZone = zone ?? last;

  const entries: Entry[] = [
    ...widgets.map((widget): Entry => ({ type: "widget", key: `widget:${widget.id}`, widget })),
    ...makeable.map((made): Entry => ({ type: "make", key: `make:${made.kind}`, ...made })),
    ...hidden.map((item): Entry => ({ type: "hidden", key: `hidden:${item.id}`, item })),
  ];
  const inCategory = (entry: Entry, name: Category) => {
    if (name === "all") return true;
    if (name === "make" || name === "hidden") return entry.type === name;
    return entry.type === "widget" && entry.widget.origin === name;
  };
  const categories: { id: Category; name: string }[] = [
    { id: "all", name: "All" },
    { id: "builtIn", name: "Built-in" },
    { id: "user", name: "Yours" },
    { id: "make", name: "Make an item" },
    ...(hidden.length > 0 ? [{ id: "hidden" as const, name: "Hidden on your bar" }] : []),
  ];
  const search = query.trim().toLowerCase();
  const shown = entries.filter(
    (entry) =>
      inCategory(entry, category) &&
      (!search || `${nameOf(entry)} ${detailOf(entry)}`.toLowerCase().includes(search)),
  );
  const selected = shown.find((entry) => entry.key === picked) ?? shown[0] ?? null;
  const onBar = selected?.type === "widget" ? (counts.get(selected.widget.id) ?? 0) : 0;

  const add = (entry: Entry | null) => {
    if (!entry) return;
    if (entry.type === "widget") onAddWidget(entry.widget, shownZone);
    else if (entry.type === "make") onMake(entry.kind, shownZone);
    else onShow(entry.item.id, shownZone);
    onClose();
  };

  return (
    <Dialog.Root open={zone !== null} onOpenChange={(open) => (open ? undefined : onClose())}>
      <Dialog.Popup className="h-[600px] w-[880px] max-w-[calc(100vw-48px)]">
        <Dialog.Header>
          <Dialog.Title>Add a widget</Dialog.Title>
          <Dialog.Description>
            To the {zoneLabels[shownZone].toLowerCase()} of the bar
          </Dialog.Description>
        </Dialog.Header>
        <div className="flex min-h-0 flex-1 border-t border-hairline">
          <nav
            aria-label="Categories"
            className="flex w-[188px] shrink-0 flex-col gap-0.5 border-r border-hairline bg-side p-2.5"
          >
            {categories.map((entry) => (
              <button
                key={entry.id}
                type="button"
                aria-pressed={category === entry.id}
                onClick={() => {
                  setCategory(entry.id);
                  setPicked(null);
                }}
                className={cn(
                  "flex h-8 items-center rounded-control px-2.5 text-left text-detail",
                  category === entry.id
                    ? "bg-accent-soft font-medium text-accent-text"
                    : "text-fg-secondary hover:bg-hover",
                  focusRing,
                )}
              >
                <span className="flex-1">{entry.name}</span>
                <span className="text-caption tabular-nums opacity-70">
                  {entries.filter((candidate) => inCategory(candidate, entry.id)).length}
                </span>
              </button>
            ))}
            <div className="flex-1" />
            <p className="px-2 pb-2 text-caption text-fg-tertiary">
              Your widgets live in <span className="font-mono">~/.config/macarchy/widgets</span>
            </p>
            <Button size="sm" onClick={onOpenFolder}>
              <Folder aria-hidden size={12} /> Open folder
            </Button>
          </nav>
          <div className="flex min-w-0 flex-1 flex-col gap-3 overflow-y-auto p-4">
            <SearchField
              label="Search widgets"
              value={query}
              onValueChange={(value) => {
                setQuery(value);
                setPicked(null);
              }}
            />
            {shown.length === 0 ? (
              <p className="grid flex-1 place-items-center text-detail text-fg-tertiary">
                Nothing matches {query ? `"${query}"` : "here"}.
              </p>
            ) : (
              <ul className="grid grid-cols-3 gap-2.5">
                {shown.map((entry) => (
                  <li key={entry.key}>
                    <LibraryCard
                      entry={entry}
                      look={look}
                      onBar={
                        entry.type === "widget" ? (counts.get(entry.widget.id) ?? 0) > 0 : false
                      }
                      selected={selected?.key === entry.key}
                      onPick={() => setPicked(entry.key)}
                      onAdd={() => add(entry)}
                    />
                  </li>
                ))}
              </ul>
            )}
          </div>
        </div>
        <Dialog.Footer
          leading={
            selected?.type === "widget" && selected.widget.scripted ? (
              <Badge tone="warn">
                <AlertTriangle aria-hidden size={11} /> Runs a script as you
              </Badge>
            ) : null
          }
        >
          <span className="mr-auto max-w-[460px] truncate pl-2 text-small text-fg-secondary">
            {selected
              ? onBar > 0
                ? `${nameOf(selected)} is already on the bar. Adding it again makes a second copy.`
                : detailOf(selected)
              : null}
          </span>
          <Button variant="ghost" onClick={onClose}>
            Cancel
          </Button>
          <Button variant="primary" disabled={!selected} onClick={() => add(selected)}>
            {selected
              ? selected.type === "hidden"
                ? `Show ${nameOf(selected)} here`
                : onBar > 0
                  ? "Add another"
                  : `Add ${nameOf(selected)}`
              : "Add"}
          </Button>
        </Dialog.Footer>
      </Dialog.Popup>
    </Dialog.Root>
  );
}

function LibraryCard({
  entry,
  look,
  onBar,
  selected,
  onPick,
  onAdd,
}: {
  entry: Entry;
  look: BarLook;
  onBar: boolean;
  selected: boolean;
  onPick: () => void;
  onAdd: () => void;
}) {
  return (
    <button
      type="button"
      aria-pressed={selected}
      onClick={onPick}
      onDoubleClick={onAdd}
      className={cn(
        "flex w-full flex-col gap-2 rounded-card border bg-card p-2.5 text-left transition-colors",
        selected ? "border-accent ring-[3px] ring-accent-soft" : "border-hairline hover:bg-hover",
        focusRing,
      )}
    >
      <span
        className="flex h-12 items-center justify-center overflow-hidden rounded-control"
        style={{ background: look.background, color: look.foreground }}
      >
        {entry.type === "widget" ? (
          <WidgetChip
            item={sampleItem(entry.widget)}
            widget={entry.widget}
            sample="widest"
            look={look}
          />
        ) : (
          <ItemIcon
            item={entry.type === "make" ? { id: entry.kind, kind: entry.kind } : entry.item}
            size={16}
          />
        )}
      </span>
      <span className="flex items-center gap-1.5">
        <span className="min-w-0 flex-1 truncate text-detail font-medium text-fg">
          {nameOf(entry)}
        </span>
        {onBar ? <Badge tone="ok">On bar</Badge> : null}
        {entry.type === "widget" && entry.widget.scripted ? (
          <Badge tone="warn">Script</Badge>
        ) : null}
        {entry.type === "widget" && entry.widget.origin === "user" && !entry.widget.scripted ? (
          <Badge tone="accent">Yours</Badge>
        ) : null}
      </span>
      <span className="line-clamp-2 min-h-[2lh] text-small text-fg-tertiary">
        {detailOf(entry)}
      </span>
    </button>
  );
}
