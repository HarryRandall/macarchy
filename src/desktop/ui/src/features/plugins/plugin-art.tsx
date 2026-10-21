import {
  ArrowRight,
  Cloud,
  CloudRain,
  CloudSun,
  GitPullRequest,
  Hash,
  type LucideIcon,
  Moon,
  Music,
  Pause,
  SkipBack,
  SkipForward,
  Video,
} from "lucide-react";
import type { CSSProperties, ReactNode } from "react";

import { cn } from "~/lib/cn";
import { BrandMark } from "~/shell/brand-mark";

import { authorHue } from "./plugins-layout";
import { officialAuthor, type Plugin } from "./plugins-mock";

/*
 * Each plugin's preview is drawn in its own hue, set as `--pl` on the card.
 * Mixing it towards the page's ink and surface keeps it legible in light and
 * dark. The words and numbers in the art are illustration, not data.
 */
const ink = "color-mix(in srgb, var(--pl) 80%, var(--ink-primary))";
const solid = "color-mix(in srgb, var(--pl) 88%, black)";
const line = "color-mix(in srgb, var(--pl) 24%, var(--line-hairline))";
const tint = (percent: number) => `color-mix(in srgb, var(--pl) ${percent}%, var(--surface-card))`;
const glass = (percent: number) => `color-mix(in srgb, var(--pl) ${percent}%, transparent)`;

/** Sets `--pl`, which every preview and accent below reads for the plugin's hue. */
export function hueStyle(plugin: Plugin): CSSProperties {
  return { "--pl": plugin.colour } as CSSProperties;
}

/** The hue's border and ink, for a label or pill drawn over the plugin's art. */
export const hueLine = line;
export const hueInk = ink;
export const hueTint = tint;
export const hueGlass = glass;

/** A faint backdrop pattern per category, so sections read differently at a glance. */
const categoryPattern: Record<Plugin["category"], CSSProperties> = {
  "Menu bar": {
    backgroundImage: `radial-gradient(circle, ${glass(34)} 1px, transparent 1.6px)`,
    backgroundSize: "14px 14px",
  },
  Windows: {
    backgroundImage: `linear-gradient(${glass(16)} 1px, transparent 1px), linear-gradient(90deg, ${glass(16)} 1px, transparent 1px)`,
    backgroundSize: "20px 20px",
  },
  Integrations: {
    backgroundImage: `repeating-linear-gradient(135deg, ${glass(14)} 0 1px, transparent 1px 10px)`,
  },
  Focus: {
    backgroundImage: `repeating-radial-gradient(circle at 50% 50%, ${glass(16)} 0 1px, transparent 1px 16px)`,
  },
};

/** The plugin's app-icon tile: its glyph on a gradient of its hue. */
export function PluginTile({ plugin, size }: { plugin: Plugin; size: number }) {
  const Icon = plugin.icon;
  return (
    <span
      aria-hidden
      className="grid shrink-0 place-items-center text-white shadow-[inset_0_0_0_1px_rgba(255,255,255,0.18),0_1px_2px_rgba(0,0,0,0.2)]"
      style={{
        ...hueStyle(plugin),
        width: size,
        height: size,
        borderRadius: Math.round(size * 0.28),
        background:
          "linear-gradient(150deg, color-mix(in srgb, var(--pl) 80%, white), color-mix(in srgb, var(--pl) 86%, black))",
      }}
    >
      <Icon size={Math.round(size * 0.5)} strokeWidth={2} />
    </span>
  );
}

/** The brand mark for Macarchy's own plugins, an initial for everyone else's. */
export function Avatar({ author, size = 20 }: { author: string; size?: number }) {
  if (author === officialAuthor) {
    return (
      <span
        aria-hidden
        className="grid shrink-0 place-items-center rounded-full bg-strong text-strong-fg"
        style={{ width: size, height: size }}
      >
        <BrandMark width={Math.round(size * 0.62)} height={Math.round(size * 0.62)} />
      </span>
    );
  }
  const hue = authorHue(author);
  return (
    <span
      aria-hidden
      className="grid shrink-0 place-items-center rounded-full font-semibold text-white ring-1 ring-black/10 ring-inset"
      style={{
        width: size,
        height: size,
        fontSize: Math.round(size * 0.48),
        background: `linear-gradient(135deg, hsl(${hue} 68% 60%), hsl(${(hue + 40) % 360} 62% 44%))`,
      }}
    >
      {author.replace(/^@/, "").slice(0, 1).toUpperCase()}
    </span>
  );
}

/** The plugin's own element, centred on a soft wash and pattern in its hue. */
export function Stage({
  plugin,
  height,
  scale = 1,
  className,
  label,
  children,
}: {
  plugin: Plugin;
  height?: number;
  scale?: number;
  className?: string;
  /** A pill in the top corner, such as "Featured". */
  label?: ReactNode;
  children: ReactNode;
}) {
  const fade = "radial-gradient(ellipse 72% 72% at 50% 50%, black 10%, transparent 78%)";
  return (
    <div
      className={cn("relative isolate overflow-hidden", className)}
      style={{
        height,
        background: `radial-gradient(110% 90% at 50% 35%, ${tint(20)}, ${tint(6)})`,
      }}
    >
      <div
        aria-hidden
        className="absolute inset-0"
        style={{
          ...categoryPattern[plugin.category],
          maskImage: fade,
          WebkitMaskImage: fade,
        }}
      />
      <div aria-hidden className="absolute inset-0 grid place-items-center">
        <div style={scale === 1 ? undefined : { transform: `scale(${scale})` }}>{children}</div>
      </div>
      {label ? (
        <span
          className="absolute top-3 left-3 inline-flex h-[22px] items-center gap-[5px] rounded-full border bg-card px-[9px] text-caption font-medium"
          style={{ borderColor: line, color: ink }}
        >
          {label}
        </span>
      ) : null}
    </div>
  );
}

function Surface({
  className,
  style,
  children,
}: {
  className?: string;
  style?: CSSProperties;
  children: ReactNode;
}) {
  return (
    <div
      className={cn("rounded-card border bg-card text-fg", className)}
      style={{
        borderColor: line,
        boxShadow: `0 14px 30px -14px ${glass(60)}, 0 1px 2px rgba(0,0,0,0.06)`,
        ...style,
      }}
    >
      {children}
    </div>
  );
}

function Keycap({ children, held }: { children: ReactNode; held?: boolean }) {
  return (
    <span
      className={cn(
        "grid h-[19px] min-w-[19px] place-items-center rounded-key border border-b-2 px-[5px] font-sans text-[10.5px] font-semibold",
        !held && "border-line-strong bg-side text-fg-secondary",
      )}
      style={held ? { borderColor: glass(55), background: tint(16), color: ink } : undefined}
    >
      {children}
    </span>
  );
}

const overlayShortcuts: [string[], string][] = [
  [["⌥", "H"], "Focus left"],
  [["⌥", "⇧", "F"], "Fullscreen"],
  [["⌥", "1"], "Desktop 1"],
];

const codeRows: [number, number][] = [
  [0, 46],
  [1, 62],
  [1, 38],
  [2, 54],
  [1, 30],
  [0, 20],
];

const outlook: [LucideIcon, string, string][] = [
  [Cloud, "19:00", "16°"],
  [CloudRain, "20:00", "14°"],
  [CloudRain, "21:00", "13°"],
];

const brewRows: [string, string, string][] = [
  ["node", "22.12", "22.13"],
  ["ffmpeg", "7.0", "7.1"],
  ["gh", "2.62", "2.63"],
];

const pullRequests: [string, string][] = [
  ["#412", "Tidy bar spacing"],
  ["#409", "Window stacks"],
  ["#401", "Theme import fixes"],
];

function MediaArt() {
  return (
    <Surface className="flex w-[226px] items-center gap-3 p-2.5">
      <span
        className="grid size-[62px] shrink-0 place-items-center rounded-tile text-white shadow-[inset_0_0_0_1px_rgba(255,255,255,0.15)]"
        style={{
          background:
            "linear-gradient(140deg, color-mix(in srgb, var(--pl) 60%, #fde68a), var(--pl) 50%, color-mix(in srgb, var(--pl) 55%, #3b0764))",
        }}
      >
        <Music size={24} strokeWidth={2} />
      </span>
      <div className="min-w-0 flex-1">
        <div className="truncate text-detail font-semibold tracking-[-0.01em]">Veridis Quo</div>
        <div className="truncate text-caption text-fg-secondary">Daft Punk</div>
        <div className="mt-[7px] flex items-center gap-3 text-fg-secondary">
          <SkipBack size={12} fill="currentColor" />
          <span
            className="grid size-6 place-items-center rounded-full text-white"
            style={{ background: solid }}
          >
            <Pause size={11} fill="currentColor" strokeWidth={0} />
          </span>
          <SkipForward size={12} fill="currentColor" />
        </div>
        <div
          className="mt-2 h-[3px] overflow-hidden rounded-full"
          style={{ background: glass(18) }}
        >
          <div className="h-full w-[42%] rounded-full" style={{ background: "var(--pl)" }} />
        </div>
      </div>
    </Surface>
  );
}

function WeatherArt() {
  return (
    <div className="flex items-center gap-3.5 text-fg">
      <CloudSun size={56} strokeWidth={1.5} style={{ color: ink }} />
      <div>
        <div className="text-[40px] leading-none font-semibold tracking-[-0.04em] tabular-nums">
          18°
        </div>
        <div className="mt-[5px] text-caption text-fg-secondary">Sydney, partly cloudy</div>
        <div className="mt-2 flex gap-2.5 text-[10.5px] text-fg-secondary tabular-nums">
          {outlook.map(([Icon, time, temperature]) => (
            <span key={time} className="flex items-center gap-[3px]">
              <Icon size={11} strokeWidth={2} style={{ color: ink }} />
              {temperature}
            </span>
          ))}
        </div>
      </div>
    </div>
  );
}

function BrewArt() {
  return (
    <div className="relative">
      <Surface className="w-[200px] p-2.5">
        <div className="mb-[5px] flex items-center justify-between text-[10.5px] font-medium text-fg-secondary">
          <span>Outdated</span>
          <span className="font-mono text-fg-tertiary">brew</span>
        </div>
        {brewRows.map(([name, from, to]) => (
          <div
            key={name}
            className="flex items-center gap-[5px] font-mono text-[10.5px] leading-[18px]"
          >
            <span className="flex-1">{name}</span>
            <span className="text-fg-tertiary">{from}</span>
            <ArrowRight size={9} className="text-fg-tertiary" />
            <span style={{ color: ink }}>{to}</span>
          </div>
        ))}
        <div
          className="mt-2 grid h-[22px] place-items-center rounded-small text-[10.5px] font-semibold"
          style={{ background: "var(--pl)", color: "color-mix(in srgb, var(--pl) 22%, black)" }}
        >
          Upgrade all
        </div>
      </Surface>
      <span
        className="absolute -top-[9px] -right-[9px] grid size-6 place-items-center rounded-full text-caption font-bold ring-2 ring-card"
        style={{ background: "var(--pl)", color: "color-mix(in srgb, var(--pl) 22%, black)" }}
      >
        7
      </span>
    </div>
  );
}

function StackArt() {
  const tabs = ["Ghostty", "Zed", "Arc"];
  return (
    <div className="relative w-[214px] pt-2.5">
      <div
        className="absolute inset-x-4 top-0 h-6 rounded-t-card border border-b-0"
        style={{ borderColor: line, background: tint(10) }}
      />
      <div
        className="absolute inset-x-2 top-[5px] h-6 rounded-t-card border border-b-0"
        style={{ borderColor: line, background: tint(16) }}
      />
      <Surface className="relative overflow-hidden">
        <div
          className="flex gap-0.5 border-b px-[5px] pt-[5px]"
          style={{ borderColor: line, background: tint(8) }}
        >
          {tabs.map((tab, index) => (
            <span
              key={tab}
              className={cn(
                "flex-1 truncate rounded-t-[5px] px-1.5 py-1 text-center text-tag font-medium",
                index === 0 ? "bg-card text-fg" : "text-fg-tertiary",
              )}
              style={index === 0 ? { boxShadow: "inset 0 2px 0 var(--pl)" } : undefined}
            >
              {tab}
            </span>
          ))}
        </div>
        <div className="space-y-[5px] p-2.5">
          {codeRows.map(([indent, width], index) => (
            <div
              // Illustration rows never reorder.
              key={index}
              className="h-1 rounded-full"
              style={{
                marginLeft: indent * 10,
                width: `${width}%`,
                background: index % 3 === 0 ? glass(70) : "var(--line-strong)",
              }}
            />
          ))}
        </div>
      </Surface>
    </div>
  );
}

function KeysArt() {
  return (
    <Surface className="w-[212px] p-2.5">
      <div className="mb-1.5 flex items-center justify-between">
        <span className="text-caption font-semibold">Ghostty</span>
        <span className="flex items-center gap-[5px] text-tag text-fg-tertiary">
          Holding <Keycap held>⌥</Keycap>
        </span>
      </div>
      {overlayShortcuts.map(([keys, label]) => (
        <div key={label} className="flex items-center justify-between py-[3px] text-caption">
          <span className="text-fg-secondary">{label}</span>
          <span className="flex gap-[3px]">
            {keys.map((key) => (
              <Keycap key={key}>{key}</Keycap>
            ))}
          </span>
        </div>
      ))}
    </Surface>
  );
}

function ScratchArt() {
  return (
    <div
      className="relative h-[118px] w-[214px] overflow-hidden rounded-card border"
      style={{ borderColor: line, background: tint(4) }}
    >
      <div className="absolute inset-2 flex gap-1.5">
        <div className="flex-1 rounded-small border border-hairline bg-card" />
        <div className="flex-1 rounded-small border border-hairline bg-card" />
      </div>
      <div
        className="absolute inset-x-[18px] top-0 rounded-b-[9px] px-2.5 pt-2 pb-[7px] font-mono text-tag leading-[15px] text-[#d4d4d8]"
        style={{
          background: "#0b0f0d",
          boxShadow: `0 0 0 1px ${glass(50)}, 0 16px 30px -12px ${glass(70)}`,
        }}
      >
        <div>
          <span style={{ color: "var(--pl)" }}>~</span> brew upgrade
        </div>
        <div className="text-[#71717a]">Upgrading 7 outdated</div>
        <div>
          <span style={{ color: "var(--pl)" }}>~</span>{" "}
          <span
            className="inline-block h-2.5 w-1.5 translate-y-px animate-pulse"
            style={{ background: "var(--pl)" }}
          />
        </div>
        <div className="mx-auto mt-[5px] h-[3px] w-7 rounded-full bg-white/20" />
      </div>
    </div>
  );
}

function PullRequestArt() {
  return (
    <Surface className="w-[222px] overflow-hidden">
      <div
        className="flex items-center justify-between border-b px-2.5 py-[7px] text-caption font-semibold"
        style={{ borderColor: line }}
      >
        <span>Review requested</span>
        <span
          className="rounded-full px-[7px] text-tag leading-4 tabular-nums"
          style={{ background: tint(16), color: ink }}
        >
          3
        </span>
      </div>
      {pullRequests.map(([number, title]) => (
        <div key={number} className="flex items-center gap-[7px] px-2.5 py-[5px] text-caption">
          <GitPullRequest size={12} strokeWidth={2.2} className="shrink-0" style={{ color: ink }} />
          <span className="min-w-0 flex-1 truncate">{title}</span>
          <span className="font-mono text-tag text-fg-tertiary">{number}</span>
        </div>
      ))}
    </Surface>
  );
}

function LinearArt() {
  return (
    <div className="relative">
      <div
        className="absolute inset-0 translate-x-3 translate-y-1.5 rotate-[5deg] rounded-card border"
        style={{ borderColor: line, background: tint(14) }}
      />
      <Surface className="relative w-[198px] p-[11px]">
        <div className="flex items-center justify-between font-mono text-tag text-fg-tertiary">
          <span>MAC-142</span>
          <Avatar author="@tobyk" size={16} />
        </div>
        <div className="mt-[5px] text-small leading-[1.35] font-semibold">
          Bar spacing on external displays
        </div>
        <div className="mt-[9px] flex items-center gap-2.5 text-[10.5px]">
          <span className="flex items-center gap-[5px] font-medium" style={{ color: ink }}>
            <span
              className="size-2.5 rounded-full"
              style={{
                background: "conic-gradient(var(--pl) 0 50%, transparent 0)",
                boxShadow: "0 0 0 1.5px var(--pl)",
              }}
            />
            In progress
          </span>
          <span className="flex items-end gap-[1.5px]">
            {[5, 8, 11].map((height) => (
              <span
                key={height}
                className="w-[3px] rounded-[1px]"
                style={{ height, background: height < 11 ? ink : "var(--line-strong)" }}
              />
            ))}
          </span>
        </div>
      </Surface>
    </div>
  );
}

function MeetingArt() {
  return (
    <Surface className="flex w-[228px] items-center gap-2.5 p-2.5">
      <div
        className="flex w-10 shrink-0 flex-col items-center rounded-tile py-[5px]"
        style={{ background: tint(16), color: ink }}
      >
        <span className="text-[9px] font-semibold tracking-[0.06em] uppercase">Oct</span>
        <span className="text-[17px] leading-none font-semibold">21</span>
      </div>
      <div className="min-w-0 flex-1">
        <div className="truncate text-small font-semibold">Daily standup</div>
        <div className="truncate text-[10.5px] text-fg-secondary">Google Meet, in 1 min</div>
      </div>
      <span
        className="flex items-center gap-1 rounded-small px-2 py-1 text-[10.5px] font-semibold text-white"
        style={{ background: solid }}
      >
        <Video size={11} strokeWidth={2.2} />
        Join
      </span>
    </Surface>
  );
}

function SlackArt() {
  return (
    <div className="relative w-[216px] pt-4">
      <div
        className="absolute inset-x-[22px] top-0 h-11 rounded-card border"
        style={{ borderColor: line, background: tint(9) }}
      />
      <div
        className="absolute inset-x-[11px] top-2 h-11 rounded-card border"
        style={{ borderColor: line, background: tint(15) }}
      />
      <Surface className="relative flex items-center gap-[9px] p-[9px]">
        <span
          className="grid size-7 shrink-0 place-items-center rounded-control text-white"
          style={{ background: solid }}
        >
          <Hash size={14} strokeWidth={2.4} />
        </span>
        <div className="min-w-0 flex-1">
          <div className="flex items-baseline justify-between text-meta font-semibold">
            <span>Slack</span>
            <span className="text-tag font-normal text-fg-tertiary">now</span>
          </div>
          <div className="truncate text-[10.5px] text-fg-secondary">Status set to Focusing</div>
        </div>
      </Surface>
    </div>
  );
}

function TimerArt() {
  return (
    <div className="flex flex-col items-center gap-2 text-fg">
      <span
        className="relative grid size-24 place-items-center rounded-full"
        style={{ background: `conic-gradient(var(--pl) 0 74%, ${glass(16)} 0)` }}
      >
        <span className="absolute inset-[7px] rounded-full bg-card" />
        <span className="relative text-center">
          <span className="block font-mono text-[19px] font-semibold tracking-[-0.02em] tabular-nums">
            18:42
          </span>
          <span className="block text-tag text-fg-tertiary">Focus</span>
        </span>
      </span>
      <span className="flex gap-1">
        {[0, 1, 2, 3].map((session) => (
          <span
            key={session}
            className="h-1 w-3.5 rounded-full"
            style={{ background: session < 2 ? "var(--pl)" : glass(20) }}
          />
        ))}
      </span>
    </div>
  );
}

function QuietArt() {
  return (
    <div className="flex flex-col items-center gap-3.5">
      <span
        className="relative grid size-[62px] place-items-center rounded-full"
        style={{
          background: tint(18),
          color: ink,
          boxShadow: `0 0 0 9px ${glass(9)}, 0 0 0 18px ${glass(5)}`,
        }}
      >
        <Moon size={26} strokeWidth={1.75} fill="currentColor" />
        <span
          className="absolute -top-[3px] -right-[5px] grid h-5 min-w-5 place-items-center rounded-full px-[5px] text-[10.5px] font-bold text-white ring-2 ring-card"
          style={{ background: solid }}
        >
          3
        </span>
      </span>
      <span
        className="rounded-full border bg-card px-2.5 py-[3px] text-[10.5px] text-fg-secondary"
        style={{ borderColor: line }}
      >
        3 held until you leave fullscreen
      </span>
    </div>
  );
}

const arts: Record<string, () => ReactNode> = {
  media: MediaArt,
  weather: WeatherArt,
  brew: BrewArt,
  stack: StackArt,
  keys: KeysArt,
  scratch: ScratchArt,
  pr: PullRequestArt,
  linear: LinearArt,
  meetings: MeetingArt,
  slack: SlackArt,
  pomodoro: TimerArt,
  quiet: QuietArt,
};

/** What each plugin adds, drawn as its one distinctive element. */
export function PluginArt({ id }: { id: string }) {
  const Art = arts[id];
  return Art ? <Art /> : null;
}
