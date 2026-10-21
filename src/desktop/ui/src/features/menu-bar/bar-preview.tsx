import { focusRing } from "~/components/ui/focus-ring";
import { cn } from "~/lib/cn";

import { ItemIcon } from "./menu-bar-icon";
import type { BarItem, BarSettings, Zone } from "./menu-bar-mock";
import type { BarLook } from "./menu-bar-store";

const spaces = ["1", "2", "3", "4", "5"];

/**
 * The bar over the theme's wallpaper, drawn from the page's draft. Each item
 * opens its editor, so the preview doubles as a way in.
 */
export function BarPreview({
  items,
  bar,
  look,
  active,
  onSelect,
}: {
  items: BarItem[];
  bar: BarSettings;
  look: BarLook;
  active: string | null;
  onSelect: (id: string) => void;
}) {
  const zone = (name: Zone) =>
    items
      .filter((item) => item.zone === name && item.on)
      .map((item) => (
        <button
          type="button"
          key={item.id}
          aria-label={`Edit ${item.label}`}
          aria-pressed={item.id === active}
          onClick={() => onSelect(item.id)}
          className={cn(
            "flex h-[22px] shrink-0 items-center gap-1 rounded-[5px] px-1.5 whitespace-nowrap transition-colors hover:bg-white/10",
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
          ) : (
            <>
              <ItemIcon icon={item.icon} size={11} style={{ color: look.accent }} />
              {item.id === "theme_switcher" ? look.themeTitle : item.sample}
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
        {bar.centre ? (
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
      <div className="h-[72px]" />
      {bar.position === "bottom" ? strip : null}
    </div>
  );
}
