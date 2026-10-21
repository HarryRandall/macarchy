import type { BorderAppearance } from "~/bridge/contract/borders";
import { ImageFill } from "~/components/ui/image-fill";
import { cn } from "~/lib/cn";
import { borderPaint, previewRadius } from "./borders-format";

/** The desktop the preview windows sit on: the active theme's colours, or a neutral dark one. */
export interface PreviewScene {
  background: string;
  foreground: string;
  accent: string;
  /** Terminal colours 0 to 7. */
  palette: readonly string[];
}

export const neutralScene: PreviewScene = {
  background: "#16181d",
  foreground: "#d4d4d8",
  accent: "#45e8ff",
  palette: ["#16181d", "#f87171", "#4ade80", "#facc15", "#60a5fa", "#c084fc", "#22d3ee", "#d4d4d8"],
};

const traffic = ["#ff5f57", "#febc2e", "#28c840"];
const coreDefaultActive = "rgb(69 232 255 / 1)";

type WindowKind = "terminal" | "browser";

/** A window in the border preview, framed as borders would draw it. */
function PreviewWindow({
  kind,
  focused,
  colour,
  width,
  radius,
  scene,
  onFocus,
}: {
  kind: WindowKind;
  focused: boolean;
  colour: string;
  width: number;
  radius: number;
  scene: PreviewScene;
  onFocus: () => void;
}) {
  const p = scene.palette;
  const line = `1px solid color-mix(in srgb, ${scene.foreground} 9%, transparent)`;
  const name = kind === "terminal" ? "Ghostty" : "Safari";
  return (
    <button
      type="button"
      aria-pressed={focused}
      aria-label={`Focus the ${name} window`}
      onClick={onFocus}
      className={cn(
        "flex min-w-0 flex-col overflow-hidden text-left outline-none transition-[box-shadow,border-radius] duration-150 focus-visible:brightness-110 motion-reduce:transition-none",
        "focus-visible:outline-2 focus-visible:outline-offset-4 focus-visible:outline-white/80",
        kind === "terminal" ? "flex-[1.15]" : "flex-1",
      )}
      style={{
        background: scene.background,
        borderRadius: radius,
        boxShadow: `0 0 0 ${width}px ${colour}, 0 16px 36px -14px rgba(0,0,0,0.65)`,
      }}
    >
      <span
        aria-hidden
        className="flex h-[22px] shrink-0 items-center gap-[5px] px-2.5"
        style={{ borderBottom: line }}
      >
        {traffic.map((dot) => (
          <span
            key={dot}
            className="size-[7px] rounded-full"
            style={{
              background: focused
                ? dot
                : `color-mix(in srgb, ${scene.foreground} 22%, transparent)`,
            }}
          />
        ))}
        <span
          className="mx-auto max-w-[60%] truncate rounded-[4px] px-2 text-[9.5px] leading-[14px]"
          style={{
            color: scene.foreground,
            opacity: focused ? 0.7 : 0.4,
            background:
              kind === "browser"
                ? `color-mix(in srgb, ${scene.foreground} 7%, transparent)`
                : undefined,
          }}
        >
          {kind === "browser" ? "github.com/FelixKratz/JankyBorders" : "~/projects/macarchy"}
        </span>
        <span
          className="flex items-center gap-1 text-[9.5px]"
          style={{ color: scene.foreground, opacity: focused ? 0.6 : 0.35 }}
        >
          <span className="size-[5px] rounded-full" style={{ background: colour }} />
          {focused ? "Focused" : "Unfocused"}
        </span>
      </span>

      <span
        aria-hidden
        className="block min-h-0 flex-1 overflow-hidden"
        style={{ opacity: focused ? 1 : 0.55 }}
      >
        {kind === "terminal" ? (
          <span
            className="block px-3 py-2 font-mono text-[10.5px] leading-[1.6]"
            style={{ color: scene.foreground }}
          >
            <span className="block truncate">
              <span style={{ color: p[4] }}>macarchy</span>{" "}
              <span style={{ color: p[2] }}>main</span> <span style={{ color: p[6] }}>$</span>{" "}
              borders apply
            </span>
            <span className="block" style={{ opacity: 0.6 }}>
              Reloading borders
            </span>
            <span className="block">
              <span style={{ color: p[2] }}>ok</span> 2 windows framed
            </span>
            <span className="block">
              <span style={{ color: p[4] }}>macarchy</span>{" "}
              <span style={{ color: p[2] }}>main</span> <span style={{ color: p[6] }}>$</span>{" "}
              <span
                className="inline-block h-[11px] w-[6px] translate-y-[2px]"
                style={{
                  background: focused ? scene.accent : scene.foreground,
                  opacity: focused ? 1 : 0.4,
                }}
              />
            </span>
          </span>
        ) : (
          <span className="block space-y-2 px-3 py-2.5">
            <span className="flex items-center gap-2">
              <span className="size-4 rounded-full" style={{ background: p[4], opacity: 0.8 }} />
              <span
                className="h-[6px] w-[42%] rounded-full"
                style={{ background: scene.foreground, opacity: 0.55 }}
              />
            </span>
            {[88, 74, 81].map((percent) => (
              <span
                key={percent}
                className="block h-[4px] rounded-full"
                style={{ width: `${percent}%`, background: scene.foreground, opacity: 0.18 }}
              />
            ))}
            <span className="flex gap-2 pt-0.5">
              {[p[6], p[3]].map((swatch, index) => (
                <span
                  key={index}
                  className="h-7 flex-1 rounded-[3px]"
                  style={{ background: `color-mix(in srgb, ${swatch} 22%, ${scene.background})` }}
                />
              ))}
            </span>
          </span>
        )}
      </span>
    </button>
  );
}

/**
 * Two windows on the theme's wallpaper, the focused one in the active colour
 * and the other in the inactive one, at the chosen width and corners.
 * Clicking a window moves focus to it, as on the desktop.
 */
export function BorderPreview({
  appearance,
  wallpaper,
  scene,
  focused,
  onFocus,
  caption,
}: {
  appearance: BorderAppearance;
  wallpaper: string | null;
  scene: PreviewScene;
  focused: 0 | 1;
  onFocus: (index: 0 | 1) => void;
  /** Says which version is shown when comparing with what is applied. */
  caption?: string;
}) {
  const width = appearance.visible ? appearance.width : 0;
  const radius = previewRadius(appearance.radius);
  const active = borderPaint(appearance.activeColour, coreDefaultActive);
  const inactive = borderPaint(appearance.inactiveColour, "transparent");
  return (
    <div
      role="group"
      aria-label={`Border preview${caption ? `, ${caption.toLowerCase()}` : ""}: ${
        appearance.visible ? `${appearance.width} pt` : "borders off"
      }, ${radius === 0 ? "square" : "rounded"} corners`}
      className="relative h-[196px] overflow-hidden"
    >
      <ImageFill src={wallpaper ?? undefined} from={scene.background} to={scene.accent} />
      <div className="absolute inset-0 bg-black/35" />
      <div
        aria-hidden
        className="absolute inset-x-0 top-0 flex h-5 items-center gap-1 px-2.5 font-mono text-[9.5px] font-medium"
        style={{
          background: `color-mix(in srgb, ${scene.background} 88%, transparent)`,
          color: scene.foreground,
        }}
      >
        {[1, 2, 3].map((n) => (
          <span
            key={n}
            className="grid h-3 min-w-3.5 place-items-center rounded-[3px] px-1"
            style={n === 1 ? { background: active, color: scene.background } : { opacity: 0.5 }}
          >
            {n}
          </span>
        ))}
        {caption ? <span className="ml-auto opacity-70">{caption}</span> : null}
      </div>
      <div className="absolute inset-x-6 top-[38px] bottom-5 flex gap-4">
        {(["terminal", "browser"] as const).map((kind, index) => (
          <PreviewWindow
            key={kind}
            kind={kind}
            focused={focused === index}
            colour={focused === index ? active : inactive}
            width={width}
            radius={radius}
            scene={scene}
            onFocus={() => onFocus(index as 0 | 1)}
          />
        ))}
      </div>
      {!appearance.visible ? (
        <div className="pointer-events-none absolute inset-0 grid place-items-center bg-black/30 backdrop-blur-[1px]">
          <span className="rounded-control bg-black/60 px-3 py-1.5 text-small font-medium text-white/85">
            Borders are off
          </span>
        </div>
      ) : null}
    </div>
  );
}
