import { Check, RotateCcw } from "lucide-react";
import { useId, useLayoutEffect, useRef, useState } from "react";

import type { BarItemKind, MenuBarSettings, MenuBarState } from "~/bridge/protocol";
import { PageHeader } from "~/components/layout/page-header";
import { Button } from "~/components/ui/button";
import { Card, CardHeader, CardRows, Row, SectionLabel } from "~/components/ui/card";
import { Notice } from "~/components/ui/notice";
import { SegmentedControl } from "~/components/ui/segmented-control";
import { ValueSlider } from "~/components/ui/value-slider";
import { useStore } from "~/lib/store";
import type { PageContext } from "~/shell/page";

import { BarPreview } from "./bar-preview";
import { BarZone, type DropTarget, type KeyMove } from "./bar-zone";
import { ItemLibrary } from "./item-library";
import {
  addItem,
  type BarItem,
  editsOf,
  moveItem,
  newItem,
  patchItem,
  problemWith,
  removeItem,
  sameBar,
  sameItems,
  shiftZone,
  stepItem,
  type Zone,
  zoneLabels,
  zones,
} from "./menu-bar-items";
import { fallbackLook, type MenuBarStore } from "./menu-bar-store";

const positionOptions = [
  { value: "top" as const, label: "Top" },
  { value: "bottom" as const, label: "Bottom" },
];

interface Draft {
  /** The state this draft started from, so a newer read can replace an untouched draft. */
  base: MenuBarState;
  items: BarItem[];
  bar: MenuBarSettings;
}

const noItems: BarItem[] = [];

const draftOf = (state: MenuBarState): Draft => ({
  base: state,
  items: state.items,
  bar: state.bar,
});

const edited = (draft: Draft) =>
  !sameItems(draft.items, draft.base.items) || !sameBar(draft.bar, draft.base.bar);

/**
 * The bar editor. Edits stay in the page until Apply, which makes SketchyBar
 * match and saves the configuration that startup replays.
 */
export function MenuBarPage({ store, context }: { store: MenuBarStore; context: PageContext }) {
  const snapshot = useStore(store);
  const paint = snapshot.look ?? fallbackLook;
  const [draft, setDraft] = useState<Draft | null>(null);
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

  // A fresh read replaces the draft only while nothing in it has been changed.
  const state = snapshot.state;
  if (state && draft?.base !== state && (!draft || !edited(draft))) setDraft(draftOf(state));

  const items = draft?.items ?? noItems;

  useLayoutEffect(() => {
    const id = refocus.current;
    if (!id) return;
    refocus.current = null;
    zonesRef.current?.querySelector<HTMLElement>(`[data-move-handle="${CSS.escape(id)}"]`)?.focus();
    // oxlint-disable-next-line react/exhaustive-effect-dependencies -- a moved item is focused again once the list has redrawn.
  }, [items]);

  if (snapshot.status === "loading") return <PageHeader title="Menu Bar" />;

  if (!state || !draft) {
    return (
      <>
        <PageHeader title="Menu Bar" />
        <Notice.Root variant="error">
          <Notice.Title>Could not read your menu bar</Notice.Title>
          <Notice.Description>{snapshot.error}</Notice.Description>
          <Notice.Actions>
            <Button onClick={() => void store.load()}>Try again</Button>
            <Button variant="ghost" onClick={() => context.openLogs()}>
              Show logs
            </Button>
          </Notice.Actions>
        </Notice.Root>
      </>
    );
  }

  const unavailable = state.unavailableReason;
  const changed = edited(draft);
  const problem = items.map(problemWith).find((entry) => entry !== null) ?? null;
  const setItems = (change: (current: BarItem[]) => BarItem[]) =>
    setDraft((current) => (current ? { ...current, items: change(current.items) } : current));
  const patchBar = (patch: Partial<MenuBarSettings>) =>
    setDraft((current) => (current ? { ...current, bar: { ...current.bar, ...patch } } : current));

  const reset = () => {
    setDraft(draftOf(state));
    setEditing(null);
    store.dismissError();
  };

  const apply = async () => {
    if (await store.apply(editsOf(draft.items), draft.bar)) {
      const next = store.getSnapshot().state;
      if (next) setDraft(draftOf(next));
      setEditing(null);
    }
  };

  const make = (kind: BarItemKind, zone: Zone) => {
    const item = newItem(kind, zone);
    setItems((current) => addItem(current, item));
    if (kind !== "spacer") setEditing(item.id);
  };

  const show = (id: string, zone: Zone) =>
    setItems((current) => patchItem(moveItem(current, id, zone), id, { visible: true }));

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
        : shiftZone(items, id, move.direction);
    if (next === items) return;
    refocus.current = id;
    setItems(() => next);
    const moved = next.find((entry) => entry.id === id);
    if (!moved) return;
    const inZone = next.filter((entry) => entry.zone === moved.zone);
    setAnnouncement(
      `${moved.title}, ${zoneLabels[moved.zone]} zone, ${inZone.indexOf(moved) + 1} of ${inZone.length}`,
    );
  };

  return (
    <>
      <PageHeader
        title="Menu Bar"
        actions={
          <>
            <Button
              size="sm"
              variant="ghost"
              disabled={!changed || snapshot.applying}
              onClick={reset}
            >
              <RotateCcw aria-hidden size={12} /> Reset
            </Button>
            <Button
              size="sm"
              variant="primary"
              disabled={!changed || problem !== null || unavailable !== null}
              busy={snapshot.applying}
              onClick={() => void apply()}
            >
              <Check aria-hidden size={13} /> Apply
            </Button>
          </>
        }
      />

      <div className="flex flex-col">
        {unavailable ? (
          <Notice.Root variant="warning" className="mb-5">
            <Notice.Title>The bar is not running</Notice.Title>
            <Notice.Description>{unavailable}</Notice.Description>
            <Notice.Actions>
              <Button onClick={() => void store.load()}>Try again</Button>
            </Notice.Actions>
          </Notice.Root>
        ) : null}

        {snapshot.error ? (
          <Notice.Root variant="error" className="mb-5">
            <Notice.Header onDismiss={() => store.dismissError()}>
              <Notice.Title>Could not change the bar</Notice.Title>
              <Notice.Description>{snapshot.error}</Notice.Description>
            </Notice.Header>
          </Notice.Root>
        ) : null}

        <div className="mb-5">
          <SectionLabel>Preview</SectionLabel>
          <BarPreview
            items={items}
            bar={draft.bar}
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
        <div ref={zonesRef} className="grid grid-cols-3 gap-3">
          {zones.map((zone) => (
            <BarZone
              key={zone}
              zone={zone}
              items={items.filter((entry) => entry.zone === zone)}
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
                  value={draft.bar.height}
                  min={16}
                  max={64}
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
                  value={draft.bar.position}
                  options={positionOptions}
                  onValueChange={(position) => patchBar({ position })}
                />
              }
            />
            <Row
              title="Padding"
              description="At each end of the bar"
              controlId={paddingId}
              control={
                <ValueSlider
                  id={paddingId}
                  label="Bar padding"
                  value={draft.bar.padding}
                  min={0}
                  max={64}
                  unit="pt"
                  onValueChange={(padding) => patchBar({ padding })}
                />
              }
            />
          </CardRows>
        </Card>
      </div>

      <ItemLibrary
        zone={adding}
        hidden={items.filter((entry) => entry.kind === null && !entry.visible)}
        onMake={make}
        onShow={show}
        onClose={() => setAdding(null)}
      />
    </>
  );
}
