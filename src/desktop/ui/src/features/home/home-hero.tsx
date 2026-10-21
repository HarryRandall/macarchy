import { ArrowRight, Moon, Shuffle, Sun } from "lucide-react";
import type { ThemeDetail } from "~/bridge/protocol";
import { focusRing } from "~/components/ui/focus-ring";
import { ImageFill } from "~/components/ui/image-fill";
import { Tooltip } from "~/components/ui/tooltip";
import { ThemeWallpaper, WallpaperTag } from "~/features/themes/theme-art";
import {
  nextWallpaper,
  themeLook,
  wallpaperName,
  wallpaperPosition,
} from "~/features/themes/theme-look";
import { cn } from "~/lib/cn";

const heroButton =
  "inline-flex h-8 items-center gap-1.5 rounded-control px-3 text-small font-medium transition-[background-color,opacity] active:translate-y-px disabled:pointer-events-none disabled:opacity-50 motion-reduce:transition-none motion-reduce:active:translate-y-0 [&_svg]:size-[13px]";

/**
 * The applied theme over its wallpaper. Until the themes are read it shows
 * the summary's name and wallpaper alone.
 */
export function HomeHero({
  title,
  wallpaper,
  theme,
  busy,
  onNextWallpaper,
  onChangeTheme,
}: {
  /** The summary's theme name, or null before setup. */
  title: string | null;
  /** The summary's wallpaper image. */
  wallpaper: string | null;
  theme: ThemeDetail | undefined;
  busy: boolean;
  onNextWallpaper(path: string): void;
  onChangeTheme(): void;
}) {
  const look = theme ? themeLook(theme) : null;
  const next = look ? nextWallpaper(look) : null;
  const name = look?.title ?? title;
  const Mode = look?.dark === false ? Sun : Moon;

  return (
    <section
      aria-label="Current theme"
      data-slot="home-hero"
      className="@container relative mb-6 h-[208px] overflow-hidden rounded-panel border border-hairline shadow-card"
    >
      {look ? (
        <ThemeWallpaper
          key={look.wallpaper?.path ?? "none"}
          look={look}
          preview={theme?.summary.preview ?? wallpaper}
        />
      ) : (
        <ImageFill src={wallpaper ?? undefined} from="#141414" to="#3f3f46" />
      )}
      <div className="absolute inset-0 bg-[linear-gradient(90deg,rgba(0,0,0,0.7)_0%,rgba(0,0,0,0.38)_50%,rgba(0,0,0,0.12)_100%)]" />
      <div className="absolute inset-x-0 bottom-0 h-2/3 bg-gradient-to-t from-black/55 to-transparent" />

      <div className="relative flex h-full flex-col justify-between p-5 text-white">
        <div className="flex items-center justify-between gap-3">
          <span className="text-label text-white/60 uppercase">Current theme</span>
          {look?.wallpaper ? (
            <WallpaperTag position={wallpaperPosition(look)}>
              {wallpaperName(look, look.wallpaper)}
            </WallpaperTag>
          ) : null}
        </div>

        <div className="flex flex-wrap items-end justify-between gap-x-6 gap-y-3">
          <div className="min-w-0">
            <div className="flex items-center gap-2.5">
              <h2 className="truncate text-hero-title leading-none drop-shadow-sm">
                {name ?? "No theme yet"}
              </h2>
              {look ? (
                <span className="inline-flex h-[21px] shrink-0 items-center gap-1 rounded-small bg-white/12 px-1.5 text-caption font-medium text-white/85 ring-1 ring-white/15 backdrop-blur-md">
                  <Mode aria-hidden className="size-2.5" /> {look.dark ? "Dark" : "Light"}
                </span>
              ) : null}
            </div>
            {look ? (
              <div className="mt-3 flex min-w-0 items-center gap-3 text-meta text-white/75">
                <span
                  role="img"
                  aria-label="Terminal palette"
                  className="flex shrink-0 items-center -space-x-[3px]"
                >
                  {look.palette.map((colour, index) => (
                    <span
                      // A palette can repeat a colour, so position is part of the key.
                      key={`${index}-${colour}`}
                      className="size-3 rounded-full ring-[1.5px] ring-black/50"
                      style={{ background: colour }}
                    />
                  ))}
                </span>
                <span aria-hidden className="h-3 w-px shrink-0 bg-white/20" />
                <span className="flex shrink-0 items-center gap-1.5 font-mono text-mono">
                  <span
                    aria-hidden
                    className="size-2.5 rounded-full ring-1 ring-white/30"
                    style={{ background: look.accent }}
                  />
                  <span className="sr-only">Accent </span>
                  {look.accent}
                </span>
                <span aria-hidden className="h-3 w-px shrink-0 bg-white/20" />
                <span className="truncate">Neovim {look.nvim}</span>
              </div>
            ) : null}
          </div>

          <div className="flex shrink-0 items-center gap-2">
            {look ? (
              <Tooltip
                content={
                  next ? `Show ${wallpaperName(look, next)}` : "This theme has one wallpaper"
                }
              >
                <button
                  type="button"
                  aria-disabled={!next || busy}
                  onClick={() => {
                    if (next && !busy) onNextWallpaper(next.path);
                  }}
                  className={cn(
                    heroButton,
                    "bg-white/10 text-white ring-1 ring-white/20 backdrop-blur-md hover:bg-white/20 aria-disabled:opacity-50 aria-disabled:hover:bg-white/10",
                    focusRing,
                  )}
                >
                  <Shuffle aria-hidden /> Next wallpaper
                </button>
              </Tooltip>
            ) : null}
            <button
              type="button"
              onClick={onChangeTheme}
              className={cn(
                heroButton,
                "bg-white text-zinc-900 shadow-[0_1px_2px_rgba(0,0,0,0.3)] hover:opacity-90",
                focusRing,
              )}
            >
              {name ? "Change theme" : "Choose a theme"} <ArrowRight aria-hidden />
            </button>
          </div>
        </div>
      </div>
    </section>
  );
}
