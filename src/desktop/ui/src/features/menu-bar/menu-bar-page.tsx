import { RotateCcw, SquarePen } from "lucide-react";
import { useId, useLayoutEffect, useRef, useState } from "react";

import { PageHeader } from "~/components/layout/page-header";
import { Badge } from "~/components/ui/badge";
import { Button } from "~/components/ui/button";
import { Card, CardHeader, CardRows, Row, SectionLabel } from "~/components/ui/card";
import { Notice } from "~/components/ui/notice";
import { PreviewTag } from "~/components/ui/preview-tag";
import { SegmentedControl } from "~/components/ui/segmented-control";
import { Switch } from "~/components/ui/switch";
import { ValueSlider } from "~/components/ui/value-slider";
import { cn } from "~/lib/cn";
import { useStore } from "~/lib/store";
import type { PageContext } from "~/shell/page";

import { BarPreview } from "./bar-preview";
import { BarZone, type DropTarget, type KeyMove } from "./bar-zone";
import { ItemLibrary } from "./item-library";
import {
  addItem,
  hiddenInCentre,
  moveItem,
  patchItem,
  removeItem,
  sameItems,
  shiftZone,
  stepItem,
  zoneLabels,
  zonesFor,
} from "./menu-bar-items";
import {
  type BarItem,
  type BarSettings,
  initialBar,
  initialItems,
  type Zone,
} from "./menu-bar-mock";
import { fallbackLook, type MenuBarStore } from "./menu-bar-store";

const positionOptions = [
  { value: "top" as const, label: "Top" },
  { value: "bottom" as const, label: "Bottom" },
];

function sameBar(a: BarSettings, b: BarSettings): boolean {
  return (
    a.centre === b.centre &&
    a.height === b.height &&
    a.padding === b.padding &&
    a.position === b.position &&
    a.hideNative === b.hideNative
  );
}

/**
 * A preview of the bar editor. Nothing here reaches SketchyBar yet: the
 * draft lives in the page, and the classic editor makes the real changes.
 */
export function MenuBarPage({ store, context }: { store: MenuBarStore; context: PageContext }) {
  const { look } = useStore(store);
  const paint = look ?? fallbackLook;
  // Mock: the bar's items and settings are placeholders until the bar has a bridge.
  const [items, setItems] = useState<BarItem[]>(initialItems);
  const [bar, setBar] = useState<BarSettings>(initialBar);
  const [editing, setEditing] = useState<string | null>(null);
  const [adding, setAdding] = useState<Zone | null>(null);
  const [dragging, setDragging] = useState<string | null>(null);
  const [over, setOver] = useState<DropTarget>(null);
  const [announcement, setAnnouncement] = useState("");
  const heightId = useId();
  const paddingId = useId();
  const moveHintId = useId();
  const zonesRef = useRef<HTMLDivElement>(null);
  /** The item whose handle had focus before a keyboard move remounted it in another zone. */
  const refocus = useRef<string | null>(null);

  useLayoutEffect(() => {
    const id = refocus.current;
    if (!id) return;
    refocus.current = null;
    zonesRef.current?.querySelector<HTMLElement>(`[data-move-handle="${CSS.escape(id)}"]`)?.focus();
    // oxlint-disable-next-line react/exhaustive-effect-dependencies -- a moved item is focused again once the list has redrawn.
  }, [items]);

  const zones = zonesFor(bar.centre);
  const hidden = hiddenInCentre(items, bar.centre);
  const changed = !sameItems(items, initialItems) || !sameBar(bar, initialBar);
  const patchBar = (patch: Partial<BarSettings>) => setBar((current) => ({ ...current, ...patch }));

  const reset = () => {
    setItems(initialItems);
    setBar(initialBar);
    setEditing(null);
  };

  const remove = (id: string) => {
    setItems((current) => removeItem(current, id));
    if (editing === id) setEditing(null);
  };

  const endDrag = () => {
    setDragging(null);
    setOver(null);
  };

  const drop = (target: DropTarget) => {
    if (dragging && target) {
      setItems((current) =>
        "item" in target
          ? moveItem(
              current,
              dragging,
              current.find((entry) => entry.id === target.item)?.zone ?? "left",
              target.item,
            )
          : moveItem(current, dragging, target.zone),
      );
    }
    endDrag();
  };

  const keyMove = (id: string, move: KeyMove) => {
    const next =
      move.kind === "step"
        ? stepItem(items, id, move.direction)
        : shiftZone(items, id, move.direction, zones);
    if (next === items) return;
    refocus.current = id;
    setItems(next);
    const moved = next.find((entry) => entry.id === id);
    if (!moved) return;
    const inZone = next.filter((entry) => entry.zone === moved.zone);
    setAnnouncement(
      `${moved.label}, ${zoneLabels[moved.zone]} zone, ${inZone.indexOf(moved) + 1} of ${inZone.length}`,
    );
  };

  return (
    <>
      <PageHeader
        title="Menu Bar"
        actions={
          <Button size="sm" onClick={() => context.openClassic({ pane: "menuBar" })}>
            <SquarePen aria-hidden size={13} /> Open the editor
          </Button>
        }
      />

      <div className="flex flex-col">
        <Notice.Root className="mb-5">
          <Notice.Title className="flex items-center gap-2">
            Changes here are a preview <PreviewTag />
          </Notice.Title>
          <Notice.Description>
            Try a layout here, then make it in the editor. This page does not change your bar yet.
          </Notice.Description>
        </Notice.Root>

        <div className="mb-5">
          <SectionLabel
            action={
              <Button size="sm" variant="ghost" disabled={!changed} onClick={reset}>
                <RotateCcw aria-hidden size={12} /> Reset
              </Button>
            }
          >
            Preview
          </SectionLabel>
          <BarPreview
            items={items}
            bar={bar}
            look={paint}
            active={editing}
            onSelect={(id) => setEditing((current) => (current === id ? null : id))}
          />
        </div>

        <p id={moveHintId} className="sr-only">
          Up and Down arrows reorder within a zone; Left and Right move to the next zone.
        </p>
        <p aria-live="polite" className="sr-only">
          {announcement}
        </p>
        <div
          ref={zonesRef}
          className={cn("grid gap-3", bar.centre ? "grid-cols-3" : "grid-cols-2")}
        >
          {zones.map((zone) => (
            <BarZone
              key={zone}
              zone={zone}
              items={items.filter((entry) => entry.zone === zone)}
              centre={bar.centre}
              editing={editing}
              dragging={dragging}
              over={over}
              moveHintId={moveHintId}
              onEdit={setEditing}
              onPatch={(id, patch) => setItems((current) => patchItem(current, id, patch))}
              onRemove={remove}
              onAdd={setAdding}
              onKeyMove={keyMove}
              onDragStart={setDragging}
              onDragOver={setOver}
              onDrop={drop}
              onDragEnd={endDrag}
            />
          ))}
        </div>

        <Card className="mt-4">
          <CardHeader title="Bar" />
          <CardRows>
            <Row
              title="Height"
              controlId={heightId}
              control={
                <ValueSlider
                  id={heightId}
                  label="Bar height"
                  value={bar.height}
                  min={22}
                  max={48}
                  unit="pt"
                  onValueChange={(height) => patchBar({ height })}
                />
              }
            />
            <Row
              title="Position"
              control={
                <SegmentedControl
                  label="Position"
                  value={bar.position}
                  options={positionOptions}
                  onValueChange={(position) => patchBar({ position })}
                />
              }
            />
            <Row
              title="Padding"
              controlId={paddingId}
              control={
                <ValueSlider
                  id={paddingId}
                  label="Bar padding"
                  value={bar.padding}
                  min={0}
                  max={24}
                  unit="pt"
                  onValueChange={(padding) => patchBar({ padding })}
                />
              }
            />
            <Row
              title="Centre zone"
              description="For displays without a notch"
              control={
                <>
                  {hidden ? (
                    <Badge tone="warn">
                      {hidden} {hidden === 1 ? "item" : "items"} hidden
                    </Badge>
                  ) : null}
                  <Switch
                    aria-label="Centre zone"
                    checked={bar.centre}
                    onCheckedChange={(centre) => patchBar({ centre })}
                  />
                </>
              }
            />
            <Row
              title="Hide the macOS menu bar"
              control={
                <Switch
                  aria-label="Hide the macOS menu bar"
                  checked={bar.hideNative}
                  onCheckedChange={(hideNative) => patchBar({ hideNative })}
                />
              }
            />
          </CardRows>
        </Card>
      </div>

      <ItemLibrary
        zone={adding}
        present={new Set(items.map((entry) => entry.id))}
        look={paint}
        onAdd={(item) => setItems((current) => addItem(current, item))}
        onClose={() => setAdding(null)}
      />
    </>
  );
}
