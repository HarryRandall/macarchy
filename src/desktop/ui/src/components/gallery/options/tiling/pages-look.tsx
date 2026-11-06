import { Check, Minus, Plus } from "lucide-react";
import { type ReactNode, useState } from "react";

import { type MockPaneId, borders, layout, services, themes } from "../data";
import { Button, Heading, Hint, PageHeader, Row, Segmented, Slider, Toggle, cx } from "./ui";

export type Theme = (typeof themes)[number];
export interface HealthItem {
  name: string;
  detail: string;
  ok: boolean;
}

/* ------------------------------------------------------------------ home */

export function Home({
  go,
  theme,
  health,
}: {
  go: (id: MockPaneId) => void;
  theme: Theme;
  health: HealthItem[];
}) {
  const [svc, setSvc] = useState(
    services.map((s) => ({ ...s, state: s.state as "running" | "stopped" })),
  );
  const passing = health.filter((h) => h.ok).length;
  const running = svc.filter((s) => s.state === "running").length;

  const actions: { label: string; keys: string; run: () => void }[] = [
    { label: "Switch theme", keys: "⌥⇧T", run: () => go("themes") },
    { label: "Reload AeroSpace config", keys: "⌥⇧R", run: () => undefined },
    { label: "Edit window rules", keys: "g r", run: () => go("rules") },
    { label: "Run setup health", keys: "g d", run: () => go("health") },
  ];

  return (
    <>
      <PageHeader
        path="home"
        title="welcome back, harry"
        detail="Your desktop at a glance. Everything here is one keystroke away."
      />

      <pre className="mb-4 rounded-[3px] border border-[var(--line)] bg-[var(--bg2)] px-3 py-2 font-mono text-[11.5px] leading-[18px] text-[var(--fg2)]">
        <span className="text-[var(--acc)]">macarchy</span> v0.9.2{"   "}
        <span className="text-[var(--dim)]">os</span> macOS 27.0{"   "}
        <span className="text-[var(--dim)]">wm</span> aerospace 0.19{"   "}
        <span className="text-[var(--dim)]">bar</span> sketchybar 2.22{"   "}
        <span className="text-[var(--dim)]">theme</span>{" "}
        <span style={{ color: theme.accent }}>{theme.name.toLowerCase()}</span>
      </pre>

      <div className="grid grid-cols-[1.35fr_1fr] gap-4">
        <div>
          <Heading
            right={
              <span className="text-[var(--ok)]">
                {running}/{svc.length} up
              </span>
            }
          >
            services
          </Heading>
          {svc.map((s, i) => (
            <Row
              key={s.name}
              label={
                <span className="flex items-center gap-2">
                  <span
                    className={cx(
                      "font-mono text-[10px]",
                      s.state === "running" ? "text-[var(--ok)]" : "text-[var(--err)]",
                    )}
                  >
                    ●
                  </span>
                  {s.name}
                </span>
              }
              detail={<span className="pl-[18px]">{s.detail}</span>}
            >
              <span
                className={cx(
                  "font-mono text-[11px]",
                  s.state === "running" ? "text-[var(--ok)]" : "text-[var(--err)]",
                )}
              >
                {s.state}
              </span>
              <Button
                onClick={() =>
                  setSvc((all) =>
                    all.map((x, j) =>
                      j === i ? { ...x, state: x.state === "running" ? "stopped" : "running" } : x,
                    ),
                  )
                }
                className="w-[64px] justify-center"
              >
                {s.state === "running" ? "restart" : "start"}
              </Button>
            </Row>
          ))}

          <Heading>quick actions</Heading>
          <div className="grid grid-cols-2 gap-2">
            {actions.map((a) => (
              <button
                key={a.label}
                type="button"
                onClick={a.run}
                className="flex items-center justify-between rounded-[3px] border border-[var(--line2)] px-2.5 py-2 text-left font-sans text-[12.5px] text-[var(--fg)] hover:border-[var(--acc)] hover:bg-[var(--tint)]"
              >
                {a.label}
                <span className="font-mono text-[11px] text-[var(--acc)]">{a.keys}</span>
              </button>
            ))}
          </div>
        </div>

        <div>
          <Heading right={<Hint k="g t">change</Hint>}>current theme</Heading>
          <button
            type="button"
            onClick={() => go("themes")}
            className="w-full overflow-hidden rounded-[3px] border border-[var(--line2)] text-left hover:border-[var(--acc)]"
          >
            <ThemePreview theme={theme} tall />
            <div className="flex items-center justify-between bg-[var(--bg2)] px-2.5 py-1.5 font-mono text-[12px] text-[var(--fg)]">
              {theme.name}
              <span className="text-[var(--ok)]">[applied]</span>
            </div>
          </button>

          <Heading right={<Hint k="g d">open</Hint>}>setup health</Heading>
          <div className="rounded-[3px] border border-[var(--line)] bg-[var(--bg2)] px-3 py-2.5 font-mono text-[12px]">
            <div className="flex justify-between text-[var(--fg)]">
              <span>
                {passing}/{health.length} checks passing
              </span>
              <span
                className={passing === health.length ? "text-[var(--ok)]" : "text-[var(--warn)]"}
              >
                {passing === health.length ? "all good" : `${health.length - passing} to fix`}
              </span>
            </div>
            <AsciiBar value={passing} max={health.length} />
          </div>
        </div>
      </div>
    </>
  );
}

export function AsciiBar({
  value,
  max,
  width = 32,
}: {
  value: number;
  max: number;
  width?: number;
}) {
  const filled = Math.round((value / max) * width);
  return (
    <div className="mt-1 font-mono text-[12px] tracking-[-0.5px]">
      <span className="text-[var(--dim)]">[</span>
      <span className="text-[var(--ok)]">{"█".repeat(filled)}</span>
      <span className="text-[var(--line2)]">{"░".repeat(width - filled)}</span>
      <span className="text-[var(--dim)]">]</span>
    </div>
  );
}

/* ---------------------------------------------------------------- themes */

function ThemePreview({ theme, tall }: { theme: Theme; tall?: boolean }) {
  return (
    <div
      className={cx("flex gap-[3px] p-[5px]", tall ? "h-[104px]" : "h-[78px]")}
      style={{ background: theme.bg }}
    >
      <div
        className="flex flex-1 flex-col gap-[3px] rounded-[2px] p-1.5 font-mono text-[9px] leading-[12px]"
        style={{ boxShadow: `inset 0 0 0 1.5px ${theme.accent}`, color: theme.fg }}
      >
        <span>
          <span style={{ color: theme.swatches[1] }}>~</span>{" "}
          <span style={{ color: theme.accent }}>❯</span> ls
        </span>
        <span style={{ color: theme.swatches[3] }}>src docs</span>
        {tall && <span style={{ color: theme.swatches[2] }}>README.md</span>}
        <div className="mt-auto flex gap-[2px]">
          {theme.swatches.map((c) => (
            <span key={c} className="h-[5px] flex-1 rounded-[1px]" style={{ background: c }} />
          ))}
        </div>
      </div>
      <div className="flex w-[34%] flex-col gap-[3px]">
        <div
          className="flex-1 rounded-[2px]"
          style={{ boxShadow: `inset 0 0 0 1px ${theme.fg}33` }}
        />
        <div
          className="flex-1 rounded-[2px]"
          style={{ boxShadow: `inset 0 0 0 1px ${theme.fg}33` }}
        />
      </div>
    </div>
  );
}

export function Themes({ applied, onApply }: { applied: string; onApply: (name: string) => void }) {
  const [cursor, setCursor] = useState(applied);
  const [followSystem, setFollowSystem] = useState(true);
  const [wallpaper, setWallpaper] = useState(true);
  const [bar, setBar] = useState(true);

  return (
    <>
      <PageHeader
        path="themes"
        title="themes"
        detail="One palette for borders, the menu bar, your terminal and wallpaper."
        right={
          <Button primary onClick={() => onApply(cursor)} disabled={cursor === applied}>
            {cursor === applied ? "applied" : `apply ${cursor.toLowerCase()}`}
            <span className="opacity-70">⏎</span>
          </Button>
        }
      />
      <Heading right={<span>{themes.length} installed</span>}>installed</Heading>
      <div className="grid grid-cols-4 gap-3">
        {themes.map((t) => {
          const selected = t.name === cursor;
          const isApplied = t.name === applied;
          return (
            <button
              key={t.name}
              type="button"
              onClick={() => setCursor(t.name)}
              onDoubleClick={() => onApply(t.name)}
              className={cx(
                "overflow-hidden rounded-[3px] border text-left transition-shadow",
                selected
                  ? "border-[var(--acc)] shadow-[0_0_0_1px_var(--acc),0_0_14px_var(--glow)]"
                  : "border-[var(--line2)] hover:border-[var(--mut)]",
              )}
            >
              <ThemePreview theme={t} />
              <div className="flex items-center justify-between gap-1 bg-[var(--bg2)] px-2 py-1.5 font-mono text-[11.5px]">
                <span
                  className={cx("truncate", selected ? "text-[var(--fg)]" : "text-[var(--fg2)]")}
                >
                  {selected ? "› " : "  "}
                  {t.name.toLowerCase()}
                </span>
                {isApplied && <Check size={13} className="shrink-0 text-[var(--ok)]" />}
              </div>
            </button>
          );
        })}
      </div>

      <Heading>options</Heading>
      <Row
        label="Follow system appearance"
        detail="Use the light variant when macOS is in light mode."
      >
        <Toggle on={followSystem} onChange={setFollowSystem} />
      </Row>
      <Row label="Matching wallpaper" detail="Set the theme's wallpaper on every display.">
        <Toggle on={wallpaper} onChange={setWallpaper} />
      </Row>
      <Row label="Recolour SketchyBar" detail="Apply theme colours to the menu bar items.">
        <Toggle on={bar} onChange={setBar} />
      </Row>
    </>
  );
}

/* --------------------------------------------------------------- borders */

const activeColours = ["#7aa2f7", "#bb9af7", "#7dcfff", "#9ece6a", "#e0af68", "#f7768e"];
const inactiveColours = ["#414868", "#565f89", "#3b4261", "#a9b1d6"];

function Swatches({
  colours,
  value,
  onChange,
}: {
  colours: string[];
  value: string;
  onChange: (c: string) => void;
}) {
  return (
    <div className="flex items-center gap-1.5">
      {colours.map((c) => (
        <button
          key={c}
          type="button"
          title={c}
          onClick={() => onChange(c)}
          className={cx(
            "size-[20px] rounded-[3px] transition-shadow",
            c === value
              ? "shadow-[0_0_0_2px_var(--bg),0_0_0_3.5px_var(--fg)]"
              : "hover:shadow-[0_0_0_2px_var(--bg),0_0_0_3px_var(--line2)]",
          )}
          style={{ background: c }}
        />
      ))}
      <span className="ml-1 w-[62px] font-mono text-[11px] text-[var(--mut)]">{value}</span>
    </div>
  );
}

function FakeWindow({ title, lines, dim }: { title: string; lines: ReactNode[]; dim?: boolean }) {
  return (
    <div
      className={cx(
        "flex h-full flex-col bg-[#1a1b26] font-mono text-[10.5px] leading-[16px]",
        dim ? "text-[#565f89]" : "text-[#c0caf5]",
      )}
    >
      <div className="border-b border-[#292e42] px-2 py-1 text-[10px] text-[#737aa2]">{title}</div>
      <div className="flex-1 px-2 py-1.5">
        {lines.map((l, i) => (
          <div key={i}>{l}</div>
        ))}
      </div>
    </div>
  );
}

export function Borders() {
  const [width, setWidth] = useState(borders.width);
  const [radius, setRadius] = useState(borders.radius);
  const [style, setStyle] = useState<string>(borders.styles[0] ?? "Round");
  const [active, setActive] = useState(borders.active);
  const [inactive, setInactive] = useState(borders.inactive);
  const [glow, setGlow] = useState(true);
  const [gradient, setGradient] = useState(false);
  const [hidpi, setHidpi] = useState(true);

  const r = style === "Square" ? 0 : radius;
  const frame = (colour: string, focused: boolean) => ({
    padding: width,
    borderRadius: r + width,
    background: focused && gradient ? `linear-gradient(135deg, ${colour}, #bb9af7)` : colour,
    boxShadow: focused && glow ? `0 0 ${width * 3 + 6}px ${colour}66` : "none",
  });

  return (
    <>
      <PageHeader
        path="borders"
        title="borders"
        detail="JankyBorders draws a frame around the focused window so you always know where you are."
        right={
          <Button
            onClick={() => {
              setWidth(borders.width);
              setRadius(borders.radius);
              setActive(borders.active);
              setInactive(borders.inactive);
            }}
          >
            reset
          </Button>
        }
      />

      <div className="relative mb-2 h-[220px] overflow-hidden rounded-[3px] border border-[var(--line)] bg-[radial-gradient(120%_120%_at_20%_0%,#2a2f4a,#13141c_70%)] p-6">
        <div className="absolute left-6 top-6 h-[150px] w-[330px]" style={frame(inactive, false)}>
          <div className="h-full overflow-hidden" style={{ borderRadius: r }}>
            <FakeWindow
              title="zed  src/main.rs"
              dim
              lines={["fn main() {", "    let wm = AeroSpace::new();", "    wm.tile();", "}"]}
            />
          </div>
        </div>
        <div className="absolute right-8 top-10 h-[160px] w-[400px]" style={frame(active, true)}>
          <div className="h-full overflow-hidden" style={{ borderRadius: r }}>
            <FakeWindow
              title="ghostty  ~/projects/macarchy"
              lines={[
                <>
                  <span className="text-[#9ece6a]">~/macarchy</span>{" "}
                  <span className="text-[#7aa2f7]">❯</span> borders active_color=0xff
                  {active.slice(1)}
                </>,
                <>
                  <span className="text-[#565f89]">
                    {" "}
                    width={width}.0 style={style === "Square" ? "square" : "round"} hidpi=
                    {hidpi ? "on" : "off"}
                  </span>
                </>,
                <>
                  <span className="text-[#9ece6a]">~/macarchy</span>{" "}
                  <span className="text-[#7aa2f7]">❯</span> <span className="animate-pulse">█</span>
                </>,
              ]}
            />
          </div>
        </div>
        <span className="absolute bottom-2 left-3 font-mono text-[10px] text-[#737aa2]">
          preview · focused window on the right
        </span>
      </div>

      <Heading>shape</Heading>
      <Row label="Width" detail="Thickness of the frame in points.">
        <Slider value={width} min={1} max={12} onChange={setWidth} />
      </Row>
      <Row
        label="Corner radius"
        detail={
          style === "Square"
            ? "Ignored while style is square."
            : "Match your windows' rounded corners."
        }
      >
        <Slider value={radius} min={0} max={20} onChange={setRadius} />
      </Row>
      <Row label="Style">
        <Segmented options={borders.styles} value={style} onChange={setStyle} />
      </Row>

      <Heading>colour</Heading>
      <Row label="Active window">
        <Swatches colours={activeColours} value={active} onChange={setActive} />
      </Row>
      <Row label="Inactive windows">
        <Swatches colours={inactiveColours} value={inactive} onChange={setInactive} />
      </Row>
      <Row label="Glow on focused window">
        <Toggle on={glow} onChange={setGlow} />
      </Row>
      <Row label="Gradient" detail="Blend the active colour into magenta.">
        <Toggle on={gradient} onChange={setGradient} />
      </Row>
      <Row label="Draw at Retina resolution">
        <Toggle on={hidpi} onChange={setHidpi} />
      </Row>
    </>
  );
}

/* ---------------------------------------------------------------- layout */

type Mode = (typeof layout.modes)[number];
type Orientation = (typeof layout.orientation)[number];

function TilingPreview({
  inner,
  outer,
  mode,
  orientation,
}: {
  inner: number;
  outer: number;
  mode: Mode;
  orientation: Orientation;
}) {
  const win = (label: string, focused: boolean) => (
    <div
      className={cx(
        "flex min-h-0 min-w-0 flex-1 flex-col rounded-[2px] border bg-[var(--bg)]",
        focused ? "border-[var(--acc)] shadow-[0_0_10px_var(--glow)]" : "border-[var(--line2)]",
      )}
    >
      <div
        className={cx(
          "px-1.5 py-0.5 font-mono text-[9px]",
          focused ? "text-[var(--acc)]" : "text-[var(--dim)]",
        )}
      >
        {label}
      </div>
    </div>
  );
  const vertical = orientation === "Vertical";

  return (
    <div className="relative h-[180px] w-full overflow-hidden rounded-[3px] border border-[var(--line)] bg-[var(--bg2)]">
      <div className="absolute inset-x-0 top-0 h-[10px] border-b border-[var(--line)] bg-[var(--bg3)]" />
      <div className="absolute inset-x-0 bottom-0 top-[10px] flex" style={{ padding: outer }}>
        {mode === "Tiles" && (
          <div
            className={cx("flex flex-1", vertical ? "flex-col" : "flex-row")}
            style={{ gap: inner }}
          >
            {win("ghostty", true)}
            <div
              className={cx("flex flex-1", vertical ? "flex-row" : "flex-col")}
              style={{ gap: inner }}
            >
              {win("arc", false)}
              {win("zed", false)}
            </div>
          </div>
        )}
        {mode === "Accordion" && (
          <div className="relative flex-1">
            {["zed", "arc", "ghostty"].map((n, i) => (
              <div
                key={n}
                className="absolute flex"
                style={
                  vertical
                    ? { left: 0, right: 0, top: i * 14, bottom: (2 - i) * 14 }
                    : { top: 0, bottom: 0, left: i * 22, right: (2 - i) * 22 }
                }
              >
                {win(n, i === 2)}
              </div>
            ))}
          </div>
        )}
        {mode === "Floating" && (
          <div className="relative flex-1">
            <div className="absolute left-[4%] top-[6%] flex h-[58%] w-[46%]">
              {win("arc", false)}
            </div>
            <div className="absolute right-[6%] top-[14%] flex h-[50%] w-[40%]">
              {win("zed", false)}
            </div>
            <div className="absolute bottom-[4%] left-[26%] flex h-[52%] w-[44%]">
              {win("ghostty", true)}
            </div>
          </div>
        )}
      </div>
    </div>
  );
}

export function Layout() {
  const [inner, setInner] = useState(layout.gaps.inner);
  const [outer, setOuter] = useState(layout.gaps.outer);
  const [mode, setMode] = useState<Mode>(layout.modes[0] ?? "Tiles");
  const [orientation, setOrientation] = useState<Orientation>(layout.orientation[0] ?? "Auto");
  const [count, setCount] = useState(layout.workspaces);
  const [normalise, setNormalise] = useState(true);
  const [mouse, setMouse] = useState(false);

  return (
    <>
      <PageHeader
        path="layout"
        title="layout"
        detail="How AeroSpace arranges new windows, and the space between them."
      />
      <div className="grid grid-cols-[1fr_300px] gap-5">
        <div>
          <Heading>gaps</Heading>
          <Row label="Inner" detail="Between neighbouring windows.">
            <Slider value={inner} min={0} max={24} onChange={setInner} />
          </Row>
          <Row label="Outer" detail="Between windows and the screen edge.">
            <Slider value={outer} min={0} max={32} onChange={setOuter} />
          </Row>

          <Heading>arrangement</Heading>
          <Row label="Default mode">
            <Segmented options={layout.modes} value={mode} onChange={setMode} />
          </Row>
          <Row label="Orientation" detail="Auto picks horizontal on wide displays.">
            <Segmented options={layout.orientation} value={orientation} onChange={setOrientation} />
          </Row>
          <Row
            label="Normalise nested containers"
            detail="Flatten containers that hold a single child."
          >
            <Toggle on={normalise} onChange={setNormalise} />
          </Row>
          <Row label="Mouse follows focus">
            <Toggle on={mouse} onChange={setMouse} />
          </Row>

          <Heading>workspaces</Heading>
          <Row
            label="Workspace count"
            detail={`Bound to ⌥1 to ⌥${Math.min(count, 9)}${count > 9 ? " and ⌥0" : ""}.`}
          >
            <div className="flex h-[24px] items-center rounded-[3px] border border-[var(--line2)] font-mono text-[12px]">
              <button
                type="button"
                onClick={() => setCount((c) => Math.max(1, c - 1))}
                className="flex h-full w-[24px] items-center justify-center text-[var(--fg2)] hover:bg-[var(--bg3)]"
              >
                <Minus size={12} />
              </button>
              <span className="w-[30px] border-x border-[var(--line2)] text-center tabular-nums text-[var(--fg)]">
                {count}
              </span>
              <button
                type="button"
                onClick={() => setCount((c) => Math.min(10, c + 1))}
                className="flex h-full w-[24px] items-center justify-center text-[var(--fg2)] hover:bg-[var(--bg3)]"
              >
                <Plus size={12} />
              </button>
            </div>
          </Row>
        </div>

        <div>
          <Heading right={<span className="lowercase">{mode}</span>}>preview</Heading>
          <TilingPreview
            inner={inner / 2}
            outer={outer / 2}
            mode={mode}
            orientation={orientation}
          />
          <div className="mt-2 flex gap-1 font-mono text-[10.5px]">
            {Array.from({ length: count }, (_, i) => (
              <span
                key={i}
                className={cx(
                  "flex h-[20px] flex-1 items-center justify-center rounded-[2px] border",
                  i === 0
                    ? "border-[var(--acc)] bg-[var(--acc)] font-semibold text-[var(--accfg)]"
                    : "border-[var(--line2)] text-[var(--mut)]",
                )}
              >
                {(i + 1) % 10}
              </span>
            ))}
          </div>
          <pre className="mt-3 rounded-[3px] border border-[var(--line)] bg-[var(--bg2)] px-2.5 py-2 font-mono text-[10.5px] leading-[16px] text-[var(--fg2)]">
            <span className="text-[var(--dim)]"># aerospace.toml</span>
            {"\n"}default-root-container-layout ={" "}
            <span className="text-[var(--ok)]">
              '{mode === "Accordion" ? "accordion" : "tiles"}'
            </span>
            {"\n"}default-root-container-orientation ={" "}
            <span className="text-[var(--ok)]">'{orientation.toLowerCase()}'</span>
            {"\n"}gaps.inner.horizontal = <span className="text-[var(--warn)]">{inner}</span>
            {"\n"}gaps.outer.left = <span className="text-[var(--warn)]">{outer}</span>
          </pre>
        </div>
      </div>
    </>
  );
}
