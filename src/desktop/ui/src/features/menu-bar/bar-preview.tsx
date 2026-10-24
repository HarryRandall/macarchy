import type { ReactNode } from "react";

import { focusRing } from "~/components/ui/focus-ring";
import { cn } from "~/lib/cn";

import type { MenuBarSettings, WidgetInfo } from "~/bridge/protocol";

import { ItemIcon } from "./menu-bar-icon";
import { type BarItem, shownText, type Zone } from "./menu-bar-items";
import type { BarLook } from "./menu-bar-store";
import { type Sample, widgetOf } from "./widget-model";
import { WidgetChip } from "./widget-preview";

const spaces = ["1", "2", "3", "4", "5"];

/**
 * The bar over the theme's wallpaper, drawn from the page's draft. Each item
 * opens its editor, so the preview doubles as a way in. Widgets show the
 * sample chosen; with `focus`, every other item is dimmed.
 */
export function BarPreview({
  items,
  bar,
  look,
  widgets,
  sample,
  active,
  focus,
  onSelect,
  below,
}: {
  items: BarItem[];
  bar: MenuBarSettings;
  look: BarLook;
  widgets: readonly WidgetInfo[];
  sample: Sample;
  active: string | null;
  focus?: string;
  onSelect: (id: string) => void;
  /** Drawn under the bar, over the wallpaper, such as a dropdown. */
  below?: ReactNode;
}) {
  const shown = (name: Zone) => items.filter((item) => item.zone === name && item.visible);
  const zone = (name: Zone) =>
    shown(name).map((item) => (
      <button
        type="button"
        key={item.id}
        aria-label={`Edit ${item.title}`}
        aria-pressed={item.id === active}
        onClick={() => onSelect(item.id)}
        className={cn(
          "flex h-[22px] shrink-0 items-center gap-1 rounded-[5px] whitespace-nowrap transition-[background-color,opacity] hover:bg-white/10",
          item.kind === "widget" ? "px-0.5" : "px-1.5",
          focus && focus !== item.id && "opacity-35",
          focusRing,
        )}
        style={{
          color: look.foreground,
          background: item.id === active ? "rgba(255,255,255,0.12)" : undefined,
          boxShadow: item.id === active ? `0 0 0 1px ${look.accent}` : undefined,
        }}
      >
        {item.id === "workspaces" ? (
          spaces.map((space) => (
            <span
              key={space}
              className="grid size-4 place-items-center rounded-[3px] text-[10px] font-semibold"
              style={
                space === "1"
                  ? { background: look.accent, color: look.background }
                  : { opacity: 0.6 }
              }
            >
              {space}
            </span>
          ))
        ) : item.kind === "spacer" ? (
          <span aria-hidden className="block w-5" />
        ) : item.kind === "widget" ? (
          <WidgetChip item={item} widget={widgetOf(item, widgets)} sample={sample} look={look} />
        ) : (
          <>
            {item.kind === null ? (
              <ItemIcon item={item} size={11} style={{ color: look.accent }} />
            ) : item.icon ? (
              <span style={{ color: look.accent }}>{item.icon}</span>
            ) : null}
            {shownText(item)}
          </>
        )}
      </button>
    ));

  const strip = (
    <div
      className="grid grid-cols-[1fr_auto_1fr] font-mono text-[11px] transition-[height,padding] motion-reduce:transition-none"
      style={{
        height: bar.height,
        paddingInline: bar.padding,
        background: `color-mix(in srgb, ${look.background} 92%, transparent)`,
        borderBottom: bar.position === "top" ? "1px solid rgba(255,255,255,0.06)" : undefined,
        borderTop: bar.position === "bottom" ? "1px solid rgba(255,255,255,0.06)" : undefined,
      }}
    >
      <div className="flex min-w-0 items-center gap-1 overflow-hidden">{zone("left")}</div>
      <div className="flex items-center justify-center gap-1 px-2">
        {shown("centre").length > 0 ? (
          zone("centre")
        ) : bar.position === "top" ? (
          <span aria-hidden className="block h-full w-[132px] rounded-b-[9px] bg-black" />
        ) : null}
      </div>
      <div className="flex min-w-0 items-center justify-end gap-1 overflow-hidden">
        {zone("right")}
      </div>
    </div>
  );

  return (
    <div
      role="group"
      aria-label="Menu bar preview"
      className="flex flex-col overflow-hidden rounded-card border border-hairline bg-cover bg-center"
      style={{
        backgroundColor: look.background,
        backgroundImage: look.wallpaper
          ? `url("${look.wallpaper}")`
          : `linear-gradient(160deg, color-mix(in srgb, ${look.accent} 25%, ${look.background}), ${look.background} 70%)`,
      }}
    >
      {bar.position === "top" ? strip : null}
      <div className={cn("flex justify-end px-3", below ? "min-h-[72px] py-2" : "h-[72px]")}>
        {below}
      </div>
      {bar.position === "bottom" ? strip : null}
    </div>
  );
}
