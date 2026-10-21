import { Image as ImageIcon } from "lucide-react";
import type { CSSProperties } from "react";
import type { Background } from "~/bridge/protocol";
import { ImageFill } from "~/components/ui/image-fill";
import { cn } from "~/lib/cn";
import { type ThemeLook, wallpaperImage, wallpaperName } from "./theme-look";

/** A theme's wallpaper as a cover image, or a gradient from its colours when it has none. */
export function ThemeWallpaper({
  look,
  wallpaper = look.wallpaper,
  preview = null,
  className,
}: {
  look: ThemeLook;
  wallpaper?: Background | null;
  /** The host's large image for the wallpaper in force. */
  preview?: string | null;
  className?: string;
}) {
  return (
    <ImageFill
      src={wallpaperImage(look, wallpaper, preview) ?? undefined}
      from={look.background}
      to={look.accent}
      alt={wallpaper ? `${look.title}, ${wallpaperName(look, wallpaper)}` : ""}
      className={className}
    />
  );
}

/** The terminal palette as overlapping dots, then the accent on its own. */
export function PaletteDots({ look }: { look: ThemeLook }) {
  return (
    <span className="flex shrink-0 items-center gap-2" aria-hidden>
      <span className="flex items-center -space-x-[3px]">
        {look.palette.slice(1).map((colour, index) => (
          <span
            // A palette can repeat a colour, so position is part of the key.
            key={`${index}-${colour}`}
            className="size-[11px] rounded-full ring-[1.5px] ring-page"
            style={{ background: colour }}
          />
        ))}
      </span>
      <span className="h-3 w-px bg-line-strong" />
      <span
        className="size-[11px] rounded-full ring-1 ring-black/15"
        style={{ background: look.accent }}
      />
    </span>
  );
}

/** Faux Neovim lines: indent, then two runs of palette index and width. */
const nvimCode: [number, number, number, number, number][] = [
  [0, 5, 18, 4, 34],
  [1, 3, 12, 7, 46],
  [1, 6, 26, 2, 22],
  [2, 1, 16, 7, 38],
  [2, 4, 22, 3, 18],
  [1, 5, 14, 6, 30],
  [0, 3, 20, 7, 28],
  [0, 4, 12, 2, 40],
  [1, 6, 24, 7, 20],
];

const previewGap = 8;
const previewRing = 3;

/**
 * The theme on screen: its wallpaper at full width with a menu bar in theme
 * colours and two tiled windows, the focused terminal framed in the accent and
 * painted with the Ghostty palette. Decorative; the details below it carry
 * the same facts as text.
 */
export function ThemeHero({ look, preview }: { look: ThemeLook; preview: string | null }) {
  const p = look.palette;
  const glass = `color-mix(in srgb, ${look.background} 90%, transparent)`;
  const hairline = `1px solid color-mix(in srgb, ${look.foreground} 9%, transparent)`;
  const frame = (focused: boolean): CSSProperties => ({
    background: glass,
    boxShadow: focused
      ? `0 0 0 ${previewRing}px ${look.accent}, 0 24px 48px -20px rgba(0,0,0,0.75)`
      : `0 0 0 1px color-mix(in srgb, ${look.foreground} 14%, transparent), 0 20px 40px -20px rgba(0,0,0,0.65)`,
  });
  const titleBar = (label: string, focused: boolean) => (
    <div
      className="flex h-[24px] shrink-0 items-center gap-[5px] px-2.5 text-[10.5px] font-medium"
      style={{ color: look.foreground, borderBottom: hairline }}
    >
      {[p[1], p[3], p[2]].map((colour, index) => (
        <span
          key={index}
          className="size-[7px] rounded-full"
          style={{
            background: focused
              ? colour
              : `color-mix(in srgb, ${look.foreground} 25%, transparent)`,
          }}
        />
      ))}
      <span className="ml-1.5 truncate" style={{ opacity: focused ? 0.85 : 0.5 }}>
        {label}
      </span>
    </div>
  );
  const prompt = (
    <>
      <span style={{ color: p[2] }}>you</span>
      <span style={{ opacity: 0.5 }}>@</span>
      <span style={{ color: p[4] }}>mac</span> <span style={{ color: p[5] }}>~</span>{" "}
      <span style={{ color: p[3] }}>$</span>
    </>
  );
  const ok = <span style={{ color: p[2] }}>ok</span>;
  const wallpaper = look.wallpaper;

  return (
    <div
      aria-hidden
      className="@container relative h-[300px] overflow-hidden rounded-t-[9px] @[720px]:h-[340px]"
    >
      <ThemeWallpaper key={wallpaper?.path ?? "none"} look={look} preview={preview} />
      <div className="absolute inset-0 bg-[linear-gradient(90deg,rgba(0,0,0,0.3)_0%,rgba(0,0,0,0)_45%,rgba(0,0,0,0.3)_100%)]" />

      <div
        className="absolute inset-x-0 top-0 flex h-[24px] items-center gap-1 px-3 font-mono text-[10.5px]"
        style={{ background: glass, color: look.foreground }}
      >
        {[1, 2, 3, 4, 5].map((n) => (
          <span
            key={n}
            className="grid h-[16px] min-w-[18px] place-items-center rounded-[3px] px-1 font-semibold"
            style={
              n === 1 ? { background: look.accent, color: look.background } : { opacity: 0.55 }
            }
          >
            {n}
          </span>
        ))}
        <span className="ml-auto hidden items-center gap-3.5 opacity-80 @[480px]:flex">
          <span style={{ color: p[6] }}>wifi</span>
          <span>cpu 12%</span>
          <span>mem 41%</span>
          <span style={{ color: p[2] }}>bat 86%</span>
        </span>
      </div>

      <div
        className="absolute left-4 flex @[640px]:left-auto @[640px]:w-[60%]"
        style={{
          top: 24 + previewGap * 2,
          right: previewGap * 2,
          bottom: previewGap * 2,
          gap: previewGap,
        }}
      >
        <div className="flex min-w-0 flex-[1.25] flex-col overflow-hidden" style={frame(true)}>
          {titleBar("ghostty", true)}
          <div
            className="min-h-0 flex-1 overflow-hidden px-3 py-2.5 font-mono text-[11px] leading-[1.65]"
            style={{ color: look.foreground }}
          >
            <div className="truncate">
              {prompt} macarchy theme {look.name}
            </div>
            <div style={{ color: p[6] }}>Applying {look.title}</div>
            <div className="truncate">
              {ok} ghostty, nvim <span style={{ opacity: 0.6 }}>({look.nvim})</span>
            </div>
            <div>{ok} borders, sketchybar</div>
            {wallpaper ? (
              <div className="truncate">
                {ok} wallpaper{" "}
                <span style={{ opacity: 0.6 }}>{wallpaperName(look, wallpaper)}</span>
              </div>
            ) : null}
            <div className="mt-2 flex gap-[3px]">
              {p.map((colour, index) => (
                <span
                  key={`${index}-${colour}`}
                  className="h-[12px] w-[20px] rounded-[2px]"
                  style={{ background: colour }}
                />
              ))}
            </div>
            <div className="mt-2">
              {prompt}{" "}
              <span
                className="inline-block h-[12px] w-[7px] translate-y-[2px]"
                style={{ background: look.accent }}
              />
            </div>
          </div>
        </div>

        <div
          className="hidden min-w-0 flex-1 flex-col overflow-hidden @[420px]:flex"
          style={frame(false)}
        >
          {titleBar(`nvim  ${look.nvim}`, false)}
          <div className="flex min-h-0 flex-1 gap-2.5 overflow-hidden p-2.5 font-mono text-[10px] leading-[16px]">
            <div className="shrink-0 text-right" style={{ color: look.foreground, opacity: 0.3 }}>
              {nvimCode.map((_, index) => (
                <div key={index}>{index + 1}</div>
              ))}
            </div>
            <div className="min-w-0 flex-1">
              {nvimCode.map(([indent, first, firstWidth, second, secondWidth], index) => (
                <div
                  key={index}
                  className="flex h-[16px] items-center gap-1.5"
                  style={{ paddingLeft: indent * 12, opacity: 0.7 }}
                >
                  <span
                    className="h-[5px] rounded-full"
                    style={{ background: p[first], width: `${firstWidth}%` }}
                  />
                  <span
                    className="h-[5px] rounded-full"
                    style={{ background: p[second], width: `${secondWidth}%` }}
                  />
                </div>
              ))}
            </div>
          </div>
          <div
            className="flex h-[18px] shrink-0 items-center gap-2 px-2.5 font-mono text-[9.5px]"
            style={{ borderTop: hairline, color: look.foreground }}
          >
            <span
              className="rounded-[2px] px-1 font-semibold"
              style={{ background: p[4], color: look.background }}
            >
              NORMAL
            </span>
            <span style={{ opacity: 0.5 }}>init.lua</span>
          </div>
        </div>
      </div>

      {wallpaper ? (
        <WallpaperTag className="absolute bottom-4 left-4 hidden max-w-[34%] @[640px]:inline-flex">
          {wallpaperName(look, wallpaper)}
        </WallpaperTag>
      ) : null}
    </div>
  );
}

/** The wallpaper's name in a frosted pill over artwork. */
export function WallpaperTag({
  className,
  children,
  position,
}: {
  className?: string;
  children: string;
  /** Its place among the theme's wallpapers, as "2/4". */
  position?: string | null;
}) {
  return (
    <span
      className={cn(
        "inline-flex h-[22px] min-w-0 items-center gap-1.5 rounded-small bg-black/40 px-2 text-meta text-white/85 ring-1 ring-white/10 backdrop-blur-md",
        className,
      )}
    >
      <ImageIcon aria-hidden className="size-[11px] shrink-0" />
      <span className="truncate">{children}</span>
      {position ? <span className="text-white/45 tabular-nums">{position}</span> : null}
    </span>
  );
}
