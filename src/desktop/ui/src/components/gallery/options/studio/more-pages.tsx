import {
  Activity,
  AppWindow,
  ArrowRight,
  BadgeCheck,
  BatteryMedium,
  Beer,
  Bell,
  BellOff,
  BellRing,
  Bluetooth,
  CalendarClock,
  CalendarDays,
  Check,
  Clock,
  Cloud,
  CloudRain,
  CloudSun,
  Coffee,
  Cpu,
  EyeOff,
  GitPullRequest,
  Globe,
  Gpu,
  GripVertical,
  HardDrive,
  Hash,
  Keyboard,
  Layers,
  ListTodo,
  Mail,
  MemoryStick,
  MessageSquare,
  Moon,
  type LucideIcon,
  Music,
  Palette,
  PanelTop,
  Pause,
  Pencil,
  Plus,
  Puzzle,
  Rocket,
  RotateCcw,
  Search,
  SkipBack,
  SkipForward,
  Sparkles,
  SquareTerminal,
  Terminal,
  Timer,
  Trash,
  Video,
  Volume2,
  Wifi,
  X,
  Zap,
} from "lucide-react";
import {
  type CSSProperties,
  type KeyboardEvent as ReactKeyboardEvent,
  type ReactNode,
  useEffect,
  useState,
} from "react";

import { BrandMark } from "~/shell/brand-mark";

import { currentThemeId, realThemes, snapshot, wallpaperUrl } from "../real";
import {
  Badge,
  Button,
  Card,
  CardHeader,
  PageHeader,
  Row,
  SectionLabel,
  Segmented,
  Slider,
  Switch,
  Tabs,
  cx,
  focusRing,
  usePageSearch,
} from "./ui";

const fieldCls =
  "w-full rounded-[7px] border border-[var(--st-border)] bg-[var(--st-bg)] px-2.5 text-[13px] text-[var(--st-fg)] shadow-[var(--st-shadow)] outline-none placeholder:text-[var(--st-fg3)] focus:border-[var(--st-accent)] focus:ring-[3px] focus:ring-[var(--st-accent-soft)]";

function SearchInput({
  value,
  onChange,
  placeholder,
  className,
}: {
  value: string;
  onChange: (v: string) => void;
  placeholder: string;
  className?: string;
}) {
  return (
    <label
      className={cx(
        "flex h-8 w-[220px] items-center gap-2 rounded-[7px] border border-[var(--st-border)] bg-[var(--st-bg)] px-2.5 shadow-[var(--st-shadow)] focus-within:border-[var(--st-accent)] focus-within:ring-[3px] focus-within:ring-[var(--st-accent-soft)]",
        className,
      )}
    >
      <Search size={14} className="text-[var(--st-fg3)]" />
      <input
        value={value}
        onChange={(e) => onChange(e.target.value)}
        placeholder={placeholder}
        className="w-full bg-transparent text-[13px] text-[var(--st-fg)] outline-none placeholder:text-[var(--st-fg3)]"
      />
    </label>
  );
}

function Empty({
  icon: Icon,
  title,
  action,
}: {
  icon: LucideIcon;
  title: string;
  action?: ReactNode;
}) {
  return (
    <div className="grid place-items-center rounded-[10px] border border-dashed border-[var(--st-border)] px-6 py-12 text-center">
      <Icon size={20} strokeWidth={1.75} className="mb-2 text-[var(--st-fg3)]" />
      <div className="text-[13px] font-medium text-[var(--st-fg)]">{title}</div>
      {action ? <div className="mt-3">{action}</div> : null}
    </div>
  );
}

function IconButton({
  label,
  onClick,
  children,
  active,
  destructive,
  big,
}: {
  label: string;
  onClick: () => void;
  children: ReactNode;
  active?: boolean;
  destructive?: boolean;
  big?: boolean;
}) {
  return (
    <button
      type="button"
      aria-label={label}
      title={label}
      onClick={(e) => {
        e.stopPropagation();
        onClick();
      }}
      className={cx(
        "grid shrink-0 place-items-center transition-colors",
        big ? "size-7 rounded-[7px]" : "size-6 rounded-[5px]",
        focusRing,
        active
          ? "bg-[var(--st-muted)] text-[var(--st-fg)]"
          : cx(
              "text-[var(--st-fg3)] hover:bg-[var(--st-hover)]",
              destructive ? "hover:text-[#e5484d]" : "hover:text-[var(--st-fg)]",
            ),
      )}
    >
      {children}
    </button>
  );
}

/** Centred modal over the whole settings window. */
function Dialog({
  label,
  onClose,
  width,
  height,
  children,
}: {
  label: string;
  onClose: () => void;
  width: number;
  height?: number;
  children: ReactNode;
}) {
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
        aria-label={label}
        className="relative flex max-h-full flex-col overflow-hidden rounded-[12px] border border-[var(--st-border)] bg-[var(--st-bg)] shadow-[0_24px_64px_-16px_rgba(0,0,0,0.35)]"
        style={{ width, height }}
      >
        {children}
      </div>
    </div>
  );
}

function DialogHeader({
  title,
  description,
  onClose,
  children,
}: {
  title: ReactNode;
  description?: ReactNode;
  onClose: () => void;
  children?: ReactNode;
}) {
  return (
    <div className="flex items-start gap-3 px-5 pt-4 pb-3">
      {children}
      <div className="min-w-0 flex-1">
        <h2 className="flex items-center gap-2 text-[14px] font-semibold tracking-[-0.01em] text-[var(--st-fg)]">
          {title}
        </h2>
        {description ? (
          <p className="mt-0.5 text-[12.5px] text-[var(--st-fg2)]">{description}</p>
        ) : null}
      </div>
      <IconButton label="Close" big onClick={onClose}>
        <X size={14} />
      </IconButton>
    </div>
  );
}

function FieldLabel({ children, hint }: { children: ReactNode; hint?: string }) {
  return (
    <div className="mb-1.5 flex items-baseline gap-2">
      <span className="text-[12px] font-medium text-[var(--st-fg2)]">{children}</span>
      {hint ? <span className="text-[11.5px] text-[var(--st-fg3)]">{hint}</span> : null}
    </div>
  );
}

/* ------------------------------------------------------------------ */
/* Plugins                                                             */
/* ------------------------------------------------------------------ */

const pluginCats = ["All", "Menu bar", "Windows", "Integrations", "Focus"] as const;
type PluginCat = (typeof pluginCats)[number];

interface Plugin {
  id: string;
  name: string;
  icon: LucideIcon;
  cat: Exclude<PluginCat, "All">;
  author: string;
  detail: string;
  about: string;
  brings: string[];
}

const plugins: Plugin[] = [
  {
    id: "media",
    name: "Now playing",
    icon: Music,
    cat: "Menu bar",
    author: "Macarchy",
    detail: "Track and controls for Music and Spotify in the bar.",
    about:
      "Shows the current track from Music or Spotify. Click to play, pause or skip, and hover for the artwork.",
    brings: ["Menu bar item", "Play, pause and skip shortcuts", "Artwork popup"],
  },
  {
    id: "weather",
    name: "Weather",
    icon: CloudSun,
    cat: "Menu bar",
    author: "Macarchy",
    detail: "Current conditions and a three-hour outlook.",
    about:
      "Temperature and conditions where you are, refreshed every 15 minutes. Click it for the next three hours.",
    brings: ["Menu bar item", "Hourly outlook popup", "Location permission"],
  },
  {
    id: "brew",
    name: "Homebrew updates",
    icon: Beer,
    cat: "Menu bar",
    author: "@oskar",
    detail: "Counts outdated formulae and upgrades them in one click.",
    about:
      "Checks Homebrew once an hour and shows how many formulae and casks are out of date. Upgrade everything, or pick what to skip.",
    brings: ["Menu bar item", "Hourly background check", "Upgrade from the popup"],
  },
  {
    id: "stack",
    name: "Window stacks",
    icon: Layers,
    cat: "Windows",
    author: "@mira",
    detail: "Group windows into tabs inside one tile.",
    about:
      "Stack several windows in a single tile and switch between them like browser tabs. Works with every AeroSpace layout.",
    brings: ["Layout mode", "Tab strip on stacked tiles", "Next and previous tab shortcuts"],
  },
  {
    id: "keys",
    name: "Key overlay",
    icon: Keyboard,
    cat: "Windows",
    author: "@tobyk",
    detail: "Shows the shortcuts for the focused app while you hold Option.",
    about:
      "Hold Option for a moment to see a cheat sheet for the app in front, including your own Macarchy shortcuts.",
    brings: ["Overlay", "Cheat sheets for 40 popular apps", "Accessibility permission"],
  },
  {
    id: "scratch",
    name: "Scratchpad",
    icon: SquareTerminal,
    cat: "Windows",
    author: "Macarchy",
    detail: "A floating terminal that drops down with one shortcut.",
    about:
      "Keeps a terminal floating above your tiles on every workspace. Press the shortcut to show or hide it without losing your place.",
    brings: ["Floating window rule", "Show and hide shortcut", "Remembers size and position"],
  },
  {
    id: "pr",
    name: "Pull requests",
    icon: GitPullRequest,
    cat: "Integrations",
    author: "@mira",
    detail: "Review requests waiting for you, counted in the bar.",
    about:
      "Counts the GitHub pull requests that are waiting on your review. Click one to open it in your browser.",
    brings: ["Menu bar item", "Sign-in with a GitHub token", "Open a review in one click"],
  },
  {
    id: "linear",
    name: "Linear issues",
    icon: ListTodo,
    cat: "Integrations",
    author: "@tobyk",
    detail: "Your assigned issues, with the active one in the bar.",
    about:
      "Shows the issue you are working on and lets you switch to another from the command palette.",
    brings: ["Menu bar item", "Issue picker in the command palette", "Linear API key"],
  },
  {
    id: "meetings",
    name: "Meeting join",
    icon: CalendarClock,
    cat: "Integrations",
    author: "Macarchy",
    detail: "Your next meeting, with a join button when it starts.",
    about:
      "Reads your calendar and shows the next meeting. A join button appears a minute before it starts.",
    brings: ["Menu bar item", "Join links for Zoom, Meet and Teams", "Calendar permission"],
  },
  {
    id: "slack",
    name: "Slack status",
    icon: MessageSquare,
    cat: "Integrations",
    author: "@oskar",
    detail: "Sets your Slack status from the workspace you are in.",
    about:
      "Pick a status for each workspace, such as Focusing on your editor workspace, and it updates as you move around.",
    brings: ["Rule set", "Status per workspace", "Slack sign-in"],
  },
  {
    id: "pomodoro",
    name: "Focus timer",
    icon: Timer,
    cat: "Focus",
    author: "Macarchy",
    detail: "25 minute sessions that hide noisy workspaces.",
    about:
      "Starts a 25 minute session and hides the workspaces you mark as noisy until it ends. Breaks are announced in the bar.",
    brings: ["Menu bar item", "Rule set", "Start and stop shortcut"],
  },
  {
    id: "quiet",
    name: "Quiet hours",
    icon: BellOff,
    cat: "Focus",
    author: "Macarchy",
    detail: "Mutes notifications while a fullscreen window has focus.",
    about: "Turns on Do Not Disturb when a window goes fullscreen, and on a schedule you choose.",
    brings: ["Rule set", "Schedule by time of day"],
  },
];

const featured = ["media", "stack"] as const;

const barTheme = realThemes.find((t) => t.id === currentThemeId) ?? realThemes[0]!;
const barWallpaper = wallpaperUrl(barTheme.id, barTheme.wallpaper);
/** Each plugin's identity hue, used for its tile, preview wash and accents. */
const pluginColour: Record<string, string> = {
  media: "#ec4899",
  weather: "#0ea5e9",
  brew: "#f59e0b",
  stack: "#6366f1",
  keys: "#64748b",
  scratch: "#10b981",
  pr: "#8b5cf6",
  linear: "#3b82f6",
  meetings: "#14b8a6",
  slack: "#a8458f",
  pomodoro: "#f97316",
  quiet: "#f43f5e",
};

/** Sets --pl, which every preview and accent below reads for the plugin's hue. */
function hueVars(p: Plugin): CSSProperties {
  return { "--pl": pluginColour[p.id] ?? "#71717a" } as CSSProperties;
}

/* Mixing towards --st-fg and --st-bg keeps the hue legible in light and dark. */
const ink = "color-mix(in srgb, var(--pl) 80%, var(--st-fg))";
const solid = "color-mix(in srgb, var(--pl) 88%, black)";
const line = "color-mix(in srgb, var(--pl) 24%, var(--st-border))";
const tint = (pct: number) => `color-mix(in srgb, var(--pl) ${pct}%, var(--st-bg))`;
const glass = (pct: number) => `color-mix(in srgb, var(--pl) ${pct}%, transparent)`;

/** A faint backdrop pattern per category, so sections read differently at a glance. */
const catPattern: Record<Plugin["cat"], CSSProperties> = {
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

function PluginTile({ plugin, size }: { plugin: Plugin; size: number }) {
  const Icon = plugin.icon;
  return (
    <span
      className="grid shrink-0 place-items-center text-white shadow-[inset_0_0_0_1px_rgba(255,255,255,0.18),0_1px_2px_rgba(0,0,0,0.2)]"
      style={{
        ...hueVars(plugin),
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

function Avatar({ author, size = 20 }: { author: string; size?: number }) {
  if (author === "Macarchy")
    return (
      <span
        aria-hidden
        className="grid shrink-0 place-items-center rounded-full bg-[var(--st-primary)] text-[var(--st-primary-fg)]"
        style={{ width: size, height: size }}
      >
        <BrandMark width={Math.round(size * 0.62)} height={Math.round(size * 0.62)} />
      </span>
    );
  const name = author.replace(/^@/, "");
  let hue = 0;
  for (const ch of name) hue = (hue * 31 + ch.charCodeAt(0)) % 360;
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
      {name.slice(0, 1).toUpperCase()}
    </span>
  );
}

/** The plugin's own element, centred on a soft wash and pattern in its hue. */
function Stage({
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
  label?: ReactNode;
  children: ReactNode;
}) {
  const fade = "radial-gradient(ellipse 72% 72% at 50% 50%, black 10%, transparent 78%)";
  return (
    <div
      className={cx("relative isolate overflow-hidden", className)}
      style={{
        height,
        background: `radial-gradient(110% 90% at 50% 35%, ${tint(20)}, ${tint(6)})`,
      }}
    >
      <div
        aria-hidden
        className="absolute inset-0"
        style={{ ...catPattern[plugin.cat], maskImage: fade, WebkitMaskImage: fade }}
      />
      <div aria-hidden className="absolute inset-0 grid place-items-center">
        <div style={scale === 1 ? undefined : { transform: `scale(${scale})` }}>{children}</div>
      </div>
      {label ? (
        <span
          className="absolute top-[12px] left-[12px] inline-flex h-[22px] items-center gap-[5px] rounded-full border bg-[var(--st-bg)] px-[9px] text-[11px] font-medium"
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
      className={cx("rounded-[10px] border bg-[var(--st-bg)] text-[var(--st-fg)]", className)}
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
      className={cx(
        "grid h-[19px] min-w-[19px] place-items-center rounded-[5px] border border-b-[2px] px-[5px] font-sans text-[10.5px] font-semibold",
        !held && "border-[var(--st-border-strong)] bg-[var(--st-side)] text-[var(--st-fg2)]",
      )}
      style={held ? { borderColor: glass(55), background: tint(16), color: ink } : undefined}
    >
      {children}
    </span>
  );
}

const shortcuts: [string[], string][] = [
  [["⌥", "H"], "Focus left"],
  [["⌥", "⇧", "F"], "Fullscreen"],
  [["⌥", "1"], "Workspace 1"],
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

const prRows: [string, string][] = [
  ["#412", "Tidy bar spacing"],
  ["#409", "Window stacks"],
  ["#401", "Theme import fixes"],
];

function MediaArt() {
  return (
    <Surface className="flex w-[226px] items-center gap-[12px] p-[10px]">
      <span
        className="grid size-[62px] shrink-0 place-items-center rounded-[8px] text-white shadow-[inset_0_0_0_1px_rgba(255,255,255,0.15)]"
        style={{
          background:
            "linear-gradient(140deg, color-mix(in srgb, var(--pl) 60%, #fde68a), var(--pl) 50%, color-mix(in srgb, var(--pl) 55%, #3b0764))",
        }}
      >
        <Music size={24} strokeWidth={2} />
      </span>
      <div className="min-w-0 flex-1">
        <div className="truncate text-[12.5px] font-semibold tracking-[-0.01em]">Veridis Quo</div>
        <div className="truncate text-[11px] text-[var(--st-fg2)]">Daft Punk</div>
        <div className="mt-[7px] flex items-center gap-[12px] text-[var(--st-fg2)]">
          <SkipBack size={12} fill="currentColor" />
          <span
            className="grid size-[24px] place-items-center rounded-full text-white"
            style={{ background: solid }}
          >
            <Pause size={11} fill="currentColor" strokeWidth={0} />
          </span>
          <SkipForward size={12} fill="currentColor" />
        </div>
        <div
          className="mt-[8px] h-[3px] overflow-hidden rounded-full"
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
    <div className="flex items-center gap-[14px] text-[var(--st-fg)]">
      <CloudSun size={56} strokeWidth={1.5} style={{ color: ink }} />
      <div>
        <div className="text-[40px] leading-none font-semibold tracking-[-0.04em] tabular-nums">
          18°
        </div>
        <div className="mt-[5px] text-[11px] text-[var(--st-fg2)]">Sydney, partly cloudy</div>
        <div className="mt-[8px] flex gap-[10px] text-[10.5px] text-[var(--st-fg2)] tabular-nums">
          {outlook.map(([Icon, time, temp]) => (
            <span key={time} className="flex items-center gap-[3px]" title={time}>
              <Icon size={11} strokeWidth={2} style={{ color: ink }} />
              {temp}
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
      <Surface className="w-[200px] p-[10px]">
        <div className="mb-[5px] flex items-center justify-between text-[10.5px] font-medium text-[var(--st-fg2)]">
          <span>Outdated</span>
          <span className="font-mono text-[var(--st-fg3)]">brew</span>
        </div>
        {brewRows.map(([name, from, to]) => (
          <div
            key={name}
            className="flex items-center gap-[5px] font-mono text-[10.5px] leading-[18px]"
          >
            <span className="flex-1">{name}</span>
            <span className="text-[var(--st-fg3)]">{from}</span>
            <ArrowRight size={9} className="text-[var(--st-fg3)]" />
            <span style={{ color: ink }}>{to}</span>
          </div>
        ))}
        <div
          className="mt-[8px] grid h-[22px] place-items-center rounded-[6px] text-[10.5px] font-semibold"
          style={{ background: "var(--pl)", color: "color-mix(in srgb, var(--pl) 22%, black)" }}
        >
          Upgrade all
        </div>
      </Surface>
      <span
        className="absolute -top-[9px] -right-[9px] grid size-[24px] place-items-center rounded-full text-[11px] font-bold ring-2 ring-[var(--st-bg)]"
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
    <div className="relative w-[214px] pt-[10px]">
      <div
        className="absolute inset-x-[16px] top-0 h-[24px] rounded-t-[10px] border border-b-0"
        style={{ borderColor: line, background: tint(10) }}
      />
      <div
        className="absolute inset-x-[8px] top-[5px] h-[24px] rounded-t-[10px] border border-b-0"
        style={{ borderColor: line, background: tint(16) }}
      />
      <Surface className="relative overflow-hidden">
        <div
          className="flex gap-[2px] border-b px-[5px] pt-[5px]"
          style={{ borderColor: line, background: tint(8) }}
        >
          {tabs.map((tab, i) => (
            <span
              key={tab}
              className={cx(
                "flex-1 truncate rounded-t-[5px] px-[6px] py-[4px] text-center text-[10px] font-medium",
                i === 0 ? "bg-[var(--st-bg)] text-[var(--st-fg)]" : "text-[var(--st-fg3)]",
              )}
              style={i === 0 ? { boxShadow: "inset 0 2px 0 var(--pl)" } : undefined}
            >
              {tab}
            </span>
          ))}
        </div>
        <div className="space-y-[5px] p-[10px]">
          {codeRows.map(([indent, width], i) => (
            <div
              key={i}
              className="h-[4px] rounded-full"
              style={{
                marginLeft: indent * 10,
                width: `${width}%`,
                background: i % 3 === 0 ? glass(70) : "var(--st-border-strong)",
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
    <Surface className="w-[212px] p-[10px]">
      <div className="mb-[6px] flex items-center justify-between">
        <span className="text-[11px] font-semibold">Ghostty</span>
        <span className="flex items-center gap-[5px] text-[10px] text-[var(--st-fg3)]">
          Holding <Keycap held>⌥</Keycap>
        </span>
      </div>
      {shortcuts.map(([keys, label]) => (
        <div key={label} className="flex items-center justify-between py-[3px] text-[11px]">
          <span className="text-[var(--st-fg2)]">{label}</span>
          <span className="flex gap-[3px]">
            {keys.map((k) => (
              <Keycap key={k}>{k}</Keycap>
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
      className="relative h-[118px] w-[214px] overflow-hidden rounded-[10px] border"
      style={{ borderColor: line, background: tint(4) }}
    >
      <div className="absolute inset-[8px] flex gap-[6px]">
        <div className="flex-1 rounded-[6px] border border-[var(--st-border)] bg-[var(--st-bg)]" />
        <div className="flex-1 rounded-[6px] border border-[var(--st-border)] bg-[var(--st-bg)]" />
      </div>
      <div
        className="absolute inset-x-[18px] top-0 rounded-b-[9px] px-[10px] pt-[8px] pb-[7px] font-mono text-[10px] leading-[15px] text-[#d4d4d8]"
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
            className="inline-block h-[10px] w-[6px] translate-y-[1px] animate-pulse"
            style={{ background: "var(--pl)" }}
          />
        </div>
        <div className="mx-auto mt-[5px] h-[3px] w-[28px] rounded-full bg-white/20" />
      </div>
    </div>
  );
}

function PrArt() {
  return (
    <Surface className="w-[222px] overflow-hidden">
      <div
        className="flex items-center justify-between border-b px-[10px] py-[7px] text-[11px] font-semibold"
        style={{ borderColor: line }}
      >
        <span>Review requested</span>
        <span
          className="rounded-full px-[7px] text-[10px] leading-[16px] tabular-nums"
          style={{ background: tint(16), color: ink }}
        >
          3
        </span>
      </div>
      {prRows.map(([n, title]) => (
        <div key={n} className="flex items-center gap-[7px] px-[10px] py-[5px] text-[11px]">
          <GitPullRequest size={12} strokeWidth={2.2} className="shrink-0" style={{ color: ink }} />
          <span className="min-w-0 flex-1 truncate">{title}</span>
          <span className="font-mono text-[10px] text-[var(--st-fg3)]">{n}</span>
        </div>
      ))}
    </Surface>
  );
}

function LinearArt() {
  return (
    <div className="relative">
      <div
        className="absolute inset-0 translate-x-[12px] translate-y-[6px] rotate-[5deg] rounded-[10px] border"
        style={{ borderColor: line, background: tint(14) }}
      />
      <Surface className="relative w-[198px] p-[11px]">
        <div className="flex items-center justify-between font-mono text-[10px] text-[var(--st-fg3)]">
          <span>MAC-142</span>
          <Avatar author="@tobyk" size={16} />
        </div>
        <div className="mt-[5px] text-[12px] leading-[1.35] font-semibold">
          Bar spacing on external displays
        </div>
        <div className="mt-[9px] flex items-center gap-[10px] text-[10.5px]">
          <span className="flex items-center gap-[5px] font-medium" style={{ color: ink }}>
            <span
              className="size-[10px] rounded-full"
              style={{
                background: "conic-gradient(var(--pl) 0 50%, transparent 0)",
                boxShadow: "0 0 0 1.5px var(--pl)",
              }}
            />
            In progress
          </span>
          <span className="flex items-end gap-[1.5px]" title="High priority">
            {[5, 8, 11].map((h) => (
              <span
                key={h}
                className="w-[3px] rounded-[1px]"
                style={{ height: h, background: h < 11 ? ink : "var(--st-border-strong)" }}
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
    <Surface className="flex w-[228px] items-center gap-[10px] p-[10px]">
      <div
        className="flex w-[40px] shrink-0 flex-col items-center rounded-[8px] py-[5px]"
        style={{ background: tint(16), color: ink }}
      >
        <span className="text-[9px] font-semibold tracking-[0.06em] uppercase">Oct</span>
        <span className="text-[17px] leading-none font-semibold">21</span>
      </div>
      <div className="min-w-0 flex-1">
        <div className="truncate text-[12px] font-semibold">Daily standup</div>
        <div className="truncate text-[10.5px] text-[var(--st-fg2)]">Google Meet, in 1 min</div>
      </div>
      <span
        className="flex items-center gap-[4px] rounded-[6px] px-[8px] py-[4px] text-[10.5px] font-semibold text-white"
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
    <div className="relative w-[216px] pt-[16px]">
      <div
        className="absolute inset-x-[22px] top-0 h-[44px] rounded-[10px] border"
        style={{ borderColor: line, background: tint(9) }}
      />
      <div
        className="absolute inset-x-[11px] top-[8px] h-[44px] rounded-[10px] border"
        style={{ borderColor: line, background: tint(15) }}
      />
      <Surface className="relative flex items-center gap-[9px] p-[9px]">
        <span
          className="grid size-[28px] shrink-0 place-items-center rounded-[7px] text-white"
          style={{ background: solid }}
        >
          <Hash size={14} strokeWidth={2.4} />
        </span>
        <div className="min-w-0 flex-1">
          <div className="flex items-baseline justify-between text-[11.5px] font-semibold">
            <span>Slack</span>
            <span className="text-[10px] font-normal text-[var(--st-fg3)]">now</span>
          </div>
          <div className="truncate text-[10.5px] text-[var(--st-fg2)]">Status set to Focusing</div>
        </div>
      </Surface>
    </div>
  );
}

function TimerArt() {
  return (
    <div className="flex flex-col items-center gap-[8px] text-[var(--st-fg)]">
      <span
        className="relative grid size-[96px] place-items-center rounded-full"
        style={{ background: `conic-gradient(var(--pl) 0 74%, ${glass(16)} 0)` }}
      >
        <span className="absolute inset-[7px] rounded-full bg-[var(--st-bg)]" />
        <span className="relative text-center">
          <span className="block font-mono text-[19px] font-semibold tracking-[-0.02em] tabular-nums">
            18:42
          </span>
          <span className="block text-[10px] text-[var(--st-fg3)]">Focus</span>
        </span>
      </span>
      <span className="flex gap-[4px]" title="Session 2 of 4">
        {[0, 1, 2, 3].map((i) => (
          <span
            key={i}
            className="h-[4px] w-[14px] rounded-full"
            style={{ background: i < 2 ? "var(--pl)" : glass(20) }}
          />
        ))}
      </span>
    </div>
  );
}

function QuietArt() {
  return (
    <div className="flex flex-col items-center gap-[14px]">
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
          className="absolute -top-[3px] -right-[5px] grid h-[20px] min-w-[20px] place-items-center rounded-full px-[5px] text-[10.5px] font-bold text-white ring-2 ring-[var(--st-bg)]"
          style={{ background: solid }}
        >
          3
        </span>
      </span>
      <span
        className="rounded-full border bg-[var(--st-bg)] px-[10px] py-[3px] text-[10.5px] text-[var(--st-fg2)]"
        style={{ borderColor: line }}
      >
        3 held until you leave fullscreen
      </span>
    </div>
  );
}

/** What each plugin adds, drawn as its one distinctive element. */
function PluginArt({ id }: { id: string }) {
  switch (id) {
    case "media":
      return <MediaArt />;
    case "weather":
      return <WeatherArt />;
    case "brew":
      return <BrewArt />;
    case "stack":
      return <StackArt />;
    case "keys":
      return <KeysArt />;
    case "scratch":
      return <ScratchArt />;
    case "pr":
      return <PrArt />;
    case "linear":
      return <LinearArt />;
    case "meetings":
      return <MeetingArt />;
    case "slack":
      return <SlackArt />;
    case "pomodoro":
      return <TimerArt />;
    case "quiet":
      return <QuietArt />;
    default:
      return null;
  }
}

function NotifyButton({ name, on, onClick }: { name: string; on: boolean; onClick: () => void }) {
  return (
    <button
      type="button"
      aria-pressed={on}
      aria-label={on ? `Stop notifying me about ${name}` : `Notify me when ${name} is ready`}
      title={on ? "Stop notifying" : "Notify me when it's ready"}
      onClick={(e) => {
        e.stopPropagation();
        onClick();
      }}
      onKeyDown={(e) => e.stopPropagation()}
      className={cx(
        "inline-flex h-[26px] shrink-0 items-center justify-center gap-[5px] rounded-full border text-[11.5px] font-medium transition-colors",
        focusRing,
        on
          ? "px-[9px] hover:brightness-110"
          : "w-[26px] border-[var(--st-border)] text-[var(--st-fg3)] hover:bg-[var(--st-hover)] hover:text-[var(--st-fg)]",
      )}
      style={on ? { background: tint(14), borderColor: glass(40), color: ink } : undefined}
    >
      {on ? <BellRing size={12} strokeWidth={2.2} /> : <Bell size={13} />}
      {on ? "Notifying" : null}
    </button>
  );
}

type CardShape = "normal" | "wide" | "tall" | "full";

const shapeClass: Record<CardShape, string> = {
  normal: "",
  wide: "col-span-2",
  tall: "col-span-2 row-span-2",
  full: "col-span-3",
};

/** Mixes in wide and tall cards so every row of three columns comes out full. */
function bento(n: number): CardShape[] {
  if (n === 1) return ["full"];
  if (n === 3) return ["tall", "normal", "normal"];
  const shapes: CardShape[] = Array.from({ length: n }, () => "normal");
  const wides = (3 - (n % 3)) % 3;
  if (wides >= 1) shapes[0] = "wide";
  if (wides === 2) shapes[n - 1] = "wide";
  return shapes;
}

function CardShell({
  plugin: p,
  onOpen,
  className,
  children,
}: {
  plugin: Plugin;
  onOpen: () => void;
  className?: string;
  children: ReactNode;
}) {
  return (
    <div
      role="button"
      tabIndex={0}
      aria-label={`${p.name} details`}
      onClick={onOpen}
      onKeyDown={(e) => {
        if (e.key === "Enter" || e.key === " ") {
          e.preventDefault();
          onOpen();
        }
      }}
      style={hueVars(p)}
      className={cx(
        "group flex min-w-0 cursor-default overflow-hidden rounded-[14px] border border-[var(--st-border)] bg-[var(--st-bg)] shadow-[var(--st-shadow)] transition-[transform,border-color,box-shadow] duration-200 ease-out hover:-translate-y-[2px] hover:border-[color-mix(in_srgb,var(--pl)_45%,var(--st-border))] hover:shadow-[0_18px_38px_-20px_var(--pl)]",
        focusRing,
        className,
      )}
    >
      {children}
    </div>
  );
}

function CardBody({ plugin: p, text, big }: { plugin: Plugin; text: string; big?: boolean }) {
  return (
    <div className="flex-1 px-[16px] pt-[14px] pb-[16px]">
      <div className="flex items-center gap-[10px]">
        <PluginTile plugin={p} size={big ? 34 : 28} />
        <span
          className="truncate font-semibold tracking-[-0.01em] text-[var(--st-fg)]"
          style={{ fontSize: big ? 15.5 : 14 }}
        >
          {p.name}
        </span>
      </div>
      <p className="mt-[10px] line-clamp-3 text-[12.5px] leading-[1.55] text-[var(--st-fg2)]">
        {text}
      </p>
    </div>
  );
}

function CardFooter({
  plugin: p,
  notified,
  onNotify,
}: {
  plugin: Plugin;
  notified: boolean;
  onNotify: () => void;
}) {
  return (
    <div className="flex h-[44px] shrink-0 items-center gap-[7px] border-t border-[var(--st-border)] px-[16px]">
      <Avatar author={p.author} size={16} />
      <span className="min-w-0 truncate text-[11.5px] text-[var(--st-fg3)]">{p.author}</span>
      {p.author === "Macarchy" ? (
        <span title="Official" className="shrink-0" style={{ color: ink }}>
          <BadgeCheck size={12} strokeWidth={2.2} />
        </span>
      ) : null}
      <span className="flex-1" />
      <NotifyButton name={p.name} on={notified} onClick={onNotify} />
    </div>
  );
}

function PluginCard({
  plugin: p,
  shape,
  notified,
  onNotify,
  onOpen,
}: {
  plugin: Plugin;
  shape: CardShape;
  notified: boolean;
  onNotify: () => void;
  onOpen: () => void;
}) {
  const footer = <CardFooter plugin={p} notified={notified} onNotify={onNotify} />;
  if (shape === "wide" || shape === "full")
    return (
      <CardShell plugin={p} onOpen={onOpen} className={cx("flex-row", shapeClass[shape])}>
        <Stage
          plugin={p}
          scale={1.1}
          className="min-h-[236px] flex-[1.2] border-r border-[var(--st-border)]"
        >
          <PluginArt id={p.id} />
        </Stage>
        <div className="flex min-w-0 flex-1 flex-col">
          <CardBody plugin={p} text={p.about} big />
          {footer}
        </div>
      </CardShell>
    );
  const tall = shape === "tall";
  return (
    <CardShell plugin={p} onOpen={onOpen} className={cx("flex-col", shapeClass[shape])}>
      <Stage
        plugin={p}
        height={tall ? undefined : 156}
        scale={tall ? 1.4 : 0.92}
        className={cx("border-b border-[var(--st-border)]", tall && "min-h-[300px] flex-1")}
      >
        <PluginArt id={p.id} />
      </Stage>
      <CardBody plugin={p} text={tall ? p.about : p.detail} big={tall} />
      {footer}
    </CardShell>
  );
}

function FeaturedCard({
  plugin: p,
  notified,
  onNotify,
  onOpen,
}: {
  plugin: Plugin;
  notified: boolean;
  onNotify: () => void;
  onOpen: () => void;
}) {
  return (
    <CardShell plugin={p} onOpen={onOpen} className="flex-col">
      <Stage
        plugin={p}
        height={220}
        scale={1.35}
        className="border-b border-[var(--st-border)]"
        label={
          <>
            <Sparkles size={11} strokeWidth={2.2} />
            Featured
          </>
        }
      >
        <PluginArt id={p.id} />
      </Stage>
      <CardBody plugin={p} text={p.about} big />
      <CardFooter plugin={p} notified={notified} onNotify={onNotify} />
    </CardShell>
  );
}

function SectionHeading({
  title,
  detail,
  aside,
}: {
  title: string;
  detail?: string;
  aside?: ReactNode;
}) {
  return (
    <div className="mb-[14px] flex items-end gap-[12px]">
      <div className="min-w-0 flex-1">
        <h3 className="text-[14px] font-semibold tracking-[-0.01em] text-[var(--st-fg)]">
          {title}
        </h3>
        {detail ? <p className="mt-[2px] text-[12.5px] text-[var(--st-fg2)]">{detail}</p> : null}
      </div>
      {aside}
    </div>
  );
}

function SoonNote() {
  return (
    <span className="inline-flex shrink-0 items-center gap-[6px] pb-[1px] text-[12px] text-[var(--st-fg3)]">
      <span className="size-[6px] rounded-full bg-[var(--st-warn)]" />
      Coming soon
    </span>
  );
}

function PluginDialog({
  plugin: p,
  notified,
  onNotify,
  onClose,
}: {
  plugin: Plugin;
  notified: boolean;
  onNotify: () => void;
  onClose: () => void;
}) {
  return (
    <Dialog label={p.name} onClose={onClose} width={540}>
      <div className="contents" style={hueVars(p)}>
        <DialogHeader
          title={
            <>
              {p.name}
              {p.author === "Macarchy" ? <Badge>Official</Badge> : null}
            </>
          }
          description={
            <span className="flex items-center gap-[6px]">
              <Avatar author={p.author} size={16} />
              {p.cat} plugin by {p.author}
            </span>
          }
          onClose={onClose}
        >
          <PluginTile plugin={p} size={44} />
        </DialogHeader>
        <div className="min-h-0 flex-1 space-y-5 overflow-y-auto border-t border-[var(--st-border)] px-5 py-4">
          <div className="overflow-hidden rounded-[12px] border" style={{ borderColor: line }}>
            <Stage plugin={p} height={220} scale={1.4}>
              <PluginArt id={p.id} />
            </Stage>
          </div>
          <p className="text-[13px] leading-[1.55] text-[var(--st-fg)]">{p.about}</p>
          <div>
            <div className="mb-2 text-[11.5px] font-semibold tracking-[0.04em] text-[var(--st-fg3)] uppercase">
              What it adds
            </div>
            <ul className="space-y-1.5">
              {p.brings.map((b) => (
                <li key={b} className="flex items-center gap-2 text-[13px] text-[var(--st-fg)]">
                  <span
                    className="grid size-4 shrink-0 place-items-center rounded-full"
                    style={{ background: tint(16), color: ink }}
                  >
                    <Check size={10} strokeWidth={2.5} />
                  </span>
                  {b}
                </li>
              ))}
            </ul>
          </div>
        </div>
        <div className="flex items-center gap-2 border-t border-[var(--st-border)] bg-[var(--st-side)] px-5 py-3">
          <span className="flex-1 text-[12px] text-[var(--st-fg3)]">Coming soon</span>
          <Button variant="ghost" onClick={onClose}>
            Close
          </Button>
          <Button variant={notified ? "outline" : "primary"} onClick={onNotify}>
            {notified ? <BellRing size={13} /> : <Bell size={13} />}
            {notified ? "Notifying" : "Notify me"}
          </Button>
        </div>
      </div>
    </Dialog>
  );
}

export function PluginsPage() {
  const [cat, setCat] = useState<PluginCat>("All");
  const [query, setQuery] = usePageSearch("Search plugins");
  const [notify, setNotify] = useState<Record<string, boolean>>({ media: true });
  const [open, setOpen] = useState<string | null>(null);
  const q = query.trim().toLowerCase();
  const visible = plugins.filter(
    (p) =>
      (cat === "All" || p.cat === cat) &&
      `${p.name} ${p.detail} ${p.author}`.toLowerCase().includes(q),
  );
  const current = plugins.find((p) => p.id === open);
  const toggle = (id: string) => setNotify((s) => ({ ...s, [id]: !s[id] }));
  const showFeatured = cat === "All" && !q;
  const isFeatured = (id: string) => (featured as readonly string[]).includes(id);
  const cats = cat === "All" ? pluginCats.filter((c): c is Plugin["cat"] => c !== "All") : [cat];
  const groups = cats
    .map((c) => ({
      cat: c,
      items: visible.filter((p) => p.cat === c && !(showFeatured && isFeatured(p.id))),
    }))
    .filter((g) => g.items.length > 0);

  return (
    <>
      <PageHeader title="Plugins" />
      <Tabs
        tabs={pluginCats.map((c) => ({
          id: c,
          label: c,
          count: c === "All" ? plugins.length : plugins.filter((p) => p.cat === c).length,
        }))}
        value={cat}
        onChange={setCat}
      />

      {visible.length === 0 ? (
        <Empty
          icon={Puzzle}
          title="No plugins found"
          action={
            <Button size="sm" onClick={() => setQuery("")}>
              Clear search
            </Button>
          }
        />
      ) : (
        <div className="space-y-[40px] pt-[6px]">
          {showFeatured ? (
            <section>
              <SectionHeading title="Featured" aside={<SoonNote />} />
              <div className="grid grid-cols-2 gap-[20px]">
                {featured.map((id) => {
                  const p = plugins.find((x) => x.id === id)!;
                  return (
                    <FeaturedCard
                      key={id}
                      plugin={p}
                      notified={!!notify[id]}
                      onNotify={() => toggle(id)}
                      onOpen={() => setOpen(id)}
                    />
                  );
                })}
              </div>
            </section>
          ) : null}
          {groups.map((g, gi) => {
            const shapes = bento(g.items.length);
            return (
              <section key={g.cat}>
                <SectionHeading
                  title={g.cat}
                  aside={!showFeatured && gi === 0 ? <SoonNote /> : null}
                />
                <div className="grid grid-cols-3 gap-[20px]">
                  {g.items.map((p, i) => (
                    <PluginCard
                      key={p.id}
                      plugin={p}
                      shape={shapes[i] ?? "normal"}
                      notified={!!notify[p.id]}
                      onNotify={() => toggle(p.id)}
                      onOpen={() => setOpen(p.id)}
                    />
                  ))}
                </div>
              </section>
            );
          })}
        </div>
      )}

      {current ? (
        <PluginDialog
          plugin={current}
          notified={!!notify[current.id]}
          onNotify={() => toggle(current.id)}
          onClose={() => setOpen(null)}
        />
      ) : null}
    </>
  );
}

/* ------------------------------------------------------------------ */
/* Menu bar                                                            */
/* ------------------------------------------------------------------ */

type Zone = "left" | "centre" | "right";
const zoneLabels: Record<Zone, string> = { left: "Left", centre: "Centre", right: "Right" };

const intervals = ["1s", "5s", "30s", "1m", "5m"] as const;
type Interval = (typeof intervals)[number];

interface BarItem {
  id: string;
  label: string;
  zone: Zone;
  on: boolean;
  sample: string;
  /** A key of barIcons, or "macarchy" for the brand mark. */
  icon: string;
  custom?: { command: string; interval: Interval };
}

const barIcons: Record<string, LucideIcon> = {
  Activity,
  AppWindow,
  BatteryMedium,
  Bluetooth,
  CalendarDays,
  Clock,
  CloudSun,
  Coffee,
  Cpu,
  Globe,
  Gpu,
  HardDrive,
  Hash,
  Mail,
  MemoryStick,
  Music,
  Palette,
  PanelTop,
  Rocket,
  Terminal,
  Volume2,
  Wifi,
  Zap,
};
const customIcons = [
  "Terminal",
  "Activity",
  "Globe",
  "Zap",
  "Coffee",
  "Mail",
  "Rocket",
  "Music",
  "CloudSun",
  "HardDrive",
];

function ItemIcon({
  icon,
  size,
  className,
  style,
}: {
  icon: string;
  size: number;
  className?: string;
  style?: CSSProperties;
}) {
  if (icon === "macarchy")
    return <BrandMark width={size + 2} height={size + 2} className={className} style={style} />;
  const Icon = barIcons[icon] ?? AppWindow;
  return <Icon size={size} strokeWidth={1.75} className={className} style={style} />;
}

const libraryCats = ["System", "Workspaces", "Media", "Info", "Macarchy"] as const;
const library: {
  id: string;
  name: string;
  icon: string;
  cat: (typeof libraryCats)[number];
  detail?: string;
  sample: string;
}[] = [
  {
    id: "calendar",
    name: "Clock",
    icon: "Clock",
    cat: "System",
    detail: "Date and time",
    sample: "Tue 21 Oct 17:24",
  },
  {
    id: "battery",
    name: "Battery",
    icon: "BatteryMedium",
    cat: "System",
    detail: "Bolt while charging",
    sample: "84%",
  },
  {
    id: "wifi",
    name: "Wi-Fi",
    icon: "Wifi",
    cat: "System",
    detail: "Network name and signal",
    sample: "Home 5G",
  },
  {
    id: "network",
    name: "Network",
    icon: "Activity",
    cat: "System",
    detail: "Upload and download speed",
    sample: "1.2 MB/s",
  },
  {
    id: "bluetooth",
    name: "Bluetooth",
    icon: "Bluetooth",
    cat: "System",
    detail: "Connected devices and their battery",
    sample: "AirPods",
  },
  {
    id: "volume",
    name: "Volume",
    icon: "Volume2",
    cat: "System",
    detail: "Scroll to adjust",
    sample: "60%",
  },
  {
    id: "cpu",
    name: "CPU",
    icon: "Cpu",
    cat: "System",
    detail: "Load across all cores",
    sample: "12%",
  },
  {
    id: "ram",
    name: "Memory",
    icon: "MemoryStick",
    cat: "System",
    detail: "In use by apps",
    sample: "9.4 GB",
  },
  { id: "gpu", name: "GPU", icon: "Gpu", cat: "System", sample: "7%" },
  {
    id: "disk",
    name: "Disk",
    icon: "HardDrive",
    cat: "System",
    detail: "Free space on the startup disk",
    sample: "212 GB",
  },
  {
    id: "workspaces",
    name: "Workspaces",
    icon: "Hash",
    cat: "Workspaces",
    detail: "AeroSpace workspaces",
    sample: "",
  },
  {
    id: "front_app",
    name: "Front app",
    icon: "AppWindow",
    cat: "Workspaces",
    sample: "Ghostty",
  },
  {
    id: "window_title",
    name: "Window title",
    icon: "PanelTop",
    cat: "Workspaces",
    sample: "zsh: ~/projects",
  },
  {
    id: "now_playing",
    name: "Now playing",
    icon: "Music",
    cat: "Media",
    detail: "Music or Spotify, with play and pause",
    sample: "Veridis Quo",
  },
  {
    id: "weather",
    name: "Weather",
    icon: "CloudSun",
    cat: "Info",
    detail: "Temperature and conditions",
    sample: "18° Cloudy",
  },
  {
    id: "next_event",
    name: "Calendar next event",
    icon: "CalendarDays",
    cat: "Info",
    detail: "Time until your next meeting",
    sample: "Standup in 20m",
  },
  {
    id: "theme_switcher",
    name: "Theme switcher",
    icon: "Palette",
    cat: "Macarchy",
    sample: barTheme.name,
  },
  {
    id: "macarchy",
    name: "Macarchy menu",
    icon: "macarchy",
    cat: "Macarchy",
    detail: "Settings, reload and themes",
    sample: "",
  },
];

/** The real SketchyBar items from settings. Theme Listener is internal, so it is never shown. */
const initialItems: BarItem[] = snapshot.barItems
  .filter((i) => i.id !== "theme_listener")
  .map((i): BarItem => {
    const known = library.find((l) => l.id === i.id);
    return {
      id: i.id,
      label: i.id === "macarchy" ? "Macarchy menu" : i.title,
      zone: i.side === "left" ? "left" : "right",
      on: i.visible,
      sample: known?.sample ?? "",
      icon: known?.icon ?? "AppWindow",
    };
  });

function BarPreview({
  items,
  centre,
  height,
  padding,
  position,
  active,
  onSelect,
}: {
  items: BarItem[];
  centre: boolean;
  height: number;
  padding: number;
  position: "Top" | "Bottom";
  active: string | null;
  onSelect: (id: string) => void;
}) {
  const t = barTheme;
  const render = (z: Zone) =>
    items
      .filter((i) => i.zone === z && i.on)
      .map((i) => (
        <button
          type="button"
          key={i.id}
          onClick={() => onSelect(i.id)}
          aria-label={`Edit ${i.label}`}
          className="flex h-[22px] shrink-0 items-center gap-1 rounded-[5px] px-1.5 whitespace-nowrap transition-colors hover:bg-white/10"
          style={{
            color: t.foreground,
            background: i.id === active ? "rgba(255,255,255,0.12)" : "transparent",
            boxShadow: i.id === active ? `0 0 0 1px ${t.accent}` : undefined,
          }}
        >
          {i.id === "workspaces" ? (
            ["1", "2", "3", "4", "5"].map((n) => (
              <span
                key={n}
                className="grid size-4 place-items-center rounded-[3px] text-[10px] font-semibold"
                style={n === "1" ? { background: t.accent, color: t.background } : { opacity: 0.6 }}
              >
                {n}
              </span>
            ))
          ) : (
            <>
              <ItemIcon icon={i.icon} size={11} style={{ color: t.accent }} />
              {i.sample}
            </>
          )}
        </button>
      ));
  const bar = (
    <div
      className="grid grid-cols-[1fr_auto_1fr] font-mono text-[11px] transition-[height,padding]"
      style={{
        height,
        paddingInline: padding,
        background: `color-mix(in srgb, ${t.background} 92%, transparent)`,
        borderBottom: position === "Top" ? "1px solid rgba(255,255,255,0.06)" : undefined,
        borderTop: position === "Bottom" ? "1px solid rgba(255,255,255,0.06)" : undefined,
      }}
    >
      <div className="flex min-w-0 items-center gap-1 overflow-hidden">{render("left")}</div>
      <div className="flex items-center justify-center gap-1 px-2">
        {centre ? (
          render("centre")
        ) : position === "Top" ? (
          <span aria-hidden className="block h-full w-[132px] rounded-b-[9px] bg-black" />
        ) : null}
      </div>
      <div className="flex min-w-0 items-center justify-end gap-1 overflow-hidden">
        {render("right")}
      </div>
    </div>
  );
  return (
    <div
      className="flex flex-col overflow-hidden rounded-[10px] border border-[var(--st-border)] bg-cover bg-center"
      style={{
        backgroundColor: t.background,
        backgroundImage: barWallpaper
          ? `url(${barWallpaper})`
          : `linear-gradient(160deg, color-mix(in srgb, ${t.accent} 25%, ${t.background}), ${t.background} 70%)`,
      }}
    >
      {position === "Top" ? bar : null}
      <div className="h-[72px]" />
      {position === "Bottom" ? bar : null}
    </div>
  );
}

function ItemEditor({
  item,
  onChange,
  onDone,
}: {
  item: BarItem;
  onChange: (patch: Partial<BarItem>) => void;
  onDone: () => void;
}) {
  const hasText = item.id !== "workspaces" && item.icon !== "macarchy";
  const onEnter = (e: ReactKeyboardEvent) => {
    if (e.key === "Enter") onDone();
  };
  return (
    <div className="space-y-2.5 border-t border-[var(--st-border)] px-3 pt-2.5 pb-3">
      <label className="block">
        <FieldLabel>Label</FieldLabel>
        <input
          autoFocus
          value={item.label}
          onChange={(e) => onChange({ label: e.target.value })}
          onKeyDown={onEnter}
          className={cx(fieldCls, "h-7 text-[12.5px]")}
        />
      </label>
      {hasText ? (
        <label className="block">
          <FieldLabel>Preview text</FieldLabel>
          <input
            value={item.sample}
            onChange={(e) => onChange({ sample: e.target.value })}
            onKeyDown={onEnter}
            className={cx(fieldCls, "h-7 font-mono text-[12px]")}
          />
        </label>
      ) : null}
      {item.custom ? (
        <div className="flex items-center gap-1.5 font-mono text-[11px] text-[var(--st-fg3)]">
          <Terminal size={11} className="shrink-0" />
          <span className="min-w-0 truncate">{item.custom.command}</span>
          <span className="shrink-0">every {item.custom.interval}</span>
        </div>
      ) : null}
      <div className="flex items-center gap-2 pt-0.5">
        <Switch checked={item.on} onChange={(v) => onChange({ on: v })} label="Visible" />
        <span className="flex-1 text-[12px] text-[var(--st-fg2)]">Visible</span>
        <Button size="sm" onClick={onDone}>
          Done
        </Button>
      </div>
    </div>
  );
}

function ItemLibrary({
  zone,
  present,
  onAdd,
  onClose,
}: {
  zone: Zone;
  present: Set<string>;
  onAdd: (item: Omit<BarItem, "zone">) => void;
  onClose: () => void;
}) {
  const [tab, setTab] = useState<"Built-in" | "Custom item">("Built-in");
  const [query, setQuery] = useState("");
  const [name, setName] = useState("");
  const [icon, setIcon] = useState("Terminal");
  const [command, setCommand] = useState("");
  const [every, setEvery] = useState<Interval>("30s");
  const q = query.trim().toLowerCase();
  const matches = library.filter((l) =>
    `${l.name} ${l.detail ?? ""} ${l.cat}`.toLowerCase().includes(q),
  );
  const zoneName = zoneLabels[zone].toLowerCase();
  const canAdd = name.trim().length > 0 && command.trim().length > 0;

  return (
    <Dialog
      label={`Add an item to the ${zoneName} zone`}
      onClose={onClose}
      width={560}
      height={560}
    >
      <DialogHeader title={`Add to the ${zoneName} zone`} onClose={onClose} />
      <div className="flex items-center gap-2 px-5 pb-3">
        <Segmented
          size="sm"
          options={["Built-in", "Custom item"] as const}
          value={tab}
          onChange={setTab}
        />
        {tab === "Built-in" ? (
          <SearchInput
            value={query}
            onChange={setQuery}
            placeholder="Search items"
            className="ml-auto"
          />
        ) : null}
      </div>

      {tab === "Built-in" ? (
        <div className="min-h-0 flex-1 overflow-y-auto border-t border-[var(--st-border)] px-2 pb-2">
          {matches.length === 0 ? (
            <div className="p-3">
              <Empty
                icon={Search}
                title="No items match"
                action={
                  <Button
                    size="sm"
                    onClick={() => {
                      setName(query.trim());
                      setTab("Custom item");
                    }}
                  >
                    <Plus size={12} /> Custom item
                  </Button>
                }
              />
            </div>
          ) : (
            libraryCats.map((c) => {
              const group = matches.filter((l) => l.cat === c);
              if (group.length === 0) return null;
              return (
                <div key={c}>
                  <div className="px-3 pt-3 pb-1 text-[11px] font-semibold tracking-[0.04em] text-[var(--st-fg3)] uppercase">
                    {c}
                  </div>
                  {group.map((l) => (
                    <div
                      key={l.id}
                      className="flex items-center gap-3 rounded-[7px] px-3 py-2 transition-colors hover:bg-[var(--st-hover)]"
                    >
                      <span className="grid size-8 shrink-0 place-items-center rounded-[8px] border border-[var(--st-border)] bg-[var(--st-bg)] text-[var(--st-fg2)]">
                        <ItemIcon icon={l.icon} size={14} />
                      </span>
                      <div className="min-w-0 flex-1">
                        <div className="text-[13px] font-medium text-[var(--st-fg)]">{l.name}</div>
                        {l.detail ? (
                          <div className="truncate text-[12px] text-[var(--st-fg2)]">
                            {l.detail}
                          </div>
                        ) : null}
                      </div>
                      {present.has(l.id) ? (
                        <span className="inline-flex h-7 items-center gap-1 px-2.5 text-[12px] font-medium text-[var(--st-fg3)]">
                          <Check size={12} /> Added
                        </span>
                      ) : (
                        <Button
                          size="sm"
                          onClick={() =>
                            onAdd({
                              id: l.id,
                              label: l.name,
                              on: true,
                              sample: l.sample,
                              icon: l.icon,
                            })
                          }
                        >
                          <Plus size={12} /> Add
                        </Button>
                      )}
                    </div>
                  ))}
                </div>
              );
            })
          )}
        </div>
      ) : (
        <div className="min-h-0 flex-1 space-y-4 overflow-y-auto border-t border-[var(--st-border)] px-5 py-4">
          <label className="block">
            <FieldLabel>Name</FieldLabel>
            <input
              value={name}
              onChange={(e) => setName(e.target.value)}
              placeholder="VPN status"
              className={cx(fieldCls, "h-8")}
            />
          </label>
          <div>
            <FieldLabel>Icon</FieldLabel>
            <div className="flex flex-wrap gap-1.5">
              {customIcons.map((k) => (
                <button
                  key={k}
                  type="button"
                  aria-label={k}
                  aria-pressed={k === icon}
                  onClick={() => setIcon(k)}
                  className={cx(
                    "grid size-8 place-items-center rounded-[7px] border transition-colors",
                    focusRing,
                    k === icon
                      ? "border-[var(--st-accent)] bg-[var(--st-accent-soft)] text-[var(--st-accent-text)]"
                      : "border-[var(--st-border)] bg-[var(--st-bg)] text-[var(--st-fg2)] hover:bg-[var(--st-hover)] hover:text-[var(--st-fg)]",
                  )}
                >
                  <ItemIcon icon={k} size={14} />
                </button>
              ))}
            </div>
          </div>
          <label className="block">
            <FieldLabel hint="Runs in zsh; shows the first line of output">
              Shell command or script path
            </FieldLabel>
            <input
              value={command}
              onChange={(e) => setCommand(e.target.value)}
              placeholder="~/.config/sketchybar/plugins/vpn.sh"
              spellCheck={false}
              className={cx(fieldCls, "h-8 font-mono text-[12px]")}
            />
          </label>
          <div>
            <FieldLabel>Update every</FieldLabel>
            <Segmented size="sm" options={intervals} value={every} onChange={setEvery} />
          </div>
          <div>
            <FieldLabel>Preview</FieldLabel>
            <div
              className="flex h-[30px] items-center justify-end gap-1 rounded-[7px] px-2 font-mono text-[11px]"
              style={{ background: barTheme.background, color: barTheme.foreground }}
            >
              <span className="flex items-center gap-1 px-1.5">
                <ItemIcon icon={icon} size={11} style={{ color: barTheme.accent }} />
                {name.trim() || "My item"}
              </span>
            </div>
          </div>
        </div>
      )}

      <div className="flex items-center gap-2 border-t border-[var(--st-border)] bg-[var(--st-side)] px-5 py-3">
        <span className="flex-1 text-[12px] text-[var(--st-fg3)]">
          {tab === "Built-in" ? `${present.size} items in the bar` : null}
        </span>
        {tab === "Built-in" ? (
          <Button variant="primary" onClick={onClose}>
            Done
          </Button>
        ) : (
          <>
            <Button variant="ghost" onClick={onClose}>
              Cancel
            </Button>
            <Button
              variant="primary"
              disabled={!canAdd}
              onClick={() => {
                onAdd({
                  id: `custom-${Date.now()}`,
                  label: name.trim(),
                  on: true,
                  sample: name.trim(),
                  icon,
                  custom: { command: command.trim(), interval: every },
                });
                onClose();
              }}
            >
              <Plus size={13} /> Add to {zoneLabels[zone]}
            </Button>
          </>
        )}
      </div>
    </Dialog>
  );
}

export function MenuBarPage() {
  const [items, setItems] = useState(initialItems);
  const [editing, setEditing] = useState<string | null>(null);
  const [adding, setAdding] = useState<Zone | null>(null);
  const [centre, setCentre] = useState(false);
  const [dragging, setDragging] = useState<string | null>(null);
  const [over, setOver] = useState<string | null>(null);
  const [height, setHeight] = useState(snapshot.menuBar.height);
  const [padding, setPadding] = useState(snapshot.menuBar.padding_left);
  const [position, setPosition] = useState<"Top" | "Bottom">(
    snapshot.menuBar.position === "bottom" ? "Bottom" : "Top",
  );
  const [hideNative, setHideNative] = useState(true);
  const current = { items, centre, height, padding, position, hideNative };
  const [saved, setSaved] = useState(current);
  const changed = JSON.stringify(current) !== JSON.stringify(saved);
  const revert = () => {
    setItems(saved.items);
    setEditing(null);
    setCentre(saved.centre);
    setHeight(saved.height);
    setPadding(saved.padding);
    setPosition(saved.position);
    setHideNative(saved.hideNative);
  };
  const zones: Zone[] = centre ? ["left", "centre", "right"] : ["left", "right"];
  const hiddenInCentre = centre ? 0 : items.filter((i) => i.zone === "centre").length;

  const move = (id: string, zone: Zone, beforeId?: string) =>
    setItems((prev) => {
      const item = prev.find((i) => i.id === id);
      if (!item || id === beforeId) return prev;
      const rest = prev.filter((i) => i.id !== id);
      const moved = { ...item, zone };
      const at = beforeId ? rest.findIndex((i) => i.id === beforeId) : -1;
      if (at === -1) {
        const lastInZone = rest.map((i) => i.zone).lastIndexOf(zone);
        rest.splice(lastInZone === -1 ? rest.length : lastInZone + 1, 0, moved);
      } else rest.splice(at, 0, moved);
      return rest;
    });
  const patch = (id: string, p: Partial<BarItem>) =>
    setItems((prev) => prev.map((i) => (i.id === id ? { ...i, ...p } : i)));
  const remove = (id: string) => {
    setItems((prev) => prev.filter((i) => i.id !== id));
    if (editing === id) setEditing(null);
  };
  const add = (item: BarItem) =>
    setItems((prev) => {
      const next = [...prev];
      const lastInZone = next.map((i) => i.zone).lastIndexOf(item.zone);
      next.splice(lastInZone === -1 ? next.length : lastInZone + 1, 0, item);
      return next;
    });

  return (
    <>
      <PageHeader title="Menu Bar" />

      <div className="mb-5">
        <SectionLabel
          action={
            <div className="flex items-center gap-[6px]">
              <Button size="sm" variant="ghost" disabled={!changed} onClick={revert}>
                <RotateCcw size={12} /> Reset
              </Button>
              <Button
                size="sm"
                variant="primary"
                disabled={!changed}
                onClick={() => setSaved(current)}
              >
                Apply
              </Button>
            </div>
          }
        >
          Preview
        </SectionLabel>
        <BarPreview
          items={items}
          centre={centre}
          height={height}
          padding={padding}
          position={position}
          active={editing}
          onSelect={(id) => setEditing((e) => (e === id ? null : id))}
        />
      </div>

      <div className={cx("grid gap-3", centre ? "grid-cols-3" : "grid-cols-2")}>
        {zones.map((z) => {
          const inZone = items.filter((i) => i.zone === z);
          return (
            <div
              key={z}
              onDragOver={(e) => {
                e.preventDefault();
                if (!over) setOver(`zone:${z}`);
              }}
              onDrop={() => {
                if (dragging && over === `zone:${z}`) move(dragging, z);
                setDragging(null);
                setOver(null);
              }}
              className={cx(
                "flex min-h-[220px] flex-col rounded-[10px] border bg-[var(--st-side)] p-2 transition-colors",
                over === `zone:${z}` ? "border-[var(--st-accent)]" : "border-[var(--st-border)]",
              )}
            >
              <div className="mb-1.5 flex items-center px-1.5 pt-0.5 text-[11.5px] font-medium text-[var(--st-fg3)]">
                <span className="flex-1">{zoneLabels[z]}</span>
                <span className="tabular-nums">{inZone.filter((i) => i.on).length} shown</span>
              </div>
              <div className="space-y-1">
                {inZone.map((i) => {
                  const open = editing === i.id;
                  return (
                    <div
                      key={i.id}
                      draggable={!open}
                      onDragStart={() => setDragging(i.id)}
                      onDragEnd={() => {
                        setDragging(null);
                        setOver(null);
                      }}
                      onDragOver={(e) => {
                        e.preventDefault();
                        e.stopPropagation();
                        setOver(i.id);
                      }}
                      onDrop={(e) => {
                        e.stopPropagation();
                        if (dragging) move(dragging, z, i.id);
                        setDragging(null);
                        setOver(null);
                      }}
                      className={cx(
                        "rounded-[7px] border bg-[var(--st-bg)] shadow-[var(--st-shadow)] transition-all",
                        open
                          ? "border-[var(--st-accent)] ring-[3px] ring-[var(--st-accent-soft)]"
                          : "border-[var(--st-border)]",
                        dragging === i.id && "opacity-40",
                        over === i.id &&
                          dragging !== i.id &&
                          "translate-y-0.5 border-t-2 border-t-[var(--st-accent)]",
                      )}
                    >
                      <div
                        className={cx(
                          "flex h-9 items-center gap-2 pr-1.5 pl-1",
                          !open && "cursor-grab active:cursor-grabbing",
                        )}
                      >
                        <GripVertical size={13} className="shrink-0 text-[var(--st-fg3)]" />
                        <ItemIcon
                          icon={i.icon}
                          size={13}
                          className={cx(
                            "shrink-0",
                            i.on ? "text-[var(--st-fg2)]" : "text-[var(--st-fg3)]",
                          )}
                        />
                        <span
                          className={cx(
                            "min-w-0 flex-1 truncate text-[12.5px] font-medium",
                            i.on ? "text-[var(--st-fg)]" : "text-[var(--st-fg3)]",
                          )}
                        >
                          {i.label}
                        </span>
                        {!i.on ? (
                          <EyeOff
                            size={12}
                            aria-label="Hidden"
                            className="shrink-0 text-[var(--st-fg3)]"
                          />
                        ) : i.sample && !centre ? (
                          <span className="max-w-[110px] truncate font-mono text-[11px] text-[var(--st-fg3)]">
                            {i.sample}
                          </span>
                        ) : null}
                        <IconButton
                          label={`Edit ${i.label}`}
                          active={open}
                          onClick={() => setEditing(open ? null : i.id)}
                        >
                          <Pencil size={12} />
                        </IconButton>
                        <IconButton
                          label={`Remove ${i.label}`}
                          destructive
                          onClick={() => remove(i.id)}
                        >
                          <Trash size={12} />
                        </IconButton>
                      </div>
                      {open ? (
                        <ItemEditor
                          item={i}
                          onChange={(p) => patch(i.id, p)}
                          onDone={() => setEditing(null)}
                        />
                      ) : null}
                    </div>
                  );
                })}
                {inZone.length === 0 ? (
                  <div className="grid h-16 place-items-center px-3 text-center text-[12px] text-[var(--st-fg3)]">
                    Empty
                  </div>
                ) : null}
              </div>
              <button
                type="button"
                onClick={() => setAdding(z)}
                className={cx(
                  "mt-auto flex h-8 w-full items-center justify-center gap-1.5 rounded-[7px] border border-dashed border-[var(--st-border-strong)] text-[12.5px] font-medium text-[var(--st-fg2)] transition-colors hover:border-[var(--st-fg3)] hover:bg-[var(--st-bg)] hover:text-[var(--st-fg)]",
                  focusRing,
                )}
                style={{ marginTop: inZone.length ? 8 : undefined }}
              >
                <Plus size={13} /> Add item
              </button>
            </div>
          );
        })}
      </div>

      <Card className="mt-4">
        <CardHeader title="Bar" />
        <Row label="Height">
          <Slider value={height} min={22} max={48} onChange={setHeight} label="Bar height" />
        </Row>
        <Row label="Position">
          <Segmented options={["Top", "Bottom"] as const} value={position} onChange={setPosition} />
        </Row>
        <Row label="Padding">
          <Slider value={padding} min={0} max={24} onChange={setPadding} label="Bar padding" />
        </Row>
        <Row label="Centre zone" hint="For displays without a notch">
          <div className="flex items-center gap-[8px]">
            {hiddenInCentre ? (
              <Badge tone="warn">
                {hiddenInCentre} {hiddenInCentre === 1 ? "item" : "items"} hidden
              </Badge>
            ) : null}
            <Switch checked={centre} onChange={setCentre} label="Centre zone" />
          </div>
        </Row>
        <Row label="Hide the macOS menu bar" last>
          <Switch checked={hideNative} onChange={setHideNative} label="Hide the macOS menu bar" />
        </Row>
      </Card>

      {adding ? (
        <ItemLibrary
          zone={adding}
          present={new Set(items.map((i) => i.id))}
          onAdd={(item) => add({ ...item, zone: adding })}
          onClose={() => setAdding(null)}
        />
      ) : null}
    </>
  );
}
