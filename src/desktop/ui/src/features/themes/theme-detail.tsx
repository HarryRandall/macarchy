import { ArrowRight, Check, ChevronLeft, ChevronRight, Moon, Sun } from "lucide-react";
import { type ReactNode, useEffect, useRef } from "react";
import type { ThemeDetail as ThemeDetailState } from "~/bridge/protocol";
import { Badge } from "~/components/ui/badge";
import { Button } from "~/components/ui/button";
import { Card, SectionLabel } from "~/components/ui/card";
import { focusRing } from "~/components/ui/focus-ring";
import { HexValue } from "~/components/ui/hex-value";
import { IconButton } from "~/components/ui/icon-button";
import { Tooltip } from "~/components/ui/tooltip";
import { cn } from "~/lib/cn";
import { ThemeHero, ThemeWallpaper } from "./theme-art";
import { ThemeCustomise } from "./theme-customise";
import {
  stepTheme,
  type ThemeLook,
  themeLook,
  wallpaperName,
  wallpaperPosition,
} from "./theme-look";
import type { ThemesStore } from "./themes-store";

function DetailCell({ label, children }: { label: string; children: ReactNode }) {
  return (
    <div className="min-w-0 bg-card px-5 py-3">
      <dt className="text-meta text-fg-tertiary">{label}</dt>
      <dd className="mt-1.5 flex min-h-5 min-w-0 items-center gap-2 font-mono text-mono-value text-fg">
        {children}
      </dd>
    </div>
  );
}

/** A palette chip that names its colour on hover or focus. */
function PaletteSwatch({ colour, index }: { colour: string; index: number }) {
  return (
    <Tooltip content={colour.toUpperCase()} side="top" describe={false}>
      <span
        role="img"
        // oxlint-disable-next-line jsx-a11y/no-noninteractive-tabindex -- the swatch takes focus so the keyboard can open the tooltip naming its colour.
        tabIndex={0}
        aria-label={`Colour ${index}, ${colour}`}
        className="size-5 shrink-0 rounded-[5px] ring-1 ring-black/15 ring-inset transition-transform duration-150 outline-none hover:-translate-y-px focus-visible:ring-2 focus-visible:ring-accent motion-reduce:transition-none"
        style={{ background: colour }}
      />
    </Tooltip>
  );
}

/**
 * One theme in full: the preview, its colours, its wallpapers and its
 * settings, with the rest of the collection under it.
 */
export function ThemeDetail({
  store,
  themes,
  theme,
  current,
  busy,
  applying,
  colourschemes,
  onOpen,
  onClose,
  onWorkshop,
}: {
  store: ThemesStore;
  themes: readonly ThemeDetailState[];
  theme: ThemeDetailState;
  current: string | null;
  busy: boolean;
  applying: boolean;
  colourschemes: readonly string[];
  onOpen: (name: string) => void;
  onClose: () => void;
  onWorkshop: () => void;
}) {
  const back = useRef<HTMLButtonElement>(null);
  const look = themeLook(theme);
  const index = themes.findIndex((item) => item.summary.name === theme.summary.name);
  const isCurrent = current === look.name;
  const preview = theme.summary.preview;
  const position = wallpaperPosition(look);
  const step = (by: number) => {
    const next = stepTheme(themes, index, by);
    if (next) onOpen(next.summary.name);
  };

  // Opening moves focus to the way back, which also scrolls the detail into view;
  // stepping between themes keeps focus on the arrow that was pressed.
  useEffect(() => {
    back.current?.focus();
  }, []);

  return (
    <>
      <div className="mb-4 flex items-center justify-between gap-3">
        <nav aria-label="Breadcrumb" className="flex min-w-0 items-center gap-1.5 text-body">
          <button
            ref={back}
            type="button"
            onClick={onClose}
            className={cn(
              "inline-flex shrink-0 items-center gap-1 rounded-small font-medium text-fg-secondary hover:text-fg",
              focusRing,
            )}
          >
            <ChevronLeft aria-hidden className="size-3.5" /> Themes
          </button>
          <span aria-hidden className="text-fg-tertiary">
            /
          </span>
          <span aria-current="page" className="truncate font-medium text-fg">
            {look.title}
          </span>
        </nav>
        <div className="flex shrink-0 items-center gap-1">
          <span className="mr-1 text-small text-fg-tertiary tabular-nums">
            {index + 1} of {themes.length}
          </span>
          <IconButton label="Previous theme" onClick={() => step(-1)}>
            <ChevronLeft aria-hidden />
          </IconButton>
          <IconButton label="Next theme" onClick={() => step(1)}>
            <ChevronRight aria-hidden />
          </IconButton>
        </div>
      </div>

      <Card className="@container mb-7 overflow-hidden">
        <ThemeHero look={look} preview={preview} />

        <div className="flex flex-wrap items-center justify-between gap-x-6 gap-y-3 border-t border-hairline px-5 py-4">
          <div className="flex min-w-0 items-center gap-2">
            <h2 className="truncate text-[19px] font-semibold tracking-[-0.02em] text-fg">
              {look.title}
            </h2>
            <Badge>
              {look.dark ? (
                <Moon aria-hidden className="size-[11px]" />
              ) : (
                <Sun aria-hidden className="size-[11px]" />
              )}
              {look.dark ? "Dark" : "Light"}
            </Badge>
            {isCurrent ? (
              <Badge tone="accent" dot>
                Current
              </Badge>
            ) : null}
          </div>
          <div className="flex shrink-0 items-center gap-2">
            <Button variant="ghost" onClick={onWorkshop}>
              Browse more in Workshop <ArrowRight aria-hidden className="size-[13px]" />
            </Button>
            <Tooltip
              content={isCurrent ? "Apply your edits to the desktop" : "Switch to this theme"}
            >
              <Button
                variant={isCurrent ? "secondary" : "primary"}
                busy={applying}
                disabled={busy && !applying}
                onClick={() => void store.apply(look.name)}
              >
                {applying ? "Applying…" : isCurrent ? "Reapply" : `Apply ${look.title}`}
              </Button>
            </Tooltip>
          </div>
        </div>

        <dl className="grid grid-cols-2 gap-px border-t border-hairline bg-hairline @[720px]:grid-cols-[1fr_1fr_1fr_1.6fr]">
          <DetailCell label="Accent">
            <HexValue value={look.accent} className="text-fg" />
          </DetailCell>
          <DetailCell label="Background">
            <HexValue value={look.background} className="text-fg" />
          </DetailCell>
          <DetailCell label="Neovim">
            <span className="truncate">{look.nvim}</span>
          </DetailCell>
          <DetailCell label="Terminal palette">
            <span className="flex flex-wrap gap-1">
              {look.palette.map((colour, slot) => (
                <PaletteSwatch key={`${slot}-${colour}`} colour={colour} index={slot} />
              ))}
            </span>
          </DetailCell>
        </dl>

        <WallpaperStrip
          look={look}
          preview={preview}
          position={position}
          busy={busy}
          onChoose={(path) => void store.choose(look.name, path)}
        />
      </Card>

      <div className="mb-7">
        <ThemeCustomise store={store} theme={theme} colourschemes={colourschemes} busy={busy} />
      </div>

      {themes.length > 1 ? (
        <>
          <SectionLabel>Other themes</SectionLabel>
          <div className="@container">
            <div className="grid grid-cols-3 gap-3 @[560px]:grid-cols-4 @[820px]:grid-cols-7">
              {themes
                .filter((item) => item.summary.name !== look.name)
                .map((item) => (
                  <OtherTheme
                    key={item.summary.name}
                    look={themeLook(item)}
                    preview={item.summary.preview}
                    applied={item.summary.name === current}
                    onOpen={() => {
                      // The pressed tile leaves the list, so focus moves to the way back.
                      back.current?.focus();
                      onOpen(item.summary.name);
                    }}
                  />
                ))}
            </div>
          </div>
        </>
      ) : null}
    </>
  );
}

function WallpaperStrip({
  look,
  preview,
  position,
  busy,
  onChoose,
}: {
  look: ThemeLook;
  preview: string | null;
  position: string | null;
  busy: boolean;
  onChoose: (path: string) => void;
}) {
  return (
    <div className="border-t border-hairline px-5 py-4">
      <div className="mb-2.5 flex items-center justify-between gap-3 text-small">
        <span className="font-medium text-fg-secondary">Wallpaper</span>
        {look.wallpaper ? (
          <span className="min-w-0 truncate text-fg-tertiary">
            {wallpaperName(look, look.wallpaper)}
            <span className="ml-1.5 tabular-nums">{position}</span>
          </span>
        ) : null}
      </div>
      {look.wallpapers.length ? (
        <div
          role="group"
          aria-label={`${look.title} wallpapers`}
          className="flex gap-2.5 overflow-x-auto p-1"
        >
          {look.wallpapers.map((wallpaper) => {
            const on = wallpaper.path === look.wallpaper?.path;
            const name = wallpaperName(look, wallpaper);
            return (
              <Tooltip key={wallpaper.path} content={on ? `${name}, in use` : `Use ${name}`}>
                <button
                  type="button"
                  data-wallpaper={wallpaper.path}
                  aria-pressed={on}
                  aria-label={name}
                  disabled={busy}
                  onClick={() => onChoose(wallpaper.path)}
                  className={cn(
                    "relative aspect-[16/10] w-[128px] shrink-0 overflow-hidden rounded-control transition-[box-shadow,opacity] duration-150 disabled:cursor-default",
                    focusRing,
                    on
                      ? "ring-2 ring-fg ring-offset-2 ring-offset-card"
                      : "opacity-70 ring-1 ring-hairline hover:opacity-100",
                  )}
                >
                  <ThemeWallpaper look={look} wallpaper={wallpaper} preview={preview} />
                  {on ? (
                    <span className="absolute right-1.5 bottom-1.5 grid size-4 place-items-center rounded-full bg-black/60 text-white backdrop-blur-sm">
                      <Check aria-hidden className="size-2.5" />
                    </span>
                  ) : null}
                </button>
              </Tooltip>
            );
          })}
        </div>
      ) : (
        <p className="text-detail text-fg-tertiary">
          This theme ships without wallpapers. Add images to its folder to choose one here.
        </p>
      )}
    </div>
  );
}

function OtherTheme({
  look,
  preview,
  applied,
  onOpen,
}: {
  look: ThemeLook;
  preview: string | null;
  applied: boolean;
  onOpen: () => void;
}) {
  return (
    <button
      type="button"
      data-theme={look.name}
      onClick={onOpen}
      aria-label={`View ${look.title}${applied ? ", current theme" : ""}`}
      className={cn("group min-w-0 rounded-tile text-left", focusRing)}
    >
      <span className="relative block aspect-[16/10] overflow-hidden rounded-control shadow-card ring-1 ring-hairline transition-transform duration-150 group-hover:-translate-y-px motion-reduce:transition-none">
        <ThemeWallpaper look={look} preview={preview} />
      </span>
      <span className="mt-1.5 flex items-center gap-1.5 px-0.5">
        <span
          aria-hidden
          className="size-2 shrink-0 rounded-full ring-1 ring-black/15"
          style={{ background: look.accent }}
        />
        <span className="truncate text-small font-medium text-fg-secondary group-hover:text-fg">
          {look.title}
        </span>
        {applied ? <Check aria-hidden className="size-[11px] shrink-0 text-accent-text" /> : null}
      </span>
    </button>
  );
}
