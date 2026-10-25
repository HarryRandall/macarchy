import { useState } from "react";

import type { ThemeSummary } from "~/bridge/protocol";
import { cn } from "~/lib/cn";

import { backgroundName } from "./switcher-model";

/** The right-hand pane: the wallpaper, then the theme's details. */
export function SwitcherPreview({
  theme,
  details,
}: {
  theme: ThemeSummary | undefined;
  details: boolean;
}) {
  return (
    <div className="flex min-w-0 flex-1 flex-col gap-3.5 overflow-y-auto p-4" data-scroll-reset>
      <div
        className="relative flex aspect-video w-full shrink-0 items-center justify-center overflow-hidden rounded-small"
        style={{ backgroundColor: theme?.colours?.background ?? "#000" }}
      >
        <Wallpaper src={theme?.preview ?? null} />
        {theme && !theme.preview && !theme.currentBackground ? (
          // On the theme's own terminal ground, not the panel's, so in the
          // theme's text colour: the panel's secondary ink vanished on a light one.
          <span
            className="relative text-[12px]"
            style={{
              color: `color-mix(in srgb, ${theme.colours?.foreground ?? "#fff"} 70%, transparent)`,
            }}
          >
            No wallpaper in this theme
          </span>
        ) : null}
      </div>
      {details && theme ? <Details theme={theme} /> : null}
    </div>
  );
}

interface Layers {
  /** The wallpaper the shown one replaced, kept under it while it fades in. */
  below: string | null;
  shown: string | null;
  /** A wallpaper that would not load, so it is not waited for again. */
  failed: string | null;
}

/**
 * Keeps the wallpaper on show until the next has loaded, then fades the new
 * one in over it, so arrowing through themes never flashes the palette ground
 * between wallpapers.
 */
function Wallpaper({ src }: { src: string | null }) {
  const [layers, setLayers] = useState<Layers>({ below: null, shown: src, failed: null });
  // Adjusted while rendering, as React suggests for state derived from props.
  if (src === null && (layers.shown !== null || layers.below !== null)) {
    setLayers({ below: null, shown: null, failed: null });
  } else if (src !== null && src === layers.below) {
    // Back to the one underneath, which has already loaded.
    setLayers({ below: layers.shown, shown: src, failed: null });
  }
  const pending = src !== null && src !== layers.shown && src !== layers.failed ? src : null;
  const urls = [layers.below, layers.shown, pending].filter(
    (url, index, all): url is string => url !== null && all.indexOf(url) === index,
  );
  return urls.map((url) => (
    <img
      key={url}
      src={url}
      alt=""
      draggable={false}
      decoding="async"
      onLoad={
        url === pending
          ? () => setLayers((now) => ({ below: now.shown, shown: url, failed: null }))
          : undefined
      }
      onError={
        url === pending ? () => setLayers({ below: null, shown: null, failed: url }) : undefined
      }
      className={cn(
        "absolute inset-0 size-full object-cover transition-opacity ease-hover",
        url === pending && "opacity-0",
      )}
    />
  ));
}

function Details({ theme }: { theme: ThemeSummary }) {
  const background = theme.currentBackground
    ? (theme.backgrounds.find((bg) => bg.path === theme.currentBackground)?.name ??
      backgroundName(theme.currentBackground))
    : null;
  const colours = theme.colours;
  return (
    <div className="flex flex-col text-[12px] text-fg">
      <h2 className="pb-2.5 text-[17px] font-semibold">{theme.title}</h2>
      <dl className="contents">
        <Metadata title="Mode" value={theme.isDark ? "Dark" : "Light"} />
        <Metadata title="Wallpapers" value={String(theme.backgrounds.length)} />
        {background ? <Metadata title="Background" value={background} /> : null}
      </dl>
      <div aria-hidden className="my-1.5 h-px bg-white/10 opacity-50" />
      <div className="flex items-center justify-between py-1">
        <span className="text-fg-secondary">Accent</span>
        <span
          role="img"
          aria-label={`Accent ${theme.ring}`}
          className="size-2.5 rounded-full"
          style={{ backgroundColor: theme.ring }}
        />
      </div>
      {/* A sample of the palette, which is noise when read aloud. */}
      {colours ? (
        <div aria-hidden className="flex items-center gap-1.5 py-1 font-mono text-[11px]">
          <span className="mr-auto text-fg-secondary">ls -la</span>
          <Tag colour={colours.blue}>dir/</Tag>
          <Tag colour={colours.cyan}>link@</Tag>
          <Tag colour={colours.green}>exec*</Tag>
          <Tag colour={colours.red}>archive</Tag>
          <Tag colour={colours.foreground}>file</Tag>
        </div>
      ) : null}
    </div>
  );
}

function Metadata({ title, value }: { title: string; value: string }) {
  return (
    <div className="flex items-center justify-between gap-3 py-1">
      <dt className="text-fg-secondary">{title}</dt>
      <dd className="truncate">{value}</dd>
    </div>
  );
}

function Tag({ colour, children }: { colour: string; children: string }) {
  return (
    <span
      className="rounded-[4px] px-[5px] py-px"
      style={{
        color: colour,
        backgroundColor: `color-mix(in srgb, ${colour} 14%, transparent)`,
      }}
    >
      {children}
    </span>
  );
}
