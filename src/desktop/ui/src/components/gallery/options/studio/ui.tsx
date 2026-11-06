import { Minus, Plus } from "lucide-react";
import {
  type CSSProperties,
  type ReactNode,
  createContext,
  useContext,
  useEffect,
  useRef,
  useState,
} from "react";
import { createPortal } from "react-dom";

import type { Appearance } from "../data";

/** Zinc palette with a sparing indigo accent, defined per appearance. */
export function tokens(appearance: Appearance): CSSProperties {
  const light = {
    "--st-bg": "#ffffff",
    "--st-side": "#fafafa",
    "--st-muted": "#f4f4f5",
    "--st-hover": "#f4f4f5",
    "--st-border": "#e4e4e7",
    "--st-border-strong": "#d4d4d8",
    "--st-fg": "#09090b",
    "--st-fg2": "#52525b",
    "--st-fg3": "#a1a1aa",
    "--st-accent": "#6366f1",
    "--st-accent-fg": "#ffffff",
    "--st-accent-soft": "rgba(99,102,241,0.10)",
    "--st-accent-text": "#4f46e5",
    "--st-ok": "#16a34a",
    "--st-ok-soft": "rgba(22,163,74,0.10)",
    "--st-warn": "#d97706",
    "--st-warn-soft": "rgba(217,119,6,0.10)",
    "--st-primary": "#18181b",
    "--st-primary-fg": "#fafafa",
    "--st-shadow": "0 1px 2px rgba(9,9,11,0.05), 0 1px 1px rgba(9,9,11,0.03)",
    "--st-window-shadow": "0 30px 80px -20px rgba(9,9,11,0.25), 0 0 0 1px rgba(9,9,11,0.08)",
    "--st-canvas": "#f4f4f5",
  };
  const dark = {
    "--st-bg": "#09090b",
    "--st-side": "#0c0c0e",
    "--st-muted": "#18181b",
    "--st-hover": "#18181b",
    "--st-border": "#232327",
    "--st-border-strong": "#2f2f35",
    "--st-fg": "#fafafa",
    "--st-fg2": "#a1a1aa",
    "--st-fg3": "#71717a",
    "--st-accent": "#818cf8",
    "--st-accent-fg": "#0b0b14",
    "--st-accent-soft": "rgba(129,140,248,0.14)",
    "--st-accent-text": "#a5b4fc",
    "--st-ok": "#4ade80",
    "--st-ok-soft": "rgba(74,222,128,0.12)",
    "--st-warn": "#fbbf24",
    "--st-warn-soft": "rgba(251,191,36,0.12)",
    "--st-primary": "#fafafa",
    "--st-primary-fg": "#09090b",
    "--st-shadow": "0 1px 2px rgba(0,0,0,0.4)",
    "--st-window-shadow": "0 30px 80px -20px rgba(0,0,0,0.7), 0 0 0 1px rgba(255,255,255,0.07)",
    "--st-canvas": "#111113",
  };
  return {
    ...(appearance === "dark" ? dark : light),
    colorScheme: appearance,
    fontFamily: 'Inter, "SF Pro Text", ui-sans-serif, system-ui, -apple-system, sans-serif',
    fontFeatureSettings: '"cv11", "ss01"',
  } as CSSProperties;
}

export function cx(...parts: (string | false | null | undefined)[]) {
  return parts.filter(Boolean).join(" ");
}

/** Keyboard focus ring shared by every interactive primitive. */
export const focusRing =
  "outline-none focus-visible:ring-2 focus-visible:ring-[var(--st-accent)] focus-visible:ring-offset-2 focus-visible:ring-offset-[var(--st-bg)]";

/** A page's live filter, drawn as the top bar's search field while the page is open. */
export interface PageSearch {
  placeholder: string;
  value: string;
  onChange: (value: string) => void;
}

/**
 * How a page reaches the window's top bar: an element its actions are portalled into,
 * and a setter that turns the top bar's search field into the page's own filter.
 */
export interface PageChrome {
  actionsSlot: HTMLElement | null;
  setSearch: (search: PageSearch | null) => void;
}

export const PageChromeContext = createContext<PageChrome>({
  actionsSlot: null,
  setSearch: () => {},
});

/**
 * A search query for the current page, typed into the top bar's search field rather than
 * a field of the page's own. ⌘K still opens the command palette.
 */
export function usePageSearch(placeholder: string): [string, (value: string) => void] {
  const [value, setValue] = useState("");
  const { setSearch } = useContext(PageChromeContext);
  useEffect(() => {
    setSearch({ placeholder, value, onChange: setValue });
  }, [placeholder, value, setSearch]);
  useEffect(() => () => setSearch(null), [setSearch]);
  return [value, setValue];
}

/** Renders a page's actions in the top bar, beside Logs, instead of a row on the page. */
export function TopBarActions({ children }: { children: ReactNode }) {
  const { actionsSlot } = useContext(PageChromeContext);
  if (!actionsSlot) return null;
  return createPortal(<div className="flex items-center gap-[6px]">{children}</div>, actionsSlot);
}

/**
 * The page's title for screen readers; the breadcrumb and sidebar already name the page,
 * so nothing is drawn. Actions go to the top bar.
 */
export function PageHeader({
  title,
  actions,
}: {
  title: string;
  /** Not shown: the breadcrumb and sidebar already say what the page is. */
  description?: string;
  actions?: ReactNode;
}) {
  return (
    <>
      <h1 className="sr-only">{title}</h1>
      {actions ? <TopBarActions>{actions}</TopBarActions> : null}
    </>
  );
}

export function Card({ children, className }: { children: ReactNode; className?: string }) {
  return (
    <section
      className={cx(
        "rounded-[10px] border border-[var(--st-border)] bg-[var(--st-bg)] shadow-[var(--st-shadow)]",
        className,
      )}
    >
      {children}
    </section>
  );
}

export function CardHeader({
  title,
  description,
  action,
}: {
  title: string;
  description?: string;
  action?: ReactNode;
}) {
  return (
    <header className="flex items-start justify-between gap-3 px-5 pt-4 pb-3">
      <div>
        <h2 className="text-[14px] font-semibold tracking-[-0.01em] text-[var(--st-fg)]">
          {title}
        </h2>
        {description ? (
          <p className="mt-0.5 text-[12.5px] text-[var(--st-fg2)]">{description}</p>
        ) : null}
      </div>
      {action}
    </header>
  );
}

export function Row({
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
        "flex items-center justify-between gap-6 px-5 py-3.5",
        !last && "border-b border-[var(--st-border)]",
      )}
    >
      <div className="min-w-0">
        <div className="text-[13px] font-medium text-[var(--st-fg)]">{label}</div>
        {hint ? <div className="mt-0.5 text-[12px] text-[var(--st-fg2)]">{hint}</div> : null}
      </div>
      <div className="shrink-0">{children}</div>
    </div>
  );
}

export function Button({
  children,
  variant = "outline",
  size = "md",
  onClick,
  className,
  disabled,
  title,
}: {
  children: ReactNode;
  variant?: "outline" | "primary" | "ghost" | "accent";
  size?: "sm" | "md";
  onClick?: () => void;
  className?: string;
  disabled?: boolean;
  title?: string;
}) {
  const styles = {
    outline:
      "border border-[var(--st-border)] bg-[var(--st-bg)] text-[var(--st-fg)] shadow-[var(--st-shadow)] hover:bg-[var(--st-hover)]",
    primary:
      "bg-[var(--st-primary)] text-[var(--st-primary-fg)] shadow-[var(--st-shadow)] hover:opacity-90",
    accent:
      "bg-[var(--st-accent)] text-[var(--st-accent-fg)] shadow-[var(--st-shadow)] hover:opacity-90",
    ghost: "text-[var(--st-fg2)] hover:bg-[var(--st-hover)] hover:text-[var(--st-fg)]",
  }[variant];
  return (
    <button
      type="button"
      onClick={onClick}
      disabled={disabled}
      title={title}
      className={cx(
        "inline-flex items-center justify-center gap-1.5 rounded-[7px] font-medium tracking-[-0.01em] whitespace-nowrap transition-[background-color,opacity,box-shadow,transform] duration-150 active:translate-y-px disabled:pointer-events-none disabled:opacity-50",
        focusRing,
        size === "sm" ? "h-7 px-2.5 text-[12px]" : "h-8 px-3 text-[13px]",
        styles,
        className,
      )}
    >
      {children}
    </button>
  );
}

export function Switch({
  checked,
  onChange,
  label,
  disabled,
}: {
  checked: boolean;
  onChange: (v: boolean) => void;
  label?: string;
  disabled?: boolean;
}) {
  return (
    <button
      type="button"
      role="switch"
      aria-checked={checked}
      aria-label={label}
      disabled={disabled}
      onClick={() => onChange(!checked)}
      className={cx(
        "relative inline-flex h-[20px] w-[34px] shrink-0 items-center rounded-full transition-colors duration-150 disabled:opacity-50",
        focusRing,
        checked ? "bg-[var(--st-primary)]" : "bg-[var(--st-border-strong)]",
      )}
    >
      <span
        className={cx(
          "inline-block size-4 rounded-full bg-[var(--st-bg)] shadow-[0_1px_2px_rgba(0,0,0,0.25)] transition-transform duration-150 ease-out",
          checked ? "translate-x-[16px]" : "translate-x-[2px]",
        )}
        style={checked ? { background: "var(--st-primary-fg)" } : { background: "#ffffff" }}
      />
    </button>
  );
}

export function Segmented<T extends string>({
  options,
  value,
  onChange,
  size = "md",
}: {
  options: readonly T[];
  value: T;
  onChange: (v: T) => void;
  size?: "sm" | "md";
}) {
  return (
    <div
      role="radiogroup"
      className="inline-flex rounded-[8px] bg-[var(--st-muted)] p-[3px] ring-1 ring-inset ring-[var(--st-border)]/60"
    >
      {options.map((o) => (
        <button
          key={o}
          type="button"
          role="radio"
          aria-checked={o === value}
          onClick={() => onChange(o)}
          className={cx(
            "rounded-[6px] font-medium transition-[color,background-color,box-shadow] duration-150",
            size === "sm" ? "h-[22px] px-2.5 text-[12px]" : "h-[26px] px-3 text-[12.5px]",
            focusRing,
            o === value
              ? "bg-[var(--st-bg)] text-[var(--st-fg)] shadow-[var(--st-shadow)] ring-1 ring-[var(--st-border)]"
              : "text-[var(--st-fg2)] hover:text-[var(--st-fg)]",
          )}
        >
          {o}
        </button>
      ))}
    </div>
  );
}

export function Slider({
  value,
  min,
  max,
  onChange,
  unit = "px",
  width = 180,
  label,
}: {
  value: number;
  min: number;
  max: number;
  onChange: (v: number) => void;
  unit?: string;
  width?: number;
  label?: string;
}) {
  const pct = ((value - min) / (max - min)) * 100;
  return (
    <div className="flex items-center gap-3">
      <div className="group relative h-5" style={{ width }}>
        <div className="absolute top-1/2 h-[5px] w-full -translate-y-1/2 rounded-full bg-[var(--st-muted)] ring-1 ring-inset ring-[var(--st-border)]" />
        <div
          className="absolute top-1/2 h-[5px] -translate-y-1/2 rounded-full bg-[var(--st-accent)]"
          style={{ width: `${pct}%` }}
        />
        <div
          className="pointer-events-none absolute top-1/2 size-[15px] -translate-x-1/2 -translate-y-1/2 rounded-full border border-[var(--st-border-strong)] bg-white shadow-[0_1px_3px_rgba(0,0,0,0.2)] transition-shadow group-hover:shadow-[0_0_0_4px_var(--st-accent-soft),0_1px_3px_rgba(0,0,0,0.2)] group-has-[:focus-visible]:shadow-[0_0_0_4px_var(--st-accent-soft),0_0_0_1.5px_var(--st-accent)]"
          style={{ left: `${pct}%` }}
        />
        <input
          type="range"
          min={min}
          max={max}
          value={value}
          aria-label={label}
          onChange={(e) => onChange(Number(e.target.value))}
          className="absolute inset-0 w-full cursor-pointer opacity-0 outline-none"
        />
      </div>
      <span className="w-11 rounded-[6px] border border-[var(--st-border)] bg-[var(--st-side)] py-0.5 text-center font-mono text-[11.5px] tabular-nums text-[var(--st-fg)]">
        {value}
        {unit}
      </span>
    </div>
  );
}

type Tone = "neutral" | "ok" | "warn" | "accent";
export function Badge({
  children,
  tone = "neutral",
  dot,
}: {
  children: ReactNode;
  tone?: Tone;
  dot?: boolean;
}) {
  const styles: Record<Tone, string> = {
    neutral: "border-[var(--st-border)] text-[var(--st-fg2)]",
    ok: "border-transparent bg-[var(--st-ok-soft)] text-[var(--st-ok)]",
    warn: "border-transparent bg-[var(--st-warn-soft)] text-[var(--st-warn)]",
    accent: "border-transparent bg-[var(--st-accent-soft)] text-[var(--st-accent-text)]",
  };
  const dotColour: Record<Tone, string> = {
    neutral: "bg-[var(--st-fg3)]",
    ok: "bg-[var(--st-ok)]",
    warn: "bg-[var(--st-warn)]",
    accent: "bg-[var(--st-accent)]",
  };
  return (
    <span
      className={cx(
        "inline-flex h-[21px] items-center gap-1.5 rounded-[6px] border px-2 text-[11.5px] font-medium whitespace-nowrap",
        styles[tone],
      )}
    >
      {dot ? <span className={cx("size-1.5 rounded-full", dotColour[tone])} /> : null}
      {children}
    </span>
  );
}

export function Kbd({ children }: { children: ReactNode }) {
  return (
    <kbd className="inline-flex h-[22px] min-w-[22px] items-center justify-center rounded-[5px] border border-[var(--st-border)] border-b-[var(--st-border-strong)] bg-[var(--st-side)] px-1.5 font-sans text-[11.5px] font-medium text-[var(--st-fg2)] shadow-[0_1px_0_var(--st-border)]">
      {children}
    </kbd>
  );
}

export function Tabs<T extends string>({
  tabs,
  value,
  onChange,
}: {
  tabs: readonly { id: T; label: string; count?: number }[];
  value: T;
  onChange: (v: T) => void;
}) {
  return (
    <div className="mb-5 flex gap-5 border-b border-[var(--st-border)]">
      {tabs.map((t) => (
        <button
          key={t.id}
          type="button"
          onClick={() => onChange(t.id)}
          className={cx(
            "relative -mb-px flex items-center gap-1.5 rounded-t-[4px] border-b-2 pb-2.5 text-[13px] font-medium transition-colors",
            focusRing,
            t.id === value
              ? "border-[var(--st-fg)] text-[var(--st-fg)]"
              : "border-transparent text-[var(--st-fg2)] hover:text-[var(--st-fg)]",
          )}
        >
          {t.label}
          {t.count !== undefined ? (
            <span className="rounded-[5px] bg-[var(--st-muted)] px-1.5 text-[11px] tabular-nums text-[var(--st-fg2)]">
              {t.count}
            </span>
          ) : null}
        </button>
      ))}
    </div>
  );
}

/** Page content wrapper; the content always takes the full width. */
export function Annotated({ children, className }: { children: ReactNode; className?: string }) {
  return <div className={className}>{children}</div>;
}

/** Small uppercase label that groups a run of cards or controls. */
export function SectionLabel({ children, action }: { children: ReactNode; action?: ReactNode }) {
  return (
    <div className="mb-2.5 flex items-center justify-between gap-3">
      <h3 className="text-[11.5px] font-semibold tracking-[0.04em] text-[var(--st-fg3)] uppercase">
        {children}
      </h3>
      {action}
    </div>
  );
}

/** Minus / value / plus control for small integer settings. */
export function Stepper({
  value,
  min,
  max,
  onChange,
  label,
}: {
  value: number;
  min: number;
  max: number;
  onChange: (v: number) => void;
  label?: string;
}) {
  const btn = cx(
    "grid h-7 w-7 place-items-center text-[var(--st-fg2)] transition-colors hover:bg-[var(--st-hover)] hover:text-[var(--st-fg)] disabled:opacity-40 disabled:hover:bg-transparent",
    focusRing,
  );
  return (
    <div
      role="group"
      aria-label={label}
      className="inline-flex items-center overflow-hidden rounded-[7px] border border-[var(--st-border)] bg-[var(--st-bg)] shadow-[var(--st-shadow)]"
    >
      <button
        type="button"
        aria-label="Decrease"
        disabled={value <= min}
        onClick={() => onChange(Math.max(min, value - 1))}
        className={btn}
      >
        <Minus size={12} />
      </button>
      <span className="w-8 border-x border-[var(--st-border)] text-center text-[12.5px] leading-7 font-medium tabular-nums text-[var(--st-fg)]">
        {value}
      </span>
      <button
        type="button"
        aria-label="Increase"
        disabled={value >= max}
        onClick={() => onChange(Math.min(max, value + 1))}
        className={btn}
      >
        <Plus size={12} />
      </button>
    </div>
  );
}

const HEX = /^#[0-9a-f]{6}$/i;

/** Swatch plus hex field. Invalid input is flagged and never committed. */
export function ColourField({
  value,
  onChange,
  presets,
  label,
  disabled,
}: {
  value: string;
  onChange: (hex: string) => void;
  presets?: readonly string[];
  label?: string;
  disabled?: boolean;
}) {
  const [draft, setDraft] = useState(value);
  const [seen, setSeen] = useState(value);
  if (seen !== value) {
    setSeen(value);
    setDraft(value);
  }
  const valid = HEX.test(draft);
  return (
    <div
      className={cx(
        "flex flex-wrap items-center gap-3",
        disabled && "pointer-events-none opacity-50",
      )}
    >
      <div
        className={cx(
          "flex h-8 items-center gap-2 rounded-[7px] border bg-[var(--st-bg)] pr-1 pl-1 shadow-[var(--st-shadow)] transition-colors focus-within:border-[var(--st-accent)] focus-within:ring-[3px] focus-within:ring-[var(--st-accent-soft)]",
          valid ? "border-[var(--st-border)]" : "border-[var(--st-warn)]",
        )}
      >
        <label className="relative size-6 shrink-0 cursor-pointer overflow-hidden rounded-[5px] ring-1 ring-inset ring-black/10">
          <span className="absolute inset-0" style={{ background: valid ? draft : value }} />
          <input
            type="color"
            aria-label={label ? `${label} colour picker` : "Colour picker"}
            value={value}
            onChange={(e) => onChange(e.target.value)}
            className="absolute inset-0 cursor-pointer opacity-0"
          />
        </label>
        <input
          aria-label={label ? `${label} hex value` : "Hex value"}
          aria-invalid={!valid}
          spellCheck={false}
          value={draft}
          onChange={(e) => {
            const next = e.target.value.startsWith("#") ? e.target.value : `#${e.target.value}`;
            setDraft(next);
            if (HEX.test(next)) onChange(next.toLowerCase());
          }}
          onBlur={() => setDraft(value)}
          className="w-[72px] bg-transparent font-mono text-[12px] text-[var(--st-fg)] uppercase outline-none"
        />
      </div>
      {presets ? (
        <div className="flex items-center gap-1.5">
          {presets.map((c) => (
            <button
              key={c}
              type="button"
              aria-label={`Use ${c}`}
              onClick={() => onChange(c)}
              className={cx(
                "size-[20px] rounded-full transition-transform hover:scale-110",
                focusRing,
                c.toLowerCase() === value.toLowerCase()
                  ? "ring-2 ring-[var(--st-fg)] ring-offset-2 ring-offset-[var(--st-bg)]"
                  : "ring-1 ring-inset ring-black/15",
              )}
              style={{ background: c }}
            />
          ))}
        </div>
      ) : null}
    </div>
  );
}

/** Calm empty state for filtered lists and first-run views. */
export function EmptyState({
  icon,
  title,
  children,
  action,
}: {
  icon?: ReactNode;
  title: string;
  children?: ReactNode;
  action?: ReactNode;
}) {
  return (
    <div className="flex flex-col items-center justify-center rounded-[10px] border border-dashed border-[var(--st-border-strong)] px-6 py-10 text-center">
      {icon ? (
        <div className="mb-3 grid size-9 place-items-center rounded-[8px] border border-[var(--st-border)] bg-[var(--st-side)] text-[var(--st-fg2)]">
          {icon}
        </div>
      ) : null}
      <div className="text-[13.5px] font-medium text-[var(--st-fg)]">{title}</div>
      {children ? (
        <p className="mt-1 max-w-[320px] text-[12.5px] text-[var(--st-fg2)]">{children}</p>
      ) : null}
      {action ? <div className="mt-4">{action}</div> : null}
    </div>
  );
}

/** Text input styled to match the other controls. */
export function TextInput({
  value,
  onChange,
  placeholder,
  icon,
  className,
  label,
}: {
  value: string;
  onChange: (v: string) => void;
  placeholder?: string;
  icon?: ReactNode;
  className?: string;
  label?: string;
}) {
  return (
    <div
      className={cx(
        "flex h-8 items-center gap-2 rounded-[7px] border border-[var(--st-border)] bg-[var(--st-bg)] px-2.5 shadow-[var(--st-shadow)] transition-colors focus-within:border-[var(--st-accent)] focus-within:ring-[3px] focus-within:ring-[var(--st-accent-soft)]",
        className,
      )}
    >
      {icon ? <span className="shrink-0 text-[var(--st-fg3)]">{icon}</span> : null}
      <input
        aria-label={label ?? placeholder}
        value={value}
        placeholder={placeholder}
        onChange={(e) => onChange(e.target.value)}
        className="min-w-0 flex-1 bg-transparent text-[13px] text-[var(--st-fg)] outline-none placeholder:text-[var(--st-fg3)]"
      />
    </div>
  );
}

/**
 * An image that fills its box with object-cover, falling back to a gradient
 * built from theme colours when the file is missing or fails to load.
 */
export function ImageFill({
  src,
  from,
  to,
  alt = "",
  className,
}: {
  src?: string;
  from: string;
  to: string;
  alt?: string;
  className?: string;
}) {
  const [failed, setFailed] = useState<string | undefined>(undefined);
  const show = src && failed !== src;
  return (
    <div
      className={cx("absolute inset-0 overflow-hidden", className)}
      style={{
        background: `radial-gradient(120% 120% at 20% 0%, color-mix(in srgb, ${to} 55%, ${from}) 0%, ${from} 70%)`,
      }}
    >
      {show ? (
        <img
          src={src}
          alt={alt}
          draggable={false}
          loading="lazy"
          onError={() => setFailed(src)}
          className="size-full object-cover"
        />
      ) : null}
    </div>
  );
}

/** A row of colour chips, such as a terminal palette. */
export function Swatches({
  colours,
  size = 18,
  className,
}: {
  colours: readonly string[];
  size?: number;
  className?: string;
}) {
  return (
    <div className={cx("flex items-center gap-1", className)}>
      {colours.map((c, i) => (
        <span
          key={`${c}-${i}`}
          title={c}
          className="shrink-0 rounded-[4px] ring-1 ring-inset ring-black/15"
          style={{ background: c, width: size, height: size }}
        />
      ))}
    </div>
  );
}

/** The current width of an element, kept up to date with a ResizeObserver. */
export function useWidth<T extends HTMLElement>(initial = 0) {
  const ref = useRef<T>(null);
  const [width, setWidth] = useState(initial);
  useEffect(() => {
    const el = ref.current;
    if (!el) return;
    setWidth(el.clientWidth);
    const ro = new ResizeObserver(([entry]) => {
      if (entry) setWidth(entry.contentRect.width);
    });
    ro.observe(el);
    return () => ro.disconnect();
  }, []);
  return [ref, width] as const;
}

/** A compact pill for listing things like menu bar items or app names. */
export function Chip({ children, colour }: { children: ReactNode; colour?: string }) {
  return (
    <span className="inline-flex h-[22px] items-center gap-1.5 rounded-[6px] border border-[var(--st-border)] bg-[var(--st-side)] px-2 text-[11.5px] font-medium whitespace-nowrap text-[var(--st-fg2)]">
      {colour ? <span className="size-2 rounded-full" style={{ background: colour }} /> : null}
      {children}
    </span>
  );
}
