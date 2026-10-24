import { Check, RotateCcw } from "lucide-react";
import { useId, useLayoutEffect, useRef, useState } from "react";

import type { MenuBarSettings, MenuBarState } from "~/bridge/protocol";
import { PageHeader } from "~/components/layout/page-header";
import { Badge } from "~/components/ui/badge";
import { Button } from "~/components/ui/button";
import { Card, CardHeader, CardRows, Row } from "~/components/ui/card";
import { Notice } from "~/components/ui/notice";
import { SegmentedControl } from "~/components/ui/segmented-control";
import { Switch } from "~/components/ui/switch";
import { ValueSlider } from "~/components/ui/value-slider";
import { cn } from "~/lib/cn";
import { useStore } from "~/lib/store";
import type { PageContext } from "~/shell/page";

import { BarPreview } from "./bar-preview";
import { BarZone, type DropTarget, type KeyMove } from "./bar-zone";
import { ItemInspector, type WidgetFileActions } from "./item-inspector";
import { ItemLibrary } from "./item-library";
import {
  addItem,
  type BarItem,
  editsOf,
  moveItem,
  newItem,
  newWidgetItem,
  patchItem,
  problemWith,
  removeItem,
  sameBar,
  sameItems,
  shiftZone,
  stepItem,
  widgetCounts,
  type Zone,
  zoneLabels,
  zones,
} from "./menu-bar-items";
import { fallbackLook, type MenuBarStore } from "./menu-bar-store";
import { type Sample, sampleOptions, widgetOf, widgetProblem } from "./widget-model";
import { WidgetEditor } from "./widget-editor";

const positionOptions = [
  { value: "top" as const, label: "Top" },
  { value: "bottom" as const, label: "Bottom" },
];

const viewOptions = [
  { value: "widgets" as const, label: "Widgets" },
  { value: "bar" as const, label: "Bar" },
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

/** How many items differ from the bar, for the badge by Apply. */
function changeCount(draft: Draft): number {
  const before = new Map(draft.base.items.map((item) => [item.id, item]));
  let count = sameBar(draft.bar, draft.base.bar) ? 0 : 1;
  for (const item of draft.items) {
    const old = before.get(item.id);
    if (!old || !sameItems([item], [old])) count++;
    before.delete(item.id);
  }
  return count + before.size;
}

/**
 * The bar editor. Edits stay in the page until Apply, which makes SketchyBar
 * match and saves the configuration that startup replays. A widget opens in
 * the inspector beside the zones, or in the full editor in place of them.
 */
export function MenuBarPage({ store, context }: { store: MenuBarStore; context: PageContext }) {
  const snapshot = useStore(store);
  const paint = snapshot.look ?? fallbackLook;
  const [draft, setDraft] = useState<Draft | null>(null);
  const [view, setView] = useState<"widgets" | "bar">("widgets");
  const [sample, setSample] = useState<Sample>("live");
  const [selected, setSelected] = useState<string | null>(null);
  const [selectedRow, setSelectedRow] = useState<number | null>(null);
  const [fullEditor, setFullEditor] = useState<string | null>(null);
  const [duplicated, setDuplicated] = useState<string | null>(null);
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

  const widgets = state.widgets;
  const unavailable = state.unavailableReason;
  const changed = edited(draft);
  const problem =
    items
      .map((item) => problemWith(item) ?? widgetProblem(item, widgetOf(item, widgets)))
      .find((entry) => entry !== null) ?? null;
  const setItems = (change: (current: BarItem[]) => BarItem[]) =>
    setDraft((current) => (current ? { ...current, items: change(current.items) } : current));
  const patch = (id: string, change: Partial<BarItem>) =>
    setItems((current) => patchItem(current, id, change));
  const patchBar = (change: Partial<MenuBarSettings>) =>
    setDraft((current) => (current ? { ...current, bar: { ...current.bar, ...change } } : current));
  const select = (id: string | null) => {
    setSelected(id);
    setSelectedRow(null);
  };

  const reset = () => {
    setDraft(draftOf(state));
    store.dismissError();
  };

  const apply = async () => {
    if (await store.apply(editsOf(draft.items), draft.bar)) {
      const next = store.getSnapshot().state;
      if (next) setDraft(draftOf(next));
    }
  };

  const add = (item: BarItem) => {
    setItems((current) => addItem(current, item));
    if (item.kind !== "spacer") select(item.id);
    setView("widgets");
  };

  const show = (id: string, zone: Zone) => {
    setItems((current) => patchItem(moveItem(current, id, zone), id, { visible: true }));
    select(id);
  };

  // One way off the bar. The bar's own items cannot be deleted, so they are
  // hidden, and Add a widget offers them back.
  const remove = (id: string) => {
    setItems((current) =>
      current.find((entry) => entry.id === id)?.kind === null
        ? patchItem(current, id, { visible: false })
        : removeItem(current, id),
    );
    if (selected === id) select(null);
    if (fullEditor === id) setFullEditor(null);
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

  const files: WidgetFileActions = {
    reveal: (widget) => void store.reveal(widget),
    open: (widget, file) => void store.openFile(widget, file),
    // The item being edited moves to the copy, so the next edit is to the person's own.
    duplicate: (widget) => {
      const target = fullEditor ?? selected;
      void store.duplicate(widget).then((copy) => {
        if (!copy) return;
        if (target) patch(target, { widget: copy });
        const folder = store
          .getSnapshot()
          .state?.widgets.find((entry) => entry.id === copy)?.folder;
        setDuplicated(folder ?? null);
      });
    },
    duplicated,
  };

  const count = changeCount(draft);
  const header = <PageHeader title="Menu Bar" />;

  // The page's own actions, beside its controls: the top bar keeps only the window's.
  const applyBar = (
    <div className="ml-auto flex items-center gap-2">
      {changed ? (
        <Badge tone="accent">
          {count} {count === 1 ? "change" : "changes"}
        </Badge>
      ) : null}
      <Button size="sm" variant="ghost" disabled={!changed || snapshot.applying} onClick={reset}>
        <RotateCcw aria-hidden size={12} /> Revert
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
    </div>
  );

  const notices = (
    <>
      {unavailable ? (
        <Notice.Root variant="warning">
          <Notice.Title>The bar is not running</Notice.Title>
          <Notice.Description>{unavailable}</Notice.Description>
          <Notice.Actions>
            <Button onClick={() => void store.load()}>Try again</Button>
          </Notice.Actions>
        </Notice.Root>
      ) : null}
      {snapshot.error ? (
        <Notice.Root variant="error">
          <Notice.Header onDismiss={() => store.dismissError()}>
            <Notice.Title>Could not change the bar</Notice.Title>
            <Notice.Description>{snapshot.error}</Notice.Description>
          </Notice.Header>
        </Notice.Root>
      ) : null}
      {changed && problem ? (
        <Notice.Root variant="warning">
          <Notice.Description>{problem}</Notice.Description>
        </Notice.Root>
      ) : null}
    </>
  );

  const editing = fullEditor ? items.find((item) => item.id === fullEditor) : undefined;
  const editingWidget = editing ? widgetOf(editing, widgets) : null;
  if (editing && editingWidget) {
    return (
      <div className="@container flex flex-col gap-4">
        {header}
        {notices}
        <WidgetEditor
          item={editing}
          widget={editingWidget}
          items={items}
          bar={draft.bar}
          look={paint}
          widgets={widgets}
          sample={sample}
          onSample={setSample}
          selectedRow={selectedRow}
          onSelectRow={setSelectedRow}
          files={files}
          actions={applyBar}
          onChange={(change) => patch(editing.id, change)}
          onBack={() => setFullEditor(null)}
        />
      </div>
    );
  }

  const current = items.find((item) => item.id === selected) ?? null;
  // A notch hides the centre, so it is offered only when asked for or already in use.
  const shownZones = zones.filter(
    (zone) =>
      zone !== "centre" ||
      draft.bar.centre ||
      items.some((item) => item.zone === zone && item.visible),
  );

  return (
    <div className="@container flex flex-col gap-4">
      {header}
      {notices}

      <div className="flex flex-col gap-2">
        <div className="flex flex-wrap items-center gap-x-3 gap-y-2">
          <SegmentedControl
            label="Menu Bar view"
            value={view}
            options={viewOptions}
            onValueChange={setView}
          />
          <SegmentedControl
            label="Sample values"
            value={sample}
            options={sampleOptions}
            onValueChange={setSample}
          />
          {applyBar}
        </div>
        <BarPreview
          items={items}
          bar={draft.bar}
          look={paint}
          widgets={widgets}
          sample={sample}
          active={selected}
          onSelect={(id) => {
            select(id);
            setView("widgets");
          }}
        />
      </div>

      {view === "widgets" ? (
        <div className="grid grid-cols-1 items-start gap-4 @min-[900px]:grid-cols-[minmax(0,1fr)_320px]">
          <div className="flex min-w-0 flex-col gap-2">
            <p id={moveHintId} className="sr-only">
              Up and Down arrows reorder within a zone; Left and Right move to the next zone.
            </p>
            <p aria-live="polite" className="sr-only">
              {announcement}
            </p>
            <div
              ref={zonesRef}
              className={cn(
                "grid grid-cols-1 gap-3",
                shownZones.length === 3 ? "@min-[480px]:grid-cols-3" : "@min-[480px]:grid-cols-2",
              )}
            >
              {shownZones.map((zone) => (
                <BarZone
                  key={zone}
                  zone={zone}
                  items={items.filter((entry) => entry.zone === zone && entry.visible)}
                  widgets={widgets}
                  sample={sample}
                  selected={selected}
                  dragging={dragging}
                  over={over}
                  moveHintId={moveHintId}
                  onSelect={(id) => select(id === selected ? null : id)}
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
          </div>
          <div className="@min-[900px]:sticky @min-[900px]:top-0">
            <ItemInspector
              key={current?.id ?? "none"}
              item={current}
              widgets={widgets}
              files={files}
              selectedRow={selectedRow}
              onSelectRow={setSelectedRow}
              onChange={(change) => current && patch(current.id, change)}
              onRemove={() => current && remove(current.id)}
              onOpenEditor={() => current && setFullEditor(current.id)}
            />
          </div>
        </div>
      ) : (
        <Card>
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
              title="Centre zone"
              description="For displays without a notch"
              control={
                <Switch
                  aria-label="Centre zone"
                  checked={draft.bar.centre}
                  onCheckedChange={(centre) => patchBar({ centre })}
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
      )}

      <ItemLibrary
        zone={adding}
        widgets={widgets}
        counts={widgetCounts(items)}
        hidden={items.filter((entry) => !entry.visible)}
        broken={state.widgetProblems}
        look={paint}
        onAddWidget={(widget, zone) => add(newWidgetItem(widget, zone, items))}
        onMake={(kind, zone) => add(newItem(kind, zone))}
        onShow={show}
        onOpenFolder={() => void store.reveal(null)}
        onClose={() => setAdding(null)}
      />
    </div>
  );
}
