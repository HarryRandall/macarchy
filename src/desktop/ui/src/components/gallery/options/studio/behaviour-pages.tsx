import {
  AppWindow,
  Check,
  ChevronRight,
  ChevronsUpDown,
  CircleAlert,
  CircleCheck,
  CircleX,
  Clock,
  Copy,
  Keyboard,
  LayoutGrid,
  Loader2,
  Play,
  Plus,
  RotateCcw,
  RotateCw,
  Search,
  SearchX,
  Settings2,
  Trash2,
  TriangleAlert,
  Wrench,
  X,
} from "lucide-react";
import { type ReactNode, useCallback, useEffect, useId, useRef, useState } from "react";

import { shortcuts } from "../data";
import { appIconUrl, snapshot } from "../real";
import {
  Badge,
  Button,
  Card,
  PageHeader,
  Row,
  Switch,
  Tabs,
  cx,
  focusRing,
  usePageSearch,
  useWidth,
} from "./ui";

/* ------------------------------------------------------------------------ */
/* Shared local pieces                                                       */
/* ------------------------------------------------------------------------ */

const danger = "var(--st-danger, #ef4444)";

function FieldLabel({ children, hint }: { children: ReactNode; hint?: string }) {
  return (
    <div className="mb-1.5 flex items-baseline justify-between">
      <span className="text-[12px] font-medium text-[var(--st-fg)]">{children}</span>
      {hint ? <span className="text-[11px] text-[var(--st-fg3)]">{hint}</span> : null}
    </div>
  );
}

function EmptyState({
  icon,
  title,
  children,
}: {
  icon: ReactNode;
  title: string;
  children?: ReactNode;
}) {
  return (
    <div className="flex flex-col items-center px-6 py-12 text-center">
      <div className="mb-3 flex size-10 items-center justify-center rounded-[10px] border border-[var(--st-border)] bg-[var(--st-side)] text-[var(--st-fg2)] shadow-[var(--st-shadow)]">
        {icon}
      </div>
      <div className="text-[13.5px] font-medium text-[var(--st-fg)]">{title}</div>
      {children ? <div className="mt-4 flex gap-2">{children}</div> : null}
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

/** Rounds a raw tick step up to 1, 2, 2.5 or 5 times a power of ten. */
function niceStep(raw: number) {
  const p = 10 ** Math.floor(Math.log10(Math.max(raw, 1e-6)));
  return [1, 2, 2.5, 5, 10].map((m) => m * p).find((s) => s >= raw) ?? 10 * p;
}

/** Deterministic noise in [0, 1) for plausible mock series. */
function noise(seed: number, i: number) {
  const s = Math.sin(seed * 12.9898 + i * 78.233) * 43758.5453;
  return s - Math.floor(s);
}

/** Single-series line chart with an optional area fill and a crosshair that snaps to the nearest point. */
function LineChart({
  values,
  dateOf,
  format,
  label,
  height = 120,
  area = false,
  ticks = 3,
}: {
  values: number[];
  dateOf: (i: number, long?: boolean) => string;
  format: (v: number) => string;
  label: string;
  height?: number;
  area?: boolean;
  ticks?: number;
}) {
  const [ref, width] = useWidth<HTMLDivElement>(300);
  const [hover, setHover] = useState<number | null>(null);
  const gradient = useId();
  const padT = 8;
  const padB = 20;
  const padL = 34;
  const padR = 6;
  const n = values.length;
  const plotW = Math.max(0, width - padL - padR);
  const plotH = height - padT - padB;
  const step = niceStep(Math.max(1, ...values) / ticks);
  const top = step * ticks;
  const x = (i: number) => padL + (n < 2 ? plotW / 2 : (i / (n - 1)) * plotW);
  const y = (v: number) => padT + plotH - (v / top) * plotH;
  const line = values
    .map((v, i) => `${i ? "L" : "M"}${x(i).toFixed(1)} ${y(v).toFixed(1)}`)
    .join("");
  const fill = `${line}L${x(n - 1).toFixed(1)} ${y(0)}L${x(0).toFixed(1)} ${y(0)}Z`;
  const tipW = 116;
  const hovered = hover === null ? undefined : values[hover];

  let tipLeft = 0;
  if (hover !== null) {
    const px = x(hover);
    tipLeft = px + 10 + tipW <= width ? px + 10 : Math.max(0, px - 10 - tipW);
  }

  return (
    <div ref={ref} className="relative" onMouseLeave={() => setHover(null)}>
      <svg width={width} height={height} className="block" role="img" aria-label={label}>
        <defs>
          <linearGradient id={gradient} x1="0" x2="0" y1="0" y2="1">
            <stop offset="0%" stopColor="var(--st-accent)" stopOpacity={0.2} />
            <stop offset="100%" stopColor="var(--st-accent)" stopOpacity={0} />
          </linearGradient>
        </defs>
        {Array.from({ length: ticks + 1 }, (_, k) => k * step).map((t) => (
          <g key={t}>
            <line
              x1={padL}
              x2={width - padR}
              y1={y(t)}
              y2={y(t)}
              stroke="var(--st-border)"
              strokeOpacity={t === 0 ? 1 : 0.6}
            />
            <text
              x={padL - 8}
              y={y(t)}
              dy="0.32em"
              textAnchor="end"
              fontSize="10"
              fill="var(--st-fg3)"
              style={{ fontVariantNumeric: "tabular-nums" }}
            >
              {t >= 1000 ? `${t / 1000}k` : t}
            </text>
          </g>
        ))}
        {area ? <path d={fill} fill={`url(#${gradient})`} /> : null}
        <path
          d={line}
          fill="none"
          stroke="var(--st-accent)"
          strokeWidth={2}
          strokeLinejoin="round"
          strokeLinecap="round"
        />
        {n > 0 ? (
          <>
            <text x={x(0)} y={height - 5} fontSize="10" fill="var(--st-fg3)">
              {dateOf(0)}
            </text>
            <text x={x(n - 1)} y={height - 5} textAnchor="end" fontSize="10" fill="var(--st-fg3)">
              {dateOf(n - 1)}
            </text>
          </>
        ) : null}
        {hover !== null && hovered !== undefined ? (
          <g pointerEvents="none">
            <line
              x1={x(hover)}
              x2={x(hover)}
              y1={padT}
              y2={y(0)}
              stroke="var(--st-fg3)"
              strokeOpacity={0.5}
              strokeDasharray="3 3"
            />
            <circle
              cx={x(hover)}
              cy={y(hovered)}
              r={4}
              fill="var(--st-accent)"
              stroke="var(--st-bg)"
              strokeWidth={2}
            />
          </g>
        ) : null}
        <rect
          x={padL - 6}
          y={0}
          width={Math.max(0, plotW + 12)}
          height={height}
          fill="transparent"
          onMouseMove={(e) => {
            const r = e.currentTarget.getBoundingClientRect();
            const scale = r.width > 0 ? (plotW + 12) / r.width : 1;
            const px = (e.clientX - r.left) * scale - 6;
            const i = Math.round((px / Math.max(1, plotW)) * (n - 1));
            setHover(Math.max(0, Math.min(n - 1, i)));
          }}
        />
      </svg>
      {hover !== null && hovered !== undefined ? (
        <ChartTooltip left={tipLeft} top={padT} width={tipW}>
          <div className="text-[11px] text-[var(--st-fg2)]">{dateOf(hover, true)}</div>
          <div className="mt-0.5 font-medium tabular-nums">{format(hovered)}</div>
        </ChartTooltip>
      ) : null}
    </div>
  );
}

/* ------------------------------------------------------------------------ */
/* Rules                                                                     */
/* ------------------------------------------------------------------------ */

interface InstalledApp {
  app: string;
  bundle: string;
}

/** Apps installed on this Mac; each has a real icon from appIconUrl. */
const installedApps: InstalledApp[] = [
  { app: "Calendar", bundle: "com.apple.iCal" },
  { app: "Cursor", bundle: "com.todesktop.230313mt4c5bs" },
  { app: "FaceTime", bundle: "com.apple.FaceTime" },
  { app: "Finder", bundle: "com.apple.finder" },
  { app: "Ghostty", bundle: "com.mitchellh.ghostty" },
  { app: "Google Chrome", bundle: "com.google.Chrome" },
  { app: "iPhone Mirroring", bundle: "com.apple.ScreenContinuity" },
  { app: "Macarchy", bundle: "dev.macarchy.settings" },
  { app: "Mail", bundle: "com.apple.mail" },
  { app: "Messages", bundle: "com.apple.MobileSMS" },
  { app: "Music", bundle: "com.apple.Music" },
  { app: "Notes", bundle: "com.apple.Notes" },
  { app: "Safari", bundle: "com.apple.Safari" },
  { app: "Spotify", bundle: "com.spotify.client" },
  { app: "System Settings", bundle: "com.apple.systempreferences" },
  { app: "TablePlus", bundle: "com.tinyapp.TablePlus" },
  { app: "Visual Studio Code", bundle: "com.microsoft.VSCode" },
];

/** Apps named in rules that are not installed, so they show a letter tile. */
const otherApps: Record<string, { bundle: string; hue: number }> = {
  Slack: { bundle: "com.tinyspeck.slackmacgap", hue: 292 },
};

const suggestedFloating = ["System Settings", "Calendar", "Messages", "Finder", "Notes", "Music"];

const workspaceNames: Record<string, string> = {
  "1": "Terminal",
  "2": "Browser",
  "3": "Chat",
  "4": "Code",
  "5": "Design",
  "6": "Notes",
  "7": "Mail",
  "8": "Calls",
  "9": "Music",
};

const bundleOf = (app: string) =>
  installedApps.find((a) => a.app === app)?.bundle ??
  otherApps[app]?.bundle ??
  `com.example.${app.toLowerCase().replace(/\W+/g, "")}`;

const isInstalled = (app: string) => installedApps.some((a) => a.app === app);

function hueFor(app: string) {
  return otherApps[app]?.hue ?? [...app].reduce((h, c) => (h * 31 + c.charCodeAt(0)) % 360, 7);
}

/**
 * The app's real icon, or a coloured letter tile when it is not installed.
 * macOS icons leave a transparent margin, so the tile is inset to match.
 */
function AppIcon({ app, size = 28 }: { app: string; size?: number }) {
  const src = appIconUrl(app);
  const [failed, setFailed] = useState<string | undefined>(undefined);
  if (src && failed !== src) {
    return (
      <img
        src={src}
        alt=""
        draggable={false}
        onError={() => setFailed(src)}
        className="shrink-0 object-contain select-none"
        style={{
          width: size,
          height: size,
          filter: "drop-shadow(0 1px 1.5px rgba(0,0,0,0.16))",
        }}
      />
    );
  }
  const hue = hueFor(app);
  const inner = Math.round(size * 0.8);
  return (
    <span className="grid shrink-0 place-items-center" style={{ width: size, height: size }}>
      <span
        className="grid place-items-center font-semibold text-white"
        style={{
          width: inner,
          height: inner,
          borderRadius: inner * 0.24,
          fontSize: inner * 0.46,
          background: `linear-gradient(160deg, hsl(${hue} 58% 58%), hsl(${(hue + 18) % 360} 52% 38%))`,
          boxShadow: "inset 0 0 0 0.5px rgba(255,255,255,0.28), 0 1px 2px rgba(0,0,0,0.22)",
        }}
      >
        {(app.trim()[0] ?? "?").toUpperCase()}
      </span>
    </span>
  );
}

/** Closes a popover when the pointer goes down outside it. */
function useDismiss(open: boolean, close: () => void) {
  const ref = useRef<HTMLDivElement>(null);
  useEffect(() => {
    if (!open) return;
    const onDown = (e: MouseEvent) => {
      if (ref.current && !ref.current.contains(e.target as Node)) close();
    };
    document.addEventListener("mousedown", onDown);
    return () => document.removeEventListener("mousedown", onDown);
  }, [open, close]);
  return ref;
}

const popover =
  "absolute z-30 rounded-[9px] border border-[var(--st-border)] bg-[var(--st-bg)] p-1 shadow-[0_12px_32px_-8px_rgba(0,0,0,0.28)]";

function AppOption({
  a,
  onPick,
  picked,
  active,
}: {
  a: InstalledApp;
  onPick: () => void;
  picked?: boolean;
  active?: boolean;
}) {
  return (
    <button
      type="button"
      onMouseDown={(e) => {
        e.preventDefault();
        onPick();
      }}
      className={cx(
        "flex h-[36px] w-full items-center gap-[10px] rounded-[6px] px-[8px] text-left",
        active ? "bg-[var(--st-hover)]" : "hover:bg-[var(--st-hover)]",
      )}
    >
      <AppIcon app={a.app} size={24} />
      <span className="min-w-0 flex-1 truncate text-[12.5px] font-medium text-[var(--st-fg)]">
        {a.app}
      </span>
      <span className="max-w-[45%] truncate font-mono text-[10.5px] text-[var(--st-fg3)]">
        {a.bundle}
      </span>
      <span className="grid w-[12px] shrink-0 place-items-center">
        {picked ? <Check size={12} className="text-[var(--st-accent-text)]" /> : null}
      </span>
    </button>
  );
}

/** Inline field that searches installed apps and adds the one you pick. */
function AddAppField({
  exclude,
  onAdd,
  placeholder,
}: {
  exclude: string[];
  onAdd: (app: string) => void;
  placeholder: string;
}) {
  const [open, setOpen] = useState(false);
  const [query, setQuery] = useState("");
  const [cursor, setCursor] = useState(0);
  const close = useCallback(() => setOpen(false), []);
  const ref = useDismiss(open, close);
  const q = query.trim().toLowerCase();
  const matches = installedApps.filter(
    (a) => !exclude.includes(a.app) && (a.app + a.bundle).toLowerCase().includes(q),
  );
  const pick = (app: string) => {
    onAdd(app);
    setQuery("");
    setCursor(0);
  };
  const suggestions = suggestedFloating.filter((app) => !exclude.includes(app)).slice(0, 4);
  return (
    <div ref={ref} className="relative">
      <div
        className={cx(
          "flex h-[34px] items-center gap-[8px] rounded-[7px] border bg-[var(--st-bg)] px-[10px] transition-shadow",
          open
            ? "border-[var(--st-accent)] ring-[3px] ring-[var(--st-accent-soft)]"
            : "border-[var(--st-border)] hover:border-[var(--st-border-strong)]",
        )}
      >
        <Plus size={14} className="shrink-0 text-[var(--st-fg3)]" />
        <input
          value={query}
          placeholder={placeholder}
          aria-label={placeholder}
          onFocus={() => setOpen(true)}
          onChange={(e) => {
            setQuery(e.target.value);
            setCursor(0);
            setOpen(true);
          }}
          onKeyDown={(e) => {
            if (e.key === "Escape") {
              setQuery("");
              setOpen(false);
              e.currentTarget.blur();
            } else if (e.key === "ArrowDown") {
              e.preventDefault();
              setCursor((c) => Math.min(c + 1, matches.length - 1));
            } else if (e.key === "ArrowUp") {
              e.preventDefault();
              setCursor((c) => Math.max(c - 1, 0));
            } else if (e.key === "Enter" && matches[cursor]) {
              pick(matches[cursor].app);
            }
          }}
          className="w-full min-w-0 bg-transparent text-[13px] text-[var(--st-fg)] outline-none placeholder:text-[var(--st-fg3)]"
        />
        {open ? (
          <span className="shrink-0 text-[10.5px] text-[var(--st-fg3)]">Return to add</span>
        ) : null}
      </div>
      {!open && suggestions.length > 0 ? (
        <div className="mt-[10px] flex flex-wrap items-center gap-[6px]">
          <span className="mr-[2px] text-[11.5px] text-[var(--st-fg3)]">Suggested</span>
          {suggestions.map((app) => (
            <button
              key={app}
              type="button"
              onClick={() => onAdd(app)}
              className={cx(
                "inline-flex h-[28px] items-center gap-[6px] rounded-full border border-[var(--st-border)] bg-[var(--st-bg)] pr-[10px] pl-[4px] text-[12px] text-[var(--st-fg2)] transition-colors hover:border-[var(--st-border-strong)] hover:bg-[var(--st-hover)] hover:text-[var(--st-fg)]",
                focusRing,
              )}
            >
              <AppIcon app={app} size={20} />
              {app}
              <Plus size={11} className="text-[var(--st-fg3)]" />
            </button>
          ))}
        </div>
      ) : null}
      {open ? (
        <div
          className={cx(popover, "inset-x-0 top-[calc(100%+4px)] max-h-[248px] overflow-y-auto")}
        >
          <div className="px-2 pt-1 pb-1.5 text-[10.5px] font-medium tracking-[0.04em] text-[var(--st-fg3)] uppercase">
            Installed apps
          </div>
          {matches.map((a, i) => (
            <AppOption key={a.bundle} a={a} active={i === cursor} onPick={() => pick(a.app)} />
          ))}
          {matches.length === 0 ? (
            <div className="px-2 py-3 text-[12px] text-[var(--st-fg2)]">
              {q ? `No installed app matches "${query}"` : "All installed apps are on this list"}
            </div>
          ) : null}
        </div>
      ) : null}
    </div>
  );
}

/** Compact select showing the workspace number and name. */
function WorkspaceSelect({
  value,
  onChange,
  disabled,
}: {
  value: string;
  onChange: (v: string) => void;
  disabled?: boolean;
}) {
  const [open, setOpen] = useState(false);
  const close = useCallback(() => setOpen(false), []);
  const ref = useDismiss(open, close);
  return (
    <div ref={ref} className={cx("relative", disabled && "opacity-50")}>
      <button
        type="button"
        disabled={disabled}
        aria-haspopup="listbox"
        aria-expanded={open}
        onClick={() => setOpen(!open)}
        className={cx(
          "flex h-[30px] w-[160px] items-center gap-[8px] rounded-[7px] border bg-[var(--st-bg)] pr-[8px] pl-[5px] text-left shadow-[var(--st-shadow)] transition-colors",
          focusRing,
          open
            ? "border-[var(--st-border-strong)]"
            : "border-[var(--st-border)] hover:border-[var(--st-border-strong)]",
        )}
      >
        <span className="flex size-[20px] shrink-0 items-center justify-center rounded-[5px] bg-[var(--st-muted)] font-mono text-[11px] font-semibold text-[var(--st-fg)]">
          {value}
        </span>
        <span className="flex-1 truncate text-[12.5px] text-[var(--st-fg)]">
          {workspaceNames[value] ?? `Workspace ${value}`}
        </span>
        <ChevronsUpDown size={13} className="shrink-0 text-[var(--st-fg3)]" />
      </button>
      {open ? (
        <div role="listbox" className={cx(popover, "top-[calc(100%+4px)] right-0 w-[200px]")}>
          {Object.entries(workspaceNames).map(([w, name]) => (
            <button
              key={w}
              type="button"
              role="option"
              aria-selected={w === value}
              onClick={() => {
                onChange(w);
                setOpen(false);
              }}
              className={cx(
                "flex w-full items-center gap-2 rounded-[6px] px-2 py-1.5 text-left text-[12.5px]",
                w === value
                  ? "bg-[var(--st-accent-soft)] text-[var(--st-accent-text)]"
                  : "text-[var(--st-fg)] hover:bg-[var(--st-hover)]",
              )}
            >
              <span className="w-3 font-mono text-[11px] font-semibold">{w}</span>
              <span className="flex-1">{name}</span>
              {w === value ? <Check size={12} /> : null}
            </button>
          ))}
        </div>
      ) : null}
    </div>
  );
}

function IconAction({
  label,
  onClick,
  children,
}: {
  label: string;
  onClick: () => void;
  children: ReactNode;
}) {
  return (
    <button
      type="button"
      aria-label={label}
      title={label}
      onClick={onClick}
      className={cx(
        "grid size-[28px] shrink-0 place-items-center rounded-[6px] text-[var(--st-fg3)] transition-colors hover:bg-[var(--st-hover)] hover:text-[var(--st-fg)]",
        focusRing,
      )}
    >
      {children}
    </button>
  );
}

/** One app per row: real icon, name and badges, bundle ID beneath, controls on the right. */
function AppRow({
  app,
  badge,
  muted,
  hot,
  onHot,
  last,
  onOpen,
  children,
}: {
  app: string;
  badge?: ReactNode;
  muted?: boolean;
  hot?: boolean;
  onHot?: (app: string | null) => void;
  last?: boolean;
  onOpen?: () => void;
  children: ReactNode;
}) {
  const installed = isInstalled(app);
  const body = (
    <>
      <span className={cx("transition-[filter,opacity]", muted && "opacity-55 grayscale")}>
        <AppIcon app={app} size={36} />
      </span>
      <div className="min-w-0">
        <div className="flex items-center gap-[8px]">
          <span
            className={cx(
              "truncate text-[13px] font-medium",
              muted ? "text-[var(--st-fg2)]" : "text-[var(--st-fg)]",
            )}
          >
            {app}
          </span>
          {badge}
          {installed ? null : (
            <span className="shrink-0 rounded-[5px] border border-dashed border-[var(--st-border-strong)] px-[6px] text-[10.5px] leading-[17px] text-[var(--st-fg3)]">
              Not installed
            </span>
          )}
        </div>
        <div className="mt-[2px] truncate font-mono text-[11px] text-[var(--st-fg3)]">
          {bundleOf(app)}
        </div>
      </div>
    </>
  );
  return (
    <div
      onMouseEnter={() => onHot?.(app)}
      onMouseLeave={() => onHot?.(null)}
      className={cx(
        "flex min-h-[60px] items-center gap-[12px] px-[20px] py-[10px] transition-colors",
        !last && "border-b border-[var(--st-border)]",
        hot && "bg-[color-mix(in_srgb,var(--st-hover)_70%,transparent)]",
      )}
    >
      {onOpen ? (
        <button
          type="button"
          onClick={onOpen}
          title={`Edit ${app}`}
          className={cx(
            "-my-[4px] -ml-[6px] flex min-w-[160px] flex-1 items-center gap-[12px] rounded-[8px] py-[4px] pl-[6px] text-left",
            focusRing,
          )}
        >
          {body}
        </button>
      ) : (
        <div className="flex min-w-[160px] flex-1 items-center gap-[12px]">{body}</div>
      )}
      <div className="flex shrink-0 items-center gap-[8px]">{children}</div>
    </div>
  );
}

function UndoStrip({ text, onUndo }: { text: string; onUndo: () => void }) {
  return (
    <div className="flex items-center justify-between gap-3 border-t border-[var(--st-border)] bg-[var(--st-side)] px-5 py-2 text-[12px] text-[var(--st-fg2)]">
      <span>{text}</span>
      <Button size="sm" variant="ghost" onClick={onUndo}>
        <RotateCcw size={12} /> Undo
      </Button>
    </div>
  );
}

function CardEmpty({ icon, title }: { icon: ReactNode; title: string }) {
  return (
    <div className="flex items-center gap-3 border-t border-[var(--st-border)] px-5 py-5">
      <div className="grid size-9 shrink-0 place-items-center rounded-[8px] border border-dashed border-[var(--st-border-strong)] text-[var(--st-fg3)]">
        {icon}
      </div>
      <div className="text-[13px] font-medium text-[var(--st-fg)]">{title}</div>
    </div>
  );
}

interface Assignment {
  id: number;
  app: string;
  workspace: string;
  enabled: boolean;
}

/** Small centred dialog for adding or editing a workspace assignment. */
function AssignmentDialog({
  initial,
  defaultWorkspace,
  taken,
  others,
  onSave,
  onRemove,
  onClose,
}: {
  initial: Assignment | null;
  defaultWorkspace?: string;
  taken: string[];
  others: Assignment[];
  onSave: (app: string, workspace: string) => void;
  onRemove?: () => void;
  onClose: () => void;
}) {
  const [app, setApp] = useState(initial?.app ?? "");
  const [workspace, setWorkspace] = useState(initial?.workspace ?? defaultWorkspace ?? "1");
  const [query, setQuery] = useState("");
  const [listOpen, setListOpen] = useState(!initial);
  const q = query.trim().toLowerCase();
  const options = installedApps.filter(
    (a) =>
      (a.app === initial?.app || !taken.includes(a.app)) &&
      (a.app + a.bundle).toLowerCase().includes(q),
  );

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (e.key === "Escape") onClose();
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [onClose]);

  return (
    <div className="absolute inset-0 z-40 flex items-center justify-center p-6">
      <button
        type="button"
        aria-label="Close dialog"
        onClick={onClose}
        className="absolute inset-0 cursor-default bg-[color-mix(in_srgb,var(--st-canvas)_55%,transparent)] backdrop-blur-[2px]"
      />
      <div
        role="dialog"
        aria-modal="true"
        aria-label={initial ? `Edit ${initial.app}` : "Assign an app to a workspace"}
        className="relative w-[460px] rounded-[12px] border border-[var(--st-border)] bg-[var(--st-bg)] shadow-[0_24px_64px_-16px_rgba(0,0,0,0.35)]"
      >
        <div className="flex items-center justify-between gap-3 px-5 pt-4 pb-3">
          <h2 className="text-[14px] font-semibold tracking-[-0.01em] text-[var(--st-fg)]">
            {initial ? "Edit assignment" : "Assign an app to a workspace"}
          </h2>
          <IconAction label="Close" onClick={onClose}>
            <X size={14} />
          </IconAction>
        </div>

        <div className="space-y-4 border-t border-[var(--st-border)] px-5 py-4">
          <div>
            <FieldLabel>App</FieldLabel>
            {app && !listOpen ? (
              <button
                type="button"
                onClick={() => setListOpen(true)}
                className={cx(
                  "flex h-[48px] w-full items-center gap-[10px] rounded-[8px] border border-[var(--st-border)] bg-[var(--st-bg)] px-[8px] text-left shadow-[var(--st-shadow)] hover:border-[var(--st-border-strong)]",
                  focusRing,
                )}
              >
                <AppIcon app={app} size={32} />
                <span className="min-w-0 flex-1">
                  <span className="block truncate text-[13px] font-medium text-[var(--st-fg)]">
                    {app}
                  </span>
                  <span className="block truncate font-mono text-[10.5px] text-[var(--st-fg3)]">
                    {bundleOf(app)}
                  </span>
                </span>
                <span className="text-[11.5px] text-[var(--st-fg3)]">Change</span>
                <ChevronsUpDown size={13} className="text-[var(--st-fg3)]" />
              </button>
            ) : (
              <div className="overflow-hidden rounded-[8px] border border-[var(--st-border)]">
                <label className="flex h-[34px] items-center gap-[8px] border-b border-[var(--st-border)] px-[10px]">
                  <Search size={14} className="shrink-0 text-[var(--st-fg3)]" />
                  <input
                    autoFocus
                    value={query}
                    onChange={(e) => setQuery(e.target.value)}
                    placeholder="Search installed apps"
                    className="w-full min-w-0 bg-transparent text-[13px] text-[var(--st-fg)] outline-none placeholder:text-[var(--st-fg3)]"
                  />
                </label>
                <div className="max-h-[188px] overflow-y-auto p-[4px]">
                  {options.map((a) => (
                    <AppOption
                      key={a.bundle}
                      a={a}
                      picked={a.app === app}
                      onPick={() => {
                        setApp(a.app);
                        setQuery("");
                        setListOpen(false);
                      }}
                    />
                  ))}
                  {options.length === 0 ? (
                    <div className="px-2 py-3 text-[12px] text-[var(--st-fg2)]">
                      No installed app matches "{query}"
                    </div>
                  ) : null}
                </div>
              </div>
            )}
          </div>

          <div>
            <FieldLabel>Workspace</FieldLabel>
            <div role="radiogroup" className="grid grid-cols-3 gap-[6px]">
              {Object.entries(workspaceNames).map(([w, name]) => {
                const here = others.filter((o) => o.workspace === w && o.id !== initial?.id);
                return (
                  <button
                    key={w}
                    type="button"
                    role="radio"
                    aria-checked={w === workspace}
                    onClick={() => setWorkspace(w)}
                    className={cx(
                      "flex h-[34px] items-center gap-[8px] rounded-[7px] border px-[10px] text-left text-[12.5px] transition-colors",
                      focusRing,
                      w === workspace
                        ? "border-[var(--st-accent)] bg-[var(--st-accent-soft)] text-[var(--st-accent-text)]"
                        : "border-[var(--st-border)] text-[var(--st-fg)] hover:bg-[var(--st-hover)]",
                    )}
                  >
                    <span className="font-mono text-[11px] font-semibold">{w}</span>
                    <span className="min-w-0 flex-1 truncate">{name}</span>
                    {here.length > 0 ? (
                      <span
                        className="flex shrink-0 -space-x-[5px]"
                        title={here.map((o) => o.app).join(", ")}
                      >
                        {here.slice(0, 2).map((o) => (
                          <AppIcon key={o.id} app={o.app} size={18} />
                        ))}
                      </span>
                    ) : null}
                  </button>
                );
              })}
            </div>
          </div>
        </div>

        <div className="flex items-center gap-2 border-t border-[var(--st-border)] px-5 py-3">
          {onRemove ? (
            <button
              type="button"
              onClick={onRemove}
              className={cx(
                "inline-flex h-7 items-center gap-1.5 rounded-[7px] px-2 text-[12px] font-medium hover:bg-[var(--st-hover)]",
                focusRing,
              )}
              style={{ color: danger }}
            >
              <Trash2 size={12} /> Remove
            </button>
          ) : null}
          <div className="ml-auto flex gap-2">
            <Button size="sm" onClick={onClose}>
              Cancel
            </Button>
            <Button
              size="sm"
              variant="primary"
              disabled={!app}
              onClick={() => onSave(app, workspace)}
            >
              {initial ? "Save" : "Add assignment"}
            </Button>
          </div>
        </div>
      </div>
    </div>
  );
}

export function RulesPage() {
  const [floating, setFloating] = useState<string[]>(() => [...snapshot.floatingApps]);
  const [removedFloat, setRemovedFloat] = useState<{ app: string; index: number } | null>(null);
  const [assignments, setAssignments] = useState<Assignment[]>([
    { id: 1, app: "Ghostty", workspace: "1", enabled: true },
    { id: 2, app: "Slack", workspace: "3", enabled: true },
    { id: 3, app: "Spotify", workspace: "9", enabled: false },
  ]);
  const [removedAssignment, setRemovedAssignment] = useState<{
    item: Assignment;
    index: number;
  } | null>(null);
  const [dialog, setDialog] = useState<{
    editing: Assignment | null;
    workspace?: string;
  } | null>(null);
  const [hot, setHot] = useState<string | null>(null);
  const nextId = useRef(10);

  const sortedFloating = [...floating].sort((a, b) =>
    a.localeCompare(b, undefined, { sensitivity: "base" }),
  );
  const sortedAssignments = [...assignments].sort(
    (a, b) => Number(a.workspace) - Number(b.workspace) || a.app.localeCompare(b.app),
  );
  const patch = (id: number, p: Partial<Assignment>) =>
    setAssignments((prev) => prev.map((a) => (a.id === id ? { ...a, ...p } : a)));
  const removeFloating = (app: string) => {
    setRemovedFloat({ app, index: floating.indexOf(app) });
    setFloating((prev) => prev.filter((a) => a !== app));
  };
  const removeAssignment = (item: Assignment) => {
    setRemovedAssignment({ item, index: assignments.findIndex((a) => a.id === item.id) });
    setAssignments((prev) => prev.filter((a) => a.id !== item.id));
    setDialog(null);
  };
  const closeDialog = useCallback(() => setDialog(null), []);
  return (
    <>
      <PageHeader title="Rules" />

      <div className="flex flex-col gap-4">
        <Card>
          <CardTitle
            title="Floating apps"
            action={<Badge>{floating.length === 1 ? "1 app" : `${floating.length} apps`}</Badge>}
          />
          {sortedFloating.length === 0 ? (
            <CardEmpty icon={<AppWindow size={16} />} title="No floating apps" />
          ) : (
            <div className="border-t border-[var(--st-border)]">
              {sortedFloating.map((app, i) => (
                <AppRow
                  key={app}
                  app={app}
                  hot={hot === app}
                  onHot={setHot}
                  last={i === sortedFloating.length - 1}
                >
                  <Button size="sm" variant="ghost" onClick={() => removeFloating(app)}>
                    <LayoutGrid size={12} /> Tile instead
                  </Button>
                </AppRow>
              ))}
            </div>
          )}
          {removedFloat ? (
            <UndoStrip
              text={`${removedFloat.app} removed`}
              onUndo={() => {
                setFloating((prev) => {
                  const next = [...prev];
                  next.splice(removedFloat.index, 0, removedFloat.app);
                  return next;
                });
                setRemovedFloat(null);
              }}
            />
          ) : null}
          <div className="border-t border-[var(--st-border)] px-[20px] py-[14px]">
            <AddAppField
              exclude={floating}
              placeholder="Add an app to float"
              onAdd={(app) => {
                setFloating((prev) => [...prev, app]);
                setRemovedFloat(null);
              }}
            />
          </div>
        </Card>

        <Card>
          <CardTitle
            title="Workspace assignments"
            action={
              <Button size="sm" onClick={() => setDialog({ editing: null })}>
                <Plus size={12} /> Add
              </Button>
            }
          />
          {sortedAssignments.length === 0 ? (
            <CardEmpty icon={<LayoutGrid size={16} />} title="No assignments" />
          ) : (
            <div className="border-t border-[var(--st-border)]">
              {sortedAssignments.map((a, i) => (
                <AppRow
                  key={a.id}
                  app={a.app}
                  muted={!a.enabled}
                  hot={hot === a.app}
                  onHot={setHot}
                  last={i === sortedAssignments.length - 1}
                  onOpen={() => setDialog({ editing: a })}
                  badge={a.enabled ? null : <Badge>Paused</Badge>}
                >
                  <span className="text-[12px] text-[var(--st-fg3)]">Opens on</span>
                  <WorkspaceSelect
                    value={a.workspace}
                    disabled={!a.enabled}
                    onChange={(w) => patch(a.id, { workspace: w })}
                  />
                  <span className="mx-[4px] h-[20px] w-px bg-[var(--st-border)]" />
                  <Switch
                    label={`Assign ${a.app}`}
                    checked={a.enabled}
                    onChange={(v) => patch(a.id, { enabled: v })}
                  />
                  <IconAction label={`Remove ${a.app}`} onClick={() => removeAssignment(a)}>
                    <Trash2 size={13} />
                  </IconAction>
                </AppRow>
              ))}
            </div>
          )}
          {removedAssignment ? (
            <UndoStrip
              text={`${removedAssignment.item.app} assignment removed`}
              onUndo={() => {
                setAssignments((prev) => {
                  const next = [...prev];
                  next.splice(removedAssignment.index, 0, removedAssignment.item);
                  return next;
                });
                setRemovedAssignment(null);
              }}
            />
          ) : null}
        </Card>

        <Card>
          <Row label="Every other app" last>
            <Badge tone="neutral">
              <LayoutGrid size={11} /> Tile here
            </Badge>
          </Row>
        </Card>
      </div>

      {dialog ? (
        <AssignmentDialog
          key={dialog.editing?.id ?? `new-${dialog.workspace ?? ""}`}
          initial={dialog.editing}
          defaultWorkspace={dialog.workspace}
          taken={assignments.map((a) => a.app)}
          others={assignments}
          onClose={closeDialog}
          onRemove={
            dialog.editing ? () => dialog.editing && removeAssignment(dialog.editing) : undefined
          }
          onSave={(app, workspace) => {
            if (dialog.editing) {
              patch(dialog.editing.id, { app, workspace });
            } else {
              setAssignments((prev) => [
                ...prev,
                { id: nextId.current++, app, workspace, enabled: true },
              ]);
            }
            setRemovedAssignment(null);
            setDialog(null);
          }}
        />
      ) : null}
    </>
  );
}

/* ------------------------------------------------------------------------ */
/* Shortcuts                                                                 */
/* ------------------------------------------------------------------------ */

const modifierOrder = ["⌃", "⌥", "⇧", "⌘"];
const systemShortcuts: Record<string, string> = {
  "⌘ Space": "Spotlight",
  "⌃ Space": "Input source switching",
  "⌘ Tab": "App Switcher",
};

function KeyCap({ children }: { children: ReactNode }) {
  const symbol = typeof children === "string" && modifierOrder.includes(children);
  return (
    <kbd
      className={cx(
        "inline-flex h-[24px] min-w-[24px] items-center justify-center rounded-[6px] border border-[var(--st-border-strong)] px-[7px] font-sans font-medium text-[var(--st-fg)]",
        symbol ? "text-[13px]" : "text-[11.5px] tracking-[0.01em]",
      )}
      style={{
        background: "linear-gradient(180deg, var(--st-bg) 0%, var(--st-side) 100%)",
        boxShadow: "inset 0 -1.5px 0 var(--st-border-strong), 0 1px 1px rgba(0,0,0,0.05)",
      }}
    >
      {children}
    </kbd>
  );
}

/** Renders a binding: modifiers as caps, "H / L" as alternatives, "H J K L" as a set. */
function KeyCombo({ keys }: { keys: string[] }) {
  return (
    <span className="inline-flex items-center gap-1">
      {keys.map((k, i) => {
        if (k.includes(" / ")) {
          return (
            <span key={i} className="inline-flex items-center gap-1">
              {k.split(" / ").map((part, j) => (
                <span key={j} className="inline-flex items-center gap-1">
                  {j > 0 ? <span className="text-[11px] text-[var(--st-fg3)]">or</span> : null}
                  <KeyCap>{part}</KeyCap>
                </span>
              ))}
            </span>
          );
        }
        if (k.includes(" ") && k.length > 1 && k !== "Space") {
          return (
            <span key={i} className="inline-flex gap-[3px]">
              {k.split(" ").map((part) => (
                <KeyCap key={part}>{part}</KeyCap>
              ))}
            </span>
          );
        }
        return <KeyCap key={i}>{k}</KeyCap>;
      })}
    </span>
  );
}

function modifiersOf(e: KeyboardEvent) {
  return [e.ctrlKey && "⌃", e.altKey && "⌥", e.shiftKey && "⇧", e.metaKey && "⌘"].filter(
    (m): m is string => Boolean(m),
  );
}

function keyLabel(e: KeyboardEvent) {
  if (e.code.startsWith("Key")) return e.code.slice(3);
  if (e.code.startsWith("Digit")) return e.code.slice(5);
  const named: Record<string, string> = {
    Space: "Space",
    Tab: "Tab",
    Enter: "Return",
    Comma: ",",
    Period: ".",
    Slash: "/",
    Semicolon: ";",
    BracketLeft: "[",
    BracketRight: "]",
    Minus: "-",
    Equal: "=",
    ArrowLeft: "←",
    ArrowRight: "→",
    ArrowUp: "↑",
    ArrowDown: "↓",
    Backquote: "`",
  };
  return named[e.code] ?? e.key.toUpperCase();
}

const comboKey = (keys: string[]) => keys.join(" ");

/** Shortcut presses per day for the 14 days up to today; weekends run quieter. */
const pressesPerDay = [236, 214, 92, 78, 251, 268, 243, 259, 221, 104, 86, 274, 291, 162];

const mostUsed = [
  { action: "Go to workspace", count: 1012 },
  { action: "Focus left / right", count: 684 },
  { action: "Launcher", count: 412 },
  { action: "Send window to workspace", count: 236 },
  { action: "Toggle floating", count: 118 },
];

function MostUsed({ onPick }: { onPick: (action: string) => void }) {
  const [ref, width] = useWidth<HTMLDivElement>(240);
  const [hover, setHover] = useState<number | null>(null);
  const total = pressesPerDay.reduce((s, v) => s + v, 0);
  const peak = Math.max(...mostUsed.map((m) => m.count));
  const rowH = 36;
  const tipW = 136;
  const hovered = hover === null ? undefined : mostUsed[hover];
  let tip = { left: 0, top: 0 };
  if (hover !== null && hovered) {
    const end = (hovered.count / peak) * width;
    tip = {
      left: Math.max(0, Math.min(end - tipW / 2, width - tipW)),
      top: hover < mostUsed.length - 1 ? (hover + 1) * rowH + 2 : hover * rowH - 50,
    };
  }
  return (
    <div ref={ref} className="relative" onMouseLeave={() => setHover(null)}>
      {mostUsed.map((m, i) => (
        <button
          key={m.action}
          type="button"
          onMouseEnter={() => setHover(i)}
          onFocus={() => setHover(i)}
          onBlur={() => setHover(null)}
          onClick={() => onPick(m.action)}
          className={cx(
            "block w-full rounded-[6px] text-left transition-opacity duration-100",
            focusRing,
          )}
          style={{ height: rowH, opacity: hover !== null && hover !== i ? 0.55 : 1 }}
        >
          <span className="flex items-baseline justify-between gap-[8px]">
            <span className="truncate text-[12px] text-[var(--st-fg)]">{m.action}</span>
            <span className="text-[11px] text-[var(--st-fg3)] tabular-nums">
              {m.count.toLocaleString("en-GB")}
            </span>
          </span>
          <span className="mt-[6px] block h-[6px] w-full rounded-full bg-[var(--st-muted)]">
            <span
              className="block h-full rounded-full bg-[var(--st-accent)]"
              style={{ width: `${(m.count / peak) * 100}%` }}
            />
          </span>
        </button>
      ))}
      {hovered ? (
        <ChartTooltip left={tip.left} top={tip.top} width={tipW}>
          <div className="font-medium">{hovered.action}</div>
          <div className="mt-0.5 text-[var(--st-fg2)] tabular-nums">
            {hovered.count.toLocaleString("en-GB")} presses,{" "}
            {Math.round((100 * hovered.count) / total)}% of all
          </div>
        </ChartTooltip>
      ) : null}
    </div>
  );
}

function UsageCard({ onPick }: { onPick: (action: string) => void }) {
  const total = pressesPerDay.reduce((s, v) => s + v, 0);
  const weekdays = pressesPerDay.filter((_, i) => ![2, 3, 9, 10, 13].includes(i));
  const typical = Math.round(weekdays.reduce((s, v) => s + v, 0) / weekdays.length);
  return (
    <Card>
      <div className="flex items-start justify-between gap-[16px] px-[20px] pt-[16px]">
        <div>
          <h2 className="text-[14px] font-semibold tracking-[-0.01em] text-[var(--st-fg)]">
            Usage
          </h2>
          <p className="mt-0.5 text-[12.5px] text-[var(--st-fg2)]">
            Last 14 days, about {typical} a weekday
          </p>
        </div>
        <div className="text-right">
          <div className="text-[18px] leading-none font-semibold tracking-[-0.02em] text-[var(--st-fg)] tabular-nums">
            {total.toLocaleString("en-GB")}
          </div>
          <div className="mt-[4px] text-[11px] text-[var(--st-fg3)]">presses</div>
        </div>
      </div>
      <div className="grid grid-cols-[minmax(0,1fr)_240px] gap-[28px] px-[20px] pt-[12px] pb-[16px]">
        <LineChart
          values={pressesPerDay}
          dateOf={dayName}
          format={(v) => `${v} presses`}
          label="Shortcut presses per day over the last 14 days"
          height={180}
          area
        />
        <div className="min-w-0">
          <div className="mb-[8px] text-[11.5px] font-medium text-[var(--st-fg2)]">Most used</div>
          <MostUsed onPick={onPick} />
        </div>
      </div>
    </Card>
  );
}

export function ShortcutsPage() {
  const [query, setQuery] = usePageSearch("Search shortcuts");
  const [group, setGroup] = useState("All");
  const [vim, setVim] = useState(true);
  const [overrides, setOverrides] = useState<Record<string, string[]>>({});
  const [recording, setRecording] = useState<string | null>(null);
  const [held, setHeld] = useState<string[]>([]);

  const keysFor = (action: string, defaults: string[]) => overrides[action] ?? defaults;

  useEffect(() => {
    if (!recording) return;
    const onDown = (e: KeyboardEvent) => {
      e.preventDefault();
      if (e.key === "Escape") {
        setRecording(null);
        return;
      }
      if (["Shift", "Meta", "Alt", "Control"].includes(e.key)) {
        setHeld(modifiersOf(e));
        return;
      }
      const mods = modifiersOf(e);
      if (mods.length === 0 && e.key === "Backspace") {
        setOverrides((o) => {
          const next = { ...o };
          delete next[recording];
          return next;
        });
        setRecording(null);
        return;
      }
      setOverrides((o) => ({ ...o, [recording]: [...mods, keyLabel(e)] }));
      setRecording(null);
    };
    const onUp = (e: KeyboardEvent) => setHeld(modifiersOf(e));
    window.addEventListener("keydown", onDown);
    window.addEventListener("keyup", onUp);
    return () => {
      window.removeEventListener("keydown", onDown);
      window.removeEventListener("keyup", onUp);
      setHeld([]);
    };
  }, [recording]);

  const all = shortcuts.flatMap((g) =>
    g.items.map((i) => ({ ...i, group: g.group, keys: keysFor(i.action, i.keys) })),
  );
  const conflicts: Record<string, string> = {};
  {
    const out = conflicts;
    for (const item of all) {
      const k = comboKey(item.keys);
      const system = systemShortcuts[k];
      const clash = all.find((o) => o.action !== item.action && comboKey(o.keys) === k);
      if (system) out[item.action] = `macOS uses ${item.keys.join(" ")} for ${system}`;
      else if (clash) out[item.action] = `Same keys as "${clash.action}"`;
    }
  }
  const conflictList = Object.entries(conflicts);

  const q = query.trim().toLowerCase();
  const filtered = shortcuts
    .filter((g) => group === "All" || g.group === group)
    .map((g) => ({
      ...g,
      items: g.items.filter(
        (i) =>
          i.action.toLowerCase().includes(q) ||
          keysFor(i.action, i.keys).join(" ").toLowerCase().includes(q),
      ),
    }))
    .filter((g) => g.items.length > 0);
  const total = shortcuts.reduce((n, g) => n + g.items.length, 0);
  const edited = Object.keys(overrides).length;

  return (
    <>
      <PageHeader title="Shortcuts" />

      <Tabs
        tabs={[
          { id: "All", label: "All", count: total },
          ...shortcuts.map((g) => ({ id: g.group, label: g.group, count: g.items.length })),
        ]}
        value={group}
        onChange={setGroup}
      />

      <div>
        <div className="flex flex-col gap-4">
          {group === "All" && !q ? (
            <UsageCard
              onPick={(action) => {
                setGroup("All");
                setQuery(action);
              }}
            />
          ) : null}
          {conflictList.length > 0 ? (
            <div
              className="flex items-start gap-3 rounded-[10px] border px-4 py-3"
              style={{
                borderColor: "color-mix(in srgb, var(--st-warn) 35%, transparent)",
                background: "var(--st-warn-soft)",
              }}
            >
              <TriangleAlert size={16} className="mt-0.5 shrink-0 text-[var(--st-warn)]" />
              <div className="min-w-0 flex-1">
                <div className="text-[13px] font-medium text-[var(--st-fg)]">
                  {conflictList.length === 1
                    ? "1 shortcut conflicts"
                    : `${conflictList.length} shortcuts conflict`}
                </div>
                <div className="mt-0.5 text-[12px] text-[var(--st-fg2)]">
                  {conflictList[0]?.[0]}: {conflictList[0]?.[1]}
                </div>
              </div>
              <Button size="sm" onClick={() => setRecording(conflictList[0]?.[0] ?? null)}>
                <Keyboard size={12} /> Record new
              </Button>
            </div>
          ) : null}

          {filtered.map((g) => (
            <Card key={g.group} className="overflow-hidden">
              <div className="flex items-center justify-between border-b border-[var(--st-border)] bg-[var(--st-side)] px-4 py-2">
                <span className="text-[11.5px] font-medium tracking-[0.02em] text-[var(--st-fg2)]">
                  {g.group}
                </span>
                <span className="text-[11px] text-[var(--st-fg3)] tabular-nums">
                  {g.items.length}
                </span>
              </div>
              {g.items.map((item, i) => {
                const keys = keysFor(item.action, item.keys);
                const isRecording = recording === item.action;
                const conflict = conflicts[item.action];
                const changed = item.action in overrides;
                return (
                  <div
                    key={item.action}
                    role="button"
                    tabIndex={0}
                    onClick={() => setRecording(isRecording ? null : item.action)}
                    className={cx(
                      "group flex min-h-[46px] cursor-pointer items-center justify-between gap-4 px-4 py-2 transition-colors",
                      i < g.items.length - 1 && "border-b border-[var(--st-border)]",
                      isRecording ? "bg-[var(--st-accent-soft)]" : "hover:bg-[var(--st-hover)]",
                    )}
                  >
                    <div className="flex min-w-0 items-center gap-2">
                      <span className="truncate text-[13px] text-[var(--st-fg)]">
                        {item.action}
                      </span>
                      {changed ? (
                        <span
                          className="size-1.5 shrink-0 rounded-full bg-[var(--st-accent)]"
                          title="Edited"
                        />
                      ) : null}
                      {conflict ? (
                        <Badge tone="warn">
                          <TriangleAlert size={11} /> Conflict
                        </Badge>
                      ) : null}
                    </div>
                    <div className="flex shrink-0 items-center gap-2">
                      {isRecording ? (
                        <span className="inline-flex h-[28px] min-w-[150px] items-center gap-2 rounded-[7px] border border-dashed border-[var(--st-accent)] bg-[var(--st-bg)] px-2.5 text-[12px] text-[var(--st-accent-text)]">
                          <span className="relative flex size-2">
                            <span className="absolute inset-0 animate-ping rounded-full bg-[var(--st-accent)] opacity-60" />
                            <span className="relative size-2 rounded-full bg-[var(--st-accent)]" />
                          </span>
                          {held.length > 0 ? <KeyCombo keys={held} /> : "Press new shortcut"}
                          <span className="ml-auto text-[10.5px] text-[var(--st-fg3)]">Esc</span>
                        </span>
                      ) : (
                        <>
                          {changed ? (
                            <button
                              type="button"
                              onClick={(e) => {
                                e.stopPropagation();
                                setOverrides((o) => {
                                  const next = { ...o };
                                  delete next[item.action];
                                  return next;
                                });
                              }}
                              className="rounded-[5px] px-1.5 py-0.5 text-[11.5px] text-[var(--st-fg3)] opacity-0 transition-opacity group-hover:opacity-100 hover:bg-[var(--st-muted)] hover:text-[var(--st-fg)]"
                            >
                              Reset
                            </button>
                          ) : (
                            <span className="text-[11.5px] text-[var(--st-fg3)] opacity-0 transition-opacity group-hover:opacity-100">
                              Click to record
                            </span>
                          )}
                          <KeyCombo keys={keys} />
                        </>
                      )}
                    </div>
                  </div>
                );
              })}
            </Card>
          ))}

          {filtered.length === 0 ? (
            <Card>
              <EmptyState icon={<SearchX size={18} />} title={`No shortcuts match "${query}"`}>
                <Button size="sm" onClick={() => setQuery("")}>
                  Clear search
                </Button>
              </EmptyState>
            </Card>
          ) : null}

          <Card>
            <Row label="Vim-style direction keys" hint="H J K L">
              <Switch label="Vim-style direction keys" checked={vim} onChange={setVim} />
            </Row>
            <div className="flex items-center justify-between px-5 py-3">
              <span className="text-[12px] text-[var(--st-fg2)]">
                {edited === 0 ? "All defaults" : `${edited} edited`}
              </span>
              <Button size="sm" variant="ghost" onClick={() => setOverrides({})}>
                <RotateCcw size={12} /> Restore defaults
              </Button>
            </div>
          </Card>
        </div>
      </div>
    </>
  );
}

/* ------------------------------------------------------------------------ */
/* Setup health                                                              */
/* ------------------------------------------------------------------------ */

type Result = "pass" | "warn" | "fail";
type Live = Result | "checking" | "fixing";

interface Check {
  id: string;
  group: "Installed" | "Permissions" | "Running";
  name: string;
  detail: string;
  result: Result;
  command: string;
  output: string;
  fix?: { label: string; command: string; detail: string; settings?: boolean };
}

const checks: Check[] = [
  {
    id: "brew",
    group: "Installed",
    name: "Homebrew",
    detail: "4.6.2",
    result: "pass",
    command: "brew --version",
    output: "Homebrew 4.6.2",
  },
  {
    id: "aero",
    group: "Installed",
    name: "AeroSpace",
    detail: "0.19.2-Beta",
    result: "pass",
    command: "aerospace --version",
    output: "aerospace CLI client version: 0.19.2-Beta",
  },
  {
    id: "bar",
    group: "Installed",
    name: "SketchyBar",
    detail: "2.22.1",
    result: "pass",
    command: "sketchybar --version",
    output: "sketchybar-v2.22.1",
  },
  {
    id: "borders",
    group: "Installed",
    name: "JankyBorders",
    detail: "1.8.0",
    result: "pass",
    command: "brew list --versions borders",
    output: "borders 1.8.0",
  },
  {
    id: "ax",
    group: "Permissions",
    name: "Accessibility",
    detail: "Granted to AeroSpace",
    result: "pass",
    command: "macarchy doctor permission accessibility --app AeroSpace",
    output: "granted (tccd, kTCCServiceAccessibility)",
  },
  {
    id: "screen",
    group: "Permissions",
    name: "Screen Recording",
    detail: "Not granted to SketchyBar",
    result: "warn",
    command: "macarchy doctor permission screen-capture --app SketchyBar",
    output: "denied (kTCCServiceScreenCapture)",
    fix: {
      label: "Open Settings",
      command: "open x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture",
      detail: "Granted to SketchyBar",
      settings: true,
    },
  },
  {
    id: "config",
    group: "Running",
    name: "AeroSpace config",
    detail: "Generated, up to date",
    result: "pass",
    command: "aerospace reload-config --dry-run",
    output: "Config is valid. 0 warnings.",
  },
  {
    id: "skhd",
    group: "Running",
    name: "skhd",
    detail: "Installed but not running",
    result: "fail",
    command: "launchctl print gui/$UID/com.koekeishiya.skhd",
    output: 'Could not find service "com.koekeishiya.skhd" in domain for user gui: 501',
    fix: {
      label: "Start skhd",
      command: "skhd --start-service",
      detail: "Running",
    },
  },
  {
    id: "login",
    group: "Running",
    name: "Login items",
    detail: "3 of 4 registered, JankyBorders missing",
    result: "warn",
    command: "sfltool dumpbtm | grep -c macarchy",
    output: "3",
    fix: {
      label: "Register",
      command: "macarchy login-items register --all",
      detail: "4 of 4 registered",
    },
  },
];

const rank: Record<Result, number> = { fail: 0, warn: 1, pass: 2 };

/** When each check last ran, how long it took and its daily result for the 13 days before today (p, w or f). */
const checkMeta: Record<string, { lastRun: string; ms: number; history: string }> = {
  brew: { lastRun: "2 min ago", ms: 180, history: "ppppppppppppp" },
  aero: { lastRun: "2 min ago", ms: 42, history: "ppppppppppppp" },
  bar: { lastRun: "2 min ago", ms: 38, history: "ppppppppppppp" },
  borders: { lastRun: "2 min ago", ms: 210, history: "ppppppppppppp" },
  ax: { lastRun: "2 min ago", ms: 64, history: "pppppfppppppp" },
  screen: { lastRun: "2 min ago", ms: 71, history: "pppppppppwwww" },
  config: { lastRun: "2 min ago", ms: 120, history: "ppppppwpppppp" },
  skhd: { lastRun: "2 min ago", ms: 55, history: "pppppppppppff" },
  login: { lastRun: "2 min ago", ms: 330, history: "ppwppppppwwww" },
};

/** Full runs of every check on each of the 13 days before today. */
const runsPerDay = [1, 2, 1, 1, 3, 1, 2, 1, 1, 2, 1, 1, 3];
const DAYS = runsPerDay.length + 1;

const pastResult = (ch: string | undefined): Result =>
  ch === "f" ? "fail" : ch === "w" ? "warn" : "pass";
const historyOf = (c: Check) =>
  (checkMeta[c.id]?.history ?? "")
    .padEnd(DAYS - 1, "p")
    .split("")
    .map(pastResult);

function dayName(i: number, long = false) {
  if (i === DAYS - 1) return "Today";
  if (long && i === DAYS - 2) return "Yesterday";
  const date = new Date(2026, 9, 21 - (DAYS - 1 - i));
  return date.toLocaleDateString(
    "en-GB",
    long
      ? { weekday: "short", day: "numeric", month: "short" }
      : { day: "numeric", month: "short" },
  );
}

const statusText: Record<Live, string> = {
  pass: "Passed",
  warn: "Warning",
  fail: "Failed",
  checking: "Checking",
  fixing: "Fixing",
};

function StatusIcon({ state, size = 15 }: { state: Live; size?: number }) {
  if (state === "pass") return <CircleCheck size={size} className="shrink-0 text-[var(--st-ok)]" />;
  if (state === "warn")
    return <CircleAlert size={size} className="shrink-0 text-[var(--st-warn)]" />;
  if (state === "fail")
    return <CircleX size={size} className="shrink-0" style={{ color: danger }} />;
  return <Loader2 size={size} className="shrink-0 animate-spin text-[var(--st-fg3)]" />;
}

function ChartTooltip({
  left,
  top,
  width,
  children,
}: {
  left: number;
  top: number;
  width: number;
  children: ReactNode;
}) {
  return (
    <div
      role="tooltip"
      className="pointer-events-none absolute z-10 rounded-[8px] border border-[var(--st-border)] bg-[var(--st-bg)] px-2.5 py-2 text-[11.5px] text-[var(--st-fg)] shadow-[0_6px_20px_-6px_rgba(0,0,0,0.22),var(--st-shadow)]"
      style={{ left, top, width }}
    >
      {children}
    </div>
  );
}

/** A bar segment anchored at the bottom, optionally with rounded top corners. */
function barPath(x: number, y: number, w: number, h: number, round: boolean) {
  const r = round ? Math.min(4, w / 2, h) : 0;
  const tl = r ? `A${r} ${r} 0 0 1 ${x + r} ${y}` : "";
  const tr = r ? `A${r} ${r} 0 0 1 ${x + w} ${y + r}` : "";
  return `M${x} ${y + h}V${y + r}${tl}H${x + w - r}${tr}V${y + h}Z`;
}

interface Day {
  runs: number;
  pass: number;
  warn: number;
  fail: number;
}

const resultColour: Record<Result, string> = {
  pass: "var(--st-ok)",
  warn: "var(--st-warn)",
  fail: danger,
};

function TooltipRow({ result, value }: { result: Result; value: number }) {
  return (
    <div className="flex items-center justify-between gap-3">
      <span className="flex items-center gap-1.5 text-[var(--st-fg2)]">
        <StatusIcon state={result} size={11} />
        {statusText[result]}
      </span>
      <span className="font-medium tabular-nums">{value}</span>
    </div>
  );
}

function HistoryChart({ days }: { days: Day[] }) {
  const [ref, width] = useWidth<HTMLDivElement>(600);
  const [hover, setHover] = useState<number | null>(null);
  const H = 144;
  const padT = 6;
  const padB = 22;
  const padL = 28;
  const plotW = Math.max(0, width - padL);
  const plotH = H - padT - padB;
  const peak = Math.max(1, ...days.map((d) => d.pass + d.warn + d.fail));
  const step = Math.max(5, Math.ceil(peak / 3 / 5) * 5);
  const ticks = [0, step, step * 2, step * 3];
  const y = (v: number) => padT + plotH - (v / (step * 3)) * plotH;
  const slot = plotW / days.length;
  const barW = Math.max(4, Math.min(14, slot - 2));
  const tipW = 156;
  const hovered = hover === null ? undefined : days[hover];

  let tipLeft = 0;
  if (hover !== null) {
    const cx = padL + slot * (hover + 0.5);
    const right = cx + barW / 2 + 10;
    tipLeft = right + tipW <= width ? right : Math.max(0, cx - barW / 2 - 10 - tipW);
  }

  return (
    <div ref={ref} className="relative" onMouseLeave={() => setHover(null)}>
      <svg
        width={width}
        height={H}
        className="block"
        role="img"
        aria-label="Passed and failed checks per day over the last 14 days"
      >
        {ticks.map((t) => (
          <g key={t}>
            <line
              x1={padL}
              x2={width}
              y1={y(t)}
              y2={y(t)}
              stroke="var(--st-border)"
              strokeOpacity={t === 0 ? 1 : 0.6}
            />
            <text
              x={padL - 8}
              y={y(t)}
              dy="0.32em"
              textAnchor="end"
              fontSize="10"
              fill="var(--st-fg3)"
              style={{ fontVariantNumeric: "tabular-nums" }}
            >
              {t}
            </text>
          </g>
        ))}
        {days.map((d, i) => {
          const cx = padL + slot * (i + 0.5);
          const x = cx - barW / 2;
          const stack = (["pass", "warn", "fail"] as const).filter((r) => d[r] > 0);
          let below = 0;
          const segments = stack.map((r, k) => {
            const bottom = y(below) - (k > 0 ? 2 : 0);
            below += d[r];
            const topY = y(below);
            return { r, topY, h: Math.max(1.5, bottom - topY), last: k === stack.length - 1 };
          });
          return (
            <g key={i}>
              {hover === i ? (
                <rect
                  x={padL + slot * i + 2}
                  y={padT}
                  width={Math.max(0, slot - 4)}
                  height={plotH}
                  rx={5}
                  fill="var(--st-hover)"
                />
              ) : null}
              <g
                style={{
                  opacity: hover !== null && hover !== i ? 0.55 : 1,
                  transition: "opacity 120ms",
                }}
              >
                {segments.map((s) => (
                  <path
                    key={s.r}
                    d={barPath(x, s.topY, barW, s.h, s.last)}
                    fill={resultColour[s.r]}
                  />
                ))}
              </g>
              {(days.length - 1 - i) % 2 === 0 ? (
                <text
                  x={cx}
                  y={H - 6}
                  textAnchor="middle"
                  fontSize="10"
                  fill={hover === i ? "var(--st-fg2)" : "var(--st-fg3)"}
                >
                  {dayName(i)}
                </text>
              ) : null}
            </g>
          );
        })}
        {days.map((_, i) => (
          <rect
            key={i}
            x={padL + slot * i}
            y={0}
            width={slot}
            height={H}
            fill="transparent"
            onMouseEnter={() => setHover(i)}
          />
        ))}
      </svg>
      {hover !== null && hovered ? (
        <ChartTooltip left={tipLeft} top={padT} width={tipW}>
          <div className="flex items-baseline justify-between gap-2">
            <span className="font-medium">{dayName(hover, true)}</span>
            <span className="text-[11px] text-[var(--st-fg3)]">
              {hovered.runs} {hovered.runs === 1 ? "run" : "runs"}
            </span>
          </div>
          <div className="mt-1.5 space-y-1">
            <TooltipRow result="pass" value={hovered.pass} />
            <TooltipRow result="warn" value={hovered.warn} />
            <TooltipRow result="fail" value={hovered.fail} />
          </div>
        </ChartTooltip>
      ) : null}
    </div>
  );
}

/** One cell per day for a single check, coloured by that day's result. */
function CheckStrip({ results }: { results: Result[] }) {
  const [ref, width] = useWidth<HTMLDivElement>(280);
  const [hover, setHover] = useState<number | null>(null);
  const slot = Math.max(10, Math.min(22, Math.floor(width / Math.max(1, results.length))));
  const tipW = 132;
  const hovered = hover === null ? undefined : results[hover];
  let tipLeft = 0;
  if (hover !== null) {
    const right = (hover + 1) * slot + 6;
    tipLeft = right + tipW <= width ? right : Math.max(0, hover * slot - 6 - tipW);
  }
  return (
    <div ref={ref} className="relative h-[84px]" onMouseLeave={() => setHover(null)}>
      <div
        className="flex h-full items-center"
        role="img"
        aria-label={`Daily results: ${results.map((r) => statusText[r]).join(", ")}`}
      >
        {results.map((r, i) => (
          <div
            key={i}
            onMouseEnter={() => setHover(i)}
            className="flex h-full items-center justify-center"
            style={{ width: slot }}
          >
            <span
              className="h-[30px] rounded-[4px] transition-opacity duration-100"
              style={{
                width: slot - 2,
                background: resultColour[r],
                opacity: hover !== null && hover !== i ? 0.55 : 1,
                boxShadow:
                  hover === i ? "0 0 0 1.5px var(--st-bg), 0 0 0 2.5px var(--st-fg3)" : undefined,
              }}
            />
          </div>
        ))}
      </div>
      <div
        className="pointer-events-none absolute bottom-[3px] left-0 flex justify-between text-[10px] text-[var(--st-fg3)]"
        style={{ width: slot * results.length }}
      >
        <span>{dayName(0)}</span>
        <span>Today</span>
      </div>
      {hover !== null && hovered ? (
        <ChartTooltip left={tipLeft} top={2} width={tipW}>
          <div className="font-medium">{dayName(hover, true)}</div>
          <div className="mt-0.5 flex items-center gap-1.5 text-[var(--st-fg2)]">
            <StatusIcon state={hovered} size={12} /> {statusText[hovered]}
          </div>
        </ChartTooltip>
      ) : null}
    </div>
  );
}

/** Deterministic run times in milliseconds for one check over the 14 days. */
function runTimesOf(c: Check) {
  const base = checkMeta[c.id]?.ms ?? 100;
  const seed = [...c.id].reduce((h, ch) => h + ch.charCodeAt(0), 0);
  return Array.from({ length: DAYS }, (_, i) =>
    i === DAYS - 1 ? base : Math.round(base * (0.78 + 0.44 * noise(seed, i))),
  );
}

const pastTense: Record<Result, string> = { pass: "passed", warn: "warned", fail: "failed" };

function StripSummary({ results }: { results: Result[] }) {
  const counts = (["pass", "warn", "fail"] as const)
    .map((r) => ({ r, n: results.filter((x) => x === r).length }))
    .filter((c) => c.n > 0);
  return (
    <span className="flex items-center gap-[10px] text-[11px] text-[var(--st-fg2)] tabular-nums">
      {counts.map(({ r, n }) => (
        <span key={r} className="flex items-center gap-[4px]">
          <StatusIcon state={r} size={11} />
          {n} {pastTense[r]}
        </span>
      ))}
    </span>
  );
}

function ToggleRow({
  expanded,
  onToggle,
  className,
  children,
}: {
  expanded: boolean;
  onToggle: () => void;
  className?: string;
  children: ReactNode;
}) {
  return (
    <div
      role="button"
      tabIndex={0}
      aria-expanded={expanded}
      onClick={onToggle}
      onKeyDown={(e) => {
        if (e.target !== e.currentTarget || (e.key !== "Enter" && e.key !== " ")) return;
        e.preventDefault();
        onToggle();
      }}
      className={cx(
        "cursor-pointer transition-colors outline-none hover:bg-[var(--st-hover)] focus-visible:bg-[var(--st-hover)] focus-visible:ring-2 focus-visible:ring-[var(--st-accent)] focus-visible:ring-inset",
        className,
      )}
    >
      {children}
    </div>
  );
}

function Chevron({ open }: { open: boolean }) {
  return (
    <ChevronRight
      size={14}
      className={cx(
        "shrink-0 justify-self-end text-[var(--st-fg3)] transition-transform duration-150",
        open && "rotate-90",
      )}
    />
  );
}

function CommandBlock({ command, output }: { command: string; output: string }) {
  const [copied, setCopied] = useState(false);
  return (
    <div className="overflow-hidden rounded-[8px] border border-[var(--st-border)] bg-[var(--st-side)] font-mono text-[11.5px]">
      <div className="flex items-center gap-2 border-b border-[var(--st-border)] px-3 py-2">
        <span className="text-[var(--st-fg3)]">$</span>
        <span className="min-w-0 flex-1 truncate text-[var(--st-fg)]">{command}</span>
        <button
          type="button"
          onClick={() => {
            void navigator.clipboard?.writeText(command).catch(() => undefined);
            setCopied(true);
            window.setTimeout(() => setCopied(false), 1200);
          }}
          className="flex items-center gap-1 rounded-[5px] px-1.5 py-0.5 font-sans text-[11px] text-[var(--st-fg2)] hover:bg-[var(--st-hover)] hover:text-[var(--st-fg)]"
        >
          {copied ? <Check size={11} /> : <Copy size={11} />} {copied ? "Copied" : "Copy"}
        </button>
      </div>
      <div className="px-3 py-2 whitespace-pre-wrap text-[var(--st-fg2)]">{output}</div>
    </div>
  );
}

function CheckDetail({
  c,
  isFixed,
  ranAt,
  results,
  busy,
  onRun,
}: {
  c: Check;
  isFixed: boolean;
  ranAt: string;
  results: Result[];
  busy: boolean;
  onRun: () => void;
}) {
  const runTimes = runTimesOf(c);
  return (
    <div className="space-y-3 pt-0.5 pr-5 pb-4 pl-[47px]">
      <CommandBlock
        command={isFixed && c.fix ? c.fix.command : c.command}
        output={isFixed && c.fix ? "Done" : c.output}
      />
      <div className="grid grid-cols-2 gap-[24px]">
        <div className="min-w-0">
          <div className="flex items-center justify-between gap-[8px]">
            <span className="text-[11.5px] font-medium text-[var(--st-fg2)]">Last 14 days</span>
            <StripSummary results={results} />
          </div>
          <CheckStrip results={results} />
        </div>
        <div className="min-w-0">
          <div className="flex items-center justify-between gap-[8px]">
            <span className="text-[11.5px] font-medium text-[var(--st-fg2)]">Run time</span>
            <span className="text-[11px] text-[var(--st-fg3)] tabular-nums">
              Average{" "}
              {Math.round(runTimes.reduce((s, v) => s + v, 0) / Math.max(1, runTimes.length))} ms
            </span>
          </div>
          <LineChart
            values={runTimes}
            dateOf={dayName}
            format={(v) => `${v} ms`}
            label={`Run time of the ${c.name} check over the last 14 days`}
            height={84}
            area
            ticks={2}
          />
        </div>
      </div>
      <div className="flex items-center justify-between gap-[12px]">
        <span className="flex items-center gap-1.5 text-[11.5px] text-[var(--st-fg2)] tabular-nums">
          <Clock size={12} className="text-[var(--st-fg3)]" /> Last ran {ranAt}, took{" "}
          {checkMeta[c.id]?.ms ?? 100} ms
        </span>
        <Button size="sm" onClick={onRun} disabled={busy}>
          <Play size={11} /> Run this check
        </Button>
      </div>
      {c.fix && !isFixed ? (
        <p className="text-[11.5px] text-[var(--st-fg3)]">
          {c.fix.label} runs{" "}
          <code className="font-mono text-[11px] break-all text-[var(--st-fg2)]">
            {c.fix.command}
          </code>
        </p>
      ) : null}
    </div>
  );
}

function Stat({
  icon,
  label,
  value,
  first,
}: {
  icon?: ReactNode;
  label: string;
  value: ReactNode;
  first?: boolean;
}) {
  return (
    <div className={cx("px-5 py-3", !first && "border-l border-[var(--st-border)]")}>
      <dt className="flex items-center gap-1.5 text-[11.5px] text-[var(--st-fg2)]">
        {icon}
        {label}
      </dt>
      <dd className="mt-1 text-[18px] leading-none font-semibold tracking-[-0.02em] text-[var(--st-fg)] tabular-nums">
        {value}
      </dd>
    </div>
  );
}

export function HealthPage() {
  const [state, setState] = useState<Record<string, Live>>(() =>
    Object.fromEntries(checks.map((c) => [c.id, c.result])),
  );
  const [fixed, setFixed] = useState<Record<string, boolean>>({});
  const [cleared, setCleared] = useState<Record<string, boolean>>({});
  const [ranAt, setRanAt] = useState<Record<string, string>>(() =>
    Object.fromEntries(checks.map((c) => [c.id, checkMeta[c.id]?.lastRun ?? "2 min ago"])),
  );
  const [open, setOpen] = useState<string | null>("skhd");
  const [showPassed, setShowPassed] = useState(false);
  const [running, setRunning] = useState(false);
  const [checkedAt, setCheckedAt] = useState("2 minutes ago");
  const [today, setToday] = useState<Day>({ runs: 2, pass: 12, warn: 4, fail: 2 });
  const timers = useRef<number[]>([]);
  useEffect(() => () => timers.current.forEach((t) => window.clearTimeout(t)), []);
  const later = (ms: number, fn: () => void) => timers.current.push(window.setTimeout(fn, ms));

  const resultOf = (c: Check): Result => (fixed[c.id] ? "pass" : c.result);
  const live = (c: Check): Live => state[c.id] ?? c.result;
  const count = (r: Result) => checks.filter((c) => resultOf(c) === r).length;

  const problems = checks
    .filter((c) => c.result !== "pass" && !cleared[c.id])
    .sort((a, b) => rank[a.result] - rank[b.result]);
  const passing = checks.filter((c) => c.result === "pass" || cleared[c.id]);
  const outstanding = problems.filter((c) => !fixed[c.id]);
  const fixable = outstanding.filter(
    (c) => c.fix && live(c) !== "fixing" && live(c) !== "checking",
  );

  const days: Day[] = [
    ...runsPerDay.map((runs, i) => {
      const on = (r: Result) =>
        runs * checks.filter((c) => pastResult(checkMeta[c.id]?.history[i]) === r).length;
      return { runs, pass: on("pass"), warn: on("warn"), fail: on("fail") };
    }),
    today,
  ];
  const totals = days.reduce(
    (t, d) => ({ pass: t.pass + d.pass, all: t.all + d.pass + d.warn + d.fail }),
    { pass: 0, all: 0 },
  );
  const passRate = Math.round((100 * totals.pass) / Math.max(1, totals.all));

  const toggle = (id: string) => setOpen((o) => (o === id ? null : id));

  const fix = (c: Check) => {
    setState((s) => ({ ...s, [c.id]: "fixing" }));
    later(c.fix?.settings ? 1600 : 1300, () => {
      setState((s) => ({ ...s, [c.id]: "pass" }));
      setFixed((f) => ({ ...f, [c.id]: true }));
      setRanAt((r) => ({ ...r, [c.id]: "just now" }));
    });
  };

  const runOne = (c: Check) => {
    const r = resultOf(c);
    setState((s) => ({ ...s, [c.id]: "checking" }));
    later(700, () => {
      setState((s) => ({ ...s, [c.id]: r }));
      setRanAt((m) => ({ ...m, [c.id]: "just now" }));
      setToday((t) => ({ ...t, [r]: t[r] + 1 }));
      if (fixed[c.id]) setCleared((m) => ({ ...m, [c.id]: true }));
    });
  };

  const runAll = () => {
    if (running) return;
    setRunning(true);
    setState(Object.fromEntries(checks.map((c) => [c.id, "checking" as Live])));
    const ordered = [...problems, ...passing];
    ordered.forEach((c, i) =>
      later(260 + i * 150, () => setState((s) => ({ ...s, [c.id]: resultOf(c) }))),
    );
    const pass = count("pass");
    const warn = count("warn");
    const fail = count("fail");
    const done = { ...fixed };
    later(260 + ordered.length * 150, () => {
      setRunning(false);
      setCheckedAt("just now");
      setCleared(done);
      setRanAt(Object.fromEntries(checks.map((c) => [c.id, "just now"])));
      setToday((t) => ({
        runs: t.runs + 1,
        pass: t.pass + pass,
        warn: t.warn + warn,
        fail: t.fail + fail,
      }));
    });
  };

  const n = outstanding.length;
  const headline = running
    ? "Running checks"
    : n === 0
      ? "Everything is set up"
      : `${n} ${n === 1 ? "thing needs" : "things need"} attention`;
  const passingBusy = passing.some((c) => live(c) === "checking");
  const names = passing.map((c) => c.name);
  const passingSummary =
    names.length > 3
      ? `${names.slice(0, 3).join(", ")} and ${names.length - 3} more`
      : names.join(", ");

  return (
    <>
      <PageHeader title="Setup health" />

      <div>
        <Card className="mb-4">
          <div className="flex items-start justify-between gap-4 px-5 pt-4">
            <div className="min-w-0">
              <div className="text-[15px] font-semibold tracking-[-0.01em] text-[var(--st-fg)]">
                {headline}
              </div>
              <div className="mt-0.5 text-[12.5px] text-[var(--st-fg2)]">
                {checks.length} checks, last run {checkedAt}
              </div>
            </div>
            <div className="flex shrink-0 items-center gap-2">
              <Button
                size="sm"
                variant={fixable.length > 0 ? "outline" : "primary"}
                onClick={running ? undefined : runAll}
              >
                <RotateCw size={12} className={running ? "animate-spin" : undefined} />{" "}
                {running ? "Checking" : "Run all checks"}
              </Button>
              {fixable.length > 0 ? (
                <Button
                  size="sm"
                  variant="primary"
                  onClick={() => fixable.forEach(fix)}
                  disabled={running}
                >
                  <Wrench size={12} /> Fix all {fixable.length}
                </Button>
              ) : null}
            </div>
          </div>

          <dl className="mt-4 grid grid-cols-4 border-y border-[var(--st-border)]">
            <Stat
              first
              icon={<StatusIcon state="pass" size={12} />}
              label="Passed"
              value={count("pass")}
            />
            <Stat
              icon={<StatusIcon state="warn" size={12} />}
              label="Warnings"
              value={count("warn")}
            />
            <Stat
              icon={<StatusIcon state="fail" size={12} />}
              label="Failed"
              value={count("fail")}
            />
            <Stat label="Pass rate, 14 days" value={`${passRate}%`} />
          </dl>

          <div className="px-5 pt-3.5 pb-3">
            <div className="mb-2 flex items-center justify-between gap-3">
              <div className="flex items-baseline gap-2">
                <span className="text-[12.5px] font-medium text-[var(--st-fg)]">Check history</span>
                <span className="text-[11.5px] text-[var(--st-fg3)]">Last 14 days</span>
              </div>
              <div className="flex items-center gap-3 text-[11.5px] text-[var(--st-fg2)]">
                {(["pass", "warn", "fail"] as const).map((r) => (
                  <span key={r} className="flex items-center gap-1.5">
                    <StatusIcon state={r} size={12} /> {statusText[r]}
                  </span>
                ))}
              </div>
            </div>
            <HistoryChart days={days} />
          </div>
        </Card>

        {problems.length > 0 ? (
          <Card className="mb-4 overflow-hidden">
            <CardTitle
              title="Needs attention"
              action={
                <span className="text-[11.5px] text-[var(--st-fg3)] tabular-nums">
                  {problems.length - n} of {problems.length} fixed
                </span>
              }
            />
            {problems.map((c) => {
              const s = live(c);
              const isFixed = Boolean(fixed[c.id]) && s === "pass";
              const expanded = open === c.id;
              return (
                <div key={c.id} className="border-t border-[var(--st-border)]">
                  <ToggleRow
                    expanded={expanded}
                    onToggle={() => toggle(c.id)}
                    className="grid grid-cols-[minmax(0,1fr)_136px_14px] items-center gap-4 px-5 py-3"
                  >
                    <div className="flex min-w-0 items-start gap-3">
                      <span className="mt-[2px]">
                        <StatusIcon state={s} />
                      </span>
                      <div className="min-w-0">
                        <div className="flex items-baseline gap-2">
                          <span className="text-[13px] font-medium text-[var(--st-fg)]">
                            {c.name}
                          </span>
                          <span className="text-[11.5px] text-[var(--st-fg3)]">{c.group}</span>
                        </div>
                        <div className="mt-0.5 truncate text-[12px] text-[var(--st-fg2)]">
                          <span className="font-medium text-[var(--st-fg)]">
                            {isFixed ? "Fixed just now" : statusText[s]}
                          </span>
                          <span className="text-[var(--st-fg3)]"> · </span>
                          {isFixed && c.fix ? c.fix.detail : c.detail}
                        </div>
                      </div>
                    </div>
                    <div onClick={(e) => e.stopPropagation()}>
                      {s === "fixing" ? (
                        <Button size="sm" className="w-full" disabled>
                          <Loader2 size={12} className="animate-spin" /> Fixing
                        </Button>
                      ) : isFixed ? (
                        <Button
                          size="sm"
                          variant="ghost"
                          className="w-full"
                          onClick={() => runOne(c)}
                        >
                          <RotateCw size={12} /> Re-check
                        </Button>
                      ) : c.fix ? (
                        <Button
                          size="sm"
                          className="w-full"
                          onClick={() => fix(c)}
                          disabled={s === "checking"}
                        >
                          {c.fix.settings ? <Settings2 size={12} /> : <Wrench size={12} />}{" "}
                          {c.fix.label}
                        </Button>
                      ) : null}
                    </div>
                    <Chevron open={expanded} />
                  </ToggleRow>
                  {expanded ? (
                    <CheckDetail
                      c={c}
                      isFixed={isFixed}
                      ranAt={ranAt[c.id] ?? "just now"}
                      results={[...historyOf(c), resultOf(c)]}
                      busy={s === "checking" || s === "fixing"}
                      onRun={() => runOne(c)}
                    />
                  ) : null}
                </div>
              );
            })}
          </Card>
        ) : null}

        <Card className="overflow-hidden">
          <ToggleRow
            expanded={showPassed}
            onToggle={() => setShowPassed((v) => !v)}
            className="grid grid-cols-[minmax(0,1fr)_auto_14px] items-center gap-4 px-5 py-3"
          >
            <div className="flex min-w-0 items-center gap-3">
              <StatusIcon state={passingBusy ? "checking" : "pass"} />
              <div className="min-w-0">
                <div className="text-[13px] font-medium text-[var(--st-fg)]">
                  {passing.length} {passing.length === 1 ? "check" : "checks"} passed
                </div>
                <div className="truncate text-[12px] text-[var(--st-fg2)]">{passingSummary}</div>
              </div>
            </div>
            <span className="text-[11.5px] text-[var(--st-fg3)]">
              {showPassed ? "Hide" : "Show all"}
            </span>
            <Chevron open={showPassed} />
          </ToggleRow>
          {showPassed
            ? passing.map((c) => {
                const s = live(c);
                const expanded = open === c.id;
                return (
                  <div key={c.id} className="border-t border-[var(--st-border)]">
                    <ToggleRow
                      expanded={expanded}
                      onToggle={() => toggle(c.id)}
                      className="grid grid-cols-[minmax(0,1fr)_auto_14px] items-center gap-4 px-5 py-2.5"
                    >
                      <div className="flex min-w-0 items-center gap-3">
                        <StatusIcon state={s} />
                        <span className="shrink-0 text-[13px] font-medium text-[var(--st-fg)]">
                          {c.name}
                        </span>
                        <span className="truncate text-[12px] text-[var(--st-fg2)]">
                          {fixed[c.id] && c.fix ? c.fix.detail : c.detail}
                        </span>
                      </div>
                      <span className="text-[11.5px] text-[var(--st-fg3)] tabular-nums">
                        {s === "checking" ? "Checking" : ranAt[c.id]}
                      </span>
                      <Chevron open={expanded} />
                    </ToggleRow>
                    {expanded ? (
                      <CheckDetail
                        c={c}
                        isFixed={Boolean(fixed[c.id])}
                        ranAt={ranAt[c.id] ?? "just now"}
                        results={[...historyOf(c), resultOf(c)]}
                        busy={s === "checking"}
                        onRun={() => runOne(c)}
                      />
                    ) : null}
                  </div>
                );
              })
            : null}
        </Card>
        <button
          type="button"
          className="mt-3 flex items-center gap-1 px-1 text-[11.5px] text-[var(--st-fg3)] hover:text-[var(--st-fg)]"
        >
          <Copy size={12} /> Copy report
        </button>
      </div>
    </>
  );
}
