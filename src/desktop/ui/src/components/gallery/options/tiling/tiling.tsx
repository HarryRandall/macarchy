import { type KeyboardEvent, useRef, useState } from "react";

import {
  type MockPaneId,
  type OptionProps,
  groups,
  healthChecks,
  mocked,
  overview,
  panes,
  services,
  themes,
} from "../data";
import { Borders, type HealthItem, Home, Layout, Themes } from "./pages-look";
import { Health, Placeholder, Rules, Shortcuts } from "./pages-system";
import { Hint, Tile, cx, paletteStyle } from "./ui";

/** Mnemonic for "g <key>" navigation, shown beside each sidebar item. */
const mnemonic: Record<MockPaneId, string> = {
  home: "h",
  workshop: "w",
  plugins: "p",
  themes: "t",
  borders: "b",
  menuBar: "m",
  layout: "l",
  rules: "r",
  shortcuts: "s",
  health: "d",
  advanced: "a",
  report: "!",
};

const order: MockPaneId[] = [...overview, ...groups.flatMap((g) => g.panes)];
const previews: MockPaneId[] = ["workshop", "plugins"];

const pageHints: Record<MockPaneId, [string, string][]> = {
  home: [
    ["enter", "open"],
    ["g t", "themes"],
  ],
  workshop: [],
  plugins: [],
  themes: [
    ["click", "select"],
    ["dbl", "apply"],
  ],
  borders: [["←/→", "adjust slider"]],
  menuBar: [],
  layout: [["←/→", "adjust slider"]],
  rules: [
    ["n", "new"],
    ["⌘s", "save"],
  ],
  shortcuts: [
    ["/", "search"],
    ["esc", "cancel"],
  ],
  health: [["r", "run checks"]],
  advanced: [],
  report: [],
};

type Focus = "sidebar" | "main";

export default function Tiling({ appearance }: OptionProps) {
  const [page, setPage] = useState<MockPaneId>("home");
  const [focus, setFocus] = useState<Focus>("sidebar");
  const [workspace, setWorkspace] = useState(1);
  const [insert, setInsert] = useState(false);
  const [applied, setApplied] = useState(themes[0]?.name ?? "Tokyo Night");
  const [health, setHealth] = useState<HealthItem[]>(() => healthChecks.map((h) => ({ ...h })));
  const [searchToken, setSearchToken] = useState(0);
  const pendingG = useRef(false);

  const theme = themes.find((t) => t.name === applied) ?? themes[0]!;
  const go = (id: MockPaneId) => {
    setPage(id);
    setFocus("main");
  };

  const onKey = (e: KeyboardEvent<HTMLDivElement>) => {
    const t = e.target as HTMLElement;
    if (t.tagName === "INPUT" || t.tagName === "TEXTAREA") {
      if (e.key === "Escape") t.blur();
      return;
    }
    if (e.metaKey || e.ctrlKey || e.altKey) return;
    if (pendingG.current) {
      pendingG.current = false;
      const hit = order.find((id) => mnemonic[id] === e.key);
      if (hit) {
        e.preventDefault();
        go(hit);
      }
      return;
    }
    const i = order.indexOf(page);
    switch (e.key) {
      case "g":
        pendingG.current = true;
        break;
      case "j":
        setPage(order[Math.min(order.length - 1, i + 1)]!);
        setFocus("sidebar");
        break;
      case "k":
        setPage(order[Math.max(0, i - 1)]!);
        setFocus("sidebar");
        break;
      case "h":
        setFocus("sidebar");
        break;
      case "l":
      case "Enter":
        if (focus === "sidebar") {
          e.preventDefault();
          setFocus("main");
        }
        break;
      case "Tab":
        e.preventDefault();
        setFocus((f) => (f === "sidebar" ? "main" : "sidebar"));
        break;
      case "/":
        e.preventDefault();
        go("shortcuts");
        setSearchToken((n) => n + 1);
        break;
      default:
        if (/^[1-9]$/.test(e.key)) setWorkspace(Number(e.key));
    }
  };

  const isInput = (el: EventTarget) =>
    el instanceof HTMLElement && (el.tagName === "INPUT" || el.tagName === "TEXTAREA");
  const running = services.filter((s) => s.state === "running").length;

  const item = (id: MockPaneId) => {
    const { title, icon: Icon } = panes[id];
    const on = id === page;
    return (
      <button
        key={id}
        type="button"
        onClick={() => go(id)}
        className={cx(
          "group flex h-[26px] w-full items-center gap-2 rounded-[2px] px-2 text-left font-mono text-[12.5px]",
          on
            ? focus === "sidebar"
              ? "bg-[var(--acc)] text-[var(--accfg)]"
              : "bg-[var(--sel)] text-[var(--fg)]"
            : "text-[var(--fg2)] hover:bg-[var(--bg3)] hover:text-[var(--fg)]",
        )}
      >
        <span className="w-[8px] text-[11px]">{on ? "›" : ""}</span>
        <Icon size={13} strokeWidth={2} className={on ? "" : "text-[var(--mut)]"} />
        <span className="flex-1 truncate lowercase">{title}</span>
        {previews.includes(id) && (
          <span className={cx("text-[9.5px]", on ? "opacity-70" : "text-[var(--dim)]")}>beta</span>
        )}
        <span
          className={cx(
            "text-[10.5px]",
            on ? "opacity-70" : "text-[var(--dim)] group-hover:text-[var(--mut)]",
          )}
        >
          g{mnemonic[id]}
        </span>
      </button>
    );
  };

  const hints = pageHints[page];

  return (
    <div
      tabIndex={0}
      onKeyDown={onKey}
      onFocusCapture={(e) => setInsert(isInput(e.target))}
      onBlurCapture={() => setInsert(false)}
      style={paletteStyle(appearance)}
      className="mx-auto flex h-[760px] w-[1180px] flex-col overflow-hidden rounded-[8px] border border-[var(--line2)] bg-[var(--base)] font-mono text-[var(--fg)] shadow-[0_24px_60px_rgba(0,0,0,0.35)] outline-none"
    >
      {/* top strip: traffic lights, workspaces, title */}
      <div className="flex h-[34px] shrink-0 items-center gap-4 px-3 text-[11.5px]">
        <div className="flex gap-[7px]">
          <span className="size-[11px] rounded-full bg-[#ff5f57]" />
          <span className="size-[11px] rounded-full bg-[#febc2e]" />
          <span className="size-[11px] rounded-full bg-[#28c840]" />
        </div>
        <div className="flex gap-[3px]">
          {Array.from({ length: 9 }, (_, i) => i + 1).map((n) => {
            const occupied = [1, 2, 3, 9].includes(n);
            const on = n === workspace;
            return (
              <button
                key={n}
                type="button"
                onClick={() => setWorkspace(n)}
                className={cx(
                  "relative h-[20px] w-[22px] rounded-[2px] text-[11px] transition-colors",
                  on
                    ? "bg-[var(--acc)] font-semibold text-[var(--accfg)]"
                    : occupied
                      ? "text-[var(--fg2)] hover:bg-[var(--bg3)]"
                      : "text-[var(--dim)] hover:bg-[var(--bg3)]",
                )}
              >
                {n}
                {occupied && !on && (
                  <span className="absolute bottom-[2px] left-1/2 h-[2px] w-[6px] -translate-x-1/2 bg-[var(--mut)]" />
                )}
              </button>
            );
          })}
        </div>
        <div className="flex-1 text-center text-[var(--mut)]">
          macarchy <span className="text-[var(--dim)]">::</span>{" "}
          <span className="text-[var(--fg)]">settings</span>
        </div>
        <div className="flex items-center gap-3 text-[var(--mut)]">
          <span>
            <span className="text-[var(--ok)]">●</span> aerospace
          </span>
          <span style={{ color: appearance === "dark" ? theme.accent : undefined }}>
            {theme.name.toLowerCase()}
          </span>
        </div>
      </div>

      {/* tiled panes */}
      <div className="flex min-h-0 flex-1 gap-[8px] px-[8px] pb-[8px] pt-[10px]">
        <Tile
          title="panes"
          index={1}
          focused={focus === "sidebar"}
          onFocus={() => setFocus("sidebar")}
          right={`${order.indexOf(page) + 1}/${order.length}`}
          className="flex w-[232px] shrink-0 flex-col"
        >
          <nav className="flex-1 overflow-y-auto px-2 pb-2 pt-4">
            <div className="space-y-px">{overview.map(item)}</div>
            {groups.map((g) => (
              <div key={g.title} className="mt-3">
                <div className="mb-1 flex items-center gap-1.5 px-2 text-[10.5px] text-[var(--dim)]">
                  <span>──</span>
                  <span className="lowercase tracking-wide text-[var(--mut)]">{g.title}</span>
                  <span className="h-px flex-1 bg-[var(--line)]" />
                </div>
                <div className="space-y-px">{g.panes.map(item)}</div>
              </div>
            ))}
          </nav>
          <div className="border-t border-[var(--line)] px-3 py-2 text-[10.5px] leading-[16px] text-[var(--mut)]">
            <div className="flex justify-between">
              <span>services</span>
              <span
                className={running === services.length ? "text-[var(--ok)]" : "text-[var(--warn)]"}
              >
                {running}/{services.length} up
              </span>
            </div>
            <div className="flex justify-between">
              <span>health</span>
              <span
                className={health.every((h) => h.ok) ? "text-[var(--ok)]" : "text-[var(--warn)]"}
              >
                {health.filter((h) => h.ok).length}/{health.length}
              </span>
            </div>
          </div>
        </Tile>

        <Tile
          title={panes[page].title.toLowerCase()}
          index={2}
          focused={focus === "main"}
          onFocus={() => setFocus("main")}
          right={mocked.includes(page) ? "rw" : "ro"}
          className="flex min-w-0 flex-1 flex-col"
        >
          <main key={page} className="min-h-0 flex-1 overflow-y-auto px-6 pb-6 pt-5">
            {page === "home" && <Home go={go} theme={theme} health={health} />}
            {page === "themes" && <Themes applied={applied} onApply={setApplied} />}
            {page === "borders" && <Borders />}
            {page === "layout" && <Layout />}
            {page === "rules" && <Rules />}
            {page === "shortcuts" && <Shortcuts focusToken={searchToken} />}
            {page === "health" && <Health items={health} setItems={setHealth} />}
            {!mocked.includes(page) && (
              <Placeholder title={panes[page].title} icon={panes[page].icon} />
            )}
          </main>
        </Tile>
      </div>

      {/* status line */}
      <div className="flex h-[24px] shrink-0 items-center gap-3 border-t border-[var(--line)] bg-[var(--bg2)] pr-3 text-[11px]">
        <span
          className={cx(
            "flex h-full items-center px-2.5 font-semibold tracking-wide",
            insert ? "bg-[var(--ok)] text-[var(--accfg)]" : "bg-[var(--acc)] text-[var(--accfg)]",
          )}
        >
          {insert ? "INSERT" : "NORMAL"}
        </span>
        <span className="text-[var(--fg2)]">
          <span className="text-[var(--dim)]">settings/</span>
          {page}
        </span>
        <span className="text-[var(--dim)]">│</span>
        <span className="flex gap-3">
          {insert ? (
            <Hint k="esc">leave field</Hint>
          ) : (
            <>
              <Hint k="j/k">move</Hint>
              <Hint k="enter">select</Hint>
              <Hint k="tab">switch pane</Hint>
              <Hint k="/">search</Hint>
              {hints.map(([k, v]) => (
                <Hint key={k} k={k}>
                  {v}
                </Hint>
              ))}
            </>
          )}
        </span>
        <span className="ml-auto flex gap-3 text-[var(--mut)]">
          <span>ws {workspace}</span>
          <span className="text-[var(--dim)]">│</span>
          <span>tiles · 8px</span>
          <span className="text-[var(--dim)]">│</span>
          <span>{appearance}</span>
        </span>
      </div>
    </div>
  );
}
