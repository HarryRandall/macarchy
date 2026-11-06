import {
  type CSSProperties,
  type KeyboardEvent,
  type PointerEvent,
  type ReactNode,
  useEffect,
  useRef,
  useState,
} from "react";

import type { Appearance } from "../data";

/** Tokyo Night (dark) and Tokyo Night Day (light), as CSS custom properties. */
const palettes: Record<Appearance, Record<string, string>> = {
  dark: {
    "--base": "#111219",
    "--bg": "#1a1b26",
    "--bg2": "#16161e",
    "--bg3": "#1f2335",
    "--sel": "#283457",
    "--line": "#292e42",
    "--line2": "#3b4261",
    "--fg": "#c0caf5",
    "--fg2": "#a9b1d6",
    "--mut": "#737aa2",
    "--dim": "#565f89",
    "--acc": "#7aa2f7",
    "--accfg": "#16161e",
    "--glow": "rgba(122, 162, 247, 0.35)",
    "--tint": "rgba(122, 162, 247, 0.12)",
    "--ok": "#9ece6a",
    "--warn": "#e0af68",
    "--err": "#f7768e",
    "--mag": "#bb9af7",
    "--cyan": "#7dcfff",
  },
  light: {
    "--base": "#c4c8da",
    "--bg": "#e6e7ed",
    "--bg2": "#dcdee7",
    "--bg3": "#d6d8e3",
    "--sel": "#c2cdef",
    "--line": "#c8ccdc",
    "--line2": "#a8aecb",
    "--fg": "#3760bf",
    "--fg2": "#4c5a95",
    "--mut": "#6c76a3",
    "--dim": "#8990b3",
    "--acc": "#2e7de9",
    "--accfg": "#ffffff",
    "--glow": "rgba(46, 125, 233, 0.3)",
    "--tint": "rgba(46, 125, 233, 0.1)",
    "--ok": "#587539",
    "--warn": "#8c6c3e",
    "--err": "#f52a65",
    "--mag": "#9854f1",
    "--cyan": "#007197",
  },
};

export function paletteStyle(appearance: Appearance): CSSProperties {
  return palettes[appearance] as CSSProperties;
}

export function cx(...parts: (string | false | null | undefined)[]) {
  return parts.filter(Boolean).join(" ");
}

/** A tiled pane with its title set into the top border, lazygit style. */
export function Tile({
  title,
  index,
  focused,
  onFocus,
  right,
  className,
  children,
}: {
  title: string;
  index?: number;
  focused: boolean;
  onFocus?: () => void;
  right?: ReactNode;
  className?: string;
  children: ReactNode;
}) {
  return (
    <section
      onMouseDown={onFocus}
      className={cx(
        "relative min-h-0 rounded-[4px] border bg-[var(--bg)] transition-[border-color,box-shadow] duration-150",
        focused
          ? "border-[var(--acc)] shadow-[0_0_0_1px_var(--acc),0_0_18px_var(--glow)]"
          : "border-[var(--line2)]",
        className,
      )}
    >
      <div className="pointer-events-none absolute -top-[9px] left-2.5 right-2.5 flex items-center justify-between font-mono text-[11px] leading-[16px]">
        <span
          className={cx(
            "bg-[var(--bg)] px-1.5",
            focused ? "text-[var(--acc)]" : "text-[var(--mut)]",
          )}
        >
          {index !== undefined && <span className="text-[var(--dim)]">[{index}] </span>}
          {title}
        </span>
        {right && (
          <span className="pointer-events-auto bg-[var(--bg)] px-1.5 text-[var(--mut)]">
            {right}
          </span>
        )}
      </div>
      {children}
    </section>
  );
}

export function Heading({ children, right }: { children: ReactNode; right?: ReactNode }) {
  return (
    <div className="mb-1.5 mt-4 flex items-center gap-2 font-mono text-[11px] text-[var(--mut)] first:mt-0">
      <span className="text-[var(--acc)]">#</span>
      <span className="lowercase tracking-wide">{children}</span>
      <span className="h-px flex-1 bg-[var(--line)]" />
      {right}
    </div>
  );
}

export function Row({
  label,
  detail,
  children,
}: {
  label: ReactNode;
  detail?: ReactNode;
  children?: ReactNode;
}) {
  return (
    <div className="flex min-h-[38px] items-center justify-between gap-4 border-b border-[var(--line)] px-1 py-1.5 last:border-b-0 hover:bg-[var(--bg3)]/60">
      <div className="min-w-0">
        <div className="font-sans text-[13px] text-[var(--fg)]">{label}</div>
        {detail && <div className="font-sans text-[11.5px] text-[var(--mut)]">{detail}</div>}
      </div>
      <div className="flex shrink-0 items-center gap-2">{children}</div>
    </div>
  );
}

/** Boxy [on]/[off] toggle. */
export function Toggle({ on, onChange }: { on: boolean; onChange: (on: boolean) => void }) {
  return (
    <button
      type="button"
      role="switch"
      aria-checked={on}
      onClick={() => onChange(!on)}
      className={cx(
        "flex h-[22px] items-center rounded-[3px] border font-mono text-[11px] leading-none",
        on ? "border-[var(--acc)]" : "border-[var(--line2)]",
      )}
    >
      <span
        className={cx(
          "flex h-full items-center px-1.5 transition-colors",
          on ? "bg-[var(--acc)] font-semibold text-[var(--accfg)]" : "text-[var(--dim)]",
        )}
      >
        on
      </span>
      <span
        className={cx(
          "flex h-full items-center px-1.5 transition-colors",
          on ? "text-[var(--dim)]" : "bg-[var(--line2)] font-semibold text-[var(--fg)]",
        )}
      >
        off
      </span>
    </button>
  );
}

export function Segmented<T extends string>({
  options,
  value,
  onChange,
}: {
  options: readonly T[];
  value: T;
  onChange: (value: T) => void;
}) {
  return (
    <div className="flex h-[24px] rounded-[3px] border border-[var(--line2)] font-mono text-[11.5px]">
      {options.map((o, i) => (
        <button
          key={o}
          type="button"
          onClick={() => onChange(o)}
          className={cx(
            "px-2.5 lowercase transition-colors",
            i > 0 && "border-l border-[var(--line2)]",
            o === value
              ? "bg-[var(--acc)] font-semibold text-[var(--accfg)]"
              : "text-[var(--fg2)] hover:bg-[var(--bg3)] hover:text-[var(--fg)]",
          )}
        >
          {o}
        </button>
      ))}
    </div>
  );
}

/** Square-thumbed slider drawn as a segmented track. */
export function Slider({
  value,
  min,
  max,
  unit = "px",
  onChange,
}: {
  value: number;
  min: number;
  max: number;
  unit?: string;
  onChange: (value: number) => void;
}) {
  const track = useRef<HTMLDivElement>(null);
  const pct = ((value - min) / (max - min)) * 100;

  const fromPointer = (e: PointerEvent<HTMLDivElement>) => {
    const r = track.current?.getBoundingClientRect();
    if (!r) return;
    const ratio = Math.min(1, Math.max(0, (e.clientX - r.left) / r.width));
    onChange(Math.round(min + ratio * (max - min)));
  };
  const onKey = (e: KeyboardEvent<HTMLDivElement>) => {
    const step =
      e.key === "ArrowRight" || e.key === "ArrowUp"
        ? 1
        : e.key === "ArrowLeft" || e.key === "ArrowDown"
          ? -1
          : 0;
    if (!step) return;
    e.preventDefault();
    e.stopPropagation();
    onChange(Math.min(max, Math.max(min, value + step)));
  };

  return (
    <div className="flex items-center gap-2.5">
      <div
        ref={track}
        role="slider"
        tabIndex={0}
        aria-valuemin={min}
        aria-valuemax={max}
        aria-valuenow={value}
        onKeyDown={onKey}
        onPointerDown={(e) => {
          e.currentTarget.setPointerCapture(e.pointerId);
          fromPointer(e);
        }}
        onPointerMove={(e) => {
          if (e.buttons === 1) fromPointer(e);
        }}
        className="group relative h-[18px] w-[180px] cursor-ew-resize touch-none outline-none"
      >
        <div className="absolute inset-x-0 top-1/2 h-[6px] -translate-y-1/2 rounded-[1px] bg-[repeating-linear-gradient(90deg,var(--line2)_0_2px,transparent_2px_6px)]" />
        <div
          className="absolute left-0 top-1/2 h-[6px] -translate-y-1/2 rounded-[1px] bg-[repeating-linear-gradient(90deg,var(--acc)_0_4px,transparent_4px_6px)]"
          style={{ width: `${pct}%` }}
        />
        <div
          className="absolute top-1/2 h-[14px] w-[8px] -translate-x-1/2 -translate-y-1/2 rounded-[2px] border border-[var(--acc)] bg-[var(--fg)] group-focus-visible:shadow-[0_0_0_3px_var(--glow)]"
          style={{ left: `${pct}%` }}
        />
      </div>
      <span className="w-[42px] text-right font-mono text-[12px] tabular-nums text-[var(--fg)]">
        {String(value).padStart(2, "0")}
        <span className="text-[var(--dim)]">{unit}</span>
      </span>
    </div>
  );
}

export function Button({
  children,
  onClick,
  primary,
  danger,
  disabled,
  className,
}: {
  children: ReactNode;
  onClick?: () => void;
  primary?: boolean;
  danger?: boolean;
  disabled?: boolean;
  className?: string;
}) {
  return (
    <button
      type="button"
      onClick={onClick}
      disabled={disabled}
      className={cx(
        "inline-flex h-[24px] items-center gap-1.5 rounded-[3px] border px-2.5 font-mono text-[11.5px] transition-colors disabled:opacity-50",
        primary
          ? "border-[var(--acc)] bg-[var(--acc)] font-semibold text-[var(--accfg)] hover:brightness-110"
          : danger
            ? "border-[var(--line2)] text-[var(--err)] hover:border-[var(--err)]"
            : "border-[var(--line2)] text-[var(--fg2)] hover:border-[var(--acc)] hover:text-[var(--fg)]",
        className,
      )}
    >
      {children}
    </button>
  );
}

export function Kbd({ children }: { children: ReactNode }) {
  return (
    <kbd className="inline-flex h-[20px] min-w-[20px] items-center justify-center rounded-[3px] border border-b-2 border-[var(--line2)] bg-[var(--bg3)] px-1.5 font-mono text-[11px] text-[var(--fg)]">
      {children}
    </kbd>
  );
}

/** Inline key hint, e.g. "enter apply". */
export function Hint({ k, children }: { k: string; children?: ReactNode }) {
  return (
    <span className="whitespace-nowrap">
      <span className="text-[var(--acc)]">{k}</span>
      {children && <span className="text-[var(--mut)]"> {children}</span>}
    </span>
  );
}

const frames = ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"];
export function useSpinner(active: boolean) {
  const [i, setI] = useState(0);
  useEffect(() => {
    if (!active) return;
    const t = setInterval(() => setI((n) => (n + 1) % frames.length), 80);
    return () => clearInterval(t);
  }, [active]);
  return frames[i] ?? "⠋";
}

export function PageHeader({
  path,
  title,
  detail,
  right,
}: {
  path: string;
  title: string;
  detail: string;
  right?: ReactNode;
}) {
  return (
    <header className="mb-4 flex items-end justify-between gap-4 border-b border-[var(--line)] pb-3">
      <div>
        <div className="font-mono text-[11px] text-[var(--dim)]">~/.config/macarchy/{path}</div>
        <h1 className="mt-0.5 font-mono text-[18px] font-semibold text-[var(--fg)]">
          <span className="text-[var(--acc)]">❯ </span>
          {title}
        </h1>
        <p className="mt-0.5 font-sans text-[12.5px] text-[var(--mut)]">{detail}</p>
      </div>
      {right && <div className="flex shrink-0 items-center gap-2">{right}</div>}
    </header>
  );
}
