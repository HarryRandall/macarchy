import { ArrowDown, ArrowUp, ListPlus, Plus, X } from "lucide-react";
import { useId } from "react";

import type {
  WidgetClick,
  WidgetMenuRow,
  WidgetRowType,
  WidgetSettingInfo,
} from "~/bridge/protocol";
import { Button } from "~/components/ui/button";
import { EmptyState } from "~/components/ui/empty-state";
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
  fill,
  moveRow,
  newRow,
  retype,
  rowTypeName,
  rowTypes,
  settingOf,
  withClick,
} from "./widget-model";
import { MenuPreview } from "./widget-preview";
import { ControlRow, CustomNote, Group, type SectionProps } from "./widget-sections";

const modes = [
  { value: "none" as const, label: "Nothing" },
  { value: "app" as const, label: "Open app" },
  { value: "command" as const, label: "Command" },
  { value: "dropdown" as const, label: "Dropdown" },
];

/**
 * What clicking the widget does. Changing it changes this copy only, and
 * says so; Reset brings back the widget's own click. With `preview`, the
 * dropdown is drawn here as well, for the inspector, where the bar preview
 * may be out of view.
 */
export function ClickSection({
  item,
  widget,
  onChange,
  selectedRow,
  onSelectRow,
  preview = false,
}: SectionProps & {
  /** The dropdown row being edited, shared with the preview. */
  selectedRow: number | null;
  onSelectRow: (index: number | null) => void;
  preview?: boolean;
}) {
  const click = clickOf(item, widget);
  const mode = clickMode(click);
  const set = (next: WidgetClick | null) => onChange(withClick(widget, next));
  const settings = Object.fromEntries(
    widget.settings.map((setting) => [setting.key, settingOf(item, setting)]),
  );
  return (
    <div className="flex flex-col gap-3">
      {item.click ? (
        <CustomNote
          onReset={() => {
            onChange({ click: null });
            onSelectRow(null);
          }}
        />
      ) : null}
      <ControlRow
        title="When clicked"
        control={
          <SegmentedControl
            label="When clicked"
            size="sm"
            value={mode}
            options={modes}
            onValueChange={(next: ClickMode) => {
              set(clickFor(next, click));
              onSelectRow(next === "dropdown" ? 0 : null);
            }}
          />
        }
      />
      {mode === "app" ? (
        <TextRow
          label="Opens"
          value={click?.open ?? ""}
          placeholder="Calendar, or a URL"
          onValue={(open) => set({ open })}
        />
      ) : null}
      {mode === "command" ? (
        <>
          <TextRow
            label="Runs"
            mono
            value={click?.run ?? ""}
            placeholder="open -a Calendar"
            onValue={(run) => set({ run })}
          />
          <Notice.Root variant="warning">
            <Notice.Description>Runs as you, with your permissions.</Notice.Description>
          </Notice.Root>
        </>
      ) : null}
      {mode === "dropdown" ? (
        <>
          {preview && click?.dropdown ? (
            <div className="flex justify-center rounded-control bg-[rgb(20_20_22)] p-3">
              <MenuPreview
                rows={click.dropdown}
                settings={settings}
                selected={selectedRow}
                onSelect={onSelectRow}
              />
            </div>
          ) : null}
          <RowsEditor
            rows={click?.dropdown ?? []}
            settings={widget.settings}
            selected={selectedRow}
            onSelect={onSelectRow}
            onRows={(dropdown) => set({ dropdown })}
          />
        </>
      ) : null}
    </div>
  );
}

function rowName(row: WidgetMenuRow): string {
  return row.type === "divider" ? "divider" : fill(row.label) || rowTypeName(row.type);
}

/** The rows, with the one being edited opened in place under it. */
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
  const update = (index: number, patch: Partial<WidgetMenuRow>) =>
    onRows(rows.map((entry, other) => (other === index ? { ...entry, ...patch } : entry)));
  return (
    <Group label={`Rows · ${rows.length}`} stacked>
      {rows.length === 0 ? (
        <EmptyState
          variant="plain"
          className="py-4"
          icon={<ListPlus />}
          title="No rows yet"
          description="Add a heading, a reading or an action below to fill the dropdown."
        />
      ) : null}
      <ul className="flex flex-col gap-1">
        {rows.map((entry, index) => (
          // oxlint-disable-next-line react/no-array-index-key -- rows have no id; their place is what is selected.
          <li key={index} className="flex flex-col gap-1">
            <div className="flex items-center gap-1">
              <button
                type="button"
                aria-pressed={selected === index}
                aria-label={`${rowTypeName(entry.type)} row: ${rowName(entry)}`}
                onClick={() => onSelect(selected === index ? null : index)}
                className={cn(
                  "flex h-8 min-w-0 flex-1 items-center gap-2 rounded-control border px-2 text-left transition-colors",
                  selected === index
                    ? "border-accent bg-accent-soft"
                    : "border-hairline bg-card hover:bg-hover",
                  focusRing,
                )}
              >
                <span className="w-16 shrink-0 text-caption font-semibold tracking-wide text-fg-secondary uppercase">
                  {rowTypeName(entry.type)}
                </span>
                <span className="min-w-0 flex-1 truncate text-detail text-fg">
                  {entry.type === "divider" ? "Line" : entry.label}
                </span>
                <span className="max-w-[40%] truncate font-mono text-small text-fg-secondary">
                  {entry.value ?? entry.open ?? entry.run ?? entry.setting ?? ""}
                </span>
              </button>
              <IconButton
                label={`Remove ${rowName(entry)} row`}
                size="sm"
                onClick={() => {
                  onRows(rows.filter((_, other) => other !== index));
                  onSelect(null);
                }}
              >
                <X aria-hidden />
              </IconButton>
            </div>
            {selected === index ? (
              <RowEditor
                row={entry}
                index={index}
                count={rows.length}
                settings={settings}
                onChange={(patch) => update(index, patch)}
                onType={(type) =>
                  onRows(
                    rows.map((row, other) => (other === index ? retype(row, type, settings) : row)),
                  )
                }
                onMove={(by) => {
                  onRows(moveRow(rows, index, by));
                  onSelect(index + by);
                }}
              />
            ) : null}
          </li>
        ))}
      </ul>
      <div role="group" aria-labelledby={addId} className="flex flex-wrap items-center gap-1">
        <span id={addId} className="pr-1 text-small text-fg-secondary">
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
    <div className="ml-2 flex flex-col gap-2 rounded-control border border-hairline bg-side p-3">
      <ControlRow
        title="Type"
        control={
          <span className="flex items-center gap-1">
            {editable ? (
              <Select
                label="Row type"
                size="sm"
                value={row.type}
                options={typeOptions}
                onValueChange={onType}
              />
            ) : (
              <span className="text-detail text-fg-secondary">{rowTypeName(row.type)}</span>
            )}
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
          </span>
        }
      />
      {row.type !== "divider" ? (
        <TextRow label="Label" value={row.label ?? ""} onValue={(label) => onChange({ label })} />
      ) : null}
      {row.type === "heading" || row.type === "reading" ? (
        <TextRow
          label={row.type === "heading" ? "Right side" : "Value"}
          mono
          value={row.value ?? ""}
          placeholder="{time}"
          help="Readings go in braces, such as {time} or {time:Europe/London}"
          onValue={(value) => onChange({ value: value || undefined })}
        />
      ) : null}
      {row.type === "action" ? <ActionFields row={row} onChange={onChange} /> : null}
      {row.type === "toggle" || row.type === "choice" ? (
        settingOptions.length > 0 ? (
          <ControlRow
            title="Setting"
            control={
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
            }
          />
        ) : (
          <p className="text-small text-fg-secondary">
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
      <ControlRow
        title="Does"
        control={
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
          />
        }
      />
      <TextRow
        label={runs ? "Command" : "App or link"}
        mono={runs}
        value={(runs ? row.run : row.open) ?? ""}
        placeholder={runs ? "open -a Calendar" : "Calendar, or a URL"}
        help={runs ? "Runs as you when picked" : undefined}
        onValue={(value) => onChange(runs ? { run: value } : { open: value })}
      />
    </>
  );
}

function TextRow({
  label,
  value,
  placeholder,
  help,
  mono,
  onValue,
}: {
  label: string;
  value: string;
  placeholder?: string;
  help?: string;
  mono?: boolean;
  onValue: (value: string) => void;
}) {
  return (
    <ControlRow
      title={label}
      help={help}
      control={
        <Input
          aria-label={label}
          size="sm"
          className="w-44"
          variant={mono ? "mono" : undefined}
          placeholder={placeholder}
          value={value}
          onChange={(event) => onValue(event.currentTarget.value)}
        />
      }
    />
  );
}
