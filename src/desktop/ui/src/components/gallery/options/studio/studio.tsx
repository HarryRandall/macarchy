import {
  ArrowRight,
  ChevronDown,
  ChevronLeft,
  ChevronRight,
  Copy,
  CornerDownLeft,
  Download,
  FolderOpen,
  Info,
  Keyboard,
  type LucideIcon,
  Monitor,
  Moon,
  PanelLeft,
  Play,
  Power,
  RotateCw,
  ScrollText,
  Search,
  Sparkles,
  Stethoscope,
  Sun,
  Trash2,
  X,
  Zap,
} from "lucide-react";
import {
  type CSSProperties,
  type KeyboardEvent as ReactKeyboardEvent,
  type ReactNode,
  createContext,
  useCallback,
  useContext,
  useEffect,
  useId,
  useLayoutEffect,
  useMemo,
  useRef,
  useState,
} from "react";
import { createPortal } from "react-dom";

import { BrandMark } from "~/shell/brand-mark";

import {
  type Appearance,
  type MockPaneId,
  type OptionProps,
  groups,
  healthChecks,
  overview,
  panes,
  services,
} from "../data";
import { currentThemeId, realThemes, snapshot, wallpaperUrl } from "../real";
import { BordersPage, HomePage, LayoutPage, ThemesPage } from "./appearance-pages";
import { HealthPage, RulesPage, ShortcutsPage } from "./behaviour-pages";
import { ChangelogPage, isNewer, latestVersion } from "./changelog";
import { MenuBarPage, PluginsPage } from "./more-pages";
import { AdvancedPage, ReportPage } from "./system-pages";
import { Badge, Button, ImageFill, type PageSearch, PageChromeContext, cx, tokens } from "./ui";
import { WorkshopPage } from "./workshop";

const issues = healthChecks.filter((c) => !c.ok).length;
const previews: MockPaneId[] = ["workshop", "plugins"];
const version = latestVersion;
const logsHeight = 280;

/** A sidebar pane, or a page reached only from menus such as the changelog. */
type Route = MockPaneId | "changelog";

function groupOf(id: Route): string | undefined {
  return groups.find((g) => g.panes.some((p) => p === id))?.title;
}

function titleOf(id: Route): string {
  return id === "changelog" ? "Changelog" : panes[id].title;
}

/** Shell-only colours that the shared tokens do not cover. */
function shellTokens(appearance: Appearance): CSSProperties {
  const light = {
    "--st-err": "#dc2626",
    "--st-err-soft": "rgba(220,38,38,0.07)",
    "--st-warn-row": "rgba(217,119,6,0.06)",
    "--st-tip-bg": "var(--st-primary)",
    "--st-tip-fg": "var(--st-primary-fg)",
    "--st-tip-border": "var(--st-primary)",
    "--st-tip-shadow": "0 6px 16px -4px rgba(9,9,11,0.25), 0 1px 3px rgba(9,9,11,0.12)",
    "--st-seg-track": "#f4f4f5",
    "--st-seg-ring": "rgba(9,9,11,0.04)",
    "--st-seg-pill": "#ffffff",
    "--st-seg-pill-shadow":
      "0 1px 2px rgba(9,9,11,0.08), 0 1px 1px rgba(9,9,11,0.04), 0 0 0 0.5px rgba(9,9,11,0.08)",
    "--st-seg-hover": "rgba(255,255,255,0.55)",
    "--st-preview": "#0f766e",
    "--st-preview-soft": "rgba(20,184,166,0.11)",
    "--st-preview-ring": "rgba(13,148,136,0.16)",
    "--st-pop-shadow": "0 16px 40px -12px rgba(9,9,11,0.28), 0 2px 6px -2px rgba(9,9,11,0.10)",
    "--st-chart-tip-shadow": "0 4px 12px -4px rgba(9,9,11,0.18), 0 1px 2px rgba(9,9,11,0.06)",
  };
  const dark = {
    "--st-err": "#f87171",
    "--st-err-soft": "rgba(248,113,113,0.09)",
    "--st-warn-row": "rgba(251,191,36,0.06)",
    "--st-tip-bg": "var(--st-muted)",
    "--st-tip-fg": "var(--st-fg)",
    "--st-tip-border": "var(--st-border-strong)",
    "--st-tip-shadow": "0 8px 20px -6px rgba(0,0,0,0.6), 0 1px 3px rgba(0,0,0,0.3)",
    "--st-seg-track": "#18181b",
    "--st-seg-ring": "rgba(255,255,255,0.04)",
    "--st-seg-pill": "#2a2a2f",
    "--st-seg-pill-shadow":
      "0 1px 2px rgba(0,0,0,0.45), inset 0 1px 0 rgba(255,255,255,0.06), 0 0 0 0.5px rgba(255,255,255,0.06)",
    "--st-seg-hover": "rgba(255,255,255,0.04)",
    "--st-preview": "#5eead4",
    "--st-preview-soft": "rgba(45,212,191,0.12)",
    "--st-preview-ring": "rgba(45,212,191,0.16)",
    "--st-pop-shadow": "0 18px 44px -12px rgba(0,0,0,0.7), 0 2px 6px -2px rgba(0,0,0,0.4)",
    "--st-chart-tip-shadow": "0 6px 16px -6px rgba(0,0,0,0.6), 0 1px 2px rgba(0,0,0,0.3)",
  };
  return (appearance === "dark" ? dark : light) as CSSProperties;
}

/** Collapsed rail width; the extra pixel is the right border, leaving a 56px content box. */
const railWidth = 57;

/** The Studio window element, so floating layers render inside it and pick up its tokens. */
const WindowRoot = createContext<HTMLElement | null>(null);

/* ------------------------------------------------------------------ */
/* Small pieces                                                        */
/* ------------------------------------------------------------------ */

/**
 * A hover label with an optional shortcut, drawn beside or below its trigger.
 * It renders into the window root and is kept inside the window bounds.
 */
function Tip({
  label,
  keys,
  side = "bottom",
  disabled,
  className,
  children,
}: {
  label: string;
  keys?: string;
  side?: "right" | "bottom";
  disabled?: boolean;
  className?: string;
  children: ReactNode;
}) {
  const root = useContext(WindowRoot);
  const [show, setShow] = useState(false);
  const [wasDisabled, setWasDisabled] = useState(disabled);
  const wrap = useRef<HTMLSpanElement>(null);
  const bubble = useRef<HTMLSpanElement>(null);
  const timer = useRef<ReturnType<typeof setTimeout>>(undefined);
  // The trigger may be mid-transition when it toggles, so wait for the next hover.
  if (wasDisabled !== disabled) {
    setWasDisabled(disabled);
    setShow(false);
  }
  const visible = show && !disabled && root !== null;

  useEffect(() => () => clearTimeout(timer.current), []);

  useLayoutEffect(() => {
    const el = bubble.current;
    const anchor = wrap.current;
    if (!visible || !el || !anchor || !root) return;
    const box = root.getBoundingClientRect();
    // The gallery may scale the window, so convert screen pixels back to CSS pixels.
    const scale = root.offsetWidth ? box.width / root.offsetWidth : 1;
    const a = anchor.getBoundingClientRect();
    const left = (a.left - box.left) / scale;
    const top = (a.top - box.top) / scale;
    const w = a.width / scale;
    const h = a.height / scale;
    const bw = el.offsetWidth;
    const bh = el.offsetHeight;
    const maxX = root.clientWidth - 8 - bw;
    const maxY = root.clientHeight - 8 - bh;
    let x: number;
    let y: number;
    if (side === "right") {
      x = left + w + 10;
      y = top + h / 2 - bh / 2;
      if (x > maxX) x = left - 10 - bw;
    } else {
      x = left + w / 2 - bw / 2;
      y = top + h + 8;
      if (y > maxY) y = top - 8 - bh;
    }
    el.style.left = `${Math.round(Math.max(8, Math.min(x, maxX)))}px`;
    el.style.top = `${Math.round(Math.max(8, Math.min(y, maxY)))}px`;
    el.style.visibility = "visible";
  }, [visible, side, root, label, keys]);

  const hide = () => {
    clearTimeout(timer.current);
    setShow(false);
  };

  return (
    <span
      ref={wrap}
      className={className ?? "inline-flex"}
      onMouseEnter={() => {
        clearTimeout(timer.current);
        timer.current = setTimeout(() => setShow(true), 350);
      }}
      onMouseLeave={hide}
      onMouseDown={hide}
      onKeyDown={(e) => {
        if (e.key === "Escape") hide();
      }}
      onFocus={(e) => {
        if ((e.target as HTMLElement).matches(":focus-visible")) setShow(true);
      }}
      onBlur={hide}
    >
      {children}
      {visible
        ? createPortal(
            <span
              ref={bubble}
              role="tooltip"
              style={{ left: 0, top: 0, visibility: "hidden" }}
              className="pointer-events-none absolute z-[60] flex animate-[st-tip-in_100ms_ease-out] items-center gap-1.5 rounded-[6px] border border-[var(--st-tip-border)] bg-[var(--st-tip-bg)] px-2 py-[3px] text-[11.5px] font-medium whitespace-nowrap text-[var(--st-tip-fg)] shadow-[var(--st-tip-shadow)]"
            >
              {label}
              {keys ? <span className="font-normal opacity-60">{keys}</span> : null}
            </span>,
            root,
          )
        : null}
    </span>
  );
}

function IconButton({
  label,
  keys,
  onClick,
  disabled,
  pressed,
  size = "md",
  children,
}: {
  label: string;
  keys?: string;
  onClick: () => void;
  disabled?: boolean;
  pressed?: boolean;
  size?: "sm" | "md";
  children: ReactNode;
}) {
  return (
    <Tip label={label} keys={keys} disabled={disabled}>
      <button
        type="button"
        aria-label={label}
        aria-pressed={pressed}
        onClick={onClick}
        disabled={disabled}
        className={cx(
          "grid place-items-center rounded-[7px] text-[var(--st-fg2)] transition-colors hover:bg-[var(--st-hover)] hover:text-[var(--st-fg)] focus-visible:ring-2 focus-visible:ring-[var(--st-accent)] focus-visible:outline-none disabled:pointer-events-none disabled:text-[var(--st-fg3)] disabled:opacity-50",
          size === "sm" ? "size-6" : "size-7",
        )}
      >
        {children}
      </button>
    </Tip>
  );
}

/** Marks panes that are still in preview, tinted apart from the warning and accent colours. */
function PreviewTag({ size = "sm" }: { size?: "sm" | "md" }) {
  return (
    <span
      className={cx(
        "inline-flex shrink-0 items-center rounded-[5px] bg-[var(--st-preview-soft)] leading-none font-medium text-[var(--st-preview)] shadow-[inset_0_0_0_1px_var(--st-preview-ring)]",
        size === "sm"
          ? "h-[16px] px-[5px] text-[10px]"
          : "h-[20px] px-[7px] text-[11px] tracking-[0.01em]",
      )}
    >
      Preview
    </span>
  );
}

/** The Macarchy logo on a small app-icon tile. */
function AppIcon({ size = 28 }: { size?: number }) {
  return (
    <span
      className="grid shrink-0 place-items-center rounded-[7px] text-white shadow-[0_1px_2px_rgba(0,0,0,0.25),inset_0_0_0_1px_rgba(255,255,255,0.10)]"
      style={{
        width: size,
        height: size,
        background: "linear-gradient(180deg, #3f3f46 0%, #18181b 100%)",
      }}
    >
      <BrandMark width={size * 0.62} height={size * 0.62} />
    </span>
  );
}

function TrafficLights() {
  return (
    <div className="flex shrink-0 items-center gap-2">
      {["#ff5f57", "#febc2e", "#28c840"].map((c) => (
        <span
          key={c}
          className="size-3 rounded-full ring-1 ring-black/10 ring-inset"
          style={{ background: c }}
        />
      ))}
    </div>
  );
}

/* ------------------------------------------------------------------ */
/* Brand menu                                                          */
/* ------------------------------------------------------------------ */

type AppearanceMode = "system" | Appearance;
type MenuAction =
  "updates" | "folder" | "reload" | "shortcuts" | "about" | "quit" | "logs" | "changelog";

interface MenuEntry {
  id: string;
  label: string;
  icon: LucideIcon;
  hint?: string;
  /** Marks unread content, such as releases not yet seen. */
  dot?: boolean;
  run: () => void;
}

const appearanceModes: { id: AppearanceMode; label: string; icon: LucideIcon }[] = [
  { id: "system", label: "System", icon: Monitor },
  { id: "light", label: "Light", icon: Sun },
  { id: "dark", label: "Dark", icon: Moon },
];

/** A full-width three-way control whose raised pill slides between equal columns. */
function AppearanceSegmented({
  mode,
  onMode,
  row,
}: {
  mode: AppearanceMode;
  onMode: (mode: AppearanceMode) => void;
  /** Keyboard row shared by all options, so arrow keys move between them. */
  row: number;
}) {
  const index = Math.max(
    0,
    appearanceModes.findIndex((m) => m.id === mode),
  );
  return (
    <div className="relative grid grid-cols-3 rounded-[8px] bg-[var(--st-seg-track)] p-[3px] shadow-[inset_0_0_0_1px_var(--st-seg-ring)]">
      <span
        aria-hidden
        className="pointer-events-none absolute top-[3px] bottom-[3px] left-[3px] rounded-[5px] bg-[var(--st-seg-pill)] shadow-[var(--st-seg-pill-shadow)] transition-transform duration-200 ease-[cubic-bezier(0.32,0.72,0,1)] motion-reduce:transition-none"
        style={{
          width: `calc((100% - 6px) / ${appearanceModes.length})`,
          transform: `translateX(${index * 100}%)`,
        }}
      />
      {appearanceModes.map((m) => {
        const Icon = m.icon;
        const on = mode === m.id;
        return (
          <button
            key={m.id}
            type="button"
            role="menuitemradio"
            aria-checked={on}
            data-row={row}
            tabIndex={-1}
            onClick={() => onMode(m.id)}
            className={cx(
              "group relative flex h-[30px] min-w-0 items-center justify-center gap-[6px] rounded-[5px] px-[10px] text-[12px] leading-none font-medium whitespace-nowrap transition-[color,background-color] duration-150 outline-none focus-visible:ring-2 focus-visible:ring-[var(--st-accent)] focus-visible:ring-inset",
              on
                ? "text-[var(--st-fg)]"
                : "text-[var(--st-fg2)] hover:bg-[var(--st-seg-hover)] hover:text-[var(--st-fg)]",
            )}
          >
            <Icon
              size={13}
              strokeWidth={on ? 2 : 1.75}
              className={cx(
                "shrink-0 transition-colors duration-150",
                on
                  ? "text-[var(--st-fg)]"
                  : "text-[var(--st-fg3)] group-hover:text-[var(--st-fg2)]",
              )}
            />
            {m.label}
          </button>
        );
      })}
    </div>
  );
}

function BrandMenu({
  collapsed,
  fresh,
  mode,
  onMode,
  onAction,
}: {
  collapsed: boolean;
  fresh: boolean;
  mode: AppearanceMode;
  onMode: (mode: AppearanceMode) => void;
  onAction: (action: MenuAction) => void;
}) {
  const [open, setOpen] = useState(false);
  const root = useRef<HTMLDivElement>(null);
  const trigger = useRef<HTMLButtonElement>(null);
  const menu = useRef<HTMLDivElement>(null);

  const close = (refocus = true) => {
    setOpen(false);
    if (refocus) trigger.current?.focus();
  };

  /** Focusable items grouped by visual row, so the segmented row counts as one stop. */
  const rows = () => {
    const byRow = new Map<string, HTMLElement[]>();
    for (const el of menu.current?.querySelectorAll<HTMLElement>("[data-row]") ?? []) {
      const key = el.dataset.row ?? "";
      byRow.set(key, [...(byRow.get(key) ?? []), el]);
    }
    return [...byRow.values()];
  };
  const pick = (row: HTMLElement[] | undefined) =>
    (row?.find((el) => el.getAttribute("aria-checked") === "true") ?? row?.[0])?.focus();

  useEffect(() => {
    if (!open) return;
    pick(rows()[0]);
    const onDown = (e: MouseEvent) => {
      if (!root.current?.contains(e.target as Node)) setOpen(false);
    };
    document.addEventListener("mousedown", onDown);
    return () => document.removeEventListener("mousedown", onDown);
  }, [open]);

  const sections: MenuEntry[][] = [
    [
      { id: "updates", label: "Check for updates", icon: Download, run: () => onAction("updates") },
      {
        id: "folder",
        label: "Open config folder",
        icon: FolderOpen,
        hint: "⇧⌘O",
        run: () => onAction("folder"),
      },
      {
        id: "reload",
        label: "Reload services",
        icon: RotateCw,
        hint: "⇧⌘R",
        run: () => onAction("reload"),
      },
      {
        id: "logs",
        label: "Show logs",
        icon: ScrollText,
        hint: "⇧⌘L",
        run: () => onAction("logs"),
      },
    ],
    [
      {
        id: "changelog",
        label: "What's new",
        icon: Sparkles,
        dot: fresh,
        run: () => onAction("changelog"),
      },
      {
        id: "shortcuts",
        label: "Keyboard shortcuts",
        icon: Keyboard,
        hint: "⌘/",
        run: () => onAction("shortcuts"),
      },
      { id: "about", label: "About Macarchy", icon: Info, run: () => onAction("about") },
    ],
    [{ id: "quit", label: "Quit Macarchy", icon: Power, hint: "⌘Q", run: () => onAction("quit") }],
  ];

  const onMenuKey = (e: ReactKeyboardEvent) => {
    const all = rows();
    const active = document.activeElement as HTMLElement;
    const at = all.findIndex((row) => row.includes(active));
    const row = all[at];
    if (e.key === "ArrowDown" || e.key === "ArrowUp") {
      e.preventDefault();
      const step = e.key === "ArrowDown" ? 1 : -1;
      pick(all[at < 0 ? 0 : (at + step + all.length) % all.length]);
    } else if ((e.key === "ArrowLeft" || e.key === "ArrowRight") && row && row.length > 1) {
      e.preventDefault();
      const step = e.key === "ArrowRight" ? 1 : -1;
      row[(row.indexOf(active) + step + row.length) % row.length]?.focus();
    } else if (e.key === "Home") {
      e.preventDefault();
      pick(all[0]);
    } else if (e.key === "End") {
      e.preventDefault();
      pick(all[all.length - 1]);
    } else if (e.key === "Escape") {
      e.preventDefault();
      e.stopPropagation();
      close();
    } else if (e.key === "Tab") {
      close(false);
    }
  };

  let rowIndex = 0;
  return (
    <div ref={root} className="relative">
      <Tip label="Macarchy" side="right" disabled={!collapsed || open} className="flex w-full">
        <button
          ref={trigger}
          type="button"
          aria-haspopup="menu"
          aria-expanded={open}
          aria-label={collapsed ? "Macarchy menu" : undefined}
          onClick={() => setOpen((o) => !o)}
          onKeyDown={(e) => {
            if (e.key === "ArrowDown" && !open) {
              e.preventDefault();
              setOpen(true);
            }
          }}
          className={cx(
            "group flex h-[40px] items-center gap-[10px] overflow-hidden rounded-[8px] px-[6px] text-left whitespace-nowrap transition-[width,background-color] duration-200 ease-out focus-visible:ring-2 focus-visible:ring-[var(--st-accent)] focus-visible:outline-none",
            collapsed ? "w-[40px]" : "w-full",
            open ? "bg-[var(--st-hover)]" : "hover:bg-[var(--st-hover)]",
          )}
        >
          <AppIcon />
          <span
            aria-hidden={collapsed}
            className={cx(
              "flex min-w-0 flex-1 items-center gap-2.5 transition-opacity duration-150",
              collapsed ? "opacity-0" : "opacity-100",
            )}
          >
            <span className="min-w-0 flex-1">
              <span className="block text-[13px] leading-[18px] font-semibold tracking-[-0.01em]">
                Macarchy
              </span>
              <span className="block truncate text-[11.5px] leading-4 text-[var(--st-fg3)]">
                MacBook Pro
              </span>
            </span>
            <ChevronDown
              size={14}
              strokeWidth={1.75}
              className={cx(
                "shrink-0 text-[var(--st-fg3)] transition-[transform,opacity] duration-150",
                open ? "rotate-180 opacity-100" : "opacity-60 group-hover:opacity-100",
              )}
            />
          </span>
        </button>
      </Tip>

      {open ? (
        <div
          ref={menu}
          role="menu"
          aria-label="Macarchy"
          onKeyDown={onMenuKey}
          className={cx(
            "absolute top-full left-0 z-50 mt-[4px] w-[256px] origin-top animate-[st-menu-in_120ms_ease-out] rounded-[10px] border border-[var(--st-border)] bg-[var(--st-bg)] p-[4px] shadow-[0_16px_40px_-12px_rgba(0,0,0,0.35),0_2px_6px_-2px_rgba(0,0,0,0.12)]",
          )}
        >
          <style>{`@keyframes st-menu-in { from { opacity: 0; transform: scale(0.98) translateY(-2px); } to { opacity: 1; transform: none; } }`}</style>
          <div role="group" aria-label="Appearance" className="px-[4px] pt-[6px] pb-[8px]">
            <div className="px-[2px] pb-[7px] text-[11px] leading-[14px] font-medium text-[var(--st-fg3)]">
              Appearance
            </div>
            <AppearanceSegmented mode={mode} onMode={onMode} row={rowIndex} />
          </div>
          {sections.map((items, si) => (
            <div key={si} role="group">
              <div role="separator" className="-mx-[4px] my-[4px] h-px bg-[var(--st-border)]" />
              {items.map((item) => {
                const Icon = item.icon;
                rowIndex += 1;
                return (
                  <button
                    key={item.id}
                    type="button"
                    role="menuitem"
                    data-row={rowIndex}
                    tabIndex={-1}
                    onMouseEnter={(e) => e.currentTarget.focus()}
                    onClick={() => {
                      close();
                      item.run();
                    }}
                    className="flex h-8 w-full items-center gap-2.5 rounded-[6px] px-2 text-left text-[13px] text-[var(--st-fg)] outline-none focus:bg-[var(--st-muted)]"
                  >
                    <Icon size={14} strokeWidth={1.75} className="shrink-0 text-[var(--st-fg2)]" />
                    <span className="min-w-0 flex-1 truncate">{item.label}</span>
                    {item.dot ? (
                      <span className="mr-[2px] size-[6px] rounded-full bg-[var(--st-accent)]">
                        <span className="sr-only">, unread</span>
                      </span>
                    ) : null}
                    {item.hint ? (
                      <span className="text-[11.5px] tracking-[0.04em] text-[var(--st-fg3)]">
                        {item.hint}
                      </span>
                    ) : null}
                  </button>
                );
              })}
            </div>
          ))}
        </div>
      ) : null}
    </div>
  );
}

/* ------------------------------------------------------------------ */
/* Sidebar                                                             */
/* ------------------------------------------------------------------ */

const releaseArt = (() => {
  const t = realThemes.find((x) => x.id === "lumon");
  return {
    src: t ? wallpaperUrl(t.id, t.wallpaper) : undefined,
    from: t?.background ?? "#18181b",
    to: t?.accent ?? "#6366f1",
  };
})();

/**
 * A release card above the sidebar footer, with room for the art and a two-line summary. Its fixed width lets the sidebar transition clip it rather than reflow.
 */
function ReleaseCard({
  visible,
  fresh,
  onOpen,
  onDismiss,
}: {
  visible: boolean;
  fresh: boolean;
  onOpen: () => void;
  onDismiss: () => void;
}) {
  return (
    <div
      inert={!visible}
      aria-hidden={!visible}
      className={cx(
        "grid transition-[grid-template-rows] duration-200 ease-out",
        visible ? "grid-rows-[1fr]" : "grid-rows-[0fr]",
      )}
    >
      <div className="min-h-0 overflow-hidden">
        <div
          className={cx(
            "w-[232px] px-[8px] pt-[2px] pb-[10px] transition-[opacity,transform] duration-200 ease-out",
            visible
              ? "translate-y-0 scale-100 opacity-100"
              : "translate-y-[6px] scale-[0.97] opacity-0",
          )}
        >
          <div className="group relative pt-[5px]">
            {/* An earlier release peeking out behind the card. */}
            <div
              aria-hidden
              className="absolute inset-x-[8px] top-0 h-[20px] rounded-[9px] border border-[var(--st-border)] bg-[var(--st-bg)] opacity-70 transition-transform duration-200 ease-out group-hover:-translate-y-[1px]"
            />
            <article className="relative overflow-hidden rounded-[10px] border border-[var(--st-border)] bg-[var(--st-bg)] shadow-[0_1px_2px_rgba(9,9,11,0.06),0_8px_20px_-12px_rgba(9,9,11,0.25)] transition-[border-color,box-shadow,transform] duration-200 ease-out group-hover:-translate-y-px group-hover:border-[var(--st-border-strong)] group-hover:shadow-[0_1px_2px_rgba(9,9,11,0.06),0_14px_28px_-14px_rgba(9,9,11,0.35)]">
              <div className="relative m-[4px] h-[64px] overflow-hidden rounded-[7px] ring-1 ring-black/5 ring-inset">
                <ImageFill
                  src={releaseArt.src}
                  from={releaseArt.from}
                  to={releaseArt.to}
                  className="transition-transform duration-500 ease-out group-hover:scale-[1.04]"
                />
                <div className="absolute inset-0 bg-gradient-to-b from-black/45 via-black/5 to-transparent" />
                <span className="absolute top-[8px] left-[8px] inline-flex h-[20px] items-center gap-[4px] rounded-[5px] bg-black/40 px-[6px] text-[10.5px] leading-none font-semibold text-white ring-1 ring-white/15 backdrop-blur-[6px]">
                  <Sparkles size={10} strokeWidth={2} />
                  What's new
                </span>
              </div>
              <div className="px-[12px] pt-[8px] pb-[12px]">
                <div className="flex h-[18px] items-center gap-[6px]">
                  {fresh ? (
                    <span className="size-[6px] shrink-0 rounded-full bg-[var(--st-accent)]" />
                  ) : null}
                  <h3 className="min-w-0 flex-1 truncate text-[13px] leading-[18px] font-semibold tracking-[-0.01em] text-[var(--st-fg)]">
                    {version}: Themes everywhere
                  </h3>
                  <ArrowRight
                    aria-hidden
                    size={12}
                    strokeWidth={2}
                    className="shrink-0 -translate-x-[3px] text-[var(--st-fg3)] opacity-0 transition-[opacity,transform] duration-150 group-hover:translate-x-0 group-hover:opacity-100"
                  />
                </div>
                <p className="mt-[4px] line-clamp-2 text-[12px] leading-[17px] text-[var(--st-fg2)]">
                  Ghostty and Neovim now follow your theme, and every theme keeps its own wallpaper.
                </p>
              </div>
              <button
                type="button"
                onClick={onOpen}
                aria-label={`What's new in Macarchy ${version}: Themes everywhere. Open the changelog`}
                className="absolute inset-0 rounded-[10px] focus-visible:ring-2 focus-visible:ring-[var(--st-accent)] focus-visible:outline-none focus-visible:ring-inset"
              />
              <button
                type="button"
                onClick={onDismiss}
                aria-label="Dismiss what's new"
                title="Dismiss"
                className="absolute top-[12px] right-[12px] grid size-[22px] place-items-center rounded-full bg-black/40 text-white/85 opacity-0 ring-1 ring-white/15 backdrop-blur-[6px] transition-[opacity,background-color] duration-150 group-hover:opacity-100 hover:bg-black/60 hover:text-white focus-visible:opacity-100 focus-visible:ring-2 focus-visible:ring-[var(--st-accent)] focus-visible:outline-none"
              >
                <X size={11} strokeWidth={2.25} />
              </button>
            </article>
          </div>
        </div>
      </div>
    </div>
  );
}

function NavItem({
  id,
  active,
  collapsed,
  onSelect,
}: {
  id: MockPaneId;
  active: boolean;
  collapsed: boolean;
  onSelect: (id: MockPaneId) => void;
}) {
  const { title, icon: Icon } = panes[id];
  const warn = id === "health" && issues > 0;
  return (
    <Tip
      label={title}
      keys={warn ? `${issues} to fix` : undefined}
      side="right"
      disabled={!collapsed}
      className="flex"
    >
      <button
        type="button"
        onClick={() => onSelect(id)}
        aria-current={active ? "page" : undefined}
        aria-label={collapsed ? title : undefined}
        className={cx(
          "group relative flex h-[30px] items-center gap-[10px] overflow-hidden rounded-[8px] px-[12.5px] text-[13px] tracking-[-0.01em] whitespace-nowrap transition-[background-color,color,width] duration-200 ease-out focus-visible:ring-2 focus-visible:ring-[var(--st-accent)] focus-visible:outline-none",
          collapsed ? "w-[40px]" : "w-full",
          active
            ? "bg-[var(--st-bg)] font-medium text-[var(--st-fg)] shadow-[var(--st-shadow)] ring-1 ring-[var(--st-border)]"
            : "text-[var(--st-fg2)] hover:bg-[var(--st-hover)] hover:text-[var(--st-fg)]",
        )}
      >
        <span className="relative shrink-0">
          <Icon
            size={15}
            strokeWidth={1.75}
            className={cx(
              "block",
              active ? "text-[var(--st-accent-text)]" : "text-[var(--st-fg3)]",
            )}
          />
          {warn ? (
            <span
              aria-hidden
              className={cx(
                "absolute -top-[3px] -right-[3px] size-[7px] rounded-full bg-[var(--st-warn)] ring-2 transition-opacity duration-150",
                active
                  ? "ring-[var(--st-bg)]"
                  : "ring-[var(--st-side)] group-hover:ring-[var(--st-hover)]",
                collapsed ? "opacity-100" : "opacity-0",
              )}
            />
          ) : null}
        </span>
        <span
          aria-hidden={collapsed}
          className={cx(
            "flex min-w-0 flex-1 items-center gap-2 transition-opacity duration-150",
            collapsed ? "opacity-0" : "opacity-100",
          )}
        >
          <span className="flex-1 truncate text-left">{title}</span>
          {previews.includes(id) ? <PreviewTag /> : null}
          {warn ? (
            <span className="flex h-[16px] min-w-[16px] items-center justify-center rounded-full bg-[var(--st-warn-soft)] px-1 text-[10px] font-semibold tabular-nums text-[var(--st-warn)]">
              {issues}
              <span className="sr-only"> checks need attention</span>
            </span>
          ) : null}
        </span>
      </button>
    </Tip>
  );
}

/* ------------------------------------------------------------------ */
/* Logs                                                                */
/* ------------------------------------------------------------------ */

type LogSource = "macarchy" | "aerospace" | "sketchybar" | "borders";
type LogLevel = "info" | "warn" | "error";

interface LogLine {
  id: number;
  time: string;
  source: LogSource;
  level: LogLevel;
  text: string;
}

const logSources: LogSource[] = ["macarchy", "aerospace", "sketchybar", "borders"];
const bordersCommand = `$ borders width=${snapshot.borders.border_width.toFixed(1)} style=${snapshot.borders.border_style} active_color=0xffd4d4d8 inactive_color=0x00000000`;
const visibleBarItems = snapshot.barItems.filter((i) => i.visible).length;

const seedLogs: [string, LogSource, LogLevel, string][] = [
  ["17:41:58.204", "macarchy", "info", `Macarchy ${version} started, watching ~/.config/macarchy`],
  ["17:41:58.391", "aerospace", "info", "Connected to AeroSpace server, 6 workspaces on 1 monitor"],
  [
    "17:41:58.402",
    "sketchybar",
    "info",
    "Connected to SketchyBar on mach port git.felix.sketchybar",
  ],
  ["17:41:58.415", "borders", "info", "JankyBorders 1.8 running (pid 812)"],
  ["17:41:58.520", "macarchy", "warn", "skhd is not running"],
  ["17:41:58.523", "macarchy", "warn", "Login items: 3 of 4 registered, borders missing"],
  ["17:42:03.118", "macarchy", "info", `$ macarchy theme apply ${currentThemeId}`],
  [
    "17:42:03.126",
    "macarchy",
    "info",
    "Wrote theme colours for aerospace, sketchybar, borders and ghostty",
  ],
  ["17:42:03.140", "aerospace", "info", "$ aerospace reload-config"],
  [
    "17:42:03.188",
    "aerospace",
    "info",
    `Config reloaded: layout ${snapshot.layout.layout}, gaps ${snapshot.layout.window_gap}px, ${snapshot.floatingApps.length} floating apps`,
  ],
  ["17:42:03.201", "sketchybar", "info", "$ sketchybar --reload"],
  [
    "17:42:03.655",
    "sketchybar",
    "info",
    `Loaded ${visibleBarItems} items from ~/.config/sketchybar/items`,
  ],
  ["17:42:03.702", "sketchybar", "error", "Item 'network' script timed out after 2.0s"],
  ["17:42:03.716", "borders", "info", bordersCommand],
  ["17:42:03.730", "borders", "info", `Blacklist applied: ${snapshot.borders.borders_blacklist}`],
  ["17:42:11.064", "aerospace", "info", "on-window-detected: TablePlus -> layout floating"],
  ["17:42:19.882", "aerospace", "info", "Workspace 2 focused on Built-in Retina Display"],
  ["17:42:19.890", "sketchybar", "info", "Event aerospace_workspace_change FOCUSED_WORKSPACE=2"],
  ["17:42:20.311", "borders", "info", "Focus changed, redrawing 3 windows"],
  [
    "17:43:02.447",
    "macarchy",
    "info",
    `Health check finished: ${issues} of ${healthChecks.length} need attention`,
  ],
  ["17:43:02.452", "macarchy", "warn", "skhd is not running: brew services start skhd"],
  ["17:43:40.019", "sketchybar", "info", "Item 'battery' updated: 84%, on battery power"],
  ["17:44:05.773", "aerospace", "info", "$ aerospace move-node-to-workspace 3"],
  ["17:44:05.790", "sketchybar", "info", "Event aerospace_workspace_change FOCUSED_WORKSPACE=3"],
];

function now() {
  const d = new Date();
  const p = (n: number, w = 2) => String(n).padStart(w, "0");
  return `${p(d.getHours())}:${p(d.getMinutes())}:${p(d.getSeconds())}.${p(d.getMilliseconds(), 3)}`;
}

const levelStyle: Record<LogLevel, { label: string; text: string; row: string }> = {
  info: { label: "INFO", text: "text-[var(--st-fg3)]", row: "" },
  warn: { label: "WARN", text: "text-[var(--st-warn)]", row: "bg-[var(--st-warn-row)]" },
  error: { label: "ERROR", text: "text-[var(--st-err)]", row: "bg-[var(--st-err-soft)]" },
};

function LogsPanel({
  open,
  lines,
  onClear,
  onCopy,
  onClose,
}: {
  open: boolean;
  lines: LogLine[];
  onClear: () => void;
  onCopy: (text: string, count: number) => void;
  onClose: () => void;
}) {
  const [filter, setFilter] = useState<LogSource | "all">("all");
  const body = useRef<HTMLDivElement>(null);
  const shown = filter === "all" ? lines : lines.filter((l) => l.source === filter);
  const problems = lines.filter((l) => l.level !== "info").length;

  useEffect(() => {
    const el = body.current;
    if (open && el) el.scrollTo({ top: el.scrollHeight });
  }, [open, shown.length]);

  const chip = (id: LogSource | "all", label: string, count: number) => (
    <button
      key={id}
      type="button"
      aria-pressed={filter === id}
      onClick={() => setFilter(id)}
      className={cx(
        "flex h-6 items-center gap-1.5 rounded-[6px] px-2 text-[11.5px] font-medium transition-colors focus-visible:ring-2 focus-visible:ring-[var(--st-accent)] focus-visible:outline-none",
        filter === id
          ? "bg-[var(--st-bg)] text-[var(--st-fg)] shadow-[var(--st-shadow)] ring-1 ring-[var(--st-border)]"
          : "text-[var(--st-fg2)] hover:bg-[var(--st-hover)] hover:text-[var(--st-fg)]",
      )}
    >
      {label}
      <span className="tabular-nums text-[var(--st-fg3)]">{count}</span>
    </button>
  );

  return (
    <div
      inert={!open}
      className={cx(
        "shrink-0 overflow-hidden border-t transition-[height,border-color] duration-200 ease-out",
        open ? "border-[var(--st-border)]" : "border-transparent",
      )}
      style={{ height: open ? logsHeight : 0 }}
    >
      <section
        aria-label="Logs"
        className="flex flex-col bg-[var(--st-side)]"
        style={{ height: logsHeight - 1 }}
      >
        <div className="flex h-11 shrink-0 items-center gap-3 border-b border-[var(--st-border)] pr-2 pl-4">
          <div className="flex items-center gap-2 text-[13px] font-medium">
            <ScrollText size={14} strokeWidth={1.75} className="text-[var(--st-fg2)]" />
            Logs
            {problems > 0 ? <Badge tone="warn">{problems} to review</Badge> : null}
          </div>
          <span className="h-4 w-px bg-[var(--st-border)]" />
          <div role="group" aria-label="Filter by source" className="flex items-center gap-1">
            {chip("all", "All", lines.length)}
            {logSources.map((s) => chip(s, s, lines.filter((l) => l.source === s).length))}
          </div>
          <div className="ml-auto flex items-center gap-0.5">
            <IconButton
              label="Copy"
              size="sm"
              disabled={shown.length === 0}
              onClick={() =>
                onCopy(
                  shown
                    .map((l) => `${l.time} ${l.level.toUpperCase()} [${l.source}] ${l.text}`)
                    .join("\n"),
                  shown.length,
                )
              }
            >
              <Copy size={13} strokeWidth={1.75} />
            </IconButton>
            <IconButton label="Clear" size="sm" disabled={lines.length === 0} onClick={onClear}>
              <Trash2 size={13} strokeWidth={1.75} />
            </IconButton>
            <span className="mx-1 h-4 w-px bg-[var(--st-border)]" />
            <IconButton label="Close" keys="Esc" size="sm" onClick={onClose}>
              <X size={14} strokeWidth={1.75} />
            </IconButton>
          </div>
        </div>
        <div
          ref={body}
          role="log"
          aria-label="Command log"
          className="min-h-0 flex-1 overflow-y-auto bg-[var(--st-bg)] py-1.5 font-mono text-[11.5px] leading-[18px]"
        >
          {shown.length === 0 ? (
            <div className="grid h-full place-items-center font-sans text-[12.5px] text-[var(--st-fg3)]">
              {lines.length === 0 ? "No logs" : `No ${filter} logs`}
            </div>
          ) : (
            shown.map((l) => {
              const lv = levelStyle[l.level];
              const command = l.text.startsWith("$ ");
              return (
                <div
                  key={l.id}
                  className={cx(
                    "grid grid-cols-[88px_44px_80px_minmax(0,1fr)] gap-3 px-4 py-[2px] hover:bg-[var(--st-hover)]",
                    lv.row,
                  )}
                >
                  <span className="tabular-nums text-[var(--st-fg3)]">{l.time}</span>
                  <span className={cx("font-semibold", lv.text)}>{lv.label}</span>
                  <span className="truncate text-[var(--st-fg2)]">{l.source}</span>
                  <span
                    className={cx(
                      "break-words whitespace-pre-wrap",
                      command ? "text-[var(--st-fg)]" : "text-[var(--st-fg2)]",
                      l.level === "error" && "text-[var(--st-err)]",
                    )}
                  >
                    {command ? (
                      <>
                        <span className="text-[var(--st-fg3)] select-none">$ </span>
                        {l.text.slice(2)}
                      </>
                    ) : (
                      l.text
                    )}
                  </span>
                </div>
              );
            })
          )}
        </div>
      </section>
    </div>
  );
}

/* ------------------------------------------------------------------ */
/* Service status                                                      */
/* ------------------------------------------------------------------ */

type ServiceName = "AeroSpace" | "SketchyBar" | "JankyBorders" | "skhd";
type ServiceState = "running" | "stopped";
type Series = (number | null)[];

const serviceList = services.map((s) => ({ ...s, name: s.name as ServiceName }));

/** CPU samples every two minutes over the hour up to 17:44, the time of the last seeded log. */
const cpuPoints = 31;
const cpuEnd = 17 * 60 + 44;

function cpuTime(i: number) {
  const t = cpuEnd - (cpuPoints - 1 - i) * 2;
  return `${String(Math.floor(t / 60)).padStart(2, "0")}:${String(t % 60).padStart(2, "0")}`;
}

function noise(seed: number, i: number) {
  const x = Math.sin(seed * 12.9898 + i * 78.233) * 43758.5453;
  return x - Math.floor(x);
}

function cpuSeries(seed: number, base: number, amp: number, spikes: Record<number, number>) {
  return Array.from({ length: cpuPoints }, (_, i) => {
    const v = base + amp * (0.6 * noise(seed, i) + 0.4 * noise(seed, i - 1)) + (spikes[i] ?? 0);
    return Math.round(v * 10) / 10;
  });
}

interface ServiceMeta {
  source: LogSource;
  uptime: string;
  /** Minutes since the service started, behind the longest-uptime stat. */
  upFor: number;
  /** Resident memory in MB while running. */
  memory: number;
  cpu: Series;
  command: (verb: "restart" | "start") => string;
  done: string;
}

const serviceMeta: Record<ServiceName, ServiceMeta> = {
  AeroSpace: {
    source: "aerospace",
    uptime: "Up 2d 4h",
    upFor: 3124,
    memory: 96,
    cpu: cpuSeries(1, 0.9, 1.3, { 14: 2.1, 29: 4.4 }),
    command: (v) =>
      v === "start" ? "$ open -a AeroSpace" : "$ killall AeroSpace && open -a AeroSpace",
    done: "AeroSpace started, 6 workspaces on 1 monitor",
  },
  SketchyBar: {
    source: "sketchybar",
    uptime: "Up 2d 4h",
    upFor: 3121,
    memory: 78,
    cpu: cpuSeries(2, 1.8, 1.6, { 8: 2.6, 29: 7.4, 30: 1.2 }),
    command: (v) => `$ brew services ${v} sketchybar`,
    done: `Loaded ${visibleBarItems} items from ~/.config/sketchybar/items`,
  },
  JankyBorders: {
    source: "borders",
    uptime: "Up 6h 12m",
    upFor: 372,
    memory: 38,
    cpu: cpuSeries(3, 0.3, 0.5, { 22: 0.6, 29: 1.5 }),
    command: (v) => `$ brew services ${v} borders`,
    done: "JankyBorders 1.8 running (pid 1204)",
  },
  skhd: {
    source: "macarchy",
    uptime: "",
    upFor: 0,
    memory: 9,
    cpu: Array.from({ length: cpuPoints }, (_, i) =>
      i === cpuPoints - 2 ? 0.8 : i === cpuPoints - 1 ? 0.2 : null,
    ),
    command: (v) => `$ brew services ${v} skhd`,
    done: "skhd started, loaded ~/.config/skhd/skhdrc",
  },
};

const sparkW = 128;
const sparkH = 34;
const sparkPad = { top: 4, bottom: 3, x: 3 };

/** A one-hour CPU line with a snapping crosshair and a tooltip kept inside the chart. */
function Sparkline({ name, values, live }: { name: string; values: Series; live: boolean }) {
  const gradient = `st-spark-${useId().replace(/[^\w-]/g, "")}`;
  const [hover, setHover] = useState<number | null>(null);
  const tip = useRef<HTMLDivElement>(null);
  const points = live ? values.flatMap((v, i) => (v === null ? [] : [{ i, v }])) : [];
  const max = Math.max(1, ...points.map((p) => p.v)) * 1.15;
  const base = sparkH - sparkPad.bottom;
  const x = (i: number) => sparkPad.x + (i / (cpuPoints - 1)) * (sparkW - sparkPad.x * 2);
  const y = (v: number) => sparkPad.top + (1 - v / max) * (base - sparkPad.top);
  const line = points.map((p, k) => `${k ? "L" : "M"}${x(p.i)},${y(p.v)}`).join("");
  const first = points[0];
  const last = points[points.length - 1];
  const area = first && last ? `${line}L${x(last.i)},${base}L${x(first.i)},${base}Z` : "";
  const active = points.find((p) => p.i === hover);
  const peak = points.reduce((m, p) => Math.max(m, p.v), 0);

  useLayoutEffect(() => {
    const el = tip.current;
    if (!el || !active) return;
    const w = el.offsetWidth;
    const h = el.offsetHeight;
    const px = x(active.i);
    let left = px + 8;
    if (left + w > sparkW) left = px - 8 - w;
    const top = Math.min(Math.max(0, y(active.v) - h / 2), sparkH - h);
    el.style.left = `${Math.max(0, Math.round(left))}px`;
    el.style.top = `${Math.round(top)}px`;
    el.style.visibility = "visible";
  });

  return (
    <div
      className="relative"
      style={{ width: sparkW, height: sparkH }}
      onMouseMove={(e) => {
        if (points.length === 0) return;
        const r = e.currentTarget.getBoundingClientRect();
        const fx = ((e.clientX - r.left) / r.width) * sparkW;
        const best = points.reduce((a, p) =>
          Math.abs(x(p.i) - fx) < Math.abs(x(a.i) - fx) ? p : a,
        );
        setHover(best.i);
      }}
      onMouseLeave={() => setHover(null)}
    >
      <svg
        width={sparkW}
        height={sparkH}
        role="img"
        aria-label={
          live && last
            ? `${name} CPU over the last hour, peak ${peak}%, now ${last.v}%`
            : `${name} is not running, no CPU data`
        }
        className="block overflow-visible"
      >
        <defs>
          <linearGradient id={gradient} x1="0" y1="0" x2="0" y2="1">
            <stop offset="0%" style={{ stopColor: "var(--st-accent)", stopOpacity: 0.18 }} />
            <stop offset="100%" style={{ stopColor: "var(--st-accent)", stopOpacity: 0 }} />
          </linearGradient>
        </defs>
        <line
          x1={0}
          x2={sparkW}
          y1={base + 0.5}
          y2={base + 0.5}
          stroke="var(--st-border)"
          strokeDasharray={points.length ? undefined : "2 3"}
        />
        {area ? <path d={area} fill={`url(#${gradient})`} /> : null}
        {points.length > 1 ? (
          <path
            d={line}
            fill="none"
            stroke="var(--st-accent)"
            strokeWidth={2}
            strokeLinejoin="round"
            strokeLinecap="round"
            opacity={active ? 0.85 : 1}
          />
        ) : null}
        {active ? (
          <>
            <line
              x1={x(active.i)}
              x2={x(active.i)}
              y1={0}
              y2={base}
              stroke="var(--st-border-strong)"
              strokeWidth={1}
            />
            <circle
              cx={x(active.i)}
              cy={y(active.v)}
              r={3.5}
              fill="var(--st-accent)"
              stroke="var(--st-bg)"
              strokeWidth={1.5}
            />
          </>
        ) : null}
      </svg>
      {active ? (
        <div
          ref={tip}
          style={{ left: 0, top: 0, visibility: "hidden" }}
          className="pointer-events-none absolute z-10 flex items-baseline gap-[5px] rounded-[6px] border border-[var(--st-border)] bg-[var(--st-bg)] px-[6px] py-[2px] text-[11px] leading-[15px] whitespace-nowrap text-[var(--st-fg)] shadow-[var(--st-chart-tip-shadow)]"
        >
          <span className="font-semibold tabular-nums">{active.v}%</span>
          <span className="tabular-nums text-[var(--st-fg3)]">{cpuTime(active.i)}</span>
        </div>
      ) : null}
    </div>
  );
}

function StatusDot({ tone, pulse }: { tone: "ok" | "warn" | "idle"; pulse?: boolean }) {
  const colour = {
    ok: "bg-[var(--st-ok)] shadow-[0_0_0_3px_var(--st-ok-soft)]",
    warn: "bg-[var(--st-warn)] shadow-[0_0_0_3px_var(--st-warn-soft)]",
    idle: "bg-[var(--st-fg3)] shadow-[0_0_0_3px_var(--st-muted)]",
  }[tone];
  return (
    <span
      aria-hidden
      className={cx("size-[7px] shrink-0 rounded-full", colour, pulse && "animate-pulse")}
    />
  );
}

type RingSegment = "on" | "off" | "busy";

/**
 * A ring split into one arc per service, clockwise from the top in list order.
 * Each arc draws in along the ring when its service comes up.
 */
function ServiceRing({
  segments,
  size,
  stroke,
  gap,
  children,
}: {
  segments: RingSegment[];
  size: number;
  stroke: number;
  /** Gap between arcs, in pixels along the ring. */
  gap: number;
  children?: ReactNode;
}) {
  const centre = size / 2;
  const r = (size - stroke) / 2;
  const c = 2 * Math.PI * r;
  const arc = c / segments.length - gap;
  return (
    <span
      className="relative grid shrink-0 place-items-center"
      style={{ width: size, height: size }}
    >
      <svg
        width={size}
        height={size}
        viewBox={`0 0 ${size} ${size}`}
        aria-hidden
        className="absolute inset-0 -rotate-90"
      >
        {segments.map((s, i) => {
          const angle = (360 / segments.length) * i + (gap / c) * 180;
          const shared = {
            cx: centre,
            cy: centre,
            r,
            fill: "none",
            strokeWidth: stroke,
            strokeDasharray: `${arc} ${c}`,
            transform: `rotate(${angle} ${centre} ${centre})`,
          };
          return (
            <g key={i}>
              <circle {...shared} stroke="var(--st-border-strong)" />
              <circle
                {...shared}
                stroke={s === "busy" ? "var(--st-fg3)" : "var(--st-ok)"}
                strokeDashoffset={s === "off" ? arc : 0}
                className={cx(
                  "transition-[stroke-dashoffset,stroke] duration-500 ease-out motion-reduce:transition-none",
                  s === "busy" && "animate-pulse",
                )}
              />
            </g>
          );
        })}
      </svg>
      {children ? <span className="relative">{children}</span> : null}
    </span>
  );
}

function formatUptime(minutes: number) {
  if (minutes < 1) return "Just now";
  const d = Math.floor(minutes / 1440);
  const h = Math.floor((minutes % 1440) / 60);
  const m = minutes % 60;
  return d ? `${d}d ${h}h` : h ? `${h}h ${m}m` : `${m}m`;
}

/** A compact outlined action for the services header. */
function HeaderAction({
  label,
  keys,
  onClick,
  children,
}: {
  label: string;
  keys?: string;
  onClick: () => void;
  children: ReactNode;
}) {
  return (
    <Tip label={label} keys={keys}>
      <button
        type="button"
        aria-label={label}
        onClick={onClick}
        className="inline-flex h-[26px] items-center gap-[5px] rounded-[7px] border border-[var(--st-border)] bg-[var(--st-bg)] px-[8px] text-[12px] font-medium tracking-[-0.01em] whitespace-nowrap text-[var(--st-fg2)] shadow-[var(--st-shadow)] transition-colors hover:bg-[var(--st-hover)] hover:text-[var(--st-fg)] focus-visible:ring-2 focus-visible:ring-[var(--st-accent)] focus-visible:outline-none active:translate-y-px [&_svg]:text-[var(--st-fg3)] hover:[&_svg]:text-[var(--st-fg2)]"
      >
        {children}
      </button>
    </Tip>
  );
}

function ServiceStat({
  label,
  value,
  unit,
  title,
}: {
  label: string;
  value: string;
  unit?: string;
  title?: string;
}) {
  return (
    <div className="min-w-0 border-r border-[var(--st-border)] px-[10px] py-[7px]" title={title}>
      <div className="truncate text-[11px] leading-[14px] text-[var(--st-fg3)]">{label}</div>
      <div className="mt-[2px] flex items-baseline gap-[3px] text-[13px] leading-[18px] font-semibold tracking-[-0.01em] tabular-nums text-[var(--st-fg)]">
        {value}
        {unit ? <span className="text-[11px] font-medium text-[var(--st-fg3)]">{unit}</span> : null}
      </div>
    </div>
  );
}

function ServiceStatus({
  log,
  notify,
  onHealth,
  onLogs,
}: {
  log: (entries: [LogSource, LogLevel, string][]) => void;
  notify: (message: string) => void;
  onHealth: () => void;
  onLogs: () => void;
}) {
  const [open, setOpen] = useState(false);
  const [states, setStates] = useState(
    () =>
      Object.fromEntries(serviceList.map((s) => [s.name, s.state])) as Record<
        ServiceName,
        ServiceState
      >,
  );
  const [uptime, setUptime] = useState(
    () =>
      Object.fromEntries(serviceList.map((s) => [s.name, serviceMeta[s.name].uptime])) as Record<
        ServiceName,
        string
      >,
  );
  const [upFor, setUpFor] = useState(
    () =>
      Object.fromEntries(serviceList.map((s) => [s.name, serviceMeta[s.name].upFor])) as Record<
        ServiceName,
        number
      >,
  );
  const [busy, setBusy] = useState<Partial<Record<ServiceName, "restart" | "start">>>({});
  const wrap = useRef<HTMLDivElement>(null);
  const trigger = useRef<HTMLButtonElement>(null);
  const timers = useRef<ReturnType<typeof setTimeout>[]>([]);

  const running = serviceList.filter((s) => states[s.name] === "running").length;
  const allUp = running === serviceList.length;
  const anyBusy = serviceList.some((s) => busy[s.name]);
  const active = serviceList.filter((s) => states[s.name] === "running" && !busy[s.name]);
  const cpuNow = active.reduce((sum, s) => {
    const values = serviceMeta[s.name].cpu;
    return sum + (values[values.length - 1] ?? 0);
  }, 0);
  const memory = active.reduce((sum, s) => sum + serviceMeta[s.name].memory, 0);
  const longest = active.reduce<(typeof active)[number] | undefined>(
    (best, s) => (!best || upFor[s.name] > upFor[best.name] ? s : best),
    undefined,
  );
  const segments = serviceList.map((s): RingSegment =>
    busy[s.name] ? "busy" : states[s.name] === "running" ? "on" : "off",
  );

  useEffect(() => () => timers.current.forEach(clearTimeout), []);

  useEffect(() => {
    if (!open) return;
    const onDown = (e: MouseEvent) => {
      if (!wrap.current?.contains(e.target as Node)) setOpen(false);
    };
    // Capture runs before the window handler, so Escape closes this panel and not the logs.
    const onKey = (e: KeyboardEvent) => {
      if (e.key !== "Escape" || e.defaultPrevented) return;
      e.preventDefault();
      setOpen(false);
      trigger.current?.focus();
    };
    document.addEventListener("mousedown", onDown);
    window.addEventListener("keydown", onKey, true);
    return () => {
      document.removeEventListener("mousedown", onDown);
      window.removeEventListener("keydown", onKey, true);
    };
  }, [open]);

  const run = (names: ServiceName[]) => {
    const jobs = names.map((name) => ({
      name,
      meta: serviceMeta[name],
      verb: states[name] === "running" ? ("restart" as const) : ("start" as const),
    }));
    const patch = <T,>(value: (job: (typeof jobs)[number]) => T) =>
      Object.fromEntries(jobs.map((j) => [j.name, value(j)])) as Record<ServiceName, T>;
    setBusy((b) => ({ ...b, ...patch((j) => j.verb) }));
    log(
      jobs.map((j): [LogSource, LogLevel, string] => [
        j.meta.source,
        "info",
        j.meta.command(j.verb),
      ]),
    );
    timers.current.push(
      setTimeout(() => {
        setBusy((b) => ({ ...b, ...patch(() => undefined) }));
        setStates((s) => ({ ...s, ...patch((): ServiceState => "running") }));
        setUpFor((u) => ({ ...u, ...patch(() => 0) }));
        setUptime((u) => ({
          ...u,
          ...patch((j) => (j.verb === "start" ? "Started just now" : "Restarted just now")),
        }));
        log(jobs.map((j): [LogSource, LogLevel, string] => [j.meta.source, "info", j.meta.done]));
        const [only] = jobs;
        notify(
          jobs.length === 1 && only
            ? `${only.name} ${only.verb === "start" ? "started" : "restarted"}`
            : "All services restarted",
        );
      }, 900),
    );
  };

  const close = (then: () => void) => {
    setOpen(false);
    then();
  };

  const columns = "grid grid-cols-[minmax(0,1fr)_128px_36px_84px] items-center gap-x-[12px]";

  return (
    <div ref={wrap} className="relative">
      <button
        ref={trigger}
        type="button"
        aria-haspopup="dialog"
        aria-expanded={open}
        aria-label={`Services: ${running} of ${serviceList.length} running`}
        onClick={() => setOpen((o) => !o)}
        className={cx(
          "flex h-[28px] items-center gap-[8px] rounded-[7px] px-[9px] text-[12.5px] font-medium whitespace-nowrap transition-colors focus-visible:ring-2 focus-visible:ring-[var(--st-accent)] focus-visible:outline-none",
          open
            ? "bg-[var(--st-muted)] text-[var(--st-fg)] ring-1 ring-[var(--st-border)]"
            : "text-[var(--st-fg2)] hover:bg-[var(--st-hover)] hover:text-[var(--st-fg)]",
        )}
      >
        <ServiceRing segments={segments} size={16} stroke={3} gap={1.75} />
        <span className="tabular-nums">
          {running}/{serviceList.length}
        </span>
      </button>

      {open ? (
        <div
          role="dialog"
          aria-label="Services"
          className="absolute top-full right-0 z-50 mt-[6px] w-[436px] origin-top-right animate-[st-pop-in_120ms_ease-out] overflow-hidden rounded-[12px] border border-[var(--st-border)] bg-[var(--st-bg)] shadow-[var(--st-pop-shadow)]"
        >
          <style>{`@keyframes st-pop-in { from { opacity: 0; transform: scale(0.98) translateY(-2px); } to { opacity: 1; transform: none; } }`}</style>
          <div className="border-b border-[var(--st-border)] px-[14px] pt-[12px] pb-[12px]">
            <div className="flex items-center gap-[12px]">
              <ServiceRing segments={segments} size={40} stroke={4} gap={3}>
                <span className="text-[12px] leading-none font-semibold tabular-nums text-[var(--st-fg)]">
                  {running}
                  <span className="font-medium text-[var(--st-fg3)]">/{serviceList.length}</span>
                </span>
              </ServiceRing>
              <div className="min-w-0 flex-1">
                <div className="text-[13px] leading-[18px] font-semibold tracking-[-0.01em] text-[var(--st-fg)]">
                  Services
                </div>
                <p className="mt-[2px] truncate text-[12px] leading-[17px] text-[var(--st-fg2)]">
                  {allUp ? "All running" : `${running} of ${serviceList.length} running`}
                </p>
              </div>
              <div className="flex shrink-0 items-center gap-[6px]">
                <HeaderAction label="Open Setup health" onClick={() => close(onHealth)}>
                  <Stethoscope size={13} strokeWidth={1.75} />
                  Setup health
                </HeaderAction>
                <HeaderAction label="Show logs" keys="⇧⌘L" onClick={() => close(onLogs)}>
                  <ScrollText size={13} strokeWidth={1.75} />
                  Logs
                </HeaderAction>
              </div>
            </div>

            <div className="mt-[12px] grid grid-cols-[repeat(3,minmax(0,1fr))_auto] items-stretch rounded-[9px] border border-[var(--st-border)] bg-[var(--st-side)]">
              <ServiceStat label="CPU now" value={`${cpuNow.toFixed(1)}`} unit="%" />
              <ServiceStat label="Memory" value={String(memory)} unit="MB" />
              <ServiceStat
                label="Longest uptime"
                value={longest ? formatUptime(upFor[longest.name]) : "None"}
                title={longest ? longest.name : undefined}
              />
              <div className="grid place-items-center px-[8px]">
                <Tip label="Restart running services and start stopped ones">
                  <Button
                    size="sm"
                    disabled={anyBusy}
                    onClick={() => run(serviceList.map((s) => s.name))}
                  >
                    <RotateCw size={12} strokeWidth={2} className={cx(anyBusy && "animate-spin")} />
                    Restart all
                  </Button>
                </Tip>
              </div>
            </div>
          </div>

          <div
            className={cx(
              columns,
              "px-[14px] pt-[10px] pb-[4px] text-[11px] leading-[14px] font-medium text-[var(--st-fg3)]",
            )}
          >
            <span>Service</span>
            <span>CPU, last hour</span>
            <span className="text-right">Now</span>
            <span />
          </div>
          <ul className="px-[6px] pb-[6px]">
            {serviceList.map((s) => {
              const state = states[s.name];
              const pending = busy[s.name];
              const live = state === "running";
              const values = live ? serviceMeta[s.name].cpu : [];
              const now = values[values.length - 1];
              return (
                <li
                  key={s.name}
                  className={cx(
                    columns,
                    "rounded-[8px] px-[8px] py-[6px] transition-colors hover:bg-[var(--st-side)]",
                  )}
                >
                  <div className="flex min-w-0 items-center gap-[10px]">
                    <StatusDot tone={pending ? "idle" : live ? "ok" : "warn"} pulse={!!pending} />
                    <div className="min-w-0">
                      <div className="truncate text-[13px] leading-[18px] font-medium text-[var(--st-fg)]">
                        {s.name}
                      </div>
                      <div
                        className={cx(
                          "truncate text-[11.5px] leading-[16px]",
                          !live && !pending ? "text-[var(--st-warn)]" : "text-[var(--st-fg3)]",
                        )}
                      >
                        {pending === "restart"
                          ? "Restarting..."
                          : pending === "start"
                            ? "Starting..."
                            : live
                              ? uptime[s.name]
                              : "Stopped"}
                      </div>
                    </div>
                  </div>
                  <Sparkline name={s.name} values={serviceMeta[s.name].cpu} live={live} />
                  <span className="text-right text-[12px] tabular-nums text-[var(--st-fg2)]">
                    {typeof now === "number" ? (
                      `${now}%`
                    ) : (
                      <span className="text-[var(--st-fg3)]">Off</span>
                    )}
                  </span>
                  <Button
                    size="sm"
                    className="justify-self-end"
                    disabled={!!pending}
                    onClick={() => run([s.name])}
                  >
                    {live ? (
                      <RotateCw
                        size={12}
                        strokeWidth={2}
                        className={cx(pending && "animate-spin")}
                      />
                    ) : (
                      <Play size={12} strokeWidth={2} />
                    )}
                    {live ? "Restart" : "Start"}
                  </Button>
                </li>
              );
            })}
          </ul>
        </div>
      ) : null}
    </div>
  );
}

/* ------------------------------------------------------------------ */
/* Command palette                                                     */
/* ------------------------------------------------------------------ */

interface Command {
  id: string;
  label: string;
  hint: string;
  icon: LucideIcon;
  section: "Go to" | "Actions";
  run: () => void;
}

function CommandPalette({ commands, onClose }: { commands: Command[]; onClose: () => void }) {
  const [query, setQuery] = useState("");
  const [index, setIndex] = useState(0);
  const input = useRef<HTMLInputElement>(null);
  const list = useRef<HTMLDivElement>(null);
  const q = query.trim().toLowerCase();
  const results = commands.filter((c) => (c.label + " " + c.hint).toLowerCase().includes(q));
  const active = Math.min(index, Math.max(results.length - 1, 0));

  useEffect(() => input.current?.focus(), []);
  useEffect(() => {
    list.current?.querySelector(`[data-index="${active}"]`)?.scrollIntoView({ block: "nearest" });
  }, [active]);

  const run = (c: Command | undefined) => {
    if (!c) return;
    onClose();
    c.run();
  };

  let lastSection = "";
  return (
    <div
      className="absolute inset-0 z-50 flex justify-center bg-black/25 pt-[96px] backdrop-blur-[1px]"
      onMouseDown={(e) => {
        if (e.target === e.currentTarget) onClose();
      }}
    >
      <div
        role="dialog"
        aria-label="Command palette"
        className="h-fit w-[560px] overflow-hidden rounded-[12px] border border-[var(--st-border)] bg-[var(--st-bg)] shadow-[0_24px_60px_-12px_rgba(0,0,0,0.35)]"
      >
        <div className="flex h-12 items-center gap-2.5 border-b border-[var(--st-border)] px-4">
          <Search size={15} className="text-[var(--st-fg3)]" />
          <input
            ref={input}
            value={query}
            onChange={(e) => {
              setQuery(e.target.value);
              setIndex(0);
            }}
            onKeyDown={(e) => {
              if (e.key === "ArrowDown") {
                e.preventDefault();
                setIndex((active + 1) % Math.max(results.length, 1));
              } else if (e.key === "ArrowUp") {
                e.preventDefault();
                setIndex((active - 1 + results.length) % Math.max(results.length, 1));
              } else if (e.key === "Enter") {
                e.preventDefault();
                run(results[active]);
              } else if (e.key === "Escape") {
                e.preventDefault();
                onClose();
              }
            }}
            placeholder="Search settings or run a command..."
            className="flex-1 bg-transparent text-[14px] text-[var(--st-fg)] outline-none placeholder:text-[var(--st-fg3)]"
          />
          <span className="rounded-[4px] border border-[var(--st-border)] px-1.5 text-[11px] font-medium text-[var(--st-fg3)]">
            Esc
          </span>
        </div>
        <div ref={list} className="max-h-[340px] overflow-y-auto p-1.5">
          {results.length === 0 ? (
            <div className="px-3 py-8 text-center text-[13px] text-[var(--st-fg2)]">
              No results for "{query}"
            </div>
          ) : (
            results.map((c, i) => {
              const header = c.section !== lastSection ? c.section : null;
              lastSection = c.section;
              const Icon = c.icon;
              return (
                <div key={c.id}>
                  {header ? (
                    <div className="px-2.5 pt-2 pb-1 text-[11px] font-medium text-[var(--st-fg3)]">
                      {header}
                    </div>
                  ) : null}
                  <button
                    type="button"
                    data-index={i}
                    onMouseMove={() => setIndex(i)}
                    onClick={() => run(c)}
                    className={cx(
                      "flex h-9 w-full items-center gap-2.5 rounded-[7px] px-2.5 text-left text-[13px]",
                      i === active
                        ? "bg-[var(--st-muted)] text-[var(--st-fg)]"
                        : "text-[var(--st-fg2)]",
                    )}
                  >
                    <Icon
                      size={15}
                      strokeWidth={1.75}
                      className={i === active ? "text-[var(--st-fg)]" : "text-[var(--st-fg3)]"}
                    />
                    <span className="font-medium">{c.label}</span>
                    <span className="flex-1 truncate text-[12px] text-[var(--st-fg3)]">
                      {c.hint}
                    </span>
                    {i === active ? (
                      <CornerDownLeft size={13} className="text-[var(--st-fg3)]" />
                    ) : null}
                  </button>
                </div>
              );
            })
          )}
        </div>
        <div className="flex items-center gap-4 border-t border-[var(--st-border)] bg-[var(--st-side)] px-4 py-2 text-[11.5px] text-[var(--st-fg3)]">
          <span>↑↓ to move</span>
          <span>↵ to open</span>
          <span className="ml-auto">{results.length} results</span>
        </div>
      </div>
    </div>
  );
}

function AboutDialog({ onClose }: { onClose: () => void }) {
  const ok = useRef<HTMLButtonElement>(null);
  useEffect(() => ok.current?.focus(), []);
  return (
    <div
      className="absolute inset-0 z-50 grid place-items-center bg-black/25 backdrop-blur-[1px]"
      onMouseDown={(e) => {
        if (e.target === e.currentTarget) onClose();
      }}
      onKeyDown={(e) => {
        if (e.key === "Escape") {
          e.preventDefault();
          onClose();
        }
      }}
    >
      <div
        role="dialog"
        aria-label="About Macarchy"
        className="w-[300px] rounded-[12px] border border-[var(--st-border)] bg-[var(--st-bg)] px-6 pt-7 pb-5 text-center shadow-[0_24px_60px_-12px_rgba(0,0,0,0.35)]"
      >
        <div className="mb-3 flex justify-center">
          <AppIcon size={56} />
        </div>
        <div className="text-[15px] font-semibold tracking-[-0.01em] text-[var(--st-fg)]">
          Macarchy
        </div>
        <div className="mt-0.5 text-[12.5px] text-[var(--st-fg2)]">Version {version}</div>
        <button
          ref={ok}
          type="button"
          onClick={onClose}
          className="mt-5 h-8 w-full rounded-[7px] border border-[var(--st-border)] bg-[var(--st-bg)] text-[13px] font-medium text-[var(--st-fg)] shadow-[var(--st-shadow)] hover:bg-[var(--st-hover)] focus-visible:ring-2 focus-visible:ring-[var(--st-accent)] focus-visible:outline-none"
        >
          Done
        </button>
      </div>
    </div>
  );
}

/* ------------------------------------------------------------------ */
/* Window                                                              */
/* ------------------------------------------------------------------ */

function systemAppearance(): Appearance {
  return typeof window !== "undefined" &&
    window.matchMedia?.("(prefers-color-scheme: dark)").matches
    ? "dark"
    : "light";
}

export default function Studio({ appearance, onAppearanceChange }: OptionProps) {
  const [history, setHistory] = useState<{ stack: Route[]; at: number }>({
    stack: ["home"],
    at: 0,
  });
  const pane = history.stack[history.at] ?? "home";
  const [lastSeen, setLastSeen] = useState("0.8.4");
  const markSeen = useCallback(() => setLastSeen(latestVersion), []);
  const fresh = isNewer(latestVersion, lastSeen);
  const [cardDismissed, setCardDismissed] = useState(false);
  const canBack = history.at > 0;
  const canForward = history.at < history.stack.length - 1;
  const [collapsed, setCollapsed] = useState(false);
  const [palette, setPalette] = useState(false);
  const [actionsSlot, setActionsSlot] = useState<HTMLElement | null>(null);
  const [pageSearch, setPageSearch] = useState<PageSearch | null>(null);
  const chrome = useMemo(() => ({ actionsSlot, setSearch: setPageSearch }), [actionsSlot]);
  const [about, setAbout] = useState(false);
  const [logsOpen, setLogsOpen] = useState(false);
  const [logs, setLogs] = useState<LogLine[]>(() =>
    seedLogs.map(([time, source, level, text], id) => ({ id, time, source, level, text })),
  );
  const logId = useRef(seedLogs.length);
  const [toast, setToast] = useState<string | null>(null);
  const [chosen, setChosen] = useState<AppearanceMode>(() =>
    appearance === systemAppearance() ? "system" : appearance,
  );
  const [root, setRoot] = useState<HTMLDivElement | null>(null);
  const main = useRef<HTMLElement>(null);
  const logsButton = useRef<HTMLButtonElement>(null);
  const logsPanel = useRef<HTMLDivElement>(null);

  // A choice only stays checked while it still matches what the gallery shows.
  const mode: AppearanceMode =
    chosen === "system"
      ? appearance === systemAppearance()
        ? "system"
        : appearance
      : chosen === appearance
        ? chosen
        : appearance;

  const go = (id: Route) =>
    setHistory((h) => {
      if (h.stack[h.at] === id) return h;
      const stack = [...h.stack.slice(0, h.at + 1), id];
      return { stack, at: stack.length - 1 };
    });
  const back = () => setHistory((h) => (h.at > 0 ? { ...h, at: h.at - 1 } : h));
  const forward = () => setHistory((h) => (h.at < h.stack.length - 1 ? { ...h, at: h.at + 1 } : h));

  const setMode = (m: AppearanceMode) => {
    setChosen(m);
    onAppearanceChange?.(m === "system" ? systemAppearance() : m);
  };

  const log = (entries: [LogSource, LogLevel, string][]) =>
    setLogs((prev) => [
      ...prev,
      ...entries.map(([source, level, text]) => ({
        id: logId.current++,
        time: now(),
        source,
        level,
        text,
      })),
    ]);

  const closeLogs = () => {
    if (logsPanel.current?.contains(document.activeElement)) logsButton.current?.focus();
    setLogsOpen(false);
  };

  const copyLogs = (text: string, count: number) => {
    const done = () => setToast(`Copied ${count} ${count === 1 ? "line" : "lines"}`);
    if (navigator.clipboard) navigator.clipboard.writeText(text).then(done, done);
    else done();
  };

  const action = (a: MenuAction) => {
    switch (a) {
      case "updates":
        log([["macarchy", "info", `Checked for updates: ${version} is the latest version`]]);
        return setToast("Macarchy is up to date");
      case "folder":
        return setToast("Opened ~/.config/macarchy in Finder");
      case "reload":
        log([
          ["macarchy", "info", "$ macarchy reload --all"],
          ["aerospace", "info", "$ aerospace reload-config"],
          ["sketchybar", "info", "$ sketchybar --reload"],
          ["borders", "info", bordersCommand],
          ["macarchy", "warn", "skhd is not running, skipped"],
        ]);
        return setToast("AeroSpace, SketchyBar and JankyBorders reloaded");
      case "logs":
        return setLogsOpen(true);
      case "shortcuts":
        return go("shortcuts");
      case "changelog":
        return go("changelog");
      case "about":
        return setAbout(true);
      case "quit":
        return setToast("Quit is disabled in this preview");
    }
  };

  // Keep the latest handlers for the window-level shortcuts without re-binding.
  const keys = useRef({ back, forward, go, action, log, closeLogs, overlay: false, logsOpen });
  keys.current = { back, forward, go, action, log, closeLogs, overlay: palette || about, logsOpen };

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (e.key === "Escape") {
        if (!e.defaultPrevented && !keys.current.overlay && keys.current.logsOpen) {
          e.preventDefault();
          keys.current.closeLogs();
        }
        return;
      }
      if (!(e.metaKey || e.ctrlKey)) return;
      const k = e.key.toLowerCase();
      const run = (f: () => void) => {
        e.preventDefault();
        f();
      };
      if (k === "k" && !e.shiftKey) run(() => setPalette((open) => !open));
      else if (k === "\\") run(() => setCollapsed((c) => !c));
      else if (k === "[") run(() => keys.current.back());
      else if (k === "]") run(() => keys.current.forward());
      else if (k === "/") run(() => keys.current.go("shortcuts"));
      else if (k === "r" && e.shiftKey) run(() => keys.current.action("reload"));
      else if (k === "o" && e.shiftKey) run(() => keys.current.action("folder"));
      else if (k === "l" && e.shiftKey)
        run(() => (keys.current.logsOpen ? keys.current.closeLogs() : setLogsOpen(true)));
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, []);

  useEffect(() => {
    if (!toast) return;
    const t = setTimeout(() => setToast(null), 2200);
    return () => clearTimeout(t);
  }, [toast]);

  useEffect(() => {
    main.current?.scrollTo({ top: 0 });
  }, [history]);

  const commands = useMemo<Command[]>(() => {
    const all: MockPaneId[] = [...overview, ...groups.flatMap((g) => g.panes)];
    return [
      ...all.map((id) => ({
        id: `go-${id}`,
        label: panes[id].title,
        hint: groupOf(id) ?? "Overview",
        icon: panes[id].icon,
        section: "Go to" as const,
        run: () => keys.current.go(id),
      })),
      {
        id: "go-changelog",
        label: "Changelog",
        hint: version,
        icon: Sparkles,
        section: "Go to" as const,
        run: () => keys.current.go("changelog"),
      },
      {
        id: "sidebar",
        label: "Toggle sidebar",
        hint: "⌘\\",
        icon: PanelLeft,
        section: "Actions",
        run: () => setCollapsed((c) => !c),
      },
      {
        id: "logs",
        label: "Show logs",
        hint: "⇧⌘L",
        icon: ScrollText,
        section: "Actions",
        run: () => setLogsOpen(true),
      },
      {
        id: "restart",
        label: "Restart AeroSpace",
        hint: "",
        icon: RotateCw,
        section: "Actions",
        run: () => {
          keys.current.log([
            ["aerospace", "info", "$ aerospace reload-config"],
            ["aerospace", "info", "Config reloaded: 6 workspaces"],
          ]);
          setToast("AeroSpace restarted");
        },
      },
      {
        id: "reload-bar",
        label: "Reload menu bar",
        hint: "SketchyBar",
        icon: Zap,
        section: "Actions",
        run: () => {
          keys.current.log([
            ["sketchybar", "info", "$ sketchybar --reload"],
            [
              "sketchybar",
              "info",
              `Loaded ${visibleBarItems} items from ~/.config/sketchybar/items`,
            ],
          ]);
          setToast("Menu bar reloaded");
        },
      },
      {
        id: "theme",
        label: "Switch theme",
        hint: "",
        icon: Moon,
        section: "Actions",
        run: () => keys.current.go("themes"),
      },
      {
        id: "folder",
        label: "Open config folder",
        hint: "~/.config/macarchy",
        icon: FolderOpen,
        section: "Actions",
        run: () => keys.current.action("folder"),
      },
      {
        id: "fix",
        label: "Fix setup issues",
        hint: `${issues} to fix`,
        icon: ArrowRight,
        section: "Actions",
        run: () => keys.current.go("health"),
      },
    ];
  }, []);

  const page = (() => {
    switch (pane) {
      case "home":
        return <HomePage go={go} />;
      case "themes":
        return <ThemesPage go={go} />;
      case "borders":
        return <BordersPage />;
      case "layout":
        return <LayoutPage />;
      case "rules":
        return <RulesPage />;
      case "shortcuts":
        return <ShortcutsPage />;
      case "health":
        return <HealthPage />;
      case "workshop":
        return <WorkshopPage />;
      case "plugins":
        return <PluginsPage />;
      case "menuBar":
        return <MenuBarPage />;
      case "advanced":
        return <AdvancedPage />;
      case "report":
        return <ReportPage />;
      case "changelog":
        return <ChangelogPage lastSeen={lastSeen} onSeen={markSeen} />;
    }
  })();
  const isPreview = previews.some((p) => p === pane);

  const group = groupOf(pane);
  const logProblems = logs.some((l) => l.level === "error")
    ? "error"
    : logs.some((l) => l.level === "warn")
      ? "warn"
      : null;

  return (
    <div
      ref={setRoot}
      data-studio-window
      style={{ ...tokens(appearance), ...shellTokens(appearance) }}
      className="relative mx-auto flex h-[760px] w-[1180px] flex-col overflow-hidden rounded-[12px] bg-[var(--st-bg)] text-[var(--st-fg)] antialiased shadow-[var(--st-window-shadow)]"
    >
      <style>{`@keyframes st-tip-in { from { opacity: 0; } to { opacity: 1; } }`}</style>
      <WindowRoot value={root}>
        <div className="relative z-30 flex h-12 shrink-0">
          {/* Sidebar title bar. When collapsed the controls overflow into the start of the top bar. */}
          <div
            className={cx(
              "relative z-10 shrink-0 border-r border-b transition-[width,background-color,border-color] duration-200 ease-out",
              collapsed
                ? "border-r-transparent border-b-[var(--st-border)] bg-[var(--st-bg)]"
                : "border-r-[var(--st-border)] border-b-transparent bg-[var(--st-side)]",
            )}
            style={{ width: collapsed ? railWidth : 232 }}
          >
            <div
              className={cx(
                "absolute inset-y-0 left-0 flex items-center gap-3 pr-2.5 pl-4 transition-[width] duration-200 ease-out",
                collapsed ? "w-[176px]" : "w-[232px]",
              )}
            >
              <TrafficLights />
              <div className="ml-auto flex items-center gap-0.5">
                <IconButton
                  label={collapsed ? "Show sidebar" : "Hide sidebar"}
                  keys="⌘\"
                  pressed={!collapsed}
                  onClick={() => setCollapsed((c) => !c)}
                >
                  <PanelLeft size={15} strokeWidth={1.75} />
                </IconButton>
                <IconButton label="Back" keys="⌘[" onClick={back} disabled={!canBack}>
                  <ChevronLeft size={16} strokeWidth={1.75} />
                </IconButton>
                <IconButton label="Forward" keys="⌘]" onClick={forward} disabled={!canForward}>
                  <ChevronRight size={16} strokeWidth={1.75} />
                </IconButton>
              </div>
            </div>
          </div>

          {/* Main top bar, laid out on the same column as the page content. */}
          <header className="min-w-0 flex-1 border-b border-[var(--st-border)] bg-[var(--st-bg)]">
            <div className="mx-auto flex h-full max-w-[900px] items-center gap-[16px] px-8">
              <nav
                aria-label="Breadcrumb"
                className="flex min-w-0 flex-1 basis-0 items-center gap-1.5 text-[13px]"
              >
                {group ? (
                  <>
                    <span className="truncate text-[var(--st-fg3)]">{group}</span>
                    <ChevronRight size={13} className="shrink-0 text-[var(--st-fg3)]" />
                  </>
                ) : null}
                <span aria-current="page" className="truncate font-medium text-[var(--st-fg)]">
                  {titleOf(pane)}
                </span>
                {isPreview ? <PreviewTag size="md" /> : null}
              </nav>
              {pageSearch ? (
                <label className="flex h-8 w-[280px] items-center gap-2 rounded-[7px] border border-[var(--st-border)] bg-[var(--st-side)] px-2.5 text-[13px] text-[var(--st-fg3)] transition-colors focus-within:border-[var(--st-accent)] focus-within:ring-[3px] focus-within:ring-[var(--st-accent-soft)] hover:border-[var(--st-border-strong)]">
                  <Search size={14} className="shrink-0" />
                  <input
                    value={pageSearch.value}
                    onChange={(e) => pageSearch.onChange(e.target.value)}
                    onKeyDown={(e) => {
                      if (e.key === "Escape") pageSearch.onChange("");
                    }}
                    placeholder={pageSearch.placeholder}
                    className="min-w-0 flex-1 bg-transparent text-[var(--st-fg)] outline-none placeholder:text-[var(--st-fg3)]"
                  />
                  {pageSearch.value ? (
                    <button
                      type="button"
                      aria-label="Clear search"
                      onClick={() => pageSearch.onChange("")}
                      className="grid size-[18px] place-items-center rounded-full text-[var(--st-fg3)] hover:bg-[var(--st-hover)] hover:text-[var(--st-fg)]"
                    >
                      <X size={11} />
                    </button>
                  ) : (
                    <button
                      type="button"
                      onClick={() => setPalette(true)}
                      title="Search all settings"
                      className="rounded-[4px] border border-[var(--st-border)] bg-[var(--st-bg)] px-1.5 text-[11px] font-medium text-[var(--st-fg2)] hover:text-[var(--st-fg)]"
                    >
                      ⌘K
                    </button>
                  )}
                </label>
              ) : (
                <button
                  type="button"
                  onClick={() => setPalette(true)}
                  className="flex h-8 w-[280px] items-center gap-2 rounded-[7px] border border-[var(--st-border)] bg-[var(--st-side)] px-2.5 text-[13px] text-[var(--st-fg3)] transition-colors hover:border-[var(--st-border-strong)] hover:text-[var(--st-fg2)] focus-visible:ring-2 focus-visible:ring-[var(--st-accent)] focus-visible:outline-none"
                >
                  <Search size={14} />
                  <span className="flex-1 text-left">Search settings...</span>
                  <span className="rounded-[4px] border border-[var(--st-border)] bg-[var(--st-bg)] px-1.5 text-[11px] font-medium text-[var(--st-fg2)]">
                    ⌘K
                  </span>
                </button>
              )}
              <div className="flex flex-1 basis-0 items-center justify-end gap-[6px] whitespace-nowrap">
                <ServiceStatus
                  log={log}
                  notify={setToast}
                  onHealth={() => go("health")}
                  onLogs={() => setLogsOpen(true)}
                />
                <div ref={setActionsSlot} className="contents" />
                <Tip label={logsOpen ? "Hide logs" : "Show logs"} keys="⇧⌘L">
                  <button
                    ref={logsButton}
                    type="button"
                    aria-pressed={logsOpen}
                    onClick={() => (logsOpen ? closeLogs() : setLogsOpen(true))}
                    className={cx(
                      "relative flex h-8 items-center gap-1.5 rounded-[7px] px-2.5 text-[13px] font-medium transition-colors focus-visible:ring-2 focus-visible:ring-[var(--st-accent)] focus-visible:outline-none",
                      logsOpen
                        ? "bg-[var(--st-muted)] text-[var(--st-fg)] ring-1 ring-[var(--st-border)]"
                        : "text-[var(--st-fg2)] hover:bg-[var(--st-hover)] hover:text-[var(--st-fg)]",
                    )}
                  >
                    <ScrollText size={14} strokeWidth={1.75} />
                    Logs
                    {logProblems ? (
                      <span
                        className={cx(
                          "size-1.5 rounded-full",
                          logProblems === "error" ? "bg-[var(--st-err)]" : "bg-[var(--st-warn)]",
                        )}
                      />
                    ) : null}
                  </button>
                </Tip>
              </div>
            </div>
          </header>
        </div>

        <div className="flex min-h-0 flex-1">
          {/*
          Rail elements centre on x = 28 of the 56px content box: the brand, nav items and footer
          share an 8px inset and are 40px wide when collapsed. Paddings are fixed in both states
          so icons never move.
        */}
          <aside
            className="relative z-20 flex shrink-0 flex-col border-r border-[var(--st-border)] bg-[var(--st-side)] transition-[width] duration-200 ease-out"
            style={{ width: collapsed ? railWidth : 232 }}
          >
            <div
              className={cx(
                "px-[8px] pb-2 transition-[padding] duration-200 ease-out",
                collapsed ? "pt-2.5" : "pt-0.5",
              )}
            >
              <BrandMenu
                collapsed={collapsed}
                fresh={fresh}
                mode={mode}
                onMode={setMode}
                onAction={action}
              />
            </div>
            <nav
              aria-label="Settings"
              className="flex-1 overflow-x-hidden overflow-y-auto px-[8px] pt-[4px] pb-[4px]"
            >
              <div className="flex flex-col gap-[2px]">
                {overview.map((id) => (
                  <NavItem
                    key={id}
                    id={id}
                    active={pane === id}
                    collapsed={collapsed}
                    onSelect={go}
                  />
                ))}
              </div>
              {groups.map((g) => (
                <div key={g.title} className="mt-[4px]">
                  <div className="relative h-7">
                    <div
                      className={cx(
                        "absolute bottom-1 left-[12.5px] text-[11px] font-medium tracking-[0.01em] whitespace-nowrap text-[var(--st-fg3)] transition-opacity duration-150",
                        collapsed ? "opacity-0" : "opacity-100",
                      )}
                    >
                      {g.title}
                    </div>
                    <div
                      aria-hidden
                      className={cx(
                        "absolute top-[10px] left-[10px] h-px w-5 bg-[var(--st-border-strong)] transition-opacity duration-150",
                        collapsed ? "opacity-100" : "opacity-0",
                      )}
                    />
                  </div>
                  <div className="flex flex-col gap-[2px]">
                    {g.panes.map((id) => (
                      <NavItem
                        key={id}
                        id={id}
                        active={pane === id}
                        collapsed={collapsed}
                        onSelect={go}
                      />
                    ))}
                  </div>
                </div>
              ))}
            </nav>
            <ReleaseCard
              visible={!collapsed && !cardDismissed}
              fresh={fresh}
              onOpen={() => go("changelog")}
              onDismiss={() => setCardDismissed(true)}
            />
            <div className="border-t border-[var(--st-border)] px-[8px] py-3">
              <Tip
                label={fresh ? `What's new in ${version}` : `Version ${version}, up to date`}
                side="right"
                disabled={!collapsed}
                className="flex"
              >
                <button
                  type="button"
                  onClick={() => go("changelog")}
                  aria-label={collapsed ? `Version ${version}, open the changelog` : undefined}
                  className={cx(
                    "flex h-[18px] items-center gap-2 overflow-hidden rounded-[5px] pl-[17px] text-left text-[12px] whitespace-nowrap text-[var(--st-fg2)] transition-[width,color] duration-200 ease-out hover:text-[var(--st-fg)] focus-visible:ring-2 focus-visible:ring-[var(--st-accent)] focus-visible:outline-none",
                    collapsed ? "w-[40px]" : "w-full",
                  )}
                >
                  <span className="relative size-1.5 shrink-0 rounded-full bg-[var(--st-ok)]">
                    <Sparkles
                      aria-hidden
                      size={9}
                      strokeWidth={2.25}
                      className={cx(
                        "absolute -top-[7px] -right-[8px] text-[var(--st-accent)] transition-opacity duration-150",
                        fresh && collapsed ? "opacity-100" : "opacity-0",
                      )}
                    />
                  </span>
                  <span
                    className={cx(
                      "flex min-w-0 flex-1 items-center gap-2 transition-opacity duration-150",
                      collapsed ? "opacity-0" : "opacity-100",
                    )}
                  >
                    <span className="flex-1 truncate">Version {version}, up to date</span>
                    {fresh && cardDismissed ? (
                      <span className="mr-[8px] size-[6px] shrink-0 rounded-full bg-[var(--st-accent)]">
                        <span className="sr-only">, what's new</span>
                      </span>
                    ) : null}
                  </span>
                </button>
              </Tip>
            </div>
          </aside>

          <div className="flex min-w-0 flex-1 flex-col">
            <main ref={main} className="min-h-0 flex-1 overflow-y-auto bg-[var(--st-bg)]">
              <div className="mx-auto max-w-[900px] px-8 pt-7 pb-10" key={`${history.at}-${pane}`}>
                <PageChromeContext value={chrome}>{page}</PageChromeContext>
              </div>
            </main>
            <div ref={logsPanel}>
              <LogsPanel
                open={logsOpen}
                lines={logs}
                onClear={() => setLogs([])}
                onCopy={copyLogs}
                onClose={closeLogs}
              />
            </div>
          </div>
        </div>

        {palette ? <CommandPalette commands={commands} onClose={() => setPalette(false)} /> : null}
        {about ? <AboutDialog onClose={() => setAbout(false)} /> : null}
        {toast ? (
          <div
            role="status"
            className="absolute left-1/2 z-40 flex -translate-x-1/2 items-center gap-2 rounded-[8px] border border-[var(--st-border)] bg-[var(--st-bg)] px-3.5 py-2 text-[13px] text-[var(--st-fg)] shadow-[0_12px_30px_-8px_rgba(0,0,0,0.3)] transition-[bottom] duration-200"
            style={{ bottom: logsOpen ? logsHeight + 20 : 20 }}
          >
            <span className="size-1.5 rounded-full bg-[var(--st-ok)]" />
            {toast}
          </div>
        ) : null}
      </WindowRoot>
    </div>
  );
}
