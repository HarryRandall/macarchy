import { Check } from "lucide-react";
import type { CSSProperties } from "react";
import { useClockPreview } from "./use-clock-preview";

import type { WidgetInfo, WidgetMenuRow, WidgetStyle } from "~/bridge/protocol";
import { cn } from "~/lib/cn";

import type { BarItem } from "./menu-bar-items";
import type { BarLook } from "./menu-bar-store";
import {
  fill,
  humanise,
  lookOf,
  type Sample,
  sampleLines,
  sampleText,
  settingOf,
} from "./widget-model";

/** A style colour as the bar draws it: the theme's text, accent or muted, or a hex. */
export function paintOf(colour: string | undefined, look: BarLook): string {
  if (!colour || colour === "text") return look.foreground;
  if (colour === "accent") return look.accent;
  if (colour === "muted") return `color-mix(in srgb, ${look.foreground} 60%, transparent)`;
  return colour;
}

function boxStyle(style: WidgetStyle, look: BarLook): CSSProperties {
  const radius = style.radius ?? 5;
  if (style.box === "outline") {
    return { border: "1px solid rgba(255,255,255,0.2)", borderRadius: radius };
  }
  if (style.box === "fill") {
    return {
      background: `color-mix(in srgb, ${look.foreground} 14%, transparent)`,
      borderRadius: radius,
    };
  }
  return { borderRadius: radius };
}

/**
 * One widget as the bar draws it: its glyph, then its label or its two
 * stacked lines, in its box. Sizes are the bar's, scaled to the preview.
 */
export function WidgetChip({
  item,
  widget,
  sample,
  look,
  className,
  height = 24,
  inset = 8,
}: {
  item: BarItem;
  widget: WidgetInfo | null;
  sample: Sample;
  look: BarLook;
  className?: string;
  height?: number;
  inset?: number;
}) {
  const preview = useClockPreview(item, widget, sample);
  const style = lookOf(item, widget);
  if (style.row) {
    return (
      <RowChip item={item} widget={widget} sample={sample} look={look} className={className} />
    );
  }
  const text = preview ?? sampleText(item, widget, sample);
  const lines = sampleLines(text, style);
  const size = Math.max(9, (style.size ?? 12) - 1);
  // The bar's own numbers (WidgetLook): a 24pt box, 8pt inside each edge
  // and 6pt between the icon and the text.
  return (
    <span
      className={cn("flex h-6 shrink-0 items-center gap-1.5 whitespace-nowrap", className)}
      style={{
        ...boxStyle(style, look),
        height,
        paddingLeft: style.paddingLeft ?? inset,
        paddingRight: style.paddingRight ?? inset,
        color: paintOf(style.textColour, look),
      }}
    >
      {widget?.icon && style.showIcon !== false ? (
        <span
          aria-hidden
          className="font-sans"
          style={{ color: paintOf(style.iconColour, look), fontSize: size + 2 }}
        >
          {widget.icon}
        </span>
      ) : null}
      {lines ? (
        <span className="flex flex-col items-end text-[8.5px] leading-[9px] font-semibold tabular-nums">
          <span>{lines[0]}</span>
          <span>{lines[1]}</span>
        </span>
      ) : (
        <span className="font-semibold tabular-nums" style={{ fontSize: size }}>
          {text.replace(/\n/g, " ")}
        </span>
      )}
    </span>
  );
}

/** One item of a row as the bar shows it. */
interface RowEntry {
  icon: string;
  label: string;
  current: boolean;
}

/**
 * The live row from the bar, one line per showing item: its icon, its label
 * and whether it is the current one, separated by tabs.
 */
function liveEntries(reading: string): RowEntry[] {
  return reading
    .split("\n")
    .filter((line) => line.includes("\t"))
    .map((line) => {
      const [icon = "", label = "", current = "0"] = line.split("\t");
      return { icon, label, current: current === "1" };
    });
}

/**
 * A made-up row from the widget's samples and settings, for the Widest and
 * Unavailable previews and before the bar has the widget: four Spaces, the
 * first one current with the sample's apps.
 */
function sampleEntries(
  widget: WidgetInfo | null,
  sample: Sample,
  value: (key: string) => unknown,
): RowEntry[] {
  const text =
    (sample === "unavailable" ? widget?.samples?.unavailable : widget?.samples?.widest) ?? "1 —";
  const glyphs = text
    .split(" ")
    .slice(1)
    .filter((part) => part.startsWith(":"));
  const show = String(value("show") ?? "numbers-and-icons");
  const most = Number(value("maxIcons") ?? 0);
  const names = String(value("names") ?? "")
    .split(",")
    .map((name) => name.trim());
  const hideEmpty = value("hideEmpty") === true;
  const entries: RowEntry[] = [];
  [glyphs, glyphs.slice(0, 1), [], []].forEach((list, index) => {
    if (hideEmpty && list.length === 0 && index > 0) return;
    const shown = most > 0 ? list.slice(0, most) : list;
    // A space before a dash and two before apps, as the bar writes them.
    const strip = list.length === 0 ? " —" : `  ${shown.join(" ")}`;
    const more = list.length > shown.length ? ` +${list.length - shown.length}` : "";
    entries.push({
      icon: show === "icons" ? "" : names[index] || String(index + 1),
      label: show === "numbers" ? "" : strip + more,
      current: index === 0,
    });
  });
  return entries;
}

/**
 * A row widget as the bar draws it, as Spaces: each item's number, then the
 * apps' glyphs, with boxes and colours from its settings.
 */
function RowChip({
  item,
  widget,
  sample,
  look,
  className,
}: {
  item: BarItem;
  widget: WidgetInfo | null;
  sample: Sample;
  look: BarLook;
  className?: string;
}) {
  const value = (key: string) => {
    const setting = widget?.settings.find((candidate) => candidate.key === key);
    return setting ? settingOf(item, setting) : undefined;
  };
  const live = sample === "live" ? liveEntries(item.reading) : [];
  const entries = live.length > 0 ? live : sampleEntries(widget, sample, value);
  const design = String(value("design") ?? "current");
  const active = paintOf(String(value("activeColour") ?? "accent"), look);
  const other = paintOf(String(value("colour") ?? "text"), look);
  const outline = "1px solid rgba(255,255,255,0.2)";
  const radius = lookOf(item, widget).radius ?? 5;
  return (
    <span
      className={cn("flex h-6 shrink-0 items-center whitespace-nowrap", className)}
      style={{ border: design === "together" ? outline : undefined, borderRadius: radius }}
    >
      {entries.map((entry, index) => {
        const boxed =
          entry.current && design !== "none"
            ? {
                background: `color-mix(in srgb, ${active} 10%, transparent)`,
                border: design === "together" ? undefined : `1px solid ${active}`,
              }
            : design === "every"
              ? { border: outline }
              : {};
        return (
          <span
            key={index}
            className="mr-[5px] ml-[2px] flex h-6 items-center gap-1 pr-2.5 pl-2.5"
            style={{
              ...boxed,
              paddingLeft: lookOf(item, widget).paddingLeft ?? 10,
              paddingRight: lookOf(item, widget).paddingRight ?? 20,
              borderRadius: radius,
              color: entry.current ? active : other,
            }}
          >
            {entry.icon ? <span className="text-[12px] font-semibold">{entry.icon}</span> : null}
            {entry.label ? (
              <span
                aria-hidden
                className="text-[13px] whitespace-pre"
                style={{ fontFamily: "sketchybar-app-font" }}
              >
                {entry.label}
              </span>
            ) : null}
          </span>
        );
      })}
    </span>
  );
}

/**
 * A widget's dropdown drawn as the native panel draws it, so rows can be
 * seen while they are edited. Readings the preview knows are filled in.
 */
export function MenuPreview({
  rows,
  settings,
  selected,
  onSelect,
}: {
  rows: WidgetMenuRow[];
  /** The widget's settings as the item has them, for toggles and choices. */
  settings: Record<string, unknown>;
  selected?: number | null;
  onSelect?: (index: number) => void;
}) {
  return (
    <div
      role="group"
      aria-label="Dropdown preview"
      className="w-[280px] rounded-[14px] border border-white/12 bg-[rgb(40_40_42/0.94)] px-1.5 py-2 text-[12.5px] text-white/90 shadow-[0_12px_40px_rgb(0_0_0/0.45)] backdrop-blur"
    >
      {rows.length === 0 ? (
        <p className="px-2.5 py-1 text-white/50">No rows yet</p>
      ) : (
        rows.map((row, index) => (
          <PreviewRow
            // oxlint-disable-next-line react/no-array-index-key -- rows have no id; their place is what the editor selects.
            key={index}
            row={row}
            settings={settings}
            selected={selected === index}
            onSelect={onSelect ? () => onSelect(index) : undefined}
          />
        ))
      )}
    </div>
  );
}

function PreviewRow({
  row,
  settings,
  selected,
  onSelect,
}: {
  row: WidgetMenuRow;
  settings: Record<string, unknown>;
  selected: boolean;
  onSelect?: () => void;
}) {
  const ring = selected ? "ring-1 ring-accent" : undefined;
  const content = (() => {
    switch (row.type) {
      case "divider":
        return <div className="mx-2.5 my-1.5 h-px bg-white/12" />;
      case "heading":
        return (
          <div className="flex items-baseline gap-3 px-2.5 pt-0.5 pb-1">
            <span className="flex-1 truncate font-bold">{fill(row.label)}</span>
            <span className="text-white/55">{fill(row.value)}</span>
          </div>
        );
      case "text":
        return <div className="truncate px-2.5 py-px text-white/55">{fill(row.label)}</div>;
      case "toggle":
        return (
          <div className="flex h-6 items-center gap-2.5 px-2.5">
            <Check
              aria-hidden
              size={11}
              strokeWidth={2.5}
              className={settings[row.setting ?? ""] === true ? undefined : "opacity-0"}
            />
            <span className="truncate">{fill(row.label)}</span>
          </div>
        );
      case "choice":
        return (
          <div className="px-2.5 py-0.5">
            <div className="pb-1 font-semibold text-white/55">{fill(row.label)}</div>
            {(row.options ?? []).map((option) => (
              <div key={option} className="flex h-6 items-center gap-2">
                <span
                  aria-hidden
                  className={cn(
                    "size-3 rounded-full border",
                    settings[row.setting ?? ""] === option
                      ? "border-[4px] border-[#0a84ff]"
                      : "border-white/40",
                  )}
                />
                {humanise(option)}
              </div>
            ))}
          </div>
        );
      case "graph":
      case "mirror":
      case "map":
      case "status":
      case "cores":
      case "apps":
        return (
          <div className="px-2.5 py-1">
            <div className="text-[11px] text-white/55">{fill(row.label)}</div>
            <div className="mt-1 flex h-9 items-end gap-[3px]">
              {[30, 45, 25, 60, 40, 70, 35, 55, 48, 62].map((height, index) => (
                <span
                  // oxlint-disable-next-line react/no-array-index-key -- a fixed sketch of bars.
                  key={index}
                  className="flex-1 rounded-[2px] bg-[#0a84ff]/70"
                  style={{ height: `${height}%` }}
                />
              ))}
            </div>
          </div>
        );
      case "action":
        return (
          <div className="flex h-6 items-center gap-2.5 rounded-[6px] px-2.5 group-hover/row:bg-[#0a84ff]">
            <span className="flex-1 truncate">{fill(row.label)}</span>
          </div>
        );
      default:
        return (
          <div className="flex h-6 items-center gap-3 px-2.5">
            <span className="flex-1 truncate">{fill(row.label)}</span>
            <span className="text-white/55 tabular-nums">{fill(row.value)}</span>
          </div>
        );
    }
  })();
  if (!onSelect) return <div className={cn("rounded-[6px]", ring)}>{content}</div>;
  return (
    <button
      type="button"
      aria-label={`Edit row: ${row.type === "divider" ? "divider" : fill(row.label) || row.type}`}
      aria-pressed={selected}
      onClick={onSelect}
      className={cn(
        "group/row block w-full rounded-[6px] text-left outline-none focus-visible:ring-1 focus-visible:ring-accent",
        ring,
      )}
    >
      {content}
    </button>
  );
}
