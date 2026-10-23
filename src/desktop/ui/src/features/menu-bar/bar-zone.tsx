import { EyeOff, GripVertical, Pencil, Plus, Trash } from "lucide-react";
import { type KeyboardEvent, useEffect, useId, useRef } from "react";

import { Button } from "~/components/ui/button";
import { focusRing } from "~/components/ui/focus-ring";
import { IconButton } from "~/components/ui/icon-button";
import { SegmentedControl } from "~/components/ui/segmented-control";
import { Switch } from "~/components/ui/switch";
import { Field, Input } from "~/components/ui/text-field";
import { Tooltip } from "~/components/ui/tooltip";
import { cn } from "~/lib/cn";

import { ItemIcon } from "./menu-bar-icon";
import { type BarItem, glyphs, intervals, type Zone, zoneLabels } from "./menu-bar-items";

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

export function BarZone({
  zone,
  items,
  editing,
  dragging,
  over,
  moveHintId,
  onEdit,
  onPatch,
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
  editing: string | null;
  dragging: string | null;
  over: DropTarget;
  moveHintId: string;
  onEdit: (id: string | null) => void;
  onPatch: (id: string, patch: Partial<BarItem>) => void;
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
        "flex min-h-[220px] min-w-0 flex-col rounded-card border bg-side p-2 transition-colors",
        zoneOver ? "border-accent" : "border-hairline",
      )}
    >
      <div className="mb-1.5 flex items-center px-1.5 pt-0.5 text-meta font-medium text-fg-tertiary">
        <h3 id={headingId} className="flex-1">
          {zoneLabels[zone]}
        </h3>
        <span className="tabular-nums">{items.filter((item) => item.visible).length} shown</span>
      </div>
      <ul className="flex flex-col gap-1">
        {items.map((item) => {
          const open = editing === item.id;
          const targeted =
            over !== null && "item" in over && over.item === item.id && dragging !== item.id;
          return (
            // oxlint-disable-next-line jsx-a11y/no-noninteractive-element-interactions -- dragging is a pointer shortcut; the move handle does the same by keyboard.
            <li
              key={item.id}
              draggable={!open}
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
                "rounded-control border bg-card shadow-card transition-all motion-reduce:transition-none",
                open ? "border-accent ring-[3px] ring-accent-soft" : "border-hairline",
                dragging === item.id && "opacity-40",
                targeted && "translate-y-0.5 border-t-2 border-t-accent",
              )}
            >
              <div
                className={cn(
                  "flex h-9 items-center gap-2 pr-1.5 pl-1",
                  !open && "cursor-grab active:cursor-grabbing",
                )}
              >
                <Tooltip content="Drag, or use the arrow keys, to move" describe={false}>
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
                      "grid h-6 w-4 shrink-0 place-items-center rounded-small text-fg-tertiary",
                      focusRing,
                    )}
                  >
                    <GripVertical aria-hidden size={13} />
                  </button>
                </Tooltip>
                <ItemIcon
                  item={item}
                  size={13}
                  className={cn(
                    "shrink-0",
                    item.visible ? "text-fg-secondary" : "text-fg-tertiary",
                  )}
                />
                <span
                  className={cn(
                    "min-w-0 flex-1 truncate text-detail font-medium",
                    item.visible ? "text-fg" : "text-fg-tertiary",
                  )}
                >
                  {item.title}
                </span>
                {!item.visible ? (
                  <Tooltip content="Hidden">
                    <span className="shrink-0 text-fg-tertiary">
                      <EyeOff aria-hidden size={12} />
                      <span className="sr-only">Hidden</span>
                    </span>
                  </Tooltip>
                ) : null}
                <IconButton
                  label={`Edit ${item.title}`}
                  size="sm"
                  pressed={open}
                  aria-expanded={open}
                  onClick={() => onEdit(open ? null : item.id)}
                >
                  <Pencil aria-hidden />
                </IconButton>
                {item.kind ? (
                  <IconButton
                    label={`Remove ${item.title}`}
                    size="sm"
                    tone="danger"
                    onClick={() => onRemove(item.id)}
                  >
                    <Trash aria-hidden />
                  </IconButton>
                ) : null}
              </div>
              {open ? (
                <ItemEditor
                  item={item}
                  onChange={(patch) => onPatch(item.id, patch)}
                  onDone={() => onEdit(null)}
                />
              ) : null}
            </li>
          );
        })}
      </ul>
      {items.length === 0 ? (
        <p className="grid h-16 place-items-center px-3 text-center text-small text-fg-tertiary">
          Empty
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
        <Plus aria-hidden size={13} /> Add item
        <span className="sr-only"> to the {zoneLabels[zone].toLowerCase()} zone</span>
      </button>
    </section>
  );
}

function ItemEditor({
  item,
  onChange,
  onDone,
}: {
  item: BarItem;
  onChange: (patch: Partial<BarItem>) => void;
  onDone: () => void;
}) {
  const ref = useRef<HTMLDivElement>(null);
  const glyphLabelId = useId();
  const onEnter = (event: KeyboardEvent) => {
    if (event.key === "Enter") onDone();
  };
  useEffect(() => {
    ref.current?.querySelector("input")?.focus();
  }, []);

  return (
    <div ref={ref} className="flex flex-col gap-2.5 border-t border-hairline px-3 pt-2.5 pb-3">
      <Field.Root>
        <Field.Label className="text-small text-fg-secondary">Name</Field.Label>
        <Input
          size="sm"
          value={item.title}
          onChange={(event) => onChange({ title: event.currentTarget.value })}
          onKeyDown={onEnter}
        />
      </Field.Root>
      {item.kind === "text" ? (
        <Field.Root>
          <Field.Label className="text-small text-fg-secondary">Text</Field.Label>
          <Input
            size="sm"
            value={item.text}
            onChange={(event) => onChange({ text: event.currentTarget.value })}
            onKeyDown={onEnter}
          />
        </Field.Root>
      ) : null}
      {item.kind === "command" ? (
        <>
          <Field.Root>
            <Field.Label className="text-small text-fg-secondary">Command</Field.Label>
            <Input
              size="sm"
              variant="mono"
              value={item.command ?? ""}
              placeholder="uptime | cut -d, -f1"
              onChange={(event) => onChange({ command: event.currentTarget.value })}
              onKeyDown={onEnter}
            />
            <Field.Description className="text-caption text-fg-tertiary">
              Runs in sh; what it prints becomes the label
            </Field.Description>
          </Field.Root>
          <SegmentedControl
            label="Update every"
            size="sm"
            value={String(item.interval ?? 30)}
            options={intervals}
            onValueChange={(value) => onChange({ interval: Number(value) })}
            className="self-start"
          />
        </>
      ) : null}
      {item.kind === "text" || item.kind === "command" ? (
        <div className="flex flex-col gap-1.5">
          <span id={glyphLabelId} className="text-small text-fg-secondary">
            Glyph
          </span>
          <div role="group" aria-labelledby={glyphLabelId} className="flex flex-wrap gap-1">
            {glyphs.map((glyph) => (
              <IconButton
                key={glyph || "none"}
                label={glyph ? `Glyph ${glyph}` : "No glyph"}
                size="sm"
                pressed={item.icon === glyph}
                onClick={() => onChange({ icon: glyph })}
              >
                <span aria-hidden className="text-detail">
                  {glyph || "–"}
                </span>
              </IconButton>
            ))}
          </div>
        </div>
      ) : null}
      <div className="flex items-center gap-2 pt-0.5">
        <Switch
          size="sm"
          aria-label="Visible"
          checked={item.visible}
          onCheckedChange={(checked) => onChange({ visible: checked })}
        />
        <span aria-hidden className="flex-1 text-small text-fg-secondary">
          Visible
        </span>
        <Button size="sm" onClick={onDone}>
          Done
        </Button>
      </div>
    </div>
  );
}
