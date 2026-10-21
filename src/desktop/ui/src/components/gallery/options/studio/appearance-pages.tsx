import {
  AppWindow,
  ArrowRight,
  Check,
  ChevronDown,
  ChevronLeft,
  ChevronRight,
  FileCode2,
  History,
  Image as ImageIcon,
  LayoutPanelLeft,
  Moon,
  PanelTop,
  Plus,
  RotateCw,
  Shuffle,
  SquareDashed,
  SquareTerminal,
  Undo2,
} from "lucide-react";
import {
  type CSSProperties,
  type MouseEvent as ReactMouseEvent,
  type ReactNode,
  useId,
  useLayoutEffect,
  useRef,
  useState,
} from "react";

import type { MockPaneId } from "../data";
import { type RealTheme, currentThemeId, realThemes, snapshot, wallpaperUrl } from "../real";
import {
  Badge,
  Button,
  Card,
  CardHeader,
  Chip,
  ColourField,
  ImageFill,
  PageHeader,
  Row,
  SectionLabel,
  Segmented,
  Slider,
  Stepper,
  Switch,
  cx,
  focusRing,
  useWidth,
} from "./ui";

type Go = (id: MockPaneId) => void;

/* ------------------------------------------------------------------ */
/* Real theme helpers                                                  */
/* ------------------------------------------------------------------ */

const themeById = (id: string): RealTheme => realThemes.find((t) => t.id === id) ?? realThemes[0]!;
const current = themeById(currentThemeId);

/** "0-ship-at-sea" reads as "Ship at sea"; bare file names become "Wallpaper 2". */
function wallpaperName(theme: RealTheme, file: string) {
  const stripped = file.replace(/^\d+-/, "").replace(/-/g, " ");
  if (/^(bg)?\d+$/i.test(stripped) || stripped === "wall") {
    return `Wallpaper ${theme.wallpapers.indexOf(file) + 1}`;
  }
  return stripped.charAt(0).toUpperCase() + stripped.slice(1);
}

/** A theme's wallpaper as a cover image, or a gradient from its colours when missing. */
function Wallpaper({
  theme,
  file,
  className,
}: {
  theme: RealTheme;
  file: string;
  className?: string;
}) {
  return (
    <ImageFill
      src={wallpaperUrl(theme.id, file)}
      from={theme.background}
      to={theme.accent}
      alt={`${theme.name}, ${wallpaperName(theme, file)}`}
      className={className}
    />
  );
}

/* ------------------------------------------------------------------ */
/* Theme hero                                                          */
/* ------------------------------------------------------------------ */

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

/**
 * The theme on screen: its wallpaper at full width with a SketchyBar in theme
 * colours and two tiled windows, the focused terminal framed in the accent and
 * painted with the Ghostty palette.
 */
function ThemeHero({ theme, wallpaper }: { theme: RealTheme; wallpaper: string }) {
  const p = theme.palette;
  const gap = snapshot.layout.window_gap;
  const ring = Math.max(snapshot.borders.border_width * 0.4, 2);
  const glass = `color-mix(in srgb, ${theme.background} 90%, transparent)`;
  const hairline = `1px solid color-mix(in srgb, ${theme.foreground} 9%, transparent)`;
  const frame = (focused: boolean): CSSProperties => ({
    background: glass,
    boxShadow: focused
      ? `0 0 0 ${ring}px ${theme.accent}, 0 24px 48px -20px rgba(0,0,0,0.75)`
      : `0 0 0 1px color-mix(in srgb, ${theme.foreground} 14%, transparent), 0 20px 40px -20px rgba(0,0,0,0.65)`,
  });
  const titleBar = (label: string, focused: boolean) => (
    <div
      className="flex h-[24px] shrink-0 items-center gap-[5px] px-2.5 text-[10.5px] font-medium"
      style={{ color: theme.foreground, borderBottom: hairline }}
    >
      {[p[1], p[3], p[2]].map((c, i) => (
        <span
          key={i}
          className="size-[7px] rounded-full"
          style={{
            background: focused ? c : `color-mix(in srgb, ${theme.foreground} 25%, transparent)`,
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
      <span style={{ color: p[2] }}>harry</span>
      <span style={{ opacity: 0.5 }}>@</span>
      <span style={{ color: p[4] }}>mac</span> <span style={{ color: p[5] }}>~</span>{" "}
      <span style={{ color: p[3] }}>$</span>
    </>
  );
  const ok = <span style={{ color: p[2] }}>ok</span>;

  return (
    <div className="@container relative h-[300px] overflow-hidden rounded-t-[9px] @[720px]:h-[340px]">
      <Wallpaper key={`${theme.id}-${wallpaper}`} theme={theme} file={wallpaper} />
      <div className="absolute inset-0 bg-[linear-gradient(90deg,rgba(0,0,0,0.3)_0%,rgba(0,0,0,0)_45%,rgba(0,0,0,0.3)_100%)]" />

      {/* SketchyBar */}
      <div
        className="absolute inset-x-0 top-0 flex h-[24px] items-center gap-1 px-3 font-mono text-[10.5px]"
        style={{ background: glass, color: theme.foreground }}
      >
        {[1, 2, 3, 4, 5].map((n) => (
          <span
            key={n}
            className="grid h-[16px] min-w-[18px] place-items-center rounded-[3px] px-1 font-semibold"
            style={
              n === 1 ? { background: theme.accent, color: theme.background } : { opacity: 0.55 }
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
          <span>Wed 21 Oct 18:02</span>
        </span>
      </div>

      {/* Two tiled windows */}
      <div
        className="absolute left-4 flex @[640px]:left-auto @[640px]:w-[60%]"
        style={{ top: 24 + gap * 2, right: gap * 2, bottom: gap * 2, gap }}
      >
        <div className="flex min-w-0 flex-[1.25] flex-col overflow-hidden" style={frame(true)}>
          {titleBar("ghostty", true)}
          <div
            className="min-h-0 flex-1 overflow-hidden px-3 py-2.5 font-mono text-[11px] leading-[1.65]"
            style={{ color: theme.foreground }}
          >
            <div className="truncate">
              {prompt} macarchy theme {theme.id}
            </div>
            <div style={{ color: p[6] }}>Applying {theme.name}</div>
            <div className="truncate">
              {ok} ghostty, nvim <span style={{ opacity: 0.6 }}>({theme.nvim})</span>
            </div>
            <div>{ok} borders, sketchybar</div>
            <div className="truncate">
              {ok} wallpaper <span style={{ opacity: 0.6 }}>{wallpaper}</span>
            </div>
            <div className="mt-2 flex gap-[3px]">
              {p.map((c, i) => (
                <span
                  key={i}
                  className="h-[12px] w-[20px] rounded-[2px]"
                  style={{ background: c }}
                />
              ))}
            </div>
            <div className="mt-2">
              {prompt}{" "}
              <span
                className="inline-block h-[12px] w-[7px] translate-y-[2px]"
                style={{ background: theme.accent }}
              />
            </div>
          </div>
        </div>

        <div
          className="hidden min-w-0 flex-1 flex-col overflow-hidden @[420px]:flex"
          style={frame(false)}
        >
          {titleBar(`nvim  ${theme.nvim}`, false)}
          <div className="flex min-h-0 flex-1 gap-2.5 overflow-hidden p-2.5 font-mono text-[10px] leading-[16px]">
            <div className="shrink-0 text-right" style={{ color: theme.foreground, opacity: 0.3 }}>
              {nvimCode.map((_, i) => (
                <div key={i}>{i + 1}</div>
              ))}
            </div>
            <div className="min-w-0 flex-1">
              {nvimCode.map(([indent, c1, w1, c2, w2], i) => (
                <div
                  key={i}
                  className="flex h-[16px] items-center gap-1.5"
                  style={{ paddingLeft: indent * 12, opacity: 0.7 }}
                >
                  <span
                    className="h-[5px] rounded-full"
                    style={{ background: p[c1], width: `${w1}%` }}
                  />
                  <span
                    className="h-[5px] rounded-full"
                    style={{ background: p[c2], width: `${w2}%` }}
                  />
                </div>
              ))}
            </div>
          </div>
          <div
            className="flex h-[18px] shrink-0 items-center gap-2 px-2.5 font-mono text-[9.5px]"
            style={{ borderTop: hairline, color: theme.foreground }}
          >
            <span
              className="rounded-[2px] px-1 font-semibold"
              style={{ background: p[4], color: theme.background }}
            >
              NORMAL
            </span>
            <span style={{ opacity: 0.5 }}>init.lua</span>
          </div>
        </div>
      </div>

      <span className="absolute bottom-4 left-4 hidden h-[22px] max-w-[34%] items-center gap-1.5 rounded-[6px] bg-black/40 px-2 text-[11.5px] text-white/85 ring-1 ring-white/10 backdrop-blur-md @[640px]:inline-flex">
        <ImageIcon size={11} className="shrink-0" />
        <span className="truncate">{wallpaperName(theme, wallpaper)}</span>
      </span>
    </div>
  );
}

/* ------------------------------------------------------------------ */
/* Charts                                                              */
/* ------------------------------------------------------------------ */

const clamp = (v: number, lo: number, hi: number) => Math.min(Math.max(v, lo), hi);

/** A bar standing on the baseline at y + h, rounded only at the top. */
function barUp(x: number, y: number, w: number, h: number) {
  const r = Math.min(4, w / 2, h);
  return `M${x},${y + h}V${y + r}Q${x},${y} ${x + r},${y}H${x + w - r}Q${x + w},${y} ${x + w},${y + r}V${y + h}Z`;
}

/** A bar growing right from x, rounded only at its end. */
function barRight(x: number, y: number, w: number, h: number) {
  const r = Math.min(4, h / 2, w);
  return `M${x},${y}H${x + w - r}Q${x + w},${y} ${x + w},${y + r}V${y + h - r}Q${x + w},${y + h} ${x + w - r},${y + h}H${x}Z`;
}

const axisText: CSSProperties = {
  fill: "var(--st-fg3)",
  fontSize: 10.5,
  fontVariantNumeric: "tabular-nums",
};

/** Hover card for a chart mark, kept inside the chart's bounds. */
function ChartTooltip({
  x,
  y,
  width,
  height,
  side,
  children,
}: {
  x: number;
  y: number;
  width: number;
  height: number;
  /** Sit beside the mark, this far from x, instead of above it. */
  side?: number;
  children: ReactNode;
}) {
  const ref = useRef<HTMLDivElement>(null);
  const [size, setSize] = useState({ w: 0, h: 0 });
  useLayoutEffect(() => {
    const el = ref.current;
    if (!el) return;
    const w = el.offsetWidth;
    const h = el.offsetHeight;
    setSize((s) => (s.w === w && s.h === h ? s : { w, h }));
  });
  const maxLeft = Math.max(0, width - size.w);
  const maxTop = Math.max(0, height - size.h);
  const above = y - size.h - 10;
  const left =
    side === undefined
      ? clamp(x - size.w / 2, 0, maxLeft)
      : x + side + size.w <= width
        ? x + side
        : clamp(x - side - size.w, 0, maxLeft);
  const top =
    side === undefined
      ? above >= 0
        ? above
        : clamp(y + 12, 0, maxTop)
      : clamp(y - size.h / 2, 0, maxTop);
  return (
    <div
      ref={ref}
      className="pointer-events-none absolute z-10 rounded-[8px] border border-[var(--st-border)] bg-[var(--st-bg)] px-2.5 py-1.5 text-[12px] whitespace-nowrap text-[var(--st-fg)] shadow-[0_8px_24px_-8px_rgba(0,0,0,0.3),0_1px_2px_rgba(0,0,0,0.06)]"
      style={{ left, top, visibility: size.w ? "visible" : "hidden" }}
    >
      {children}
    </div>
  );
}

function TipTitle({ children }: { children: ReactNode }) {
  return <div className="text-[11px] text-[var(--st-fg3)]">{children}</div>;
}

function TipValue({ children }: { children: ReactNode }) {
  return <div className="font-medium tabular-nums">{children}</div>;
}

function TipNote({ children }: { children: ReactNode }) {
  return <div className="text-[11.5px] text-[var(--st-fg2)]">{children}</div>;
}

/** A card title on one line with its action, for headers without a description. */
function CardTitle({ title, action }: { title: string; action?: ReactNode }) {
  return (
    <header className="flex items-center justify-between gap-3 px-5 pt-4 pb-3">
      <h2 className="text-[14px] font-semibold tracking-[-0.01em] text-[var(--st-fg)]">{title}</h2>
      {action}
    </header>
  );
}

function ChartCard({
  title,
  description,
  action,
  className,
  children,
}: {
  title: string;
  description?: string;
  action?: ReactNode;
  className?: string;
  children: ReactNode;
}) {
  return (
    <Card className={className}>
      <CardHeader title={title} description={description} action={action} />
      <div className="px-5 pb-4">{children}</div>
    </Card>
  );
}

/* Deterministic mock data */

function seeded(seed: number) {
  let s = seed;
  return () => {
    s = (s * 1664525 + 1013904223) % 4294967296;
    return s / 4294967296;
  };
}

const weekdays = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
const months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
const last30 = Array.from({ length: 30 }, (_, i) => {
  const d = new Date(Date.UTC(2026, 9, 21 - 29 + i));
  const short = `${d.getUTCDate()} ${months[d.getUTCMonth()]}`;
  return { long: `${weekdays[d.getUTCDay()]} ${short}`, short, weekend: d.getUTCDay() % 6 === 0 };
});

const rand = seeded(783);
const serviceLoad = last30.map((d, i) => ({
  cpu: Math.round((1.7 + 0.5 * Math.sin(i / 3.2) + rand() * 0.9 - (d.weekend ? 0.7 : 0)) * 10) / 10,
  memory: Math.round(188 + i * 1.1 + 12 * Math.sin(i / 4.5) + rand() * 14 - (d.weekend ? 10 : 0)),
}));

const workspaceWindows = [
  { ws: 1, windows: 4, apps: "Ghostty, Zed, Safari, Notes" },
  { ws: 2, windows: 3, apps: "Safari, Slack, Mail" },
  { ws: 3, windows: 2, apps: "Figma, Preview" },
  { ws: 4, windows: 5, apps: "Ghostty (3), TablePlus, Docker" },
  { ws: 5, windows: 1, apps: "Spotify" },
  { ws: 6, windows: 0, apps: "" },
  { ws: 7, windows: 2, apps: "Messages, FaceTime" },
  { ws: 8, windows: 0, apps: "" },
  { ws: 9, windows: 1, apps: "Activity Monitor" },
];
const windowTotal = workspaceWindows.reduce((a, w) => a + w.windows, 0);

const focusTime = [
  { app: "Ghostty", minutes: 680, sessions: 41, ws: 1 },
  { app: "Zed", minutes: 485, sessions: 23, ws: 1 },
  { app: "Safari", minutes: 370, sessions: 58, ws: 2 },
  { app: "Slack", minutes: 165, sessions: 74, ws: 2 },
  { app: "Figma", minutes: 110, sessions: 9, ws: 3 },
  { app: "Notes", minutes: 55, sessions: 17, ws: 1 },
];
const focusTotal = focusTime.reduce((a, f) => a + f.minutes, 0);
const hm = (m: number) =>
  m >= 60 ? `${Math.floor(m / 60)}h ${String(m % 60).padStart(2, "0")}m` : `${m}m`;

const themeChangeLog: Record<number, string[]> = {
  2: ["Carbonfox"],
  5: ["Midnight", "Lumon"],
  9: ["Turbonite"],
  13: ["Awakening", "City 783", "Black Gold"],
  14: ["Midnight"],
  19: ["Lumon"],
  23: ["Carbonfox", "Turbonite"],
  26: ["Midnight"],
  29: [current.name],
};
const themeChanges = last30.map((d, i) => ({ ...d, themes: themeChangeLog[i] ?? [] }));
const themeChangeTotal = themeChanges.reduce((a, d) => a + d.themes.length, 0);
const mostApplied = (() => {
  const counts = new Map<string, number>();
  for (const d of themeChanges) for (const t of d.themes) counts.set(t, (counts.get(t) ?? 0) + 1);
  return [...counts].sort((a, b) => b[1] - a[1])[0]?.[0] ?? current.name;
})();

/* Windows per workspace */

function WorkspaceChart() {
  const [ref, width] = useWidth<HTMLDivElement>(320);
  const [hover, setHover] = useState<number | null>(null);
  const H = 176;
  const T = 10;
  const B = 22;
  const L = 22;
  const plotW = Math.max(width - L, 1);
  const plotH = H - T - B;
  const max = 6;
  const base = T + plotH;
  const y = (v: number) => base - (v / max) * plotH;
  const slot = plotW / workspaceWindows.length;
  const barW = clamp(slot - 2, 4, 22);
  const h = hover === null ? null : workspaceWindows[hover];

  return (
    <div ref={ref} className="relative" onMouseLeave={() => setHover(null)}>
      <svg
        width={width}
        height={H}
        role="img"
        aria-label="Bar chart of open windows on workspaces 1 to 9"
        className="block"
      >
        {[0, 2, 4, 6].map((t) => (
          <g key={t}>
            <line
              x1={L}
              x2={width}
              y1={y(t)}
              y2={y(t)}
              style={{ stroke: "var(--st-border)" }}
              strokeDasharray={t === 0 ? undefined : "2 3"}
            />
            <text x={L - 8} y={y(t)} dy="0.32em" textAnchor="end" style={axisText}>
              {t}
            </text>
          </g>
        ))}
        {workspaceWindows.map((d, i) => {
          const mid = L + slot * i + slot / 2;
          const on = hover === i;
          const dim = hover !== null && !on;
          return (
            <g key={d.ws}>
              {on ? (
                <rect
                  x={L + slot * i + 1}
                  y={T}
                  width={slot - 2}
                  height={plotH}
                  rx={4}
                  style={{ fill: "var(--st-hover)" }}
                />
              ) : null}
              {d.windows > 0 ? (
                <path
                  d={barUp(mid - barW / 2, y(d.windows), barW, base - y(d.windows))}
                  style={{ fill: "var(--st-accent)", opacity: dim ? 0.4 : 1 }}
                  className="transition-opacity duration-150"
                />
              ) : (
                <rect
                  x={mid - barW / 2}
                  y={base - 2}
                  width={barW}
                  height={2}
                  rx={1}
                  style={{ fill: "var(--st-border-strong)" }}
                />
              )}
              <text
                x={mid}
                y={H - 6}
                textAnchor="middle"
                style={{ ...axisText, fill: on ? "var(--st-fg)" : "var(--st-fg3)" }}
              >
                {d.ws}
              </text>
              <rect
                x={L + slot * i}
                y={0}
                width={slot}
                height={H}
                fill="transparent"
                onMouseEnter={() => setHover(i)}
              />
            </g>
          );
        })}
      </svg>
      {h && hover !== null ? (
        <ChartTooltip x={L + slot * hover + slot / 2} y={y(h.windows)} width={width} height={H}>
          <TipTitle>Workspace {h.ws}</TipTitle>
          <TipValue>
            {h.windows === 0 ? "No windows" : `${h.windows} window${h.windows === 1 ? "" : "s"}`}
          </TipValue>
          {h.apps ? <TipNote>{h.apps}</TipNote> : null}
        </ChartTooltip>
      ) : null}
    </div>
  );
}

/* Focus time by app */

function FocusChart() {
  const [ref, width] = useWidth<HTMLDivElement>(320);
  const [hover, setHover] = useState<number | null>(null);
  const rowH = 29;
  const barH = 10;
  const labelW = 64;
  const valueW = 60;
  const H = rowH * focusTime.length;
  const maxW = Math.max(width - labelW - valueW, 1);
  const top = focusTime[0]!.minutes;
  const h = hover === null ? null : focusTime[hover];

  return (
    <div ref={ref} className="relative" onMouseLeave={() => setHover(null)}>
      <svg
        width={width}
        height={H}
        role="img"
        aria-label="Horizontal bar chart of focus time by app this week"
        className="block"
      >
        {focusTime.map((f, i) => {
          const mid = rowH * i + rowH / 2;
          const w = Math.max((f.minutes / top) * maxW, 2);
          const on = hover === i;
          const dim = hover !== null && !on;
          return (
            <g key={f.app}>
              {on ? (
                <rect
                  x={0}
                  y={rowH * i + 1}
                  width={width}
                  height={rowH - 2}
                  rx={5}
                  style={{ fill: "var(--st-hover)" }}
                />
              ) : null}
              <text
                x={6}
                y={mid}
                dy="0.32em"
                style={{ fontSize: 12, fill: on ? "var(--st-fg)" : "var(--st-fg2)" }}
              >
                {f.app}
              </text>
              <path
                d={barRight(labelW, mid - barH / 2, w, barH)}
                style={{ fill: "var(--st-accent)", opacity: dim ? 0.4 : 1 }}
                className="transition-opacity duration-150"
              />
              <text
                x={labelW + w + 8}
                y={mid}
                dy="0.32em"
                style={{ ...axisText, fontSize: 11, fill: on ? "var(--st-fg)" : "var(--st-fg2)" }}
              >
                {hm(f.minutes)}
              </text>
              <rect
                x={0}
                y={rowH * i}
                width={width}
                height={rowH}
                fill="transparent"
                onMouseEnter={() => setHover(i)}
              />
            </g>
          );
        })}
      </svg>
      {h && hover !== null ? (
        <ChartTooltip
          x={labelW + (h.minutes / top) * maxW}
          y={rowH * hover + rowH / 2 - barH / 2}
          width={width}
          height={H}
        >
          <TipTitle>{h.app}</TipTitle>
          <TipValue>
            {hm(h.minutes)}, {Math.round((h.minutes / focusTotal) * 100)}% of the week
          </TipValue>
          <TipNote>
            {h.sessions} sessions, mostly on workspace {h.ws}
          </TipNote>
        </ChartTooltip>
      ) : null}
    </div>
  );
}

/* Service load */

type Metric = "CPU" | "Memory";

function ServicesChart({ metric }: { metric: Metric }) {
  const [ref, width] = useWidth<HTMLDivElement>(640);
  const [hover, setHover] = useState<number | null>(null);
  const fillId = `st-area-${useId().replace(/[^\w-]/g, "")}`;
  const cpu = metric === "CPU";
  const values = serviceLoad.map((d) => (cpu ? d.cpu : d.memory));
  const step = cpu ? 1 : 100;
  const max = Math.ceil(Math.max(...values) / step) * step;
  const ticks = Array.from({ length: max / step + 1 }, (_, i) => i * step);
  const H = 188;
  const T = 12;
  const B = 22;
  const L = 46;
  const R = 6;
  const plotW = Math.max(width - L - R, 1);
  const plotH = H - T - B;
  const base = T + plotH;
  const n = values.length;
  const x = (i: number) => L + (i / (n - 1)) * plotW;
  const y = (v: number) => base - (v / max) * plotH;
  const line = values.map((v, i) => `${i ? "L" : "M"}${x(i)},${y(v)}`).join("");
  const area = `${line}L${x(n - 1)},${base}L${x(0)},${base}Z`;
  const v = hover === null ? undefined : values[hover];
  const onMove = (e: ReactMouseEvent<SVGSVGElement>) => {
    const mx = e.clientX - e.currentTarget.getBoundingClientRect().left;
    setHover(clamp(Math.round(((mx - L) / plotW) * (n - 1)), 0, n - 1));
  };

  return (
    <div ref={ref} className="relative">
      <svg
        width={width}
        height={H}
        role="img"
        aria-label={`Area chart of daily ${cpu ? "CPU" : "memory"} use by Macarchy services over 30 days`}
        className="block"
        onMouseMove={onMove}
        onMouseLeave={() => setHover(null)}
      >
        <defs>
          <linearGradient id={fillId} x1="0" x2="0" y1="0" y2="1">
            <stop offset="0%" style={{ stopColor: "var(--st-accent)", stopOpacity: 0.22 }} />
            <stop offset="100%" style={{ stopColor: "var(--st-accent)", stopOpacity: 0 }} />
          </linearGradient>
        </defs>
        {ticks.map((t) => (
          <g key={t}>
            <line
              x1={L}
              x2={width - R}
              y1={y(t)}
              y2={y(t)}
              style={{ stroke: "var(--st-border)" }}
              strokeDasharray={t === 0 ? undefined : "2 3"}
            />
            <text x={L - 8} y={y(t)} dy="0.32em" textAnchor="end" style={axisText}>
              {cpu ? `${t}%` : `${t} MB`}
            </text>
          </g>
        ))}
        {[0, 7, 14, 21, 29].map((i) => (
          <text
            key={i}
            x={x(i)}
            y={H - 6}
            textAnchor={i === 0 ? "start" : i === n - 1 ? "end" : "middle"}
            style={axisText}
          >
            {i === n - 1 ? "Today" : last30[i]!.short}
          </text>
        ))}
        <path d={area} fill={`url(#${fillId})`} />
        <path
          d={line}
          fill="none"
          strokeWidth={2}
          strokeLinejoin="round"
          strokeLinecap="round"
          style={{ stroke: "var(--st-accent)" }}
        />
        {hover !== null && v !== undefined ? (
          <g pointerEvents="none">
            <line
              x1={x(hover)}
              x2={x(hover)}
              y1={T}
              y2={base}
              strokeWidth={1}
              style={{ stroke: "var(--st-border-strong)" }}
            />
            <circle
              cx={x(hover)}
              cy={y(v)}
              r={4}
              strokeWidth={2}
              style={{ fill: "var(--st-accent)", stroke: "var(--st-bg)" }}
            />
          </g>
        ) : null}
      </svg>
      {hover !== null && v !== undefined ? (
        <ChartTooltip x={x(hover)} y={y(v)} width={width} height={H}>
          <TipTitle>
            {hover === n - 1 ? `Today, ${last30[hover]!.short}` : last30[hover]!.long}
          </TipTitle>
          <TipValue>{cpu ? `${v.toFixed(1)}% CPU` : `${v} MB memory`}</TipValue>
        </ChartTooltip>
      ) : null}
    </div>
  );
}

function ServicesCard({ className }: { className?: string }) {
  const [metric, setMetric] = useState<Metric>("CPU");
  const values = serviceLoad.map((d) => (metric === "CPU" ? d.cpu : d.memory));
  const avg = values.reduce((a, b) => a + b, 0) / values.length;
  return (
    <ChartCard
      className={className}
      title="CPU and memory of Macarchy services"
      description={`${metric === "CPU" ? `${avg.toFixed(1)}%` : `${Math.round(avg)} MB`} daily average, 30 days`}
      action={
        <Segmented
          size="sm"
          options={["CPU", "Memory"] as const}
          value={metric}
          onChange={setMetric}
        />
      }
    >
      <ServicesChart metric={metric} />
    </ChartCard>
  );
}

/* Theme changes */

const changeFill = (count: number) =>
  count === 0
    ? "var(--st-muted)"
    : `color-mix(in srgb, var(--st-accent) ${[0, 40, 70, 100][Math.min(count, 3)]}%, var(--st-bg))`;

function ThemeChangesChart() {
  const [ref, width] = useWidth<HTMLDivElement>(640);
  const [hover, setHover] = useState<number | null>(null);
  const n = themeChanges.length;
  const gap = 3;
  const cellW = Math.max((width - gap * (n - 1)) / n, 2);
  const cellH = 40;
  const H = cellH + 22;
  const x = (i: number) => i * (cellW + gap);
  const d = hover === null ? null : themeChanges[hover];

  return (
    <div ref={ref} className="relative" onMouseLeave={() => setHover(null)}>
      <svg
        width={width}
        height={H}
        role="img"
        aria-label="Theme changes per day over the last 30 days"
        className="block"
      >
        {themeChanges.map((c, i) => {
          const on = hover === i;
          const dim = hover !== null && !on;
          return (
            <g key={c.long}>
              <rect
                x={x(i) + (on ? 0.75 : 0)}
                y={on ? 0.75 : 0}
                width={cellW - (on ? 1.5 : 0)}
                height={cellH - (on ? 1.5 : 0)}
                rx={4}
                strokeWidth={on ? 1.5 : 0}
                style={{
                  fill: changeFill(c.themes.length),
                  stroke: "var(--st-fg2)",
                  opacity: dim ? 0.55 : 1,
                }}
                className="transition-opacity duration-150"
              />
              <rect
                x={x(i) - gap / 2}
                y={0}
                width={cellW + gap}
                height={H}
                fill="transparent"
                onMouseEnter={() => setHover(i)}
              />
            </g>
          );
        })}
        <text x={0} y={H - 6} style={axisText}>
          {themeChanges[0]!.short}
        </text>
        <text x={width} y={H - 6} textAnchor="end" style={axisText}>
          Today
        </text>
      </svg>
      {d && hover !== null ? (
        <ChartTooltip
          x={x(hover) + cellW / 2}
          y={cellH / 2}
          side={cellW / 2 + 8}
          width={width}
          height={H}
        >
          <TipTitle>{hover === n - 1 ? `Today, ${d.short}` : d.long}</TipTitle>
          <TipValue>
            {d.themes.length === 0
              ? "No changes"
              : `${d.themes.length} change${d.themes.length === 1 ? "" : "s"}`}
          </TipValue>
          {d.themes.length ? <TipNote>{d.themes.join(", ")}</TipNote> : null}
        </ChartTooltip>
      ) : null}
    </div>
  );
}

function ChangeScale() {
  return (
    <span className="flex items-center gap-1.5 text-[11px] text-[var(--st-fg3)]">
      Fewer
      {[0, 1, 2, 3].map((c) => (
        <span key={c} className="size-2.5 rounded-[3px]" style={{ background: changeFill(c) }} />
      ))}
      More
    </span>
  );
}

/* ------------------------------------------------------------------ */
/* Home                                                                */
/* ------------------------------------------------------------------ */

const barItems = snapshot.barItems.filter((i) => i.visible);

const activity: { when: string; text: string; detail?: string }[] = [
  { when: "2h ago", text: `Applied ${current.name}` },
  { when: "2h ago", text: "Wallpaper changed", detail: wallpaperName(current, current.wallpaper) },
  { when: "Yesterday", text: "Border width set to 7px", detail: "Square corners" },
  { when: "Yesterday", text: "TablePlus now floats" },
  { when: "Mon", text: "Menu bar reloaded" },
];

function IntegrationRow({
  icon,
  name,
  summary,
  on,
  onToggle,
  children,
  onOpen,
  last,
}: {
  icon: ReactNode;
  name: string;
  summary: ReactNode;
  on?: boolean;
  onToggle?: (v: boolean) => void;
  children?: ReactNode;
  onOpen: () => void;
  last?: boolean;
}) {
  const off = on === false;
  return (
    <div
      className={cx(
        "flex items-start gap-3.5 px-5 py-3.5",
        !last && "border-b border-[var(--st-border)]",
      )}
    >
      <div
        className={cx(
          "mt-0.5 grid size-8 shrink-0 place-items-center rounded-[8px] border border-[var(--st-border)] bg-[var(--st-side)] text-[var(--st-fg2)]",
          off && "opacity-50",
        )}
      >
        {icon}
      </div>
      <div className={cx("min-w-0 flex-1 transition-opacity", off && "opacity-50")}>
        <div className="flex items-center gap-2">
          <span className="text-[13.5px] font-medium text-[var(--st-fg)]">{name}</span>
          {on === undefined ? null : on ? (
            <Badge tone="ok" dot>
              Running
            </Badge>
          ) : (
            <Badge>Off</Badge>
          )}
        </div>
        <div className="mt-0.5 text-[12.5px] text-[var(--st-fg2)]">{summary}</div>
        {children && !off ? <div className="mt-2 flex flex-wrap gap-1.5">{children}</div> : null}
      </div>
      <div className="flex shrink-0 items-center gap-2 pt-0.5">
        {onToggle ? <Switch label={`${name} enabled`} checked={!!on} onChange={onToggle} /> : null}
        <Button size="sm" variant="ghost" onClick={onOpen}>
          Open <ChevronRight size={13} />
        </Button>
      </div>
    </div>
  );
}

export function HomePage({ go }: { go: Go }) {
  const theme = current;
  const [wallpaper, setWallpaper] = useState(theme.wallpaper);
  const [aero, setAero] = useState(true);
  const [bar, setBar] = useState(true);
  const [borders, setBorders] = useState(snapshot.borders.borders_visible);
  const [follow, setFollow] = useState(true);
  const l = snapshot.layout;
  const b = snapshot.borders;
  const nextWallpaper = () => {
    const i = theme.wallpapers.indexOf(wallpaper);
    setWallpaper(theme.wallpapers[(i + 1) % theme.wallpapers.length]!);
  };

  return (
    <>
      <PageHeader title="Home" />

      {/* Current theme */}
      <section className="@container relative mb-6 h-[208px] overflow-hidden rounded-[12px] border border-[var(--st-border)] shadow-[var(--st-shadow)]">
        <Wallpaper key={wallpaper} theme={theme} file={wallpaper} />
        <div className="absolute inset-0 bg-[linear-gradient(90deg,rgba(0,0,0,0.7)_0%,rgba(0,0,0,0.38)_50%,rgba(0,0,0,0.12)_100%)]" />
        <div className="absolute inset-x-0 bottom-0 h-2/3 bg-gradient-to-t from-black/55 to-transparent" />

        <div className="relative flex h-full flex-col justify-between p-5 text-white">
          <div className="flex items-center justify-between gap-3">
            <span className="text-[11px] font-semibold tracking-[0.06em] text-white/60 uppercase">
              Current theme
            </span>
            <span className="inline-flex h-[22px] min-w-0 items-center gap-1.5 rounded-[6px] bg-black/35 px-2 text-[11.5px] text-white/80 ring-1 ring-white/10 backdrop-blur-md">
              <ImageIcon size={11} className="shrink-0" />
              <span className="truncate">{wallpaperName(theme, wallpaper)}</span>
              <span className="text-white/45 tabular-nums">
                {theme.wallpapers.indexOf(wallpaper) + 1}/{theme.wallpapers.length}
              </span>
            </span>
          </div>

          <div className="flex flex-wrap items-end justify-between gap-x-6 gap-y-3">
            <div className="min-w-0">
              <div className="flex items-center gap-2.5">
                <h2 className="truncate text-[28px] leading-none font-semibold tracking-[-0.025em] drop-shadow-sm">
                  {theme.name}
                </h2>
                <span className="inline-flex h-[21px] shrink-0 items-center gap-1 rounded-[6px] bg-white/12 px-1.5 text-[11px] font-medium text-white/85 ring-1 ring-white/15 backdrop-blur-md">
                  <Moon size={10} /> {theme.dark ? "Dark" : "Light"}
                </span>
              </div>
              <div className="mt-3 flex items-center gap-3 text-[12px] text-white/75">
                <span className="flex items-center -space-x-[3px]" aria-label="Terminal palette">
                  {theme.palette.map((c, i) => (
                    <span
                      key={i}
                      title={c}
                      className="size-3 rounded-full ring-[1.5px] ring-black/50"
                      style={{ background: c }}
                    />
                  ))}
                </span>
                <span className="h-3 w-px bg-white/20" />
                <span className="flex items-center gap-1.5 font-mono text-[11.5px]">
                  <span
                    className="size-2.5 rounded-full ring-1 ring-white/30"
                    style={{ background: theme.accent }}
                  />
                  {theme.accent}
                </span>
                <span className="h-3 w-px bg-white/20" />
                <span className="truncate">Neovim {theme.nvim}</span>
              </div>
            </div>

            <div className="flex shrink-0 items-center gap-2">
              <button
                type="button"
                onClick={nextWallpaper}
                className={cx(
                  "inline-flex h-8 items-center gap-1.5 rounded-[7px] bg-white/10 px-3 text-[12.5px] font-medium text-white ring-1 ring-white/20 backdrop-blur-md transition-colors hover:bg-white/20 active:translate-y-px",
                  focusRing,
                )}
              >
                <Shuffle size={13} /> Next wallpaper
              </button>
              <button
                type="button"
                onClick={() => go("themes")}
                className={cx(
                  "inline-flex h-8 items-center gap-1.5 rounded-[7px] bg-white px-3 text-[12.5px] font-medium text-zinc-900 shadow-[0_1px_2px_rgba(0,0,0,0.3)] transition-opacity hover:opacity-90 active:translate-y-px",
                  focusRing,
                )}
              >
                Change theme <ArrowRight size={13} />
              </button>
            </div>
          </div>
        </div>
      </section>

      {/* Enabled */}
      <SectionLabel>Enabled</SectionLabel>
      <Card className="mb-6">
        <IntegrationRow
          icon={<LayoutPanelLeft size={15} />}
          name="AeroSpace"
          on={aero}
          onToggle={setAero}
          onOpen={() => go("layout")}
          summary={`${l.layout.toUpperCase()} layout, ${l.window_gap}px gaps, mouse follows focus ${l.mouse_follows_focus ? "on" : "off"}`}
        />
        <IntegrationRow
          icon={<PanelTop size={15} />}
          name="SketchyBar"
          on={bar}
          onToggle={setBar}
          onOpen={() => go("menuBar")}
          summary={`At the ${snapshot.menuBar.position}, ${snapshot.menuBar.height}px tall, ${barItems.length} items`}
        />
        <IntegrationRow
          icon={<SquareDashed size={15} />}
          name="JankyBorders"
          on={borders}
          onToggle={setBorders}
          onOpen={() => go("borders")}
          summary={
            <span className="inline-flex items-center gap-1.5">
              {b.border_width}px {b.border_style},
              <span
                className="size-2.5 rounded-full ring-1 ring-black/15"
                style={{ background: theme.accent }}
              />
              <span className="font-mono text-[11.5px]">{theme.accent}</span>
            </span>
          }
        />
        <IntegrationRow
          icon={<AppWindow size={15} />}
          name="Floating apps"
          onOpen={() => go("rules")}
          summary={`${snapshot.floatingApps.length} apps: ${snapshot.floatingApps.join(", ")}`}
        />
        <IntegrationRow
          icon={<SquareTerminal size={15} />}
          name="Ghostty and Neovim"
          onOpen={() => go("themes")}
          onToggle={setFollow}
          on={follow}
          last
          summary={`${theme.name} in Ghostty, ${theme.nvim} in Neovim`}
        />
      </Card>

      {/* Activity */}
      <SectionLabel
        action={
          <Button size="sm" variant="ghost">
            <History size={12} /> View all
          </Button>
        }
      >
        Recent activity
      </SectionLabel>
      <Card className="mb-6">
        <ul>
          {activity.map((a, i) => (
            <li
              key={i}
              className={cx(
                "group flex items-center gap-3 px-5 py-2.5 text-[12.5px]",
                i < activity.length - 1 && "border-b border-[var(--st-border)]",
              )}
            >
              <span className="w-[68px] shrink-0 text-[var(--st-fg3)] tabular-nums">{a.when}</span>
              <span className="font-medium text-[var(--st-fg)]">{a.text}</span>
              <span className="min-w-0 flex-1 truncate text-[var(--st-fg2)]">{a.detail ?? ""}</span>
              {i === 0 ? (
                <Button
                  size="sm"
                  variant="ghost"
                  className="opacity-0 group-hover:opacity-100 focus-visible:opacity-100"
                >
                  <Undo2 size={12} /> Undo
                </Button>
              ) : null}
            </li>
          ))}
        </ul>
      </Card>

      {/* Insights */}
      <SectionLabel>Insights</SectionLabel>
      <div className="@container">
        <div className="grid grid-cols-1 gap-4 @[680px]:grid-cols-2">
          <ChartCard title="Windows per workspace" description={`${windowTotal} open`}>
            <WorkspaceChart />
          </ChartCard>
          <ChartCard title="Focus time by app this week" description={`${hm(focusTotal)} total`}>
            <FocusChart />
          </ChartCard>
          <ServicesCard className="@[680px]:col-span-2" />
          <ChartCard
            className="@[680px]:col-span-2"
            title="Theme changes over the last 30 days"
            description={`${themeChangeTotal} changes, ${mostApplied} applied most often`}
            action={<ChangeScale />}
          >
            <ThemeChangesChart />
          </ChartCard>
        </div>
      </div>
    </>
  );
}

/* ------------------------------------------------------------------ */
/* Themes                                                              */
/* ------------------------------------------------------------------ */

/** The terminal palette as overlapping dots, then the accent on its own. */
function PaletteDots({ theme }: { theme: RealTheme }) {
  return (
    <span className="flex shrink-0 items-center gap-2" aria-hidden>
      <span className="flex items-center -space-x-[3px]">
        {theme.palette.slice(1).map((c, i) => (
          <span
            key={i}
            className="size-[11px] rounded-full ring-[1.5px] ring-[var(--st-bg)]"
            style={{ background: c }}
          />
        ))}
      </span>
      <span className="h-3 w-px bg-[var(--st-border-strong)]" />
      <span
        className="size-[11px] rounded-full ring-1 ring-black/15"
        style={{ background: theme.accent }}
      />
    </span>
  );
}

/** A large wallpaper card in the theme gallery. */
function ThemeCard({
  theme,
  wallpaper,
  applied,
  onOpen,
  onApply,
}: {
  theme: RealTheme;
  wallpaper: string;
  applied: boolean;
  onOpen: () => void;
  onApply: () => void;
}) {
  return (
    <div className="group">
      <div
        className={cx(
          "relative aspect-[16/10] overflow-hidden rounded-[10px] transition-[transform,box-shadow] duration-200 ease-out group-hover:-translate-y-0.5",
          applied
            ? "shadow-[0_0_0_2px_var(--st-bg),0_0_0_4px_var(--st-accent)] group-hover:shadow-[0_0_0_2px_var(--st-bg),0_0_0_4px_var(--st-accent),0_18px_36px_-18px_rgba(0,0,0,0.5)]"
            : "shadow-[var(--st-shadow)] ring-1 ring-[var(--st-border)] group-hover:shadow-[0_18px_36px_-18px_rgba(0,0,0,0.5)]",
        )}
      >
        <Wallpaper
          theme={theme}
          file={wallpaper}
          className="transition-transform duration-500 ease-out group-hover:scale-[1.04]"
        />
        <div className="pointer-events-none absolute inset-0 bg-gradient-to-t from-black/55 via-black/0 to-black/0 opacity-0 transition-opacity duration-200 group-focus-within:opacity-100 group-hover:opacity-100" />
        <button
          type="button"
          onClick={onOpen}
          aria-label={`View ${theme.name}`}
          className="absolute inset-0 rounded-[10px] outline-none focus-visible:ring-2 focus-visible:ring-[var(--st-accent)] focus-visible:ring-inset"
        />
        {applied ? (
          <span className="pointer-events-none absolute top-2.5 left-2.5 inline-flex h-[22px] items-center gap-1 rounded-[6px] bg-black/55 px-2 text-[11px] font-medium text-white ring-1 ring-white/15 backdrop-blur-md">
            <Check size={11} /> Current
          </span>
        ) : null}
        <div className="pointer-events-none absolute inset-x-2.5 bottom-2.5 flex translate-y-1 items-center justify-between gap-2 opacity-0 transition-[opacity,transform] duration-200 group-focus-within:translate-y-0 group-focus-within:opacity-100 group-hover:translate-y-0 group-hover:opacity-100">
          <span className="truncate text-[11.5px] font-medium text-white/85">View details</span>
          {applied ? null : (
            <button
              type="button"
              onClick={onApply}
              className={cx(
                "pointer-events-auto inline-flex h-7 shrink-0 items-center gap-1.5 rounded-[7px] bg-white px-2.5 text-[12px] font-medium text-zinc-900 shadow-[0_1px_2px_rgba(0,0,0,0.3)] transition-opacity hover:opacity-90 active:translate-y-px",
                focusRing,
              )}
            >
              Apply
            </button>
          )}
        </div>
      </div>
      <div className="mt-3 flex items-center justify-between gap-3 px-0.5">
        <span className="min-w-0 truncate text-[13.5px] font-medium text-[var(--st-fg)]">
          {theme.name}
        </span>
        <PaletteDots theme={theme} />
      </div>
      <div className="mt-0.5 truncate px-0.5 text-[12px] text-[var(--st-fg3)]">
        Neovim {theme.nvim}, {theme.wallpapers.length} wallpaper
        {theme.wallpapers.length === 1 ? "" : "s"}
      </div>
    </div>
  );
}

/** A palette chip that shows its hex value on hover or focus. */
function PaletteSwatch({ colour, index, count }: { colour: string; index: number; count: number }) {
  return (
    <span
      tabIndex={0}
      aria-label={`Colour ${index}, ${colour}`}
      className="group relative size-[20px] shrink-0 rounded-[5px] ring-1 ring-black/15 outline-none ring-inset transition-transform duration-150 hover:-translate-y-px focus-visible:ring-2 focus-visible:ring-[var(--st-accent)]"
      style={{ background: colour }}
    >
      <span
        className={cx(
          "pointer-events-none absolute bottom-full z-10 mb-1.5 rounded-[6px] border border-[var(--st-border)] bg-[var(--st-bg)] px-1.5 py-0.5 font-mono text-[10.5px] whitespace-nowrap text-[var(--st-fg)] opacity-0 shadow-[0_6px_16px_-6px_rgba(0,0,0,0.3)] transition-opacity group-hover:opacity-100 group-focus-visible:opacity-100",
          index < 2 ? "left-0" : index >= count - 2 ? "right-0" : "left-1/2 -translate-x-1/2",
        )}
      >
        {colour}
      </span>
    </span>
  );
}

function DetailCell({ label, children }: { label: string; children: ReactNode }) {
  return (
    <div className="min-w-0 bg-[var(--st-bg)] px-5 py-3">
      <dt className="text-[11.5px] text-[var(--st-fg3)]">{label}</dt>
      <dd className="mt-1.5 flex min-h-[20px] items-center gap-2 font-mono text-[12px] text-[var(--st-fg)]">
        {children}
      </dd>
    </div>
  );
}

function HexValue({ colour }: { colour: string }) {
  return (
    <>
      <span
        className="size-3.5 shrink-0 rounded-[4px] ring-1 ring-black/15 ring-inset"
        style={{ background: colour }}
      />
      {colour}
    </>
  );
}

export function ThemesPage({ go }: { go?: Go } = {}) {
  const [openId, setOpenId] = useState<string | null>(null);
  const [appliedId, setAppliedId] = useState(currentThemeId);
  const [walls, setWalls] = useState<Record<string, string>>(() =>
    Object.fromEntries(realThemes.map((t) => [t.id, t.wallpaper])),
  );
  const [appliedWall, setAppliedWall] = useState(current.wallpaper);
  const wallOf = (t: RealTheme) => walls[t.id] ?? t.wallpaper;
  const apply = (t: RealTheme) => {
    setAppliedId(t.id);
    setAppliedWall(wallOf(t));
  };
  const workshop = (size: "sm" | "md") => (
    <Button variant="ghost" size={size} onClick={() => go?.("workshop")}>
      Browse more in Workshop <ArrowRight size={13} />
    </Button>
  );

  if (openId === null) {
    return (
      <>
        <PageHeader title="Themes" />
        <SectionLabel
          action={
            <button
              type="button"
              onClick={() => go?.("workshop")}
              className={cx(
                "group inline-flex items-center gap-[4px] rounded-[5px] text-[12px] font-medium text-[var(--st-fg2)] transition-colors hover:text-[var(--st-fg)]",
                focusRing,
              )}
            >
              Browse more in Workshop
              <ArrowRight
                size={12}
                className="transition-transform duration-150 group-hover:translate-x-[2px]"
              />
            </button>
          }
        >
          Installed · {realThemes.length}
        </SectionLabel>
        <div className="@container">
          <div className="grid grid-cols-1 gap-x-5 gap-y-7 @[520px]:grid-cols-2 @[1080px]:grid-cols-4">
            {realThemes.map((t) => (
              <ThemeCard
                key={t.id}
                theme={t}
                wallpaper={wallOf(t)}
                applied={t.id === appliedId}
                onOpen={() => setOpenId(t.id)}
                onApply={() => apply(t)}
              />
            ))}
          </div>
        </div>
      </>
    );
  }

  const theme = themeById(openId);
  const index = realThemes.indexOf(theme);
  const wallpaper = wallOf(theme);
  const isCurrent = appliedId === theme.id;
  const isApplied = isCurrent && appliedWall === wallpaper;
  const step = (by: number) =>
    setOpenId(realThemes[(index + by + realThemes.length) % realThemes.length]!.id);

  return (
    <>
      <div className="mb-4 flex items-center justify-between gap-3">
        <nav aria-label="Breadcrumb" className="flex min-w-0 items-center gap-1.5 text-[13px]">
          <button
            type="button"
            onClick={() => setOpenId(null)}
            className={cx(
              "inline-flex items-center gap-1 rounded-[5px] font-medium text-[var(--st-fg2)] hover:text-[var(--st-fg)]",
              focusRing,
            )}
          >
            <ChevronLeft size={14} /> Themes
          </button>
          <span className="text-[var(--st-fg3)]">/</span>
          <span className="truncate font-medium text-[var(--st-fg)]">{theme.name}</span>
        </nav>
        <div className="flex shrink-0 items-center gap-1">
          <span className="mr-1 text-[12px] text-[var(--st-fg3)] tabular-nums">
            {index + 1} of {realThemes.length}
          </span>
          <Button size="sm" variant="ghost" title="Previous theme" onClick={() => step(-1)}>
            <ChevronLeft size={14} />
          </Button>
          <Button size="sm" variant="ghost" title="Next theme" onClick={() => step(1)}>
            <ChevronRight size={14} />
          </Button>
        </div>
      </div>

      <Card className="@container mb-7">
        <ThemeHero theme={theme} wallpaper={wallpaper} />

        <div className="flex flex-wrap items-center justify-between gap-x-6 gap-y-3 border-t border-[var(--st-border)] px-5 py-4">
          <div className="min-w-0">
            <div className="flex items-center gap-2">
              <h2 className="truncate text-[19px] font-semibold tracking-[-0.02em] text-[var(--st-fg)]">
                {theme.name}
              </h2>
              <Badge>
                <Moon size={11} /> {theme.dark ? "Dark" : "Light"}
              </Badge>
              {isCurrent ? (
                <Badge tone="accent" dot>
                  Current
                </Badge>
              ) : null}
            </div>
          </div>
          <div className="flex shrink-0 items-center gap-2">
            {workshop("md")}
            <Button variant="primary" disabled={isApplied} onClick={() => apply(theme)}>
              {isApplied ? (
                <>
                  <Check size={14} /> Applied
                </>
              ) : isCurrent ? (
                "Apply wallpaper"
              ) : (
                `Apply ${theme.name}`
              )}
            </Button>
          </div>
        </div>

        <dl className="grid grid-cols-2 gap-px border-t border-[var(--st-border)] bg-[var(--st-border)] @[720px]:grid-cols-[1fr_1fr_1fr_1.6fr]">
          <DetailCell label="Accent">
            <HexValue colour={theme.accent} />
          </DetailCell>
          <DetailCell label="Background">
            <HexValue colour={theme.background} />
          </DetailCell>
          <DetailCell label="Neovim">
            <span className="truncate">{theme.nvim}</span>
          </DetailCell>
          <DetailCell label="Terminal palette">
            <span className="flex gap-1">
              {theme.palette.map((c, i) => (
                <PaletteSwatch key={i} colour={c} index={i} count={theme.palette.length} />
              ))}
            </span>
          </DetailCell>
        </dl>

        <div className="border-t border-[var(--st-border)] px-5 py-4">
          <div className="mb-2.5 flex items-center justify-between gap-3 text-[12px]">
            <span className="font-medium text-[var(--st-fg2)]">Wallpaper</span>
            <span className="text-[var(--st-fg3)]">
              {wallpaperName(theme, wallpaper)}
              <span className="ml-1.5 tabular-nums">
                {theme.wallpapers.indexOf(wallpaper) + 1}/{theme.wallpapers.length}
              </span>
            </span>
          </div>
          <div className="flex gap-2.5 overflow-x-auto p-1">
            {theme.wallpapers.map((w) => {
              const on = w === wallpaper;
              return (
                <button
                  key={w}
                  type="button"
                  aria-pressed={on}
                  aria-label={wallpaperName(theme, w)}
                  onClick={() => setWalls({ ...walls, [theme.id]: w })}
                  className={cx(
                    "relative aspect-[16/10] w-[128px] shrink-0 overflow-hidden rounded-[7px] transition-[box-shadow,opacity] duration-150",
                    focusRing,
                    on
                      ? "ring-2 ring-[var(--st-fg)] ring-offset-2 ring-offset-[var(--st-bg)]"
                      : "opacity-70 ring-1 ring-[var(--st-border)] hover:opacity-100",
                  )}
                >
                  <Wallpaper theme={theme} file={w} />
                  {isCurrent && appliedWall === w ? (
                    <span className="absolute right-1.5 bottom-1.5 grid size-4 place-items-center rounded-full bg-black/60 text-white backdrop-blur-sm">
                      <Check size={10} />
                    </span>
                  ) : null}
                </button>
              );
            })}
          </div>
        </div>
      </Card>

      <SectionLabel>Other themes</SectionLabel>
      <div className="@container">
        <div className="grid grid-cols-3 gap-3 @[560px]:grid-cols-4 @[820px]:grid-cols-7">
          {realThemes
            .filter((t) => t.id !== theme.id)
            .map((t) => (
              <button
                key={t.id}
                type="button"
                onClick={() => setOpenId(t.id)}
                className={cx("group rounded-[8px] text-left", focusRing)}
              >
                <span className="relative block aspect-[16/10] overflow-hidden rounded-[7px] shadow-[var(--st-shadow)] ring-1 ring-[var(--st-border)] transition-transform duration-150 group-hover:-translate-y-px">
                  <Wallpaper theme={t} file={wallOf(t)} />
                </span>
                <span className="mt-1.5 flex items-center gap-1.5 px-0.5">
                  <span
                    className="size-2 shrink-0 rounded-full ring-1 ring-black/15"
                    style={{ background: t.accent }}
                  />
                  <span className="truncate text-[12px] font-medium text-[var(--st-fg2)] group-hover:text-[var(--st-fg)]">
                    {t.name}
                  </span>
                  {t.id === appliedId ? (
                    <Check size={11} className="shrink-0 text-[var(--st-accent-text)]" />
                  ) : null}
                </span>
              </button>
            ))}
        </div>
      </div>
    </>
  );
}

/* ------------------------------------------------------------------ */
/* Borders                                                             */
/* ------------------------------------------------------------------ */

const themeActive = current.accent;
const themeInactive = current.palette[0]!;
const activePresets = [...new Set([current.accent, ...current.palette.slice(1, 7)])];
const inactivePresets = [
  current.palette[0]!,
  current.background,
  "#2a2a2a",
  "#4a4a4a",
  current.foreground,
];
const initialStyle = snapshot.borders.border_style === "square" ? "Square" : "Round";
const excludedApps = snapshot.borders.borders_blacklist
  .split(",")
  .map((a) => a.trim())
  .filter(Boolean);

/** Heading strip that starts a group of rows inside a settings list. */
function GroupHeader({ title, first }: { title: string; first?: boolean }) {
  return (
    <div
      className={cx(
        "border-b border-[var(--st-border)] bg-[var(--st-side)] px-5 py-2 text-[11px] font-semibold tracking-[0.05em] text-[var(--st-fg3)] uppercase",
        !first && "border-t",
      )}
    >
      {title}
    </div>
  );
}

/** A settings row whose control wraps under the label when space runs out. */
function SettingRow({
  label,
  hint,
  children,
  last,
}: {
  label: string;
  hint?: string;
  children: ReactNode;
  last?: boolean;
}) {
  return (
    <div
      className={cx(
        "flex flex-wrap items-center justify-between gap-x-6 gap-y-2.5 px-5 py-3",
        !last && "border-b border-[var(--st-border)]",
      )}
    >
      <div className="min-w-0">
        <div className="text-[13px] font-medium text-[var(--st-fg)]">{label}</div>
        {hint ? <div className="mt-0.5 text-[12px] text-[var(--st-fg2)]">{hint}</div> : null}
      </div>
      <div className="ml-auto">{children}</div>
    </div>
  );
}

const traffic = ["#ff5f57", "#febc2e", "#28c840"];

/** A window in the border preview, framed like JankyBorders would draw it. */
function PreviewWindow({
  kind,
  focused,
  colour,
  width,
  radius,
  onFocus,
}: {
  kind: "terminal" | "browser";
  focused: boolean;
  colour: string;
  width: number;
  radius: number;
  onFocus: () => void;
}) {
  const t = current;
  const p = t.palette;
  const line = `1px solid color-mix(in srgb, ${t.foreground} 9%, transparent)`;
  return (
    <button
      type="button"
      aria-pressed={focused}
      aria-label={`${kind === "terminal" ? "Ghostty" : "Safari"}, ${focused ? "focused" : "unfocused"}`}
      onClick={onFocus}
      className={cx(
        "flex min-w-0 flex-col overflow-hidden text-left outline-none transition-[box-shadow,border-radius] duration-150 focus-visible:brightness-110",
        kind === "terminal" ? "flex-[1.15]" : "flex-1",
      )}
      style={{
        background: t.background,
        borderRadius: radius,
        boxShadow: `0 0 0 ${width}px ${colour}, 0 16px 36px -14px rgba(0,0,0,0.65)`,
      }}
    >
      <div
        className="flex h-[22px] shrink-0 items-center gap-[5px] px-2.5"
        style={{ borderBottom: line }}
      >
        {traffic.map((c) => (
          <span
            key={c}
            className="size-[7px] rounded-full"
            style={{
              background: focused ? c : `color-mix(in srgb, ${t.foreground} 22%, transparent)`,
            }}
          />
        ))}
        {kind === "browser" ? (
          <span
            className="mx-auto max-w-[60%] truncate rounded-[4px] px-2 font-sans text-[9.5px] leading-[14px]"
            style={{
              color: t.foreground,
              opacity: focused ? 0.7 : 0.4,
              background: `color-mix(in srgb, ${t.foreground} 7%, transparent)`,
            }}
          >
            github.com/FelixKratz/JankyBorders
          </span>
        ) : (
          <span
            className="mx-auto font-sans text-[10px] font-medium"
            style={{ color: t.foreground, opacity: focused ? 0.7 : 0.4 }}
          >
            ~/projects/macarchy
          </span>
        )}
        <span
          className="flex items-center gap-1 font-sans text-[9.5px]"
          style={{ color: t.foreground, opacity: focused ? 0.6 : 0.35 }}
        >
          <span className="size-[5px] rounded-full" style={{ background: colour }} />
          {focused ? "Focused" : "Unfocused"}
        </span>
      </div>

      <div className="min-h-0 flex-1 overflow-hidden" style={{ opacity: focused ? 1 : 0.55 }}>
        {kind === "terminal" ? (
          <div
            className="px-3 py-2 font-mono text-[10.5px] leading-[1.6]"
            style={{ color: t.foreground }}
          >
            <div>
              <span style={{ color: p[4] }}>macarchy</span>{" "}
              <span style={{ color: p[2] }}>main</span> <span style={{ color: p[6] }}>$</span>{" "}
              borders style=square width=7.0
            </div>
            <div style={{ opacity: 0.6 }}>Reloading JankyBorders</div>
            <div>
              <span style={{ color: p[2] }}>ok</span> 3 windows framed
            </div>
            <div>
              <span style={{ color: p[4] }}>macarchy</span>{" "}
              <span style={{ color: p[2] }}>main</span> <span style={{ color: p[6] }}>$</span>{" "}
              <span
                className="inline-block h-[11px] w-[6px] translate-y-[2px]"
                style={{
                  background: focused ? t.accent : t.foreground,
                  opacity: focused ? 1 : 0.4,
                }}
              />
            </div>
          </div>
        ) : (
          <div className="space-y-2 px-3 py-2.5">
            <div className="flex items-center gap-2">
              <span className="size-4 rounded-full" style={{ background: p[4], opacity: 0.8 }} />
              <span
                className="h-[6px] w-[42%] rounded-full"
                style={{ background: t.foreground, opacity: 0.55 }}
              />
            </div>
            {[88, 74, 81].map((pct) => (
              <div
                key={pct}
                className="h-[4px] rounded-full"
                style={{ width: `${pct}%`, background: t.foreground, opacity: 0.18 }}
              />
            ))}
            <div className="flex gap-2 pt-0.5">
              {[p[6], p[3]].map((c, i) => (
                <span
                  key={i}
                  className="h-7 flex-1 rounded-[3px]"
                  style={{ background: `color-mix(in srgb, ${c} 22%, ${t.background})` }}
                />
              ))}
            </div>
          </div>
        )}
      </div>
    </button>
  );
}

export function BordersPage() {
  const [enabled, setEnabled] = useState(snapshot.borders.borders_visible);
  const [width, setWidth] = useState(snapshot.borders.border_width);
  const [radius, setRadius] = useState(10);
  const [active, setActive] = useState(themeActive);
  const [inactive, setInactive] = useState(themeInactive);
  const [style, setStyle] = useState<"Round" | "Square">(initialStyle);
  const [hidpi, setHidpi] = useState(true);
  const [followTheme, setFollowTheme] = useState(true);
  const [focused, setFocused] = useState<0 | 1>(0);
  const [showConfig, setShowConfig] = useState(false);
  const r = style === "Square" ? 0 : radius;
  const w = enabled ? width : 0;
  const custom = (fn: (c: string) => void) => (c: string) => {
    fn(c);
    setFollowTheme(false);
  };
  const reset = () => {
    setWidth(snapshot.borders.border_width);
    setRadius(10);
    setActive(themeActive);
    setInactive(themeInactive);
    setStyle(initialStyle);
    setFollowTheme(true);
  };
  const changed =
    width !== snapshot.borders.border_width ||
    active !== themeActive ||
    inactive !== themeInactive ||
    style !== initialStyle;
  const hex = (c: string) => `0xff${c.slice(1)}`;

  return (
    <>
      <PageHeader title="Borders" />

      <SectionLabel
        action={
          <div className="flex items-center gap-2 text-[12px] text-[var(--st-fg2)]">
            {enabled ? "Enabled" : "Disabled"}
            <Switch label="Borders enabled" checked={enabled} onChange={setEnabled} />
          </div>
        }
      >
        JankyBorders
      </SectionLabel>

      <Card className="mb-6 overflow-hidden">
        <div className="relative h-[196px]">
          <Wallpaper theme={current} file={current.wallpaper} />
          <div className="absolute inset-0 bg-black/35" />
          <div
            className="absolute inset-x-0 top-0 flex h-5 items-center gap-1 px-2.5 font-mono text-[9.5px] font-medium"
            style={{
              background: `color-mix(in srgb, ${current.background} 88%, transparent)`,
              color: current.foreground,
            }}
          >
            {[1, 2, 3].map((n) => (
              <span
                key={n}
                className="grid h-3 min-w-3.5 place-items-center rounded-[3px] px-1"
                style={
                  n === 1 ? { background: active, color: current.background } : { opacity: 0.5 }
                }
              >
                {n}
              </span>
            ))}
          </div>
          <div className="absolute inset-x-6 top-[38px] bottom-5 flex gap-4">
            {(["terminal", "browser"] as const).map((kind, i) => (
              <PreviewWindow
                key={kind}
                kind={kind}
                focused={focused === i}
                colour={focused === i ? active : inactive}
                width={w}
                radius={r}
                onFocus={() => setFocused(i as 0 | 1)}
              />
            ))}
          </div>
          {!enabled ? (
            <div className="absolute inset-0 grid place-items-center bg-black/30 backdrop-blur-[1px]">
              <span className="rounded-[7px] bg-black/60 px-3 py-1.5 text-[12px] font-medium text-white/85">
                Borders are off
              </span>
            </div>
          ) : null}
        </div>
        <div className="flex items-center border-t border-[var(--st-border)] bg-[var(--st-side)] pr-2">
          <button
            type="button"
            aria-expanded={showConfig}
            onClick={() => setShowConfig(!showConfig)}
            className={cx(
              "flex min-w-0 flex-1 items-center gap-2 px-4 py-2 text-left text-[12px] text-[var(--st-fg2)] hover:text-[var(--st-fg)]",
              focusRing,
            )}
          >
            <FileCode2 size={13} className="shrink-0" />
            <span className="font-medium">Generated config</span>
            <ChevronDown
              size={13}
              className={cx("shrink-0 transition-transform", showConfig && "rotate-180")}
            />
          </button>
          <Button size="sm" variant="ghost" disabled={!changed} onClick={reset}>
            <RotateCw size={12} /> Reset to theme
          </Button>
        </div>
        {showConfig ? (
          <pre className="overflow-x-auto border-t border-[var(--st-border)] bg-[var(--st-side)] px-4 py-3 font-mono text-[11.5px] leading-[1.65] whitespace-pre-wrap text-[var(--st-fg2)]">
            <span className="text-[var(--st-fg)]">borders</span> active_color={hex(active)}{" "}
            inactive_color={hex(inactive)} width={w}.0 style=
            {style === "Square" ? "square" : "round"} hidpi={hidpi ? "on" : "off"} blacklist="
            {excludedApps.join(",")}"
          </pre>
        ) : null}
      </Card>

      {!enabled ? (
        <div className="mb-4 flex items-center gap-3 rounded-[10px] border border-[var(--st-border)] bg-[var(--st-side)] px-4 py-3">
          <SquareDashed size={16} className="text-[var(--st-fg2)]" />
          <div className="flex-1 text-[12.5px] text-[var(--st-fg2)]">JankyBorders is off</div>
          <Button size="sm" variant="primary" onClick={() => setEnabled(true)}>
            Turn on
          </Button>
        </div>
      ) : null}

      <Card
        className={cx(
          "overflow-hidden transition-opacity",
          !enabled && "pointer-events-none opacity-50",
        )}
      >
        <GroupHeader title="Shape" first />
        <SettingRow label="Width">
          <Slider
            label="Border width"
            value={width}
            min={1}
            max={12}
            onChange={setWidth}
            width={140}
          />
        </SettingRow>
        <SettingRow label="Corners" last={style === "Square"}>
          <Segmented
            size="sm"
            options={["Round", "Square"] as const}
            value={style}
            onChange={setStyle}
          />
        </SettingRow>
        {style === "Round" ? (
          <SettingRow label="Radius" last>
            <Slider
              label="Border radius"
              value={radius}
              min={0}
              max={20}
              onChange={setRadius}
              width={140}
            />
          </SettingRow>
        ) : null}

        <GroupHeader title="Colour" />
        <SettingRow
          label="Follow theme"
          hint={followTheme ? `${current.name} accent` : "Custom colours"}
        >
          <Switch
            label="Follow theme"
            checked={followTheme}
            onChange={(v) => {
              setFollowTheme(v);
              if (v) {
                setActive(themeActive);
                setInactive(themeInactive);
              }
            }}
          />
        </SettingRow>
        <SettingRow label="Focused">
          <ColourField
            label="Focused"
            value={active}
            presets={activePresets}
            onChange={custom(setActive)}
          />
        </SettingRow>
        <SettingRow label="Unfocused" last>
          <ColourField
            label="Unfocused"
            value={inactive}
            presets={inactivePresets}
            onChange={custom(setInactive)}
          />
        </SettingRow>

        <GroupHeader title="Behaviour" />
        <SettingRow label="HiDPI">
          <Switch label="HiDPI rendering" checked={hidpi} onChange={setHidpi} />
        </SettingRow>
        <SettingRow label="Excluded apps" last>
          <div className="flex flex-wrap items-center justify-end gap-1.5">
            {excludedApps.map((a) => (
              <Chip key={a}>{a}</Chip>
            ))}
            <Button size="sm" variant="ghost">
              <Plus size={12} /> Add app
            </Button>
          </div>
        </SettingRow>
      </Card>
    </>
  );
}

/* ------------------------------------------------------------------ */
/* Layout                                                              */
/* ------------------------------------------------------------------ */

type Mode = "BSP" | "Stack" | "Float";
type Split = "Auto" | "Vertical" | "Horizontal";
type Placement = "First child" | "Second child";
type Monitor = "Landscape" | "Portrait";
interface Sides {
  top: number;
  right: number;
  bottom: number;
  left: number;
}

const apps = ["Ghostty", "Safari", "Zed", "Notes"];
const SCALE = 0.8;
const l0 = snapshot.layout;
const modeOf: Record<string, Mode> = { bsp: "BSP", stack: "Stack", float: "Float" };
const initialSides: Sides = {
  top: l0.top_padding,
  right: l0.right_padding,
  bottom: l0.bottom_padding,
  left: l0.left_padding,
};

function TilingPreview({
  gap,
  padding,
  mode,
  split,
  placement,
  monitor,
  windows,
}: {
  gap: number;
  padding: Sides;
  mode: Mode;
  split: Split;
  placement: Placement;
  monitor: Monitor;
  windows: number;
}) {
  const [focus, setFocus] = useState(0);
  const [ws, setWs] = useState(1);
  const f = Math.min(focus, windows - 1);
  const horizontal = split === "Vertical" || (split === "Auto" && monitor === "Landscape");
  const pad = {
    paddingTop: padding.top * SCALE,
    paddingRight: padding.right * SCALE,
    paddingBottom: padding.bottom * SCALE,
    paddingLeft: padding.left * SCALE,
  };

  const win = (i: number, extra?: string, style?: CSSProperties) => (
    <button
      key={i}
      type="button"
      onClick={() => setFocus(i)}
      className={cx(
        "flex min-h-0 min-w-0 flex-col overflow-hidden rounded-[5px] border text-left outline-none transition-all duration-200",
        i === f
          ? "border-[var(--st-accent)] bg-[var(--st-bg)] shadow-[0_0_0_2px_var(--st-accent-soft)]"
          : "border-[var(--st-border-strong)] bg-[var(--st-bg)]/80",
        extra,
      )}
      style={style}
    >
      <span
        className={cx(
          "flex h-4 shrink-0 items-center gap-1 border-b px-1.5 text-[8.5px] font-medium",
          i === f
            ? "border-[var(--st-accent)]/30 text-[var(--st-accent-text)]"
            : "border-[var(--st-border)] text-[var(--st-fg3)]",
        )}
      >
        <span
          className={cx(
            "size-1 rounded-full",
            i === f ? "bg-[var(--st-accent)]" : "bg-[var(--st-fg3)]",
          )}
        />
        {apps[i]}
      </span>
      <span className="flex flex-1 flex-col gap-1 p-1.5">
        {[70, 50, 60].map((pct, k) => (
          <span
            key={k}
            className="h-[3px] rounded-full bg-[var(--st-fg3)]/40"
            style={{ width: `${pct}%` }}
          />
        ))}
      </span>
    </button>
  );

  /** Each new window splits the last one in half, alternating direction. */
  const bsp = (i: number, row: boolean): ReactNode => {
    if (i === windows - 1) return win(i, "flex-1");
    return (
      <div
        className={cx(
          "flex min-h-0 min-w-0 flex-1",
          row
            ? placement === "First child"
              ? "flex-row-reverse"
              : "flex-row"
            : placement === "First child"
              ? "flex-col-reverse"
              : "flex-col",
        )}
        style={{ gap: gap * SCALE }}
      >
        {win(i, "flex-1")}
        <div className="flex min-h-0 min-w-0 flex-1">{bsp(i + 1, !row)}</div>
      </div>
    );
  };

  return (
    <div
      className="grid h-[248px] place-items-center bg-[var(--st-canvas)] p-4"
      style={{
        backgroundImage: "radial-gradient(var(--st-border) 1px, transparent 1px)",
        backgroundSize: "14px 14px",
      }}
    >
      <div
        className="flex h-full flex-col overflow-hidden rounded-[8px] border border-[var(--st-border-strong)] bg-[var(--st-side)] shadow-[var(--st-shadow)] transition-[width] duration-300"
        style={{ width: monitor === "Landscape" ? "100%" : 150 }}
      >
        <div className="flex h-5 shrink-0 items-center gap-0.5 border-b border-[var(--st-border)] bg-[var(--st-bg)] px-1.5">
          {Array.from({ length: 5 }, (_, i) => (
            <button
              key={i}
              type="button"
              onClick={() => setWs(i + 1)}
              className={cx(
                "grid h-3 min-w-3 place-items-center rounded-[3px] px-0.5 text-[8px] font-semibold transition-colors",
                i + 1 === ws
                  ? "bg-[var(--st-accent)] text-[var(--st-accent-fg)]"
                  : "text-[var(--st-fg3)] hover:text-[var(--st-fg)]",
              )}
            >
              {i + 1}
            </button>
          ))}
        </div>
        <div className="relative min-h-0 flex-1" style={pad}>
          <div
            className="pointer-events-none absolute rounded-[3px] border border-dashed border-[var(--st-accent)]/55 transition-all duration-200"
            style={{
              top: pad.paddingTop / 2,
              right: pad.paddingRight / 2,
              bottom: pad.paddingBottom / 2,
              left: pad.paddingLeft / 2,
              opacity: padding.top + padding.left > 0 ? 1 : 0,
            }}
          />
          {mode === "BSP" ? (
            <div className="relative flex h-full w-full">{bsp(0, horizontal)}</div>
          ) : mode === "Stack" ? (
            <div className="relative h-full w-full">
              {Array.from({ length: windows }, (_, i) =>
                win(i, i === f ? "" : "opacity-70", {
                  position: "absolute",
                  inset: 0,
                  top: i * 5,
                  zIndex: i === f ? 10 : i,
                }),
              )}
            </div>
          ) : (
            <div className="relative h-full w-full">
              {Array.from({ length: windows }, (_, i) =>
                win(i, "shadow-lg", {
                  position: "absolute",
                  left: `${6 + i * 12}%`,
                  top: `${6 + i * 11}%`,
                  width: monitor === "Landscape" ? "48%" : "72%",
                  height: "52%",
                  zIndex: i === f ? 10 : i,
                }),
              )}
            </div>
          )}
        </div>
      </div>
    </div>
  );
}

export function LayoutPage() {
  const [gap, setGap] = useState(l0.window_gap);
  const [padding, setPadding] = useState(l0.top_padding);
  const [perSide, setPerSide] = useState(false);
  const [sides, setSides] = useState<Sides>(initialSides);
  const [mode, setMode] = useState<Mode>(modeOf[l0.layout] ?? "BSP");
  const [split, setSplit] = useState<Split>("Auto");
  const [placement, setPlacement] = useState<Placement>(
    l0.window_placement === "first_child" ? "First child" : "Second child",
  );
  const [balance, setBalance] = useState(l0.auto_balance);
  const [modifier, setModifier] = useState<string>(l0.mouse_modifier);
  const [drop, setDrop] = useState<"Stack" | "Swap">(
    l0.mouse_drop_action === "swap" ? "Swap" : "Stack",
  );
  const [follow, setFollow] = useState(l0.mouse_follows_focus);
  const [monitor, setMonitor] = useState<Monitor>("Landscape");
  const [windows, setWindows] = useState(3);
  const [showConfig, setShowConfig] = useState(false);

  const pad: Sides = perSide
    ? sides
    : { top: padding, right: padding, bottom: padding, left: padding };
  const snake = (s: string) => s.toLowerCase().replace(" ", "_");
  const config = [
    `"layout": "${mode.toLowerCase()}",`,
    `"split_type": "${split.toLowerCase()}",`,
    `"window_placement": "${snake(placement)}",`,
    `"auto_balance": ${balance},`,
    `"window_gap": ${gap},`,
    ...(["top", "right", "bottom", "left"] as const).map((s) => `"${s}_padding": ${pad[s]},`),
    `"mouse_modifier": "${modifier}",`,
    `"mouse_drop_action": "${drop.toLowerCase()}",`,
    `"mouse_follows_focus": ${follow}`,
  ];
  const splitHint =
    split === "Auto"
      ? `Side by side on this ${monitor.toLowerCase()} monitor`
      : split === "Vertical"
        ? "Side by side"
        : "Above and below";

  return (
    <>
      <PageHeader title="Layout" />

      <Card className="mb-6 overflow-hidden">
        <div className="flex items-center justify-between gap-3 px-4 py-3">
          <div>
            <div className="text-[13.5px] font-semibold tracking-[-0.01em] text-[var(--st-fg)]">
              Preview
            </div>
            <div className="text-[12px] text-[var(--st-fg2)]">
              {mode === "BSP" ? `BSP, ${gap}px gaps` : mode === "Stack" ? "Stacked" : "Floating"}
            </div>
          </div>
          <div className="flex items-center gap-2">
            <Stepper label="Windows" value={windows} min={1} max={4} onChange={setWindows} />
            <Segmented
              size="sm"
              options={["Landscape", "Portrait"] as const}
              value={monitor}
              onChange={setMonitor}
            />
          </div>
        </div>
        <div className="border-y border-[var(--st-border)]">
          <TilingPreview
            gap={gap}
            padding={pad}
            mode={mode}
            split={split}
            placement={placement}
            monitor={monitor}
            windows={windows}
          />
        </div>
        <button
          type="button"
          onClick={() => setShowConfig(!showConfig)}
          className={cx(
            "flex w-full items-center gap-2 bg-[var(--st-side)] px-4 py-2 text-left text-[12px] text-[var(--st-fg2)] hover:text-[var(--st-fg)]",
            focusRing,
          )}
        >
          <FileCode2 size={13} />
          <span className="flex-1 font-mono">~/.config/macarchy/settings.json</span>
          <span>{showConfig ? "Hide" : "Show"} saved values</span>
          <ChevronDown
            size={13}
            className={cx("transition-transform", showConfig && "rotate-180")}
          />
        </button>
        {showConfig ? (
          <pre className="overflow-x-auto border-t border-[var(--st-border)] bg-[var(--st-side)] px-4 py-3 font-mono text-[11.5px] leading-[1.65] text-[var(--st-fg2)]">
            {config.map((line, i) => (
              <div key={i}>{line}</div>
            ))}
          </pre>
        ) : null}
      </Card>

      <div className="@container">
        <div className="grid grid-cols-1 items-start gap-5 @[720px]:grid-cols-2">
          <Card>
            <CardHeader title="Tiling" />
            <div className="border-t border-[var(--st-border)]">
              <Row label="Layout">
                <Segmented
                  size="sm"
                  options={["BSP", "Stack", "Float"] as const}
                  value={mode}
                  onChange={setMode}
                />
              </Row>
              <Row label="Split" hint={splitHint}>
                <Segmented
                  size="sm"
                  options={["Auto", "Vertical", "Horizontal"] as const}
                  value={split}
                  onChange={setSplit}
                />
              </Row>
              <Row
                label="New windows"
                hint={placement === "Second child" ? "Right or below" : "Left or above"}
              >
                <Segmented
                  size="sm"
                  options={["First child", "Second child"] as const}
                  value={placement}
                  onChange={setPlacement}
                />
              </Row>
              <Row label="Auto balance" hint="Equal window sizes" last>
                <Switch label="Auto balance" checked={balance} onChange={setBalance} />
              </Row>
            </div>
          </Card>

          <div className="flex flex-col gap-5">
            <Card>
              <CardTitle
                title="Gaps"
                action={
                  <Button size="sm" variant="ghost" onClick={() => setPerSide(!perSide)}>
                    {perSide ? "One value" : "Per side"}
                  </Button>
                }
              />
              <div className="border-t border-[var(--st-border)]">
                <Row label="Window gap">
                  <Slider
                    label="Window gap"
                    value={gap}
                    min={0}
                    max={24}
                    onChange={setGap}
                    width={120}
                  />
                </Row>
                {perSide ? (
                  (["top", "right", "bottom", "left"] as const).map((s, i, all) => (
                    <Row key={s} label={`Padding ${s}`} last={i === all.length - 1}>
                      <Slider
                        label={`Padding ${s}`}
                        value={sides[s]}
                        min={0}
                        max={48}
                        width={120}
                        onChange={(v) => setSides({ ...sides, [s]: v })}
                      />
                    </Row>
                  ))
                ) : (
                  <Row label="Screen padding" last>
                    <Slider
                      label="Screen padding"
                      value={padding}
                      min={0}
                      max={32}
                      width={120}
                      onChange={(v) => {
                        setPadding(v);
                        setSides({ top: v, right: v, bottom: v, left: v });
                      }}
                    />
                  </Row>
                )}
              </div>
            </Card>

            <Card>
              <CardHeader title="Mouse" />
              <div className="border-t border-[var(--st-border)]">
                <Row label="Modifier" hint="Hold to drag and resize windows">
                  <Segmented
                    size="sm"
                    options={["fn", "ctrl", "alt", "cmd"] as const}
                    value={modifier}
                    onChange={setModifier}
                  />
                </Row>
                <Row label="On drop">
                  <Segmented
                    size="sm"
                    options={["Stack", "Swap"] as const}
                    value={drop}
                    onChange={setDrop}
                  />
                </Row>
                <Row label="Mouse follows focus" last>
                  <Switch label="Mouse follows focus" checked={follow} onChange={setFollow} />
                </Row>
              </div>
            </Card>
          </div>
        </div>
      </div>
    </>
  );
}
