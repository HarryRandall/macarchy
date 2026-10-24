import { Maximize2, MousePointerClick, Terminal, Trash } from "lucide-react";
import { type KeyboardEvent, useId, useState } from "react";

import type { WidgetInfo } from "~/bridge/protocol";
import { Badge } from "~/components/ui/badge";
import { EmptyState } from "~/components/ui/empty-state";
import { IconButton } from "~/components/ui/icon-button";
import { SegmentedControl } from "~/components/ui/segmented-control";
import { TabPanel, Tabs } from "~/components/ui/tabs";
import { Field, Input } from "~/components/ui/text-field";
import { Tooltip } from "~/components/ui/tooltip";

import { ItemIcon } from "./menu-bar-icon";
import { type BarItem, glyphs, intervals } from "./menu-bar-items";
import { ClickSection } from "./widget-click";
import { widgetOf } from "./widget-model";
import {
  ContentSection,
  FilesSection,
  Group,
  LookSection,
  UpdatesSection,
} from "./widget-sections";

export type InspectorTab = "content" | "look" | "click" | "files";

const tabs = [
  { id: "content" as const, label: "Content" },
  { id: "look" as const, label: "Look" },
  { id: "click" as const, label: "Click" },
  { id: "files" as const, label: "Files" },
];

export interface WidgetFileActions {
  reveal: (widget: string) => void;
  open: (widget: string, file: string) => void;
  duplicate: (widget: string) => void;
  /** Where the last copy went, to say so. */
  duplicated: string | null;
}

/** Where a widget comes from, as a badge. */
export function OriginBadge({ widget }: { widget: WidgetInfo }) {
  return (
    <>
      {widget.origin === "user" ? <Badge tone="accent">Yours</Badge> : <Badge>Built-in</Badge>}
      {widget.scripted ? <ScriptBadge widget={widget} /> : null}
    </>
  );
}

/** That the widget runs a command as the person, and which, on hover. */
export function ScriptBadge({ widget, compact }: { widget: WidgetInfo; compact?: boolean }) {
  const what = widget.provider ?? "a command";
  return (
    <Tooltip content={`Runs ${what} as you, with your permissions`}>
      <Badge tone="warn" className={compact ? "h-[18px] px-1.5 text-caption" : undefined}>
        <Terminal aria-hidden size={10} />
        {compact ? null : "Runs a script"}
        <span className="sr-only">{compact ? `Runs ${what} as you` : null}</span>
      </Badge>
    </Tooltip>
  );
}

/**
 * The selected item's settings beside the zones. A widget gets its sections
 * in tabs and a way into the full editor; a made item gets its fields.
 */
export function ItemInspector({
  item,
  widgets,
  files,
  selectedRow,
  onSelectRow,
  onChange,
  onRemove,
  onOpenEditor,
}: {
  item: BarItem | null;
  widgets: readonly WidgetInfo[];
  files: WidgetFileActions;
  selectedRow: number | null;
  onSelectRow: (index: number | null) => void;
  onChange: (patch: Partial<BarItem>) => void;
  onRemove: () => void;
  onOpenEditor: () => void;
}) {
  const [tab, setTab] = useState<InspectorTab>("content");
  const tabsId = useId();
  if (!item) {
    return (
      <aside
        aria-label="Item"
        className="grid place-items-center rounded-card border border-dashed border-hairline @min-[900px]:min-h-[220px]"
      >
        <EmptyState
          variant="plain"
          icon={<MousePointerClick />}
          title="Nothing picked"
          description="Click a widget in the preview, or one in a zone, to edit it here."
        />
      </aside>
    );
  }
  const widget = widgetOf(item, widgets);
  return (
    <aside
      aria-label={item.title}
      className="flex flex-col gap-4 rounded-card border border-hairline bg-card p-4 shadow-card"
    >
      <div className="flex items-center gap-3">
        <span className="grid size-9 shrink-0 place-items-center rounded-tile border border-hairline bg-side text-fg-secondary">
          <ItemIcon item={item} size={15} />
        </span>
        <div className="flex min-w-0 flex-1 flex-col gap-1">
          <div className="flex items-center gap-2">
            <span className="truncate text-card-title text-fg">{item.title}</span>
            {widget ? <OriginBadge widget={widget} /> : null}
          </div>
        </div>
        {widget ? (
          <IconButton label="Open full editor" onClick={onOpenEditor}>
            <Maximize2 aria-hidden />
          </IconButton>
        ) : null}
        <IconButton label="Remove from the bar" tone="danger" onClick={onRemove}>
          <Trash aria-hidden />
        </IconButton>
      </div>

      {widget ? (
        <>
          <Tabs tabs={tabs} value={tab} onChange={setTab} label="Widget settings" id={tabsId} />
          <TabPanel tabs={tabsId} value={tab} className="flex flex-col gap-4">
            {tab === "content" ? (
              <ContentSection
                item={item}
                widget={widget}
                onChange={onChange}
                onOpenFile={(file) => files.open(widget.id, file)}
              />
            ) : tab === "look" ? (
              <LookSection item={item} widget={widget} onChange={onChange} />
            ) : tab === "click" ? (
              <>
                <ClickSection
                  item={item}
                  widget={widget}
                  onChange={onChange}
                  selectedRow={selectedRow}
                  onSelectRow={onSelectRow}
                />
                <Group label="Updates">
                  <UpdatesSection widget={widget} />
                </Group>
              </>
            ) : (
              <FilesSection
                widget={widget}
                onReveal={() => files.reveal(widget.id)}
                onOpen={(file) => files.open(widget.id, file)}
                onDuplicate={() => files.duplicate(widget.id)}
                duplicated={files.duplicated}
              />
            )}
          </TabPanel>
        </>
      ) : item.kind === "widget" ? (
        <p className="text-detail text-fg-secondary">
          The widget {item.widget} is no longer in your widgets folder. Remove it, or put its folder
          back.
        </p>
      ) : (
        <ItemFields item={item} onChange={onChange} />
      )}
    </aside>
  );
}

/** Enter finishes typing in a field, as Return does in a macOS form. */
function stopEnter(event: KeyboardEvent) {
  if (event.key === "Enter") (event.currentTarget as HTMLInputElement).blur();
}

/** A made item's own fields: its name, and what it shows. */
function ItemFields({
  item,
  onChange,
}: {
  item: BarItem;
  onChange: (patch: Partial<BarItem>) => void;
}) {
  const glyphLabelId = useId();

  return (
    <div className="flex flex-col gap-3">
      <Field.Root>
        <Field.Label className="text-small text-fg-secondary">Name</Field.Label>
        <Input
          size="sm"
          value={item.title}
          onChange={(event) => onChange({ title: event.currentTarget.value })}
          onKeyDown={stopEnter}
        />
      </Field.Root>
      {item.kind === "text" ? (
        <Field.Root>
          <Field.Label className="text-small text-fg-secondary">Text</Field.Label>
          <Input
            size="sm"
            value={item.text}
            onChange={(event) => onChange({ text: event.currentTarget.value })}
            onKeyDown={stopEnter}
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
              onKeyDown={stopEnter}
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
    </div>
  );
}
