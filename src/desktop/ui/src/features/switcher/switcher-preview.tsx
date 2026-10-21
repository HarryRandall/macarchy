import type { ThemeSummary } from "~/bridge/protocol";

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
        {theme?.preview ? (
          <img
            key={theme.preview}
            src={theme.preview}
            alt=""
            draggable={false}
            className="absolute inset-0 size-full object-cover"
          />
        ) : theme && !theme.currentBackground ? (
          <span className="text-[12px] text-fg-secondary">No wallpaper in this theme</span>
        ) : null}
      </div>
      {details && theme ? <Details theme={theme} /> : null}
    </div>
  );
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
      {colours ? (
        <div className="flex items-center gap-1.5 py-1 font-mono text-[11px]">
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
