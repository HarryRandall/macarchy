import { ArrowDown, ArrowUp, Plus, Trash } from "lucide-react";
import { useId } from "react";

import type {
  WidgetClick,
  WidgetMenuRow,
  WidgetRowType,
  WidgetSettingInfo,
} from "~/bridge/protocol";
import { Button } from "~/components/ui/button";
import { focusRing } from "~/components/ui/focus-ring";
import { IconButton } from "~/components/ui/icon-button";
import { Notice } from "~/components/ui/notice";
import { SegmentedControl } from "~/components/ui/segmented-control";
import { Select } from "~/components/ui/select";
import { Input } from "~/components/ui/text-field";
import { cn } from "~/lib/cn";

import {
  type ClickMode,
  clickFor,
  clickMode,
  clickOf,
  moveRow,
  newRow,
  retype,
  rowTypeName,
  rowTypes,
  withClick,
} from "./widget-model";
import { Group, type SectionProps } from "./widget-sections";

const modes = [
  { value: "none" as const, label: "Nothing" },
  { value: "app" as const, label: "Open app" },
  { value: "command" as const, label: "Command" },
  { value: "dropdown" as const, label: "Dropdown" },
];

/**
 * What clicking the widget does. Changing it changes this item only; the
 * widget's own click comes back with "Use the widget's click".
 */
export function ClickSection({
  item,
  widget,
  onChange,
  selectedRow,
  onSelectRow,
}: SectionProps & {
  /** The dropdown row being edited, shared with the preview. */
  selectedRow: number | null;
  onSelectRow: (index: number | null) => void;
}) {
  const click = clickOf(item, widget);
  const mode = clickMode(click);
  const set = (next: WidgetClick | null) => onChange(withClick(widget, next));
  return (
    <div className="flex flex-col gap-4">
      <Group label="When clicked">
        <SegmentedControl
          label="When clicked"
          size="sm"
          value={mode}
          options={modes}
          onValueChange={(next: ClickMode) => {
            set(clickFor(next, click));
            onSelectRow(next === "dropdown" ? 0 : null);
          }}
          fill
        />
      </Group>
      {mode === "app" ? (
        <Group label="App or link" hint="An app's name, such as Calendar, or a URL.">
          <Input
            aria-label="App or link"
            size="sm"
            value={click?.open ?? ""}
            placeholder="Calendar"
            onChange={(event) => set({ open: event.currentTarget.value })}
          />
        </Group>
      ) : null}
      {mode === "command" ? (
        <Group label="Command">
          <Input
            aria-label="Command"
            size="sm"
            variant="mono"
            value={click?.run ?? ""}
            placeholder="open -a Calendar"
            onChange={(event) => set({ run: event.currentTarget.value })}
          />
          <Notice.Root variant="warning">
            <Notice.Description>
              Runs as you, with your permissions, from the widget&apos;s folder.
            </Notice.Description>
          </Notice.Root>
        </Group>
      ) : null}
      {mode === "dropdown" ? (
        <RowsEditor
          rows={click?.dropdown ?? []}
          settings={widget.settings}
          selected={selectedRow}
          onSelect={onSelectRow}
          onRows={(dropdown) => set({ dropdown })}
        />
      ) : null}
      {item.click ? (
        <Button
          size="sm"
          variant="ghost"
          className="self-start"
          onClick={() => {
            onChange({ click: null });
            onSelectRow(null);
          }}
        >
          Use the widget&apos;s click
        </Button>
      ) : null}
    </div>
  );
}

function RowsEditor({
  rows,
  settings,
  selected,
  onSelect,
  onRows,
}: {
  rows: WidgetMenuRow[];
  settings: WidgetSettingInfo[];
  selected: number | null;
  onSelect: (index: number | null) => void;
  onRows: (rows: WidgetMenuRow[]) => void;
}) {
  const addId = useId();
  const row = selected !== null ? rows[selected] : undefined;
  const update = (patch: Partial<WidgetMenuRow>) => {
    if (selected === null || !row) return;
    onRows(rows.map((entry, index) => (index === selected ? { ...entry, ...patch } : entry)));
  };
  return (
    <>
      <Group label={`Menu · ${rows.length} ${rows.length === 1 ? "row" : "rows"}`}>
        <ul className="flex flex-col gap-1">
          {rows.map((entry, index) => (
            // oxlint-disable-next-line react/no-array-index-key -- rows have no id; their place is what is selected.
            <li key={index} className="flex items-center gap-1">
              <button
                type="button"
                aria-pressed={selected === index}
                onClick={() => onSelect(index)}
                className={cn(
                  "flex h-8 min-w-0 flex-1 items-center gap-2 rounded-control border px-2 text-left transition-colors",
                  selected === index
                    ? "border-accent bg-accent-soft"
                    : "border-hairline bg-card hover:bg-hover",
                  focusRing,
                )}
              >
                <span className="w-16 shrink-0 text-caption font-semibold tracking-wide text-fg-tertiary uppercase">
                  {rowTypeName(entry.type)}
                </span>
                <span className="min-w-0 flex-1 truncate text-detail text-fg">
                  {entry.type === "divider" ? "Line" : entry.label}
                </span>
                <span className="max-w-[40%] truncate font-mono text-small text-fg-tertiary">
                  {entry.value ?? entry.open ?? entry.run ?? entry.setting ?? ""}
                </span>
              </button>
              <IconButton
                label={`Remove row ${index + 1}`}
                size="sm"
                tone="danger"
                onClick={() => {
                  onRows(rows.filter((_, other) => other !== index));
                  onSelect(null);
                }}
              >
                <Trash aria-hidden />
              </IconButton>
            </li>
          ))}
        </ul>
        <div role="group" aria-labelledby={addId} className="flex flex-wrap items-center gap-1.5">
          <span id={addId} className="text-small text-fg-tertiary">
            Add
          </span>
          {rowTypes.map(({ type, name }) => (
            <Button
              key={type}
              size="sm"
              variant="ghost"
              onClick={() => {
                onRows([...rows, newRow(type, settings)]);
                onSelect(rows.length);
              }}
            >
              <Plus aria-hidden size={11} /> {name}
            </Button>
          ))}
        </div>
      </Group>
      {row && selected !== null ? (
        <RowEditor
          row={row}
          index={selected}
          count={rows.length}
          settings={settings}
          onChange={update}
          onType={(type) =>
            onRows(
              rows.map((entry, index) =>
                index === selected ? retype(entry, type, settings) : entry,
              ),
            )
          }
          onMove={(by) => {
            onRows(moveRow(rows, selected, by));
            onSelect(selected + by);
          }}
        />
      ) : null}
    </>
  );
}

const typeOptions = rowTypes.map(({ type, name }) => ({ value: type, label: name }));

function RowEditor({
  row,
  index,
  count,
  settings,
  onChange,
  onType,
  onMove,
}: {
  row: WidgetMenuRow;
  index: number;
  count: number;
  settings: WidgetSettingInfo[];
  onChange: (patch: Partial<WidgetMenuRow>) => void;
  onType: (type: WidgetRowType) => void;
  onMove: (by: -1 | 1) => void;
}) {
  const editable = rowTypes.some((entry) => entry.type === row.type);
  const settingOptions = settings
    .filter((setting) => setting.type === (row.type === "toggle" ? "toggle" : "choice"))
    .map((setting) => ({ value: setting.key, label: setting.label }));
  return (
    <div className="flex flex-col gap-3 rounded-control border border-hairline bg-side p-3">
      <div className="flex items-center gap-2">
        <span className="flex-1 text-label text-fg-tertiary uppercase">Row {index + 1}</span>
        <IconButton label="Move up" size="sm" disabled={index === 0} onClick={() => onMove(-1)}>
          <ArrowUp aria-hidden />
        </IconButton>
        <IconButton
          label="Move down"
          size="sm"
          disabled={index === count - 1}
          onClick={() => onMove(1)}
        >
          <ArrowDown aria-hidden />
        </IconButton>
      </div>
      {editable ? (
        <Select
          label="Row type"
          size="sm"
          value={row.type}
          options={typeOptions}
          onValueChange={onType}
        />
      ) : (
        <p className="text-small text-fg-tertiary">
          A {rowTypeName(row.type).toLowerCase()} row, drawn from what the widget reads.
        </p>
      )}
      {row.type !== "divider" ? (
        <Field label="Label" value={row.label ?? ""} onValue={(label) => onChange({ label })} />
      ) : null}
      {row.type === "heading" || row.type === "reading" ? (
        <Field
          label={row.type === "heading" ? "Right side" : "Value"}
          mono
          value={row.value ?? ""}
          hint="Readings in braces, such as {time} or {time:Europe/London}."
          onValue={(value) => onChange({ value: value || undefined })}
        />
      ) : null}
      {row.type === "action" ? <ActionFields row={row} onChange={onChange} /> : null}
      {row.type === "toggle" || row.type === "choice" ? (
        settingOptions.length > 0 ? (
          <Select
            label="Setting"
            size="sm"
            value={row.setting ?? settingOptions[0]?.value ?? ""}
            options={settingOptions}
            onValueChange={(setting) =>
              onChange({
                setting,
                options:
                  row.type === "choice"
                    ? settings.find((entry) => entry.key === setting)?.options
                    : undefined,
              })
            }
          />
        ) : (
          <p className="text-small text-fg-tertiary">
            This widget has no {row.type === "toggle" ? "toggle" : "choice"} setting to change.
          </p>
        )
      ) : null}
    </div>
  );
}

function ActionFields({
  row,
  onChange,
}: {
  row: WidgetMenuRow;
  onChange: (patch: Partial<WidgetMenuRow>) => void;
}) {
  const runs = row.run !== undefined;
  return (
    <>
      <SegmentedControl
        label="The action"
        size="sm"
        value={runs ? "run" : "open"}
        options={[
          { value: "open", label: "Opens" },
          { value: "run", label: "Runs" },
        ]}
        onValueChange={(next) =>
          onChange(
            next === "run"
              ? { run: row.open ?? "", open: undefined }
              : { open: row.run ?? "", run: undefined },
          )
        }
        fill
      />
      <Field
        label={runs ? "Command" : "App or link"}
        mono={runs}
        value={(runs ? row.run : row.open) ?? ""}
        hint={
          runs
            ? "Runs as you when picked."
            : "An app's name, or a URL such as a System Settings page."
        }
        onValue={(value) => onChange(runs ? { run: value } : { open: value })}
      />
    </>
  );
}

function Field({
  label,
  value,
  hint,
  mono,
  onValue,
}: {
  label: string;
  value: string;
  hint?: string;
  mono?: boolean;
  onValue: (value: string) => void;
}) {
  return (
    <Group label={label} hint={hint}>
      <Input
        aria-label={label}
        size="sm"
        variant={mono ? "mono" : undefined}
        value={value}
        onChange={(event) => onValue(event.currentTarget.value)}
      />
    </Group>
  );
}
