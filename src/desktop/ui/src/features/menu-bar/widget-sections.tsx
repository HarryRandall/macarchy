import { ExternalLink, FileText, Folder, SlidersHorizontal } from "lucide-react";
import { type ReactNode, useId } from "react";

import type { WidgetInfo, WidgetSettingInfo, WidgetStyle } from "~/bridge/protocol";
import { Button } from "~/components/ui/button";
import { CodeBlock } from "~/components/ui/code-block";
import { ColourField } from "~/components/ui/colour-field";
import { EmptyState } from "~/components/ui/empty-state";
import { focusRing } from "~/components/ui/focus-ring";
import { SegmentedControl } from "~/components/ui/segmented-control";
import { Select } from "~/components/ui/select";
import { Switch } from "~/components/ui/switch";
import { Input } from "~/components/ui/text-field";
import { ValueSlider } from "~/components/ui/value-slider";
import { cn } from "~/lib/cn";

import type { BarItem } from "./menu-bar-items";
import {
  eventName,
  humanise,
  lookOf,
  settingOf,
  updateText,
  withLook,
  withSetting,
} from "./widget-model";

export interface SectionProps {
  item: BarItem;
  widget: WidgetInfo;
  onChange: (patch: Partial<BarItem>) => void;
}

/** A small heading over a group of controls. */
export function Group({
  label,
  labelId,
  hint,
  children,
}: {
  label: string;
  labelId?: string;
  hint?: ReactNode;
  children: ReactNode;
}) {
  return (
    <div className="flex flex-col gap-2">
      <span id={labelId} className="text-label text-fg-tertiary uppercase">
        {label}
      </span>
      {children}
      {hint ? <p className="text-small text-fg-tertiary">{hint}</p> : null}
    </div>
  );
}

/** A label and hint on the left, a control on the right. */
export function ControlRow({
  title,
  hint,
  control,
}: {
  title: string;
  hint?: string;
  control: ReactNode;
}) {
  return (
    <div className="flex min-h-8 items-center gap-3">
      <div className="flex min-w-0 flex-1 flex-col">
        <span className="text-detail text-fg">{title}</span>
        {hint ? <span className="text-small text-fg-tertiary">{hint}</span> : null}
      </div>
      {control}
    </div>
  );
}

/** A setting on or off, as a word to press, for a widget's "Show" parts. */
function Token({
  label,
  pressed,
  onPress,
}: {
  label: string;
  pressed: boolean;
  onPress: () => void;
}) {
  return (
    <button
      type="button"
      aria-pressed={pressed}
      onClick={onPress}
      className={cn(
        "h-7 rounded-full border px-3 text-detail font-medium transition-colors",
        pressed
          ? "border-accent bg-accent-soft text-accent-text"
          : "border-hairline text-fg-secondary hover:bg-hover",
        focusRing,
      )}
    >
      {label}
    </button>
  );
}

/**
 * The widget's settings, drawn from `widget.json` in the order written.
 * Toggles without a hint are parts to show, as words to press; the rest
 * get a control each.
 */
export function ContentSection({
  item,
  widget,
  onChange,
  onOpenFile,
}: SectionProps & { onOpenFile: (file: string) => void }) {
  const showId = useId();
  const parts = widget.settings.filter((setting) => setting.type === "toggle" && !setting.hint);
  const rest = widget.settings.filter((setting) => !parts.includes(setting));
  if (widget.settings.length === 0) {
    const file = widget.provider ?? "widget.json";
    return (
      <EmptyState
        variant="plain"
        icon={<SlidersHorizontal />}
        title="Nothing to set"
        description={
          widget.provider
            ? `${widget.name} shows whatever ${widget.provider} prints. Change the script to change it.`
            : `${widget.name} has no settings in its widget.json.`
        }
        action={<Button onClick={() => onOpenFile(file)}>Open {file}</Button>}
      />
    );
  }
  return (
    <div className="flex flex-col gap-4">
      {parts.length > 0 ? (
        <Group label="Show" labelId={showId}>
          <div role="group" aria-labelledby={showId} className="flex flex-wrap gap-1.5">
            {parts.map((setting) => (
              <Token
                key={setting.key}
                label={setting.label}
                pressed={settingOf(item, setting) === true}
                onPress={() =>
                  onChange(withSetting(item, setting, settingOf(item, setting) !== true))
                }
              />
            ))}
          </div>
        </Group>
      ) : null}
      {rest.map((setting) => (
        <SettingControl
          key={setting.key}
          setting={setting}
          value={settingOf(item, setting)}
          onValue={(value) => onChange(withSetting(item, setting, value))}
        />
      ))}
    </div>
  );
}

function SettingControl({
  setting,
  value,
  onValue,
}: {
  setting: WidgetSettingInfo;
  value: string | number | boolean | undefined;
  onValue: (value: string | number | boolean) => void;
}) {
  const id = useId();
  switch (setting.type) {
    case "toggle":
      return (
        <ControlRow
          title={setting.label}
          hint={setting.hint}
          control={
            <Switch
              aria-label={setting.label}
              checked={value === true}
              onCheckedChange={(checked) => onValue(checked)}
            />
          }
        />
      );
    case "choice": {
      const options = (setting.options ?? []).map((option) => ({
        value: option,
        label: humanise(option),
      }));
      const current = typeof value === "string" ? value : (options[0]?.value ?? "");
      return (
        <Group label={setting.label} hint={setting.hint}>
          {options.length <= 3 ? (
            <SegmentedControl
              label={setting.label}
              value={current}
              options={options}
              onValueChange={onValue}
              fill
            />
          ) : (
            <Select
              label={setting.label}
              value={current}
              options={options}
              onValueChange={onValue}
            />
          )}
        </Group>
      );
    }
    case "number":
      return (
        <ControlRow
          title={setting.label}
          hint={setting.hint}
          control={
            <ValueSlider
              id={id}
              label={setting.label}
              value={typeof value === "number" ? value : (setting.min ?? 0)}
              min={setting.min ?? 0}
              max={setting.max ?? 100}
              step={setting.step}
              unit={setting.unit}
              onValueChange={onValue}
            />
          }
        />
      );
    case "colour":
      return (
        <ControlRow
          title={setting.label}
          hint={setting.hint}
          control={
            <ColourField
              label={setting.label}
              value={typeof value === "string" ? value : "#ffffff"}
              onValueChange={onValue}
            />
          }
        />
      );
    default:
      return (
        <Group label={setting.label} hint={setting.hint}>
          <Input
            aria-label={setting.label}
            variant={setting.type === "format" ? "mono" : undefined}
            size="sm"
            value={typeof value === "string" ? value : String(value ?? "")}
            onChange={(event) => onValue(event.currentTarget.value)}
          />
        </Group>
      );
  }
}

const boxOptions = [
  { value: "none" as const, label: "None" },
  { value: "outline" as const, label: "Outline" },
  { value: "fill" as const, label: "Fill" },
];

const layoutOptions = [
  { value: "stacked" as const, label: "Stacked" },
  { value: "side" as const, label: "Side by side" },
];

const colourChoices = [
  { value: "text", label: "Text" },
  { value: "accent", label: "Accent" },
  { value: "muted", label: "Muted" },
  { value: "custom", label: "Custom" },
] as const;

type ColourChoice = (typeof colourChoices)[number]["value"];

function ColourChoiceRow({
  title,
  value,
  onValue,
}: {
  title: string;
  value: string | undefined;
  onValue: (value: string) => void;
}) {
  const choice: ColourChoice =
    !value || value === "text"
      ? "text"
      : value === "accent" || value === "muted"
        ? value
        : "custom";
  return (
    <Group label={title}>
      <SegmentedControl
        label={title}
        size="sm"
        value={choice}
        options={colourChoices}
        onValueChange={(next) => onValue(next === "custom" ? "#a5b4fc" : next)}
        fill
      />
      {choice === "custom" && value ? (
        <ColourField label={`${title}, custom`} value={value} onValueChange={onValue} />
      ) : null}
    </Group>
  );
}

/** The widget's look. Anything left alone follows the widget, and through it the theme. */
export function LookSection({ item, widget, onChange }: SectionProps) {
  const style = lookOf(item, widget);
  const set = (patch: WidgetStyle) => onChange(withLook(item, widget, patch));
  const sizeOptions = [11, 12, 13, 14].map((size) => ({
    value: String(size),
    label: String(size),
  }));
  return (
    <div className="flex flex-col gap-4">
      <div className="grid grid-cols-2 gap-3">
        <Group label="Box">
          <SegmentedControl
            label="Box"
            size="sm"
            value={style.box ?? "none"}
            options={boxOptions}
            onValueChange={(box) => set({ box })}
            fill
          />
        </Group>
        <Group label="Text size">
          <SegmentedControl
            label="Text size"
            size="sm"
            value={String(style.size ?? 12)}
            options={sizeOptions}
            onValueChange={(size) => set({ size: Number(size) })}
            fill
          />
        </Group>
      </div>
      {widget.style?.lines === 2 || widget.label?.includes("\n") ? (
        <Group label="Layout">
          <SegmentedControl
            label="Layout"
            size="sm"
            value={style.lines === 2 ? "stacked" : "side"}
            options={layoutOptions}
            onValueChange={(layout) => set({ lines: layout === "stacked" ? 2 : 1 })}
            fill
          />
        </Group>
      ) : null}
      <ColourChoiceRow
        title="Text colour"
        value={style.textColour}
        onValue={(textColour) => set({ textColour })}
      />
      {widget.icon ? (
        <ColourChoiceRow
          title="Icon colour"
          value={style.iconColour}
          onValue={(iconColour) => set({ iconColour })}
        />
      ) : null}
      {style.box && style.box !== "none" ? (
        <ControlRow
          title="Corner radius"
          control={
            <ValueSlider
              label="Corner radius"
              value={style.radius ?? 5}
              min={0}
              max={20}
              unit="pt"
              onValueChange={(radius) => set({ radius })}
            />
          }
        />
      ) : null}
      <ControlRow
        title="Padding left"
        control={
          <ValueSlider
            label="Padding left"
            value={style.paddingLeft ?? 8}
            min={0}
            max={40}
            unit="pt"
            onValueChange={(paddingLeft) => set({ paddingLeft })}
          />
        }
      />
      <ControlRow
        title="Padding right"
        control={
          <ValueSlider
            label="Padding right"
            value={style.paddingRight ?? 8}
            min={0}
            max={40}
            unit="pt"
            onValueChange={(paddingRight) => set({ paddingRight })}
          />
        }
      />
      {item.style ? (
        <Button
          size="sm"
          variant="ghost"
          className="self-start"
          onClick={() => onChange({ style: null })}
        >
          Use the widget's look
        </Button>
      ) : null}
    </div>
  );
}

/** When the widget updates. The widget decides; this says what it decided. */
export function UpdatesSection({ widget }: { widget: WidgetInfo }) {
  const events = widget.update?.events ?? [];
  return (
    <div className="flex flex-col gap-3">
      <ControlRow
        title={updateText(widget.update?.every)}
        hint={
          widget.source
            ? "Read by Macarchy"
            : widget.provider
              ? `Runs ${widget.provider}`
              : undefined
        }
        control={null}
      />
      {events.length > 0 ? (
        <Group label="Also when">
          <div className="flex flex-wrap gap-1.5">
            {events.map((event) => (
              <span
                key={event}
                className="flex h-6 items-center rounded-full border border-hairline px-2.5 text-small text-fg-secondary"
              >
                {eventName(event)}
              </span>
            ))}
          </div>
        </Group>
      ) : null}
      <p className="text-small text-fg-tertiary">
        Set in widget.json, for every copy of {widget.name}.
      </p>
    </div>
  );
}

/** The widget's folder and files, to read or open. Built-ins can be copied to edit. */
export function FilesSection({
  widget,
  onReveal,
  onOpen,
  onDuplicate,
  duplicated,
}: {
  widget: WidgetInfo;
  onReveal: () => void;
  onOpen: (file: string) => void;
  onDuplicate: () => void;
  /** Where the last copy went, to say so. */
  duplicated: string | null;
}) {
  const builtIn = widget.origin === "builtIn";
  return (
    <div className="flex flex-col gap-4">
      <Group label="Folder">
        <div className="overflow-hidden rounded-control border border-hairline">
          <div className="flex items-center gap-2 border-b border-hairline bg-side px-3 py-2">
            <Folder aria-hidden size={13} className="shrink-0 text-fg-tertiary" />
            <span className="min-w-0 flex-1 truncate font-mono text-small text-fg-secondary">
              {widget.folder}
            </span>
          </div>
          <ul>
            {widget.files.map((file) => (
              <li key={file} className="flex items-center gap-2 px-3 py-1.5">
                <FileText aria-hidden size={13} className="shrink-0 text-fg-tertiary" />
                <span className="flex-1 font-mono text-small text-fg">{file}</span>
                <Button size="sm" variant="ghost" onClick={() => onOpen(file)}>
                  <ExternalLink aria-hidden size={11} /> Open
                  <span className="sr-only"> {file}</span>
                </Button>
              </li>
            ))}
          </ul>
        </div>
      </Group>
      <Group label="widget.json">
        <CodeBlock
          code={widget.manifest}
          label="widget.json"
          copyLabel="Copy widget.json"
          maxHeight={220}
        />
      </Group>
      <div className="flex flex-wrap gap-2">
        <Button size="sm" onClick={onReveal}>
          Show in Finder
        </Button>
        {builtIn ? (
          <Button size="sm" onClick={onDuplicate}>
            Duplicate as my own
          </Button>
        ) : null}
      </div>
      {builtIn ? (
        <p className="text-small text-fg-tertiary">
          Built-ins update with Macarchy, so they cannot be edited in place. Duplicating copies the
          folder into your widgets.
        </p>
      ) : null}
      {duplicated ? (
        <p role="status" className="text-small text-fg-secondary">
          Copied to <span className="font-mono">{duplicated}</span>. This item now uses the copy;
          Apply to keep it.
        </p>
      ) : null}
    </div>
  );
}
