import { GripVertical, Plus, X } from "lucide-react";
import { type KeyboardEvent, useId } from "react";

import type { WidgetInfo } from "~/bridge/protocol";
import { focusRing } from "~/components/ui/focus-ring";
import { IconButton } from "~/components/ui/icon-button";
import { cn } from "~/lib/cn";

import { ScriptBadge } from "./item-inspector";
import { ItemIcon } from "./menu-bar-icon";
import { type BarItem, shownText, type Zone, zoneLabels } from "./menu-bar-items";
import { readable, type Sample, sampleText, widgetOf } from "./widget-model";

/** What a key on an item's handle asks for: a step within its zone, or to the next zone. */
export type KeyMove = { kind: "step" | "zone"; direction: -1 | 1 };

const moveKeys: Record<string, KeyMove> = {
  ArrowUp: { kind: "step", direction: -1 },
  ArrowDown: { kind: "step", direction: 1 },
  ArrowLeft: { kind: "zone", direction: -1 },
  ArrowRight: { kind: "zone", direction: 1 },
};

/** A drop target: an item to land before, or a zone's end. */
export type DropTarget = { item: string } | { zone: Zone } | null;

/** What a row says the item shows, at the preview's sample. */
function sampleOf(item: BarItem, widgets: readonly WidgetInfo[], sample: Sample): string {
  const text =
    item.kind === "widget"
      ? sampleText(item, widgetOf(item, widgets), sample)
      : item.kind === "spacer"
        ? ""
        : shownText(item);
  return readable(text);
}

export function BarZone({
  zone,
  items,
  widgets,
  sample,
  selected,
  changed,
  dragging,
  over,
  moveHintId,
  onSelect,
  onRemove,
  onAdd,
  onKeyMove,
  onDragStart,
  onDragOver,
  onDrop,
  onDragEnd,
}: {
  zone: Zone;
  items: BarItem[];
  widgets: readonly WidgetInfo[];
  sample: Sample;
  selected: string | null;
  /** Items that differ from the bar, marked until Apply or Revert. */
  changed: ReadonlySet<string>;
  dragging: string | null;
  over: DropTarget;
  moveHintId: string;
  onSelect: (id: string) => void;
  onRemove: (id: string) => void;
  onAdd: (zone: Zone) => void;
  onKeyMove: (id: string, move: KeyMove) => void;
  onDragStart: (id: string) => void;
  onDragOver: (target: DropTarget) => void;
  onDrop: (target: DropTarget) => void;
  onDragEnd: () => void;
}) {
  const headingId = useId();
  const zoneOver = over !== null && "zone" in over && over.zone === zone;
  return (
    // oxlint-disable-next-line jsx-a11y/no-noninteractive-element-interactions -- dragging is a pointer shortcut; each item's move handle does the same by keyboard.
    <section
      aria-labelledby={headingId}
      onDragOver={(event) => {
        event.preventDefault();
        if (!over) onDragOver({ zone });
      }}
      onDrop={() => onDrop(zoneOver ? { zone } : null)}
      className={cn(
        "flex min-h-[120px] min-w-0 flex-col rounded-card border bg-side p-2 transition-colors @min-[480px]:min-h-[220px]",
        zoneOver ? "border-accent" : "border-hairline",
      )}
    >
      <div className="mb-1.5 flex items-center px-1.5 pt-0.5 text-meta font-medium text-fg-secondary">
        <h3 id={headingId} className="flex-1">
          {zoneLabels[zone]}
        </h3>
        <span className="tabular-nums">{items.length}</span>
      </div>
      <ul className="flex flex-col gap-1">
        {items.map((item) => {
          const picked = selected === item.id;
          const targeted =
            over !== null && "item" in over && over.item === item.id && dragging !== item.id;
          const widget = widgetOf(item, widgets);
          return (
            // oxlint-disable-next-line jsx-a11y/no-noninteractive-element-interactions -- dragging is a pointer shortcut; the move handle does the same by keyboard.
            <li
              key={item.id}
              draggable
              onDragStart={() => onDragStart(item.id)}
              onDragEnd={onDragEnd}
              onDragOver={(event) => {
                event.preventDefault();
                event.stopPropagation();
                onDragOver({ item: item.id });
              }}
              onDrop={(event) => {
                event.stopPropagation();
                onDrop({ item: item.id });
              }}
              className={cn(
                "group/row flex h-10 cursor-grab items-center gap-1 rounded-control border bg-card pr-1 pl-0.5 shadow-card transition-all active:cursor-grabbing motion-reduce:transition-none",
                picked ? "border-accent ring-[3px] ring-accent-soft" : "border-hairline",
                dragging === item.id && "opacity-40",
                targeted && "translate-y-0.5 border-t-2 border-t-accent",
              )}
            >
              <button
                type="button"
                aria-label={`Move ${item.title}`}
                aria-describedby={moveHintId}
                data-move-handle={item.id}
                onKeyDown={(event: KeyboardEvent) => {
                  const move = moveKeys[event.key];
                  if (!move) return;
                  event.preventDefault();
                  onKeyMove(item.id, move);
                }}
                className={cn(
                  "grid h-6 w-4 shrink-0 place-items-center rounded-small text-fg-secondary",
                  focusRing,
                )}
              >
                <GripVertical aria-hidden size={13} />
              </button>
              <button
                type="button"
                aria-pressed={picked}
                onClick={() => onSelect(item.id)}
                className={cn(
                  "flex h-8 min-w-0 flex-1 items-center gap-2 rounded-small px-1 text-left",
                  focusRing,
                )}
              >
                <span
                  className={cn(
                    "grid size-6 shrink-0 place-items-center rounded-[6px] border border-hairline bg-side",
                    "text-fg-secondary",
                  )}
                >
                  <ItemIcon item={item} size={12} />
                </span>
                <span className="min-w-0 flex-1 truncate text-detail font-medium text-fg">
                  {item.title}
                </span>
                {changed.has(item.id) ? (
                  <span className="size-1.5 shrink-0 rounded-full bg-accent">
                    <span className="sr-only">, changed</span>
                  </span>
                ) : null}
                {widget?.scripted ? <ScriptBadge widget={widget} compact /> : null}
                <span className="max-w-[45%] shrink-0 truncate pl-1 font-mono text-caption text-fg-secondary">
                  {sampleOf(item, widgets, sample)}
                </span>
              </button>
              <IconButton
                label={`Remove ${item.title}`}
                size="sm"
                onClick={() => onRemove(item.id)}
                className="opacity-0 group-hover/row:opacity-100 focus-visible:opacity-100"
              >
                <X aria-hidden />
              </IconButton>
            </li>
          );
        })}
      </ul>
      {items.length === 0 ? (
        <p className="grid h-16 place-items-center px-3 text-center text-small text-fg-secondary">
          Nothing here
        </p>
      ) : null}
      <button
        type="button"
        onClick={() => onAdd(zone)}
        className={cn(
          "mt-auto flex h-8 w-full items-center justify-center gap-1.5 rounded-control border border-dashed border-line-strong text-detail font-medium text-fg-secondary transition-colors hover:border-fg-tertiary hover:bg-card hover:text-fg",
          focusRing,
          items.length > 0 && "mt-2",
        )}
      >
        <Plus aria-hidden size={13} /> Add widget
        <span className="sr-only"> to the {zoneLabels[zone].toLowerCase()} zone</span>
      </button>
    </section>
  );
}
