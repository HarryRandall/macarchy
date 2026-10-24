import { ExternalLink, FileText, Folder, SlidersHorizontal } from "lucide-react";
import { type ReactNode, useId } from "react";

import type { WidgetInfo, WidgetSettingInfo, WidgetStyle } from "~/bridge/protocol";
import { Button } from "~/components/ui/button";
import { CodeBlock } from "~/components/ui/code-block";
import { ColourField } from "~/components/ui/colour-field";
import { EmptyState } from "~/components/ui/empty-state";
import { focusRing } from "~/components/ui/focus-ring";
import { HelpTooltip } from "~/components/ui/help-tooltip";
import { SegmentedControl } from "~/components/ui/segmented-control";
import { Select } from "~/components/ui/select";
import { Switch } from "~/components/ui/switch";
import { Input } from "~/components/ui/text-field";
import { Tooltip } from "~/components/ui/tooltip";
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

/**
 * One setting as the app's other pages draw it: the name on the left, the
 * control on the right, dropping below when the column is too narrow. A
 * hint is help on hover, not a line of text. `stacked` puts a wide control,
 * such as a list or a field, under the name.
 */
export function Group({
  label,
  labelId,
  help,
  stacked,
  children,
}: {
  label: string;
  labelId?: string;
  help?: string;
  stacked?: boolean;
  children: ReactNode;
}) {
  return (
    <div
      className={cn(
        "flex gap-x-3 gap-y-2",
        stacked ? "flex-col" : "min-h-8 flex-wrap items-center justify-between",
      )}
    >
      <span className="flex items-center gap-1">
        <span id={labelId} className="text-detail whitespace-nowrap text-fg">
          {label}
        </span>
        {help ? <HelpTooltip text={help} /> : null}
      </span>
      {children}
    </div>
  );
}

/** A row whose control is a single element. */
export function ControlRow({
  title,
  help,
  control,
}: {
  title: string;
  help?: string;
  control: ReactNode;
}) {
  return (
    <Group label={title} help={help}>
      {control}
    </Group>
  );
}

/** That a section's values are this copy's own, with the way back to the widget's. */
export function CustomNote({ onReset }: { onReset: () => void }) {
  return (
    <div className="flex items-center gap-2 rounded-control bg-accent-soft px-3 py-1.5 text-small text-accent-text">
      <span className="flex-1">Custom for this copy</span>
      <Button size="sm" variant="ghost" onClick={onReset}>
        Reset
      </Button>
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
 * get a row each.
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
    <div className="flex flex-col gap-3">
      {parts.length > 0 ? (
        <Group label="Show" labelId={showId} stacked>
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
  const help = setting.hint;
  switch (setting.type) {
    case "toggle":
      return (
        <ControlRow
          title={setting.label}
          help={help}
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
        <ControlRow
          title={setting.label}
          help={help}
          control={
            options.length <= 3 ? (
              <SegmentedControl
                label={setting.label}
                size="sm"
                value={current}
                options={options}
                onValueChange={onValue}
              />
            ) : (
              <Select
                label={setting.label}
                size="sm"
                value={current}
                options={options}
                onValueChange={onValue}
              />
            )
          }
        />
      );
    }
    case "number":
      return (
        <ControlRow
          title={setting.label}
          help={help}
          control={
            <ValueSlider
              id={id}
              label={setting.label}
              value={typeof value === "number" ? value : (setting.min ?? 0)}
              min={setting.min ?? 0}
              max={setting.max ?? 100}
              step={setting.step}
              unit={setting.unit}
              width={120}
              onValueChange={onValue}
            />
          }
        />
      );
    case "colour":
      return (
        <ControlRow
          title={setting.label}
          help={help}
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
        <ControlRow
          title={setting.label}
          help={help}
          control={
            <Input
              aria-label={setting.label}
              variant={setting.type === "format" ? "mono" : undefined}
              size="sm"
              className="w-44"
              placeholder={setting.type === "format" ? "Automatic" : "Default"}
              value={typeof value === "string" ? value : String(value ?? "")}
              onChange={(event) => onValue(event.currentTarget.value)}
            />
          }
        />
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
    <>
      <ControlRow
        title={title}
        control={
          <SegmentedControl
            label={title}
            size="sm"
            value={choice}
            options={colourChoices}
            onValueChange={(next) => onValue(next === "custom" ? "#a5b4fc" : next)}
          />
        }
      />
      {choice === "custom" && value ? (
        <ColourField label={`${title}, custom`} value={value} onValueChange={onValue} />
      ) : null}
    </>
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
    <div className="flex flex-col gap-3">
      {item.style ? <CustomNote onReset={() => onChange({ style: null })} /> : null}
      <ControlRow
        title="Box"
        control={
          <SegmentedControl
            label="Box"
            size="sm"
            value={style.box ?? "none"}
            options={boxOptions}
            onValueChange={(box) => set({ box })}
          />
        }
      />
      <ControlRow
        title="Text size"
        control={
          <SegmentedControl
            label="Text size"
            size="sm"
            value={String(style.size ?? 12)}
            options={sizeOptions}
            onValueChange={(size) => set({ size: Number(size) })}
          />
        }
      />
      {widget.style?.lines === 2 || widget.label?.includes("\n") ? (
        <ControlRow
          title="Layout"
          control={
            <SegmentedControl
              label="Layout"
              size="sm"
              value={style.lines === 2 ? "stacked" : "side"}
              options={layoutOptions}
              onValueChange={(layout) => set({ lines: layout === "stacked" ? 2 : 1 })}
            />
          }
        />
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
              width={120}
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
            width={120}
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
            width={120}
            onValueChange={(paddingRight) => set({ paddingRight })}
          />
        }
      />
    </div>
  );
}

/**
 * When the widget updates, its folder and its files. The widget decides when
 * it updates, for every copy, so that part is read only.
 */
export function AboutSection({
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
  const events = widget.update?.events ?? [];
  const builtIn = widget.origin === "builtIn";
  return (
    <div className="flex flex-col gap-3">
      <ControlRow
        title="Updates"
        help={`Set in widget.json, for every copy of ${widget.name}`}
        control={
          <span className="text-detail text-fg-secondary">{updateText(widget.update?.every)}</span>
        }
      />
      {events.length > 0 ? (
        <Group label="Also when" stacked>
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
      <Group label="Files" stacked>
        <div className="overflow-hidden rounded-control border border-hairline">
          <div className="flex items-center gap-2 border-b border-hairline bg-side px-3 py-2">
            <Folder aria-hidden size={13} className="shrink-0 text-fg-secondary" />
            <span className="min-w-0 flex-1 truncate font-mono text-small text-fg-secondary">
              {widget.folder}
            </span>
          </div>
          <ul>
            {widget.files.map((file) => (
              <li key={file} className="flex items-center gap-2 px-3 py-1.5">
                <FileText aria-hidden size={13} className="shrink-0 text-fg-secondary" />
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
      <CodeBlock
        code={widget.manifest}
        label="widget.json"
        copyLabel="Copy widget.json"
        maxHeight={200}
      />
      <div className="flex flex-wrap gap-2">
        <Button size="sm" onClick={onReveal}>
          Show in Finder
        </Button>
        {builtIn ? (
          <Tooltip content="Built-ins update with Macarchy, so a copy in your widgets is the one to change">
            <Button size="sm" onClick={onDuplicate}>
              Duplicate as my own
            </Button>
          </Tooltip>
        ) : null}
      </div>
      {duplicated ? (
        <p role="status" className="text-small text-fg-secondary">
          Copied to <span className="font-mono">{duplicated}</span>. This item now uses the copy;
          Apply to keep it.
        </p>
      ) : null}
    </div>
  );
}
