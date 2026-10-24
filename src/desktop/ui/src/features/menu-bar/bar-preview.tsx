import { type ReactNode, useLayoutEffect, useRef, useState } from "react";

import { focusRing } from "~/components/ui/focus-ring";
import { observeResize } from "~/lib/observe-resize";
import { useElementSize } from "~/lib/use-element-size";
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
  // A bar wider than the page is drawn smaller, whole, rather than cut or scrolled.
  const holder = useRef<HTMLDivElement>(null);
  const parts = useRef<(HTMLDivElement | null)[]>([]);
  const { width } = useElementSize(holder);
  const [natural, setNatural] = useState(0);
  useLayoutEffect(() => {
    // The three zones size to their items, so watching them catches every change.
    const measure = () => {
      const content = parts.current.reduce((sum, part) => sum + (part?.scrollWidth ?? 0), 0);
      setNatural(Math.ceil(content + bar.padding * 2 + 16));
    };
    measure();
    const stops = parts.current.flatMap((part) => (part ? [observeResize(part, measure)] : []));
    return () => {
      for (const stop of stops) stop();
    };
  }, [bar.padding]);
  const scale = natural > 0 && width > 0 ? Math.min(1, width / natural) : 1;

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
          item.kind === "widget" ? "px-0.5" : "border border-white/20 px-1.5",
          focus && focus !== item.id && "opacity-35",
          // Samples are a widget's; the bar's own items show what they show now.
          !focus && sample !== "live" && item.kind !== "widget" && "opacity-40",
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
        width: scale < 1 ? natural : "100%",
        transform: scale < 1 ? `scale(${scale})` : undefined,
        transformOrigin: "left top",
        height: bar.height,
        paddingInline: bar.padding,
        background: `color-mix(in srgb, ${look.background} 92%, transparent)`,
        borderBottom: bar.position === "top" ? "1px solid rgba(255,255,255,0.06)" : undefined,
        borderTop: bar.position === "bottom" ? "1px solid rgba(255,255,255,0.06)" : undefined,
      }}
    >
      <div
        ref={(element) => {
          parts.current[0] = element;
        }}
        className="flex w-max items-center gap-1.5 justify-self-start"
      >
        {zone("left")}
      </div>
      <div
        ref={(element) => {
          parts.current[1] = element;
        }}
        className="flex w-max items-center justify-center gap-1.5 px-2"
      >
        {shown("centre").length > 0 ? (
          zone("centre")
        ) : bar.position === "top" ? (
          <span aria-hidden className="block h-full w-[132px] rounded-b-[9px] bg-black" />
        ) : null}
      </div>
      <div
        ref={(element) => {
          parts.current[2] = element;
        }}
        className="flex w-max items-center gap-1.5 justify-self-end"
      >
        {zone("right")}
      </div>
    </div>
  );

  const held = (
    <div ref={holder} className="overflow-hidden" style={{ height: bar.height * scale }}>
      {strip}
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
      {bar.position === "top" ? held : null}
      <div className={cn("flex justify-end px-3", below ? "min-h-[72px] py-2" : "h-[72px]")}>
        {below}
      </div>
      {bar.position === "bottom" ? held : null}
    </div>
  );
}
