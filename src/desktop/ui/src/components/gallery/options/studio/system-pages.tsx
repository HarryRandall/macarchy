import {
  Activity,
  AppWindow,
  Archive,
  CalendarDays,
  Check,
  ChevronRight,
  CircleCheck,
  CircleQuestionMark,
  Clock,
  Copy,
  ExternalLink,
  FileDiff,
  FolderOpen,
  Hammer,
  HardDrive,
  ImagePlus,
  Info,
  Keyboard,
  LayoutGrid,
  ListOrdered,
  type LucideIcon,
  Palette,
  PanelTop,
  RotateCcw,
  Send,
  ShieldCheck,
  Square,
  SquareTerminal,
  TriangleAlert,
  X,
} from "lucide-react";
import {
  type DragEvent as ReactDragEvent,
  type MouseEvent as ReactMouseEvent,
  type ReactNode,
  useId,
  useLayoutEffect,
  useRef,
  useState,
} from "react";

import { currentThemeId, realThemes, snapshot, wallpaperUrl } from "../real";
import {
  Badge,
  Button,
  Card,
  Chip,
  PageHeader,
  SectionLabel,
  Switch,
  cx,
  focusRing,
  useWidth,
} from "./ui";

/** Red that reads on both zinc backgrounds; Studio tokens have no danger colour yet. */
const danger = "#e5484d";

const fieldCls =
  "w-full rounded-[7px] border border-[var(--st-border)] bg-[var(--st-bg)] px-[11px] text-[13px] text-[var(--st-fg)] shadow-[var(--st-shadow)] outline-none transition-[border-color,box-shadow] placeholder:text-[var(--st-fg3)] focus:border-[var(--st-accent)] focus:ring-[3px] focus:ring-[var(--st-accent-soft)]";

const themeName = realThemes.find((t) => t.id === currentThemeId)?.name ?? "Matte Black";

function copyText(text: string) {
  void navigator.clipboard?.writeText(text).catch(() => {});
}

function Empty({ icon: Icon, title }: { icon: LucideIcon; title: string }) {
  return (
    <div className="grid place-items-center rounded-[10px] border border-dashed border-[var(--st-border)] px-[24px] py-[40px] text-center">
      <Icon size={20} strokeWidth={1.75} className="mb-[8px] text-[var(--st-fg3)]" />
      <div className="text-[13px] font-medium text-[var(--st-fg)]">{title}</div>
    </div>
  );
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

/** Small square icon holder used for rows and summary cells. */
function IconTile({
  icon: Icon,
  size = 28,
  tone = "neutral",
}: {
  icon: LucideIcon;
  size?: number;
  tone?: "neutral" | "danger" | "accent";
}) {
  const styles = {
    neutral: "border-[var(--st-border)] bg-[var(--st-side)] text-[var(--st-fg2)]",
    accent: "border-transparent bg-[var(--st-accent-soft)] text-[var(--st-accent-text)]",
    danger: "border-[#e5484d]/25 bg-[#e5484d]/[0.08] text-[#e5484d]",
  }[tone];
  return (
    <span
      className={cx("grid shrink-0 place-items-center rounded-[7px] border", styles)}
      style={{ width: size, height: size }}
    >
      <Icon size={Math.round(size * 0.5)} strokeWidth={1.75} />
    </span>
  );
}

/** Square icon button with a tooltip from its label. */
function IconButton({
  icon: Icon,
  label,
  onClick,
  active,
}: {
  icon: LucideIcon;
  label: string;
  onClick: () => void;
  active?: boolean;
}) {
  return (
    <button
      type="button"
      aria-label={label}
      title={label}
      aria-pressed={active}
      onClick={onClick}
      className={cx(
        "grid size-[28px] place-items-center rounded-[7px] transition-colors",
        active
          ? "bg-[var(--st-muted)] text-[var(--st-fg)]"
          : "text-[var(--st-fg2)] hover:bg-[var(--st-hover)] hover:text-[var(--st-fg)]",
        focusRing,
      )}
    >
      <Icon size={14} strokeWidth={1.75} />
    </button>
  );
}

/* ------------------------------------------------------------------ */
/* Advanced                                                            */
/* ------------------------------------------------------------------ */

type FileState = "generated" | "custom" | "rebuilt";

interface ConfigFile {
  name: string;
  tool: string;
  icon: LucideIcon;
  path: string;
  state: FileState;
  edited: string;
  kb: number;
  diff: { kind: " " | "+" | "-"; text: string }[];
}

const initialFiles: ConfigFile[] = [
  {
    name: "aerospace.toml",
    tool: "AeroSpace",
    icon: LayoutGrid,
    path: "~/.config/aerospace/aerospace.toml",
    state: "generated",
    edited: "Today, 17:02",
    kb: 9.4,
    diff: [],
  },
  {
    name: "sketchybarrc",
    tool: "SketchyBar",
    icon: PanelTop,
    path: "~/.config/sketchybar/sketchybarrc",
    state: "custom",
    edited: "Yesterday, 21:40",
    kb: 22.6,
    diff: [
      { kind: " ", text: "sketchybar --add item clock right" },
      { kind: "-", text: "sketchybar --set clock update_freq=30" },
      { kind: "+", text: "sketchybar --set clock update_freq=10 \\" },
      { kind: "+", text: '  icon.font="SF Pro:Semibold:13.0"' },
      { kind: " ", text: "" },
      { kind: "+", text: "# Spotify now playing, added by hand" },
      { kind: "+", text: "sketchybar --add item spotify right" },
    ],
  },
  {
    name: "bordersrc",
    tool: "JankyBorders",
    icon: Square,
    path: "~/.config/borders/bordersrc",
    state: "generated",
    edited: "Today, 16:48",
    kb: 1.2,
    diff: [],
  },
  {
    name: "skhdrc",
    tool: "skhd",
    icon: Keyboard,
    path: "~/.config/skhd/skhdrc",
    state: "generated",
    edited: "18 Oct, 09:15",
    kb: 4.1,
    diff: [],
  },
];

/** Days shown in the Advanced charts; the last one is today, 21 Oct 2026. */
const DAYS = 30;
const dayDate = (i: number) => new Date(2026, 9, 21 - (DAYS - 1 - i));
const fmtDay = (i: number) =>
  dayDate(i).toLocaleDateString("en-GB", { weekday: "short", day: "numeric", month: "short" });
const fmtShortDay = (i: number) =>
  i === DAYS - 1
    ? "Today"
    : dayDate(i).toLocaleDateString("en-GB", { day: "numeric", month: "short" });
const fmtWhen = (day: number, time: string) =>
  `${day === DAYS - 1 ? "Today" : day === DAYS - 2 ? "Yesterday" : fmtShortDay(day)}, ${time}`;
const fmtSize = (kb: number) =>
  kb >= 1000 ? `${(kb / 1024).toFixed(1)} MB` : `${kb.toFixed(1)} KB`;
const clamp = (v: number, lo: number, hi: number) => Math.min(Math.max(v, lo), hi);

interface Backup {
  id: number;
  day: number;
  time: string;
  reason: string;
  files: number;
  kb: number;
}

const recentBackups: Omit<Backup, "id">[] = [
  { day: 29, time: "17:02", reason: `Theme changed to ${themeName}`, files: 3, kb: 46.2 },
  { day: 29, time: "16:48", reason: "Border width 6 to 7", files: 1, kb: 14.8 },
  { day: 29, time: "09:31", reason: "Gaps changed from 6 to 8", files: 1, kb: 15.1 },
  { day: 28, time: "21:40", reason: "Before rebuilding menu bar", files: 1, kb: 22.6 },
  { day: 28, time: "13:05", reason: "Network item added to menu bar", files: 1, kb: 22.4 },
  { day: 27, time: "11:20", reason: "Rule added for TablePlus", files: 1, kb: 15.0 },
];
/** Snapshots per day before the last three days. */
const olderCounts = [
  1, 0, 2, 0, 1, 3, 0, 0, 2, 1, 0, 4, 2, 1, 0, 0, 3, 1, 2, 0, 0, 5, 1, 2, 0, 1, 2,
];
const olderReasons = [
  "Theme changed to Catppuccin",
  "Gaps changed from 6 to 8",
  "Shortcut added for Ghostty",
  "Clock format changed",
  "Rule added for FaceTime",
  "Menu bar height 32 to 35",
  "Active border colour changed",
  "Workspace 4 renamed to Mail",
  "Before rebuilding aerospace.toml",
  "Battery item hidden",
];

const initialBackups: Backup[] = (() => {
  const older: Omit<Backup, "id">[] = [];
  olderCounts.forEach((n, d) => {
    const times = Array.from({ length: n }, (_, k) => {
      const hh = 8 + ((d * 5 + k * 4) % 14);
      const mm = (d * 13 + k * 29) % 60;
      return `${String(hh).padStart(2, "0")}:${String(mm).padStart(2, "0")}`;
    }).sort((a, b) => b.localeCompare(a));
    times.forEach((time, k) => {
      const files = 1 + ((d + k) % 3);
      older.push({
        day: d,
        time,
        reason: olderReasons[(d * 3 + k) % olderReasons.length]!,
        files,
        kb: Math.round((files * 14.6 + ((d * 5 + k * 3) % 9)) * 10) / 10,
      });
    });
  });
  return [...recentBackups, ...older.reverse()].map((b, i) => ({ ...b, id: i + 1 }));
})();

/** Total size of the generated config, in KB, at the end of each day. */
const configSizes = [
  38.2, 38.2, 38.6, 38.6, 38.9, 39.4, 39.4, 39.4, 40.1, 40.3, 40.3, 41.8, 42.2, 42.4, 42.4, 42.4,
  43.6, 43.1, 43.9, 43.9, 43.9, 46.0, 46.2, 46.9, 46.9, 47.3, 48.0, 48.4, 49.6, 51.2,
];

const toolFiles = [
  { name: "SketchyBar", files: 14, lines: 612, edited: "Yesterday, 21:40" },
  { name: "Neovim", files: 4, lines: 188, edited: "Today, 17:02" },
  { name: "AeroSpace", files: 3, lines: 214, edited: "Today, 09:31" },
  { name: "Ghostty", files: 2, lines: 96, edited: "Today, 17:02" },
  { name: "JankyBorders", files: 1, lines: 18, edited: "Today, 16:48" },
];

/** A bar with 4px rounded corners on the end away from the baseline. */
function barPath(x: number, y: number, w: number, h: number, horizontal = false) {
  if (horizontal) {
    const r = Math.min(4, h / 2, w);
    return `M${x},${y}H${x + w - r}A${r},${r} 0 0 1 ${x + w},${y + r}V${y + h - r}A${r},${r} 0 0 1 ${x + w - r},${y + h}H${x}Z`;
  }
  const r = Math.min(4, w / 2, h);
  return `M${x},${y + h}V${y + r}A${r},${r} 0 0 1 ${x + r},${y}H${x + w - r}A${r},${r} 0 0 1 ${x + w},${y + r}V${y + h}Z`;
}

/** Hover card that measures itself so it always stays inside the chart. */
function ChartTip({
  x,
  y,
  below,
  bounds,
  place,
  children,
}: {
  x: number;
  y: number;
  /** Where to drop to when there is no room above, for "above" placement. */
  below?: number;
  bounds: { w: number; h: number };
  place: "side" | "above";
  children: ReactNode;
}) {
  const ref = useRef<HTMLDivElement>(null);
  const [size, setSize] = useState({ w: 0, h: 0 });
  useLayoutEffect(() => {
    const el = ref.current;
    if (el && (el.offsetWidth !== size.w || el.offsetHeight !== size.h))
      setSize({ w: el.offsetWidth, h: el.offsetHeight });
  });
  let left: number;
  let top: number;
  if (place === "side") {
    left = x + 12 + size.w <= bounds.w ? x + 12 : x - 12 - size.w;
    top = y - size.h / 2;
  } else {
    left = x - size.w / 2;
    top = y - size.h - 8 >= 0 ? y - size.h - 8 : (below ?? y) + 8;
  }
  return (
    <div
      ref={ref}
      role="status"
      className="pointer-events-none absolute z-10 min-w-[136px] rounded-[8px] border border-[var(--st-border)] bg-[var(--st-bg)] px-[10px] py-[8px] text-[11.5px] whitespace-nowrap text-[var(--st-fg)] shadow-[0_8px_24px_-10px_rgba(0,0,0,0.3),0_2px_6px_-2px_rgba(0,0,0,0.12)]"
      style={{
        left: clamp(left, 0, Math.max(0, bounds.w - size.w)),
        top: clamp(top, 0, Math.max(0, bounds.h - size.h)),
        visibility: size.w ? "visible" : "hidden",
      }}
    >
      {children}
    </div>
  );
}

function TipTitle({ children }: { children: ReactNode }) {
  return <div className="mb-[4px] font-semibold text-[var(--st-fg)]">{children}</div>;
}

function TipRow({ label, value }: { label: string; value: ReactNode }) {
  return (
    <div className="flex items-center justify-between gap-[16px] leading-[1.6]">
      <span className="text-[var(--st-fg2)]">{label}</span>
      <span className="font-medium tabular-nums text-[var(--st-fg)]">{value}</span>
    </div>
  );
}

const chartFocus =
  "rounded-[6px] outline-none focus-visible:ring-2 focus-visible:ring-[var(--st-accent)] focus-visible:ring-offset-2 focus-visible:ring-offset-[var(--st-bg)]";
const axisText = { fontSize: 10.5, fill: "var(--st-fg3)" } as const;

/** Snapshots per day; click a bar to filter the list below to that day. */
function BackupsChart({
  counts,
  sizes,
  selected,
  onSelect,
}: {
  counts: number[];
  sizes: number[];
  selected: number | null;
  onSelect: (day: number | null) => void;
}) {
  const [ref, W] = useWidth<HTMLDivElement>(640);
  const [hover, setHover] = useState<number | null>(null);
  const H = 132;
  const PT = 8;
  const PB = 20;
  const PL = 24;
  const n = counts.length;
  const latest = n - 1;
  const band = Math.max(0, W - PL) / n;
  const bw = Math.max(2, band - 2);
  const yMax = Math.max(2, Math.ceil(Math.max(...counts) / 2) * 2);
  const plotH = H - PT - PB;
  const base = PT + plotH;
  const y = (v: number) => base - (v / yMax) * plotH;
  const ticks = [0, yMax / 2, yMax];
  const toggle = (i: number) => onSelect(selected === i ? null : i);

  const opacity = (i: number) => {
    if (hover !== null) return i === hover ? 1 : i === selected ? 0.7 : 0.45;
    if (selected !== null) return i === selected ? 1 : 0.3;
    return i === latest ? 1 : 0.75;
  };

  const hv = hover === null ? null : { i: hover, c: counts[hover] ?? 0, kb: sizes[hover] ?? 0 };

  return (
    <div
      ref={ref}
      tabIndex={0}
      role="group"
      aria-label="Backups per day over the last 30 days. Use the arrow keys to move between days and Enter to filter the list."
      className={cx("relative", chartFocus)}
      onMouseLeave={() => setHover(null)}
      onFocus={() => setHover((h) => h ?? selected ?? latest)}
      onBlur={() => setHover(null)}
      onKeyDown={(e) => {
        if (e.key === "ArrowLeft" || e.key === "ArrowRight") {
          e.preventDefault();
          const step = e.key === "ArrowLeft" ? -1 : 1;
          setHover((h) => clamp((h ?? latest) + step, 0, latest));
        } else if ((e.key === "Enter" || e.key === " ") && hover !== null) {
          e.preventDefault();
          toggle(hover);
        } else if (e.key === "Escape") onSelect(null);
      }}
    >
      <svg width={W} height={H} className="block" aria-hidden>
        {ticks.map((t) => (
          <g key={t}>
            <line
              x1={PL}
              x2={W}
              y1={Math.round(y(t)) + 0.5}
              y2={Math.round(y(t)) + 0.5}
              stroke="var(--st-border)"
              strokeDasharray={t === 0 ? undefined : "2 3"}
            />
            <text x={PL - 8} y={y(t)} dy="0.32em" textAnchor="end" {...axisText}>
              {t}
            </text>
          </g>
        ))}
        {counts.map((c, i) => {
          const x = PL + i * band + (band - bw) / 2;
          return c > 0 ? (
            <path
              key={i}
              d={barPath(x, y(c), bw, base - y(c))}
              fill="var(--st-accent)"
              style={{ opacity: opacity(i), transition: "opacity 120ms" }}
            />
          ) : (
            <rect
              key={i}
              x={x}
              y={base - 2}
              width={bw}
              height={2}
              rx={1}
              fill="var(--st-border-strong)"
              style={{ opacity: hover === i || selected === i ? 1 : 0.7 }}
            />
          );
        })}
        {[1, 8, 15, 22].map((i) => (
          <text key={i} x={PL + (i + 0.5) * band} y={H - 4} textAnchor="middle" {...axisText}>
            {fmtShortDay(i)}
          </text>
        ))}
        <text x={W} y={H - 4} textAnchor="end" {...axisText}>
          Today
        </text>
        {counts.map((_, i) => (
          <rect
            key={i}
            x={PL + i * band}
            y={0}
            width={band}
            height={H}
            fill="transparent"
            className="cursor-pointer"
            onMouseEnter={() => setHover(i)}
            onClick={() => toggle(i)}
          />
        ))}
      </svg>
      {hv ? (
        <ChartTip
          x={PL + (hv.i + 0.5) * band}
          y={y(Math.max(hv.c, yMax / 2))}
          bounds={{ w: W, h: H }}
          place="side"
        >
          <TipTitle>{fmtDay(hv.i)}</TipTitle>
          <TipRow label="Snapshots" value={hv.c} />
          <TipRow label="Total size" value={hv.c ? fmtSize(hv.kb) : "None"} />
          <div className="mt-[4px] text-[11px] text-[var(--st-fg3)]">
            {selected === hv.i ? "Click to clear the filter" : "Click to show this day"}
          </div>
        </ChartTip>
      ) : null}
    </div>
  );
}

/** Area chart with a crosshair that snaps to the nearest day. */
function ConfigSizeChart({ values }: { values: number[] }) {
  const [ref, W] = useWidth<HTMLDivElement>(320);
  const [hover, setHover] = useState<number | null>(null);
  const gradient = `config-size-${useId().replace(/[^\w-]/g, "")}`;
  const H = 136;
  const PT = 8;
  const PB = 20;
  const PL = 40;
  const PR = 6;
  const n = values.length;
  const lo = Math.floor(Math.min(...values) / 5) * 5;
  const hi = Math.ceil(Math.max(...values) / 5) * 5;
  const plotW = Math.max(0, W - PL - PR);
  const plotH = H - PT - PB;
  const base = PT + plotH;
  const step = plotW / (n - 1);
  const x = (i: number) => PL + i * step;
  const y = (v: number) => base - ((v - lo) / (hi - lo || 1)) * plotH;
  const ticks = [lo, (lo + hi) / 2, hi];
  const line = values.map((v, i) => `${i ? "L" : "M"}${x(i)},${y(v)}`).join("");
  const area = `${line}L${x(n - 1)},${base}L${x(0)},${base}Z`;

  const onMove = (e: ReactMouseEvent<SVGSVGElement>) => {
    const r = e.currentTarget.getBoundingClientRect();
    setHover(clamp(Math.round((e.clientX - r.left - PL) / (step || 1)), 0, n - 1));
  };

  const hv = hover === null ? undefined : values[hover];
  const prev = hover === null ? undefined : values[hover - 1];
  const delta = hv !== undefined && prev !== undefined ? hv - prev : null;

  return (
    <div
      ref={ref}
      tabIndex={0}
      role="group"
      aria-label="Config size over the last 30 days. Use the arrow keys to move between days."
      className={cx("relative", chartFocus)}
      onFocus={() => setHover((h) => h ?? n - 1)}
      onBlur={() => setHover(null)}
      onKeyDown={(e) => {
        if (e.key === "ArrowLeft" || e.key === "ArrowRight") {
          e.preventDefault();
          const s = e.key === "ArrowLeft" ? -1 : 1;
          setHover((h) => clamp((h ?? n - 1) + s, 0, n - 1));
        }
      }}
    >
      <svg
        width={W}
        height={H}
        className="block cursor-crosshair"
        aria-hidden
        onMouseMove={onMove}
        onMouseLeave={() => setHover(null)}
      >
        <defs>
          <linearGradient id={gradient} x1="0" x2="0" y1="0" y2="1">
            <stop offset="0%" stopColor="var(--st-accent)" stopOpacity={0.22} />
            <stop offset="100%" stopColor="var(--st-accent)" stopOpacity={0} />
          </linearGradient>
        </defs>
        {ticks.map((t) => (
          <g key={t}>
            <line
              x1={PL}
              x2={W - PR}
              y1={Math.round(y(t)) + 0.5}
              y2={Math.round(y(t)) + 0.5}
              stroke="var(--st-border)"
              strokeDasharray={t === lo ? undefined : "2 3"}
            />
            <text x={PL - 8} y={y(t)} dy="0.32em" textAnchor="end" {...axisText}>
              {t} KB
            </text>
          </g>
        ))}
        <path d={area} fill={`url(#${gradient})`} />
        <path
          d={line}
          fill="none"
          stroke="var(--st-accent)"
          strokeWidth={2}
          strokeLinejoin="round"
          strokeLinecap="round"
        />
        <text x={PL} y={H - 4} textAnchor="start" {...axisText}>
          {fmtShortDay(0)}
        </text>
        <text x={x(Math.floor(n / 2))} y={H - 4} textAnchor="middle" {...axisText}>
          {fmtShortDay(Math.floor(n / 2))}
        </text>
        <text x={W - PR} y={H - 4} textAnchor="end" {...axisText}>
          Today
        </text>
        {hover !== null && hv !== undefined ? (
          <g pointerEvents="none">
            <line
              x1={x(hover)}
              x2={x(hover)}
              y1={PT}
              y2={base}
              stroke="var(--st-border-strong)"
              strokeWidth={1}
            />
            <circle
              cx={x(hover)}
              cy={y(hv)}
              r={4}
              fill="var(--st-accent)"
              stroke="var(--st-bg)"
              strokeWidth={2}
            />
          </g>
        ) : null}
      </svg>
      {hover !== null && hv !== undefined ? (
        <ChartTip x={x(hover)} y={y(hv)} bounds={{ w: W, h: H }} place="side">
          <TipTitle>{fmtDay(hover)}</TipTitle>
          <TipRow label="Config size" value={fmtSize(hv)} />
          {delta !== null ? (
            <TipRow
              label="Change"
              value={delta === 0 ? "None" : `${delta > 0 ? "+" : ""}${delta.toFixed(1)} KB`}
            />
          ) : null}
        </ChartTip>
      ) : null}
    </div>
  );
}

/** Horizontal bars, one per tool, sized by the number of generated files. */
function ToolFilesChart({ tools }: { tools: typeof toolFiles }) {
  const [ref, W] = useWidth<HTMLDivElement>(320);
  const [hover, setHover] = useState<number | null>(null);
  const LW = 92;
  const VW = 28;
  const rowH = 27;
  const barH = 10;
  const H = tools.length * rowH;
  const max = Math.max(...tools.map((t) => t.files), 1);
  const len = (v: number) => Math.max(2, (v / max) * Math.max(0, W - LW - VW));
  const ht = hover === null ? undefined : tools[hover];

  return (
    <div
      ref={ref}
      tabIndex={0}
      role="group"
      aria-label="Generated files by tool. Use the arrow keys to move between tools."
      className={cx("relative", chartFocus)}
      onMouseLeave={() => setHover(null)}
      onFocus={() => setHover((h) => h ?? 0)}
      onBlur={() => setHover(null)}
      onKeyDown={(e) => {
        if (e.key === "ArrowUp" || e.key === "ArrowDown") {
          e.preventDefault();
          const s = e.key === "ArrowUp" ? -1 : 1;
          setHover((h) => clamp((h ?? 0) + s, 0, tools.length - 1));
        }
      }}
    >
      <svg width={W} height={H} className="block" aria-hidden>
        {tools.map((t, i) => {
          const top = i * rowH;
          const mid = top + rowH / 2;
          const dim = hover !== null && hover !== i;
          return (
            <g key={t.name}>
              <rect
                x={LW}
                y={mid - barH / 2}
                width={Math.max(0, W - LW - VW)}
                height={barH}
                rx={3}
                fill="var(--st-muted)"
              />
              <text
                x={0}
                y={mid}
                dy="0.32em"
                fontSize={12}
                fill={hover === i ? "var(--st-fg)" : "var(--st-fg2)"}
              >
                {t.name}
              </text>
              <path
                d={barPath(LW, mid - barH / 2, len(t.files), barH, true)}
                fill="var(--st-accent)"
                style={{ opacity: dim ? 0.45 : 1, transition: "opacity 120ms" }}
              />
              <text
                x={W}
                y={mid}
                dy="0.32em"
                textAnchor="end"
                fontSize={11.5}
                fill={hover === i ? "var(--st-fg)" : "var(--st-fg2)"}
                className="tabular-nums"
              >
                {t.files}
              </text>
              <rect
                x={0}
                y={top}
                width={W}
                height={rowH}
                fill="transparent"
                onMouseEnter={() => setHover(i)}
              />
            </g>
          );
        })}
      </svg>
      {ht && hover !== null ? (
        <ChartTip
          x={LW + len(ht.files) / 2}
          y={hover * rowH + (rowH - barH) / 2}
          below={hover * rowH + (rowH + barH) / 2}
          bounds={{ w: W, h: H }}
          place="above"
        >
          <TipTitle>{ht.name}</TipTitle>
          <TipRow label="Files" value={ht.files} />
          <TipRow label="Lines" value={ht.lines.toLocaleString("en-GB")} />
          <TipRow label="Last written" value={ht.edited} />
        </ChartTip>
      ) : null}
    </div>
  );
}

function SummaryCell({
  icon: Icon,
  label,
  value,
  detail,
}: {
  icon: LucideIcon;
  label: string;
  value: string;
  detail: ReactNode;
}) {
  return (
    <div className="min-w-0 px-[16px] py-[13px]">
      <div className="flex items-center gap-[6px] text-[12px] text-[var(--st-fg2)]">
        <Icon size={13} strokeWidth={1.75} className="text-[var(--st-fg3)]" />
        {label}
      </div>
      <div className="mt-[5px] text-[15px] font-semibold tracking-[-0.01em] tabular-nums text-[var(--st-fg)]">
        {value}
      </div>
      <div className="mt-[1px] truncate text-[11.5px] text-[var(--st-fg3)]">{detail}</div>
    </div>
  );
}

function FileStatus({ state }: { state: FileState }) {
  const { label, dot, text } = {
    generated: { label: "Generated", dot: "bg-[var(--st-fg3)]", text: "text-[var(--st-fg2)]" },
    custom: { label: "Custom edits", dot: "bg-[var(--st-warn)]", text: "text-[var(--st-warn)]" },
    rebuilt: { label: "Rebuilt", dot: "bg-[var(--st-ok)]", text: "text-[var(--st-ok)]" },
  }[state];
  return (
    <span className={cx("inline-flex items-center gap-[7px] text-[12.5px]", text)}>
      <span className={cx("size-[6px] rounded-full", dot)} />
      {label}
    </span>
  );
}

const fileGrid =
  "grid grid-cols-[minmax(0,1fr)_120px_120px_96px] items-center gap-[16px] px-[20px]";

function ConfigFileRow({
  file,
  last,
  open,
  onToggleDiff,
  onRebuild,
}: {
  file: ConfigFile;
  last: boolean;
  open: boolean;
  onToggleDiff: () => void;
  onRebuild: () => void;
}) {
  return (
    <div className={cx(!last && "border-b border-[var(--st-border)]")}>
      <div
        className={cx(
          "group h-[56px] transition-colors hover:bg-[var(--st-side)]",
          fileGrid,
          open && "bg-[var(--st-side)]",
        )}
      >
        <div className="flex min-w-0 items-center gap-[12px]">
          <IconTile icon={file.icon} />
          <div className="min-w-0">
            <div className="flex items-baseline gap-[8px]">
              <span className="font-mono text-[12.5px] font-medium text-[var(--st-fg)]">
                {file.name}
              </span>
              <span className="text-[11.5px] text-[var(--st-fg3)]">{file.tool}</span>
            </div>
            <div className="truncate font-mono text-[11.5px] text-[var(--st-fg3)]">{file.path}</div>
          </div>
        </div>
        <FileStatus state={file.state} />
        <span className="text-[12.5px] tabular-nums text-[var(--st-fg2)]">{file.edited}</span>
        <div
          className={cx(
            "flex items-center justify-end gap-[2px] transition-opacity",
            open
              ? "opacity-100"
              : "opacity-0 group-focus-within:opacity-100 group-hover:opacity-100",
          )}
        >
          <IconButton icon={ExternalLink} label={`Open ${file.name}`} onClick={() => {}} />
          <IconButton icon={Hammer} label={`Rebuild ${file.name}`} onClick={onRebuild} />
          <IconButton
            icon={FileDiff}
            label={open ? "Hide diff" : "Show diff"}
            onClick={onToggleDiff}
            active={open}
          />
        </div>
      </div>
      {open ? (
        <div className="border-t border-[var(--st-border)] bg-[var(--st-side)] px-[20px] py-[12px]">
          {file.diff.length === 0 ? (
            <div className="flex items-center gap-[8px] text-[12.5px] text-[var(--st-fg2)]">
              <Check size={13} className="text-[var(--st-fg3)]" />
              No custom edits
            </div>
          ) : (
            <>
              <div className="mb-[8px] flex items-center justify-between text-[12px] text-[var(--st-fg2)]">
                <span>Rebuilding replaces these edits</span>
                <span className="font-mono text-[11.5px] text-[var(--st-fg3)]">
                  +{file.diff.filter((d) => d.kind === "+").length} -
                  {file.diff.filter((d) => d.kind === "-").length}
                </span>
              </div>
              <div className="overflow-hidden rounded-[8px] border border-[var(--st-border)] bg-[var(--st-bg)] py-[6px] font-mono text-[11.5px] leading-[20px]">
                {file.diff.map((d, i) => (
                  <div
                    key={i}
                    className={cx(
                      "flex gap-[12px] px-[12px]",
                      d.kind === "+" && "bg-[var(--st-ok-soft)]",
                      d.kind === "-" && "bg-[#e5484d]/[0.08]",
                    )}
                  >
                    <span
                      className="w-[16px] shrink-0 text-right tabular-nums text-[var(--st-fg3)] select-none"
                      aria-hidden
                    >
                      {41 + i}
                    </span>
                    <span
                      className="w-[8px] shrink-0 select-none"
                      style={{
                        color:
                          d.kind === "+"
                            ? "var(--st-ok)"
                            : d.kind === "-"
                              ? danger
                              : "var(--st-fg3)",
                      }}
                    >
                      {d.kind === " " ? "" : d.kind}
                    </span>
                    <span className="whitespace-pre text-[var(--st-fg)]">{d.text}</span>
                  </div>
                ))}
              </div>
            </>
          )}
        </div>
      ) : null}
    </div>
  );
}

export function AdvancedPage() {
  const [backups, setBackups] = useState(initialBackups);
  const [files, setFiles] = useState(initialFiles);
  const [diffOpen, setDiffOpen] = useState<string | null>(null);
  const [restored, setRestored] = useState<number | null>(null);
  const [copied, setCopied] = useState(false);
  const [cli, setCli] = useState(true);
  const [armed, setArmed] = useState(false);
  const [confirm, setConfirm] = useState("");
  const [resetDone, setResetDone] = useState(false);
  const [day, setDay] = useState<number | null>(null);
  const [showAll, setShowAll] = useState(false);
  const cliPath = "/opt/homebrew/bin/macarchy";

  const counts = Array.from({ length: DAYS }, () => 0);
  const sizes = Array.from({ length: DAYS }, () => 0);
  for (const b of backups) {
    counts[b.day] = (counts[b.day] ?? 0) + 1;
    sizes[b.day] = (sizes[b.day] ?? 0) + b.kb;
  }
  const totalKb = backups.reduce((s, b) => s + b.kb, 0);
  const dayBackups = day === null ? backups : backups.filter((b) => b.day === day);
  const listed = day === null && !showAll ? dayBackups.slice(0, 5) : dayBackups;
  const totalFiles = toolFiles.reduce((s, t) => s + t.files, 0);
  const sizeNow = configSizes[configSizes.length - 1] ?? 0;
  const sizeGrowth = sizeNow - (configSizes[0] ?? 0);
  const custom = files.filter((f) => f.state === "custom").length;
  const latest = backups[0];
  const latestIsNew = latest !== undefined && latest.id > initialBackups.length;

  const addBackup = (reason: string, n: number, kb: number) =>
    setBackups((list) => [
      {
        id: Math.max(0, ...list.map((b) => b.id)) + 1,
        day: DAYS - 1,
        time: "18:20",
        reason,
        files: n,
        kb,
      },
      ...list,
    ]);

  const rebuild = (name: string) => {
    const f = files.find((x) => x.name === name);
    if (!f) return;
    if (f.state === "custom") addBackup(`Before rebuilding ${name}`, 1, f.kb);
    setFiles((list) =>
      list.map((x) =>
        x.name === name ? { ...x, state: "rebuilt" as const, edited: "Just now", diff: [] } : x,
      ),
    );
  };

  return (
    <>
      <PageHeader title="Advanced" />

      <Card className="mb-[20px] grid grid-cols-4 divide-x divide-[var(--st-border)]">
        <SummaryCell
          icon={Activity}
          label="Services"
          value="3 of 4 running"
          detail={
            <span className="inline-flex items-center gap-[5px] text-[var(--st-warn)]">
              <TriangleAlert size={11} /> skhd is not running
            </span>
          }
        />
        <SummaryCell
          icon={Archive}
          label="Backups"
          value={String(backups.length)}
          detail={`${fmtSize(totalKb)}, kept for 30 days`}
        />
        <SummaryCell
          icon={Clock}
          label="Last backup"
          value={latestIsNew ? "Just now" : "1 hr ago"}
          detail={latest?.reason ?? "None yet"}
        />
        <SummaryCell
          icon={HardDrive}
          label="Config size"
          value={fmtSize(sizeNow)}
          detail={`+${sizeGrowth.toFixed(1)} KB in 30 days`}
        />
      </Card>

      <Card className="mb-[20px] overflow-hidden">
        <CardTitle
          title="Config files"
          action={
            <div className="flex shrink-0 items-center gap-[6px]">
              <Button size="sm" variant="ghost">
                <FolderOpen size={12} /> Open config folder
              </Button>
              <Button size="sm" onClick={() => files.forEach((f) => rebuild(f.name))}>
                <Hammer size={12} /> Rebuild all
              </Button>
            </div>
          }
        />
        <div
          className={cx(
            "h-[32px] border-y border-[var(--st-border)] bg-[var(--st-side)] text-[11.5px] font-medium text-[var(--st-fg3)]",
            fileGrid,
          )}
        >
          <span>File</span>
          <span>Status</span>
          <span>Modified</span>
          <span className="sr-only">Actions</span>
        </div>
        {files.map((f, i) => (
          <ConfigFileRow
            key={f.name}
            file={f}
            last={i === files.length - 1}
            open={diffOpen === f.name}
            onToggleDiff={() => setDiffOpen((o) => (o === f.name ? null : f.name))}
            onRebuild={() => rebuild(f.name)}
          />
        ))}
        {custom > 0 ? (
          <div className="flex items-center gap-[8px] border-t border-[var(--st-border)] px-[20px] py-[10px] text-[12px] text-[var(--st-fg2)]">
            <Info size={13} className="shrink-0 text-[var(--st-fg3)]" />
            {custom === 1 ? "1 file has" : `${custom} files have`} edits made outside Macarchy
          </div>
        ) : null}
      </Card>

      <div className="mb-[20px] grid grid-cols-2 gap-[16px]">
        <Card>
          <CardTitle
            title="Config size, 30 days"
            action={
              <div className="text-right">
                <div className="text-[14px] font-semibold tabular-nums text-[var(--st-fg)]">
                  {fmtSize(sizeNow)}
                </div>
                <div className="text-[11.5px] tabular-nums text-[var(--st-fg3)]">
                  +{sizeGrowth.toFixed(1)} KB
                </div>
              </div>
            }
          />
          <div className="px-[20px] pb-[16px]">
            <ConfigSizeChart values={configSizes} />
          </div>
        </Card>
        <Card>
          <CardTitle
            title="Generated files by tool"
            action={
              <div className="text-right">
                <div className="text-[14px] font-semibold tabular-nums text-[var(--st-fg)]">
                  {totalFiles}
                </div>
                <div className="text-[11.5px] text-[var(--st-fg3)]">files</div>
              </div>
            }
          />
          <div className="px-[20px] pb-[16px]">
            <ToolFilesChart tools={toolFiles} />
          </div>
        </Card>
      </div>

      <Card className="mb-[20px] overflow-hidden">
        <CardTitle
          title="Backups"
          action={
            <span className="text-[12px] tabular-nums text-[var(--st-fg3)]">
              {backups.length} snapshots, {fmtSize(totalKb)}
            </span>
          }
        />
        <div className="px-[20px] pb-[16px]">
          <BackupsChart
            counts={counts}
            sizes={sizes}
            selected={day}
            onSelect={(d) => {
              setDay(d);
              setShowAll(false);
            }}
          />
        </div>
        {day !== null ? (
          <div className="flex items-center gap-[8px] border-t border-[var(--st-border)] bg-[var(--st-side)] px-[20px] py-[8px]">
            <span className="text-[12px] text-[var(--st-fg2)]">Showing</span>
            <span className="inline-flex h-[24px] items-center gap-[6px] rounded-[6px] border border-[var(--st-border)] bg-[var(--st-bg)] pr-[2px] pl-[8px] text-[12px] font-medium text-[var(--st-fg)] shadow-[var(--st-shadow)]">
              <CalendarDays size={12} className="text-[var(--st-fg3)]" />
              {fmtDay(day)}
              <button
                type="button"
                aria-label="Clear day filter"
                onClick={() => setDay(null)}
                className={cx(
                  "grid size-[20px] place-items-center rounded-[4px] text-[var(--st-fg3)] hover:bg-[var(--st-hover)] hover:text-[var(--st-fg)]",
                  focusRing,
                )}
              >
                <X size={11} />
              </button>
            </span>
            <span className="ml-auto text-[12px] tabular-nums text-[var(--st-fg3)]">
              {dayBackups.length} {dayBackups.length === 1 ? "backup" : "backups"}
              {dayBackups.length ? `, ${fmtSize(sizes[day] ?? 0)}` : ""}
            </span>
          </div>
        ) : null}
        <div className="border-t border-[var(--st-border)]">
          {dayBackups.length === 0 ? (
            <div className="p-[16px]">
              {day === null ? (
                <Empty icon={Archive} title="No backups yet" />
              ) : (
                <Empty icon={CalendarDays} title={`No backups on ${fmtDay(day)}`} />
              )}
            </div>
          ) : (
            listed.map((b, i) => (
              <div
                key={b.id}
                className={cx(
                  "group flex h-[52px] items-center gap-[12px] px-[20px] transition-colors hover:bg-[var(--st-side)]",
                  i < listed.length - 1 && "border-b border-[var(--st-border)]",
                )}
              >
                <IconTile icon={Archive} size={26} />
                <div className="min-w-0 flex-1">
                  <div className="truncate text-[13px] text-[var(--st-fg)]">{b.reason}</div>
                  <div className="text-[11.5px] tabular-nums text-[var(--st-fg3)]">
                    {b.files} {b.files === 1 ? "file" : "files"}, {fmtSize(b.kb)}
                  </div>
                </div>
                <span className="text-[12.5px] tabular-nums text-[var(--st-fg2)]">
                  {fmtWhen(b.day, b.time)}
                </span>
                <div className="flex w-[124px] items-center justify-end gap-[2px]">
                  {restored === b.id ? (
                    <Badge tone="ok">
                      <Check size={11} /> Restored
                    </Badge>
                  ) : (
                    <div className="opacity-0 transition-opacity group-focus-within:opacity-100 group-hover:opacity-100">
                      <Button size="sm" onClick={() => setRestored(b.id)}>
                        <RotateCcw size={12} /> Restore
                      </Button>
                    </div>
                  )}
                  <div className="opacity-0 transition-opacity group-focus-within:opacity-100 group-hover:opacity-100">
                    <IconButton
                      icon={X}
                      label="Delete backup"
                      onClick={() => setBackups((list) => list.filter((x) => x.id !== b.id))}
                    />
                  </div>
                </div>
              </div>
            ))
          )}
        </div>
        {day === null && backups.length > 5 ? (
          <button
            type="button"
            onClick={() => setShowAll((s) => !s)}
            className={cx(
              "flex h-[36px] w-full items-center justify-center border-t border-[var(--st-border)] text-[12.5px] font-medium text-[var(--st-fg2)] transition-colors hover:bg-[var(--st-hover)] hover:text-[var(--st-fg)]",
              focusRing,
            )}
          >
            {showAll ? "Show fewer" : `Show all ${backups.length} backups`}
          </button>
        ) : null}
      </Card>

      <Card className="mb-[28px] flex items-center gap-[14px] px-[20px] py-[16px]">
        <IconTile icon={SquareTerminal} size={32} />
        <div className="min-w-0 flex-1">
          <div className="text-[13px] font-medium text-[var(--st-fg)]">Command line</div>
          <div className="mt-[2px] font-mono text-[11.5px] text-[var(--st-fg2)]">macarchy</div>
        </div>
        {cli ? (
          <span className="inline-flex h-[28px] shrink-0 items-center gap-[6px] rounded-[7px] border border-[var(--st-border)] bg-[var(--st-side)] pr-[2px] pl-[10px] font-mono text-[12px] text-[var(--st-fg)]">
            {cliPath}
            <button
              type="button"
              aria-label={copied ? "Copied" : "Copy path"}
              title={copied ? "Copied" : "Copy path"}
              onClick={() => {
                copyText(cliPath);
                setCopied(true);
                setTimeout(() => setCopied(false), 1500);
              }}
              className={cx(
                "grid size-[22px] place-items-center rounded-[5px] text-[var(--st-fg3)] transition-colors hover:bg-[var(--st-hover)] hover:text-[var(--st-fg)]",
                focusRing,
              )}
            >
              {copied ? <Check size={12} className="text-[var(--st-ok)]" /> : <Copy size={12} />}
            </button>
          </span>
        ) : (
          <span className="shrink-0 text-[12.5px] text-[var(--st-fg3)]">Not installed</span>
        )}
        <Switch checked={cli} onChange={setCli} label="Install the macarchy command" />
      </Card>

      <SectionLabel>Danger zone</SectionLabel>
      <section className="overflow-hidden rounded-[10px] border border-[#e5484d]/30 bg-[#e5484d]/[0.025]">
        <div className="flex items-start gap-[14px] px-[20px] py-[16px]">
          <IconTile icon={RotateCcw} size={32} tone="danger" />
          <div className="min-w-0 flex-1">
            <h2 className="text-[13.5px] font-semibold text-[var(--st-fg)]">Reset to defaults</h2>
            <p className="mt-[3px] max-w-[460px] text-[12.5px] leading-[1.5] text-[var(--st-fg2)]">
              Replaces all {files.length} config files. Themes, wallpapers and backups are kept.
            </p>
          </div>
          {!armed && !resetDone ? (
            <button
              type="button"
              onClick={() => setArmed(true)}
              className={cx(
                "h-[30px] shrink-0 rounded-[7px] border border-[#e5484d]/40 bg-[var(--st-bg)] px-[12px] text-[12.5px] font-medium text-[#e5484d] shadow-[var(--st-shadow)] transition-colors hover:bg-[#e5484d]/[0.08]",
                focusRing,
              )}
            >
              Reset to defaults
            </button>
          ) : null}
        </div>
        {armed ? (
          <div className="border-t border-[#e5484d]/20 px-[20px] py-[14px] pl-[66px]">
            <label
              htmlFor="reset-confirm"
              className="mb-[8px] block text-[12.5px] text-[var(--st-fg2)]"
            >
              Type{" "}
              <code className="rounded-[4px] bg-[var(--st-muted)] px-[5px] py-[1px] font-mono text-[11.5px] text-[var(--st-fg)]">
                reset
              </code>{" "}
              to confirm.
            </label>
            <div className="flex items-center gap-[8px]">
              <input
                id="reset-confirm"
                autoFocus
                value={confirm}
                onChange={(e) => setConfirm(e.target.value)}
                onKeyDown={(e) => {
                  if (e.key === "Escape") {
                    setArmed(false);
                    setConfirm("");
                  }
                }}
                placeholder="reset"
                spellCheck={false}
                className={cx(fieldCls, "h-[32px] max-w-[220px] font-mono text-[12px]")}
              />
              <button
                type="button"
                disabled={confirm.trim().toLowerCase() !== "reset"}
                onClick={() => {
                  addBackup("Before reset to defaults", files.length, 37.3);
                  setFiles((list) =>
                    list.map((f) => ({
                      ...f,
                      state: "generated" as const,
                      edited: "Just now",
                      diff: [],
                    })),
                  );
                  setResetDone(true);
                  setArmed(false);
                  setConfirm("");
                }}
                className={cx(
                  "h-[32px] rounded-[7px] px-[12px] text-[12.5px] font-medium text-white shadow-[var(--st-shadow)] transition-opacity hover:opacity-90 disabled:opacity-40",
                  focusRing,
                )}
                style={{ background: danger }}
              >
                Reset everything
              </button>
              <Button
                variant="ghost"
                onClick={() => {
                  setArmed(false);
                  setConfirm("");
                }}
              >
                Cancel
              </Button>
            </div>
          </div>
        ) : null}
        {resetDone ? (
          <div className="flex items-center gap-[8px] border-t border-[#e5484d]/20 px-[20px] py-[12px] pl-[66px] text-[12.5px] text-[var(--st-fg2)]">
            <CircleCheck size={14} className="text-[var(--st-ok)]" />
            <span className="flex-1">Reset complete</span>
            <Button size="sm" variant="ghost" onClick={() => setResetDone(false)}>
              Dismiss
            </Button>
          </div>
        ) : null}
      </section>
    </>
  );
}

/* ------------------------------------------------------------------ */
/* Report a problem                                                    */
/* ------------------------------------------------------------------ */

const areas = [
  { id: "Menu bar", icon: PanelTop },
  { id: "Windows", icon: AppWindow },
  { id: "Shortcuts", icon: Keyboard },
  { id: "Themes", icon: Palette },
  { id: "Other", icon: CircleQuestionMark },
] as const;
type Area = (typeof areas)[number]["id"];

const SUMMARY_MAX = 80;

const diagnosticsInfo = [
  ["Macarchy", "0.9.2"],
  ["macOS", "27.0 (25A101)"],
  ["AeroSpace", "0.19.2, running"],
  ["SketchyBar", "2.22.1, running"],
  ["JankyBorders", "1.8.0, running"],
  ["skhd", "0.3.9, not running"],
  ["Setup health", "2 checks need attention"],
] as const;

const configInfo = [
  ["aerospace.toml", `${snapshot.layout.layout}, gaps ${snapshot.layout.window_gap}`],
  ["sketchybarrc", `${snapshot.menuBar.position}, ${snapshot.menuBar.height}px high`],
  ["bordersrc", `${snapshot.borders.border_style}, ${snapshot.borders.border_width}px wide`],
] as const;

interface Shot {
  id: number;
  url: string;
  name: string;
  kb: number;
}

const sampleShot = wallpaperUrl(currentThemeId, "1-dark-waters");

function Step({
  n,
  title,
  hint,
  done,
  optional,
  last,
  children,
}: {
  n: number;
  title: string;
  hint?: string;
  done: boolean;
  optional?: boolean;
  last?: boolean;
  children: ReactNode;
}) {
  return (
    <div
      className={cx(
        "relative grid grid-cols-[22px_minmax(0,1fr)] gap-[14px]",
        !last && "pb-[24px]",
      )}
    >
      {!last ? (
        <span
          aria-hidden
          className="absolute top-[28px] bottom-[4px] left-[10.5px] w-px bg-[var(--st-border)]"
        />
      ) : null}
      <span
        className={cx(
          "grid size-[22px] place-items-center rounded-full text-[11px] font-semibold tabular-nums transition-colors",
          done
            ? "bg-[var(--st-accent)] text-[var(--st-accent-fg)]"
            : "border border-[var(--st-border-strong)] bg-[var(--st-bg)] text-[var(--st-fg2)]",
        )}
      >
        {done ? <Check size={12} strokeWidth={2.5} /> : n}
      </span>
      <div className="min-w-0">
        <div className="flex items-baseline gap-[8px] pt-[2px]">
          <h3 className="text-[13.5px] font-semibold tracking-[-0.01em] text-[var(--st-fg)]">
            {title}
          </h3>
          {optional ? <span className="text-[11.5px] text-[var(--st-fg3)]">Optional</span> : null}
        </div>
        {hint ? <p className="mt-[2px] text-[12px] text-[var(--st-fg2)]">{hint}</p> : null}
        <div className="mt-[12px]">{children}</div>
      </div>
    </div>
  );
}

function AttachToggle({
  label,
  checked,
  onChange,
  items,
  last,
}: {
  label: string;
  checked: boolean;
  onChange: (v: boolean) => void;
  items: readonly (readonly [string, string])[];
  last?: boolean;
}) {
  const [open, setOpen] = useState(false);
  return (
    <div className={cx("px-[14px] py-[12px]", !last && "border-b border-[var(--st-border)]")}>
      <div className="flex items-start justify-between gap-[16px]">
        <div className="min-w-0">
          <div className="text-[13px] font-medium text-[var(--st-fg)]">{label}</div>
          <button
            type="button"
            aria-expanded={open}
            onClick={() => setOpen((o) => !o)}
            className={cx(
              "mt-[6px] -ml-[4px] inline-flex h-[22px] items-center gap-[4px] rounded-[5px] px-[4px] text-[12px] font-medium text-[var(--st-fg2)] transition-colors hover:text-[var(--st-fg)]",
              focusRing,
            )}
          >
            <ChevronRight
              size={12}
              className={cx("transition-transform duration-150", open && "rotate-90")}
            />
            What's included
          </button>
        </div>
        <Switch checked={checked} onChange={onChange} label={label} />
      </div>
      {open ? (
        <dl
          className={cx(
            "mt-[8px] grid grid-cols-[auto_minmax(0,1fr)] gap-x-[16px] gap-y-[3px] rounded-[7px] border border-[var(--st-border)] bg-[var(--st-side)] px-[12px] py-[10px] font-mono text-[11.5px] transition-opacity",
            !checked && "opacity-50",
          )}
        >
          {items.map(([k, v]) => (
            <div key={k} className="contents">
              <dt className="text-[var(--st-fg3)]">{k}</dt>
              <dd className="truncate text-[var(--st-fg)]">{v}</dd>
            </div>
          ))}
        </dl>
      ) : null}
    </div>
  );
}

export function ReportPage() {
  const [area, setArea] = useState<Area>("Menu bar");
  const [summary, setSummary] = useState("");
  const [body, setBody] = useState("");
  const [shots, setShots] = useState<Shot[]>([]);
  const [dragging, setDragging] = useState(false);
  const [diagnostics, setDiagnostics] = useState(true);
  const [configs, setConfigs] = useState(false);
  const [sent, setSent] = useState(false);
  const [copied, setCopied] = useState(false);
  const fileInput = useRef<HTMLInputElement>(null);
  const nextId = useRef(1);
  const title = summary.trim();
  const ready = title.length > 0;

  const addFiles = (list: FileList | null) => {
    if (!list) return;
    const added = Array.from(list)
      .filter((f) => f.type.startsWith("image/"))
      .map((f) => ({
        id: nextId.current++,
        url: URL.createObjectURL(f),
        name: f.name,
        kb: f.size / 1024,
      }));
    setShots((s) => [...s, ...added].slice(0, 6));
  };
  const removeShot = (id: number) =>
    setShots((s) => {
      const gone = s.find((x) => x.id === id);
      if (gone?.url.startsWith("blob:")) URL.revokeObjectURL(gone.url);
      return s.filter((x) => x.id !== id);
    });
  const onDrop = (e: ReactDragEvent<HTMLDivElement>) => {
    e.preventDefault();
    setDragging(false);
    addFiles(e.dataTransfer.files);
  };

  const markdown = [
    `## ${title || "Short summary"}`,
    `Area: ${area}`,
    "",
    body.trim() || "What happened, and what you expected.",
    ...(shots.length ? ["", "### Screenshots", ...shots.map((s) => `- ${s.name}`)] : []),
    ...(diagnostics
      ? ["", "### Diagnostics", ...diagnosticsInfo.map(([k, v]) => `- ${k}: ${v}`)]
      : []),
    ...(configs ? ["", "### Config files", ...configInfo.map(([k, v]) => `- ${k} (${v})`)] : []),
  ].join("\n");

  const header = <PageHeader title="Report a problem" />;

  if (sent) {
    const included = [
      `Area: ${area}`,
      shots.length ? `${shots.length} ${shots.length === 1 ? "screenshot" : "screenshots"}` : null,
      diagnostics ? "Diagnostics" : null,
      configs ? "Config files" : null,
    ].filter((x): x is string => x !== null);
    return (
      <>
        {header}
        <Card className="mx-auto mt-[24px] max-w-[460px] overflow-hidden">
          <div className="px-[32px] pt-[32px] pb-[24px] text-center">
            <span className="mx-auto mb-[14px] grid size-[44px] place-items-center rounded-full bg-[var(--st-ok-soft)] text-[var(--st-ok)]">
              <CircleCheck size={20} />
            </span>
            <div className="text-[16px] font-semibold tracking-[-0.01em] text-[var(--st-fg)]">
              Issue opened on GitHub
            </div>
          </div>
          <div className="mx-[24px] mb-[24px] rounded-[9px] border border-[var(--st-border)] bg-[var(--st-side)] px-[14px] py-[12px]">
            <div className="truncate text-[13px] font-medium text-[var(--st-fg)]">{title}</div>
            <div className="mt-[8px] flex flex-wrap gap-[6px]">
              {included.map((x) => (
                <Chip key={x}>
                  <Check size={11} className="text-[var(--st-fg3)]" /> {x}
                </Chip>
              ))}
            </div>
          </div>
          <div className="flex items-center justify-between gap-[8px] border-t border-[var(--st-border)] bg-[var(--st-side)] px-[24px] py-[12px]">
            <Button variant="ghost" onClick={() => setSent(false)}>
              Back to report
            </Button>
            <Button
              onClick={() => {
                shots.forEach((s) => s.url.startsWith("blob:") && URL.revokeObjectURL(s.url));
                setShots([]);
                setSummary("");
                setBody("");
                setSent(false);
              }}
            >
              Write another report
            </Button>
          </div>
        </Card>
      </>
    );
  }

  return (
    <>
      {header}

      <div className="flex flex-col gap-[14px]">
        <Card className="px-[24px] py-[22px]">
          <Step n={1} title="What is it about?" done>
            <div role="radiogroup" aria-label="Area" className="grid grid-cols-5 gap-[8px]">
              {areas.map((a) => {
                const on = a.id === area;
                const Icon = a.icon;
                return (
                  <button
                    key={a.id}
                    type="button"
                    role="radio"
                    aria-checked={on}
                    onClick={() => setArea(a.id)}
                    className={cx(
                      "flex h-[68px] flex-col items-center justify-center gap-[7px] rounded-[9px] border text-[12px] font-medium transition-[border-color,background-color,color,box-shadow]",
                      focusRing,
                      on
                        ? "border-[var(--st-accent)] bg-[var(--st-accent-soft)] text-[var(--st-fg)] shadow-[0_0_0_1px_var(--st-accent)]"
                        : "border-[var(--st-border)] bg-[var(--st-bg)] text-[var(--st-fg2)] shadow-[var(--st-shadow)] hover:border-[var(--st-border-strong)] hover:text-[var(--st-fg)]",
                    )}
                  >
                    <Icon
                      size={17}
                      strokeWidth={1.75}
                      className={on ? "text-[var(--st-accent-text)]" : "text-[var(--st-fg3)]"}
                    />
                    {a.id}
                  </button>
                );
              })}
            </div>
          </Step>

          <Step n={2} title="Describe it" done={ready}>
            <label
              htmlFor="report-summary"
              className="mb-[6px] flex items-baseline justify-between text-[12px] font-medium text-[var(--st-fg2)]"
            >
              Summary
              <span
                className={cx(
                  "font-normal tabular-nums",
                  summary.length >= SUMMARY_MAX - 10
                    ? "text-[var(--st-fg2)]"
                    : "text-[var(--st-fg3)]",
                )}
              >
                {summary.length}/{SUMMARY_MAX}
              </span>
            </label>
            <input
              id="report-summary"
              value={summary}
              maxLength={SUMMARY_MAX}
              onChange={(e) => setSummary(e.target.value)}
              placeholder="Menu bar disappears after sleep"
              className={cx(fieldCls, "h-[34px]")}
            />

            <div className="mt-[16px] mb-[6px] flex items-center justify-between text-[12px] font-medium text-[var(--st-fg2)]">
              <label htmlFor="report-body">What happened, and what you expected</label>
              <button
                type="button"
                onClick={() =>
                  setBody(
                    (b) =>
                      `${b.trimEnd()}${b.trim() ? "\n\n" : ""}Steps to reproduce:\n1. \n2. \n3. \n\nExpected:\n`,
                  )
                }
                className={cx(
                  "inline-flex h-[22px] items-center gap-[5px] rounded-[5px] px-[6px] font-medium text-[var(--st-fg2)] transition-colors hover:bg-[var(--st-hover)] hover:text-[var(--st-fg)]",
                  focusRing,
                )}
              >
                <ListOrdered size={12} /> Add steps
              </button>
            </div>
            <textarea
              id="report-body"
              value={body}
              onChange={(e) => setBody(e.target.value)}
              rows={5}
              placeholder="Steps to reproduce"
              className={cx(fieldCls, "resize-none py-[8px] leading-[1.5]")}
            />
          </Step>

          <Step n={3} title="Screenshots" done={shots.length > 0} optional>
            <div
              role="button"
              tabIndex={0}
              onClick={() => fileInput.current?.click()}
              onKeyDown={(e) => {
                if (e.key === "Enter" || e.key === " ") {
                  e.preventDefault();
                  fileInput.current?.click();
                }
              }}
              onDragOver={(e) => {
                e.preventDefault();
                setDragging(true);
              }}
              onDragLeave={() => setDragging(false)}
              onDrop={onDrop}
              className={cx(
                "flex cursor-pointer items-center gap-[12px] rounded-[9px] border border-dashed px-[16px] py-[14px] transition-colors",
                focusRing,
                dragging
                  ? "border-[var(--st-accent)] bg-[var(--st-accent-soft)]"
                  : "border-[var(--st-border-strong)] bg-[var(--st-side)] hover:border-[var(--st-fg3)]",
              )}
            >
              <IconTile icon={ImagePlus} size={32} tone={dragging ? "accent" : "neutral"} />
              <div className="min-w-0 flex-1">
                <div className="text-[13px] font-medium text-[var(--st-fg)]">
                  {dragging ? "Drop to attach" : "Drop screenshots here, or browse"}
                </div>
                <div className="text-[12px] text-[var(--st-fg3)]">PNG or JPG, up to 6 images</div>
              </div>
              {sampleShot && !shots.some((s) => s.url === sampleShot) ? (
                <span onClick={(e) => e.stopPropagation()} onKeyDown={(e) => e.stopPropagation()}>
                  <Button
                    size="sm"
                    onClick={() => {
                      setShots((s) => [
                        ...s,
                        {
                          id: nextId.current++,
                          url: sampleShot,
                          name: "Screenshot 2026-10-21 at 18.02.png",
                          kb: 1184,
                        },
                      ]);
                    }}
                  >
                    Attach last screenshot
                  </Button>
                </span>
              ) : null}
              <input
                ref={fileInput}
                type="file"
                accept="image/*"
                multiple
                hidden
                onChange={(e) => {
                  addFiles(e.target.files);
                  e.target.value = "";
                }}
              />
            </div>
            {shots.length ? (
              <div className="mt-[10px] grid grid-cols-3 gap-[10px]">
                {shots.map((s) => (
                  <figure
                    key={s.id}
                    className="group relative overflow-hidden rounded-[8px] border border-[var(--st-border)] bg-[var(--st-bg)] shadow-[var(--st-shadow)]"
                  >
                    <div className="aspect-[16/10] overflow-hidden bg-[var(--st-muted)]">
                      <img src={s.url} alt="" className="size-full object-cover" />
                    </div>
                    <figcaption className="flex items-center gap-[6px] px-[8px] py-[6px] text-[11.5px]">
                      <span className="min-w-0 flex-1 truncate text-[var(--st-fg)]">{s.name}</span>
                      <span className="shrink-0 tabular-nums text-[var(--st-fg3)]">
                        {fmtSize(s.kb)}
                      </span>
                    </figcaption>
                    <button
                      type="button"
                      aria-label={`Remove ${s.name}`}
                      onClick={() => removeShot(s.id)}
                      className={cx(
                        "absolute top-[6px] right-[6px] grid size-[22px] place-items-center rounded-[6px] border border-[var(--st-border)] bg-[var(--st-bg)] text-[var(--st-fg2)] opacity-0 shadow-[var(--st-shadow)] transition-opacity group-hover:opacity-100 hover:text-[var(--st-fg)] focus-visible:opacity-100",
                        focusRing,
                      )}
                    >
                      <X size={12} />
                    </button>
                  </figure>
                ))}
              </div>
            ) : null}
          </Step>

          <Step n={4} title="Diagnostics" done={diagnostics || configs} last>
            <div className="overflow-hidden rounded-[9px] border border-[var(--st-border)]">
              <AttachToggle
                label="Attach diagnostics"
                checked={diagnostics}
                onChange={setDiagnostics}
                items={diagnosticsInfo}
              />
              <AttachToggle
                label="Attach config files"
                checked={configs}
                onChange={setConfigs}
                items={configInfo}
                last
              />
            </div>
            <p className="mt-[10px] flex items-center gap-[6px] text-[12px] text-[var(--st-fg3)]">
              <ShieldCheck size={13} className="shrink-0" />
              Never includes logs, personal files or window titles.
            </p>
          </Step>
        </Card>

        <div className="flex items-center gap-[10px]">
          <p className="flex min-w-0 flex-1 items-center gap-[6px] text-[12px] text-[var(--st-fg3)]">
            {ready ? null : (
              <>
                <Info size={13} className="shrink-0" /> Summary required
              </>
            )}
          </p>
          <Button
            variant="ghost"
            onClick={() => {
              copyText(markdown);
              setCopied(true);
              setTimeout(() => setCopied(false), 1500);
            }}
          >
            {copied ? <Check size={13} /> : <Copy size={13} />}
            {copied ? "Copied" : "Copy as Markdown"}
          </Button>
          <Button variant="primary" disabled={!ready} onClick={() => setSent(true)}>
            <Send size={13} /> Open on GitHub
          </Button>
        </div>
      </div>
    </>
  );
}
