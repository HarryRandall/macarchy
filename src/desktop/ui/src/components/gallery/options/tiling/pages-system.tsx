import { type LucideIcon, Search } from "lucide-react";
import { type ReactNode, useEffect, useMemo, useRef, useState } from "react";

import { rules as seedRules, shortcuts } from "../data";
import type { HealthItem } from "./pages-look";
import { AsciiBar } from "./pages-look";
import { Button, Heading, Hint, Kbd, PageHeader, Segmented, Toggle, cx, useSpinner } from "./ui";

/* ----------------------------------------------------------------- rules */

const actions = ["Float", "Tile", "Move to workspace"] as const;
type Action = (typeof actions)[number];
interface Rule {
  id: number;
  app: string;
  bundle: string;
  action: Action;
  workspace: string;
  launchOnly: boolean;
}

function runFor(r: Rule) {
  if (r.action === "Float") return "layout floating";
  if (r.action === "Tile") return "layout tiling";
  return `move-node-to-workspace ${r.workspace}`;
}

export function Rules() {
  const [list, setList] = useState<Rule[]>(() =>
    seedRules.map((r, i) => ({ ...r, id: i, action: r.action as Action, launchOnly: i % 2 === 1 })),
  );
  const [selected, setSelected] = useState(1);
  const [saved, setSaved] = useState(false);
  const rule = list.find((r) => r.id === selected);

  const patch = (p: Partial<Rule>) => {
    setSaved(false);
    setList((all) => all.map((r) => (r.id === selected ? { ...r, ...p } : r)));
  };
  const add = () => {
    const id = Math.max(-1, ...list.map((r) => r.id)) + 1;
    setList((all) => [
      ...all,
      {
        id,
        app: "New app",
        bundle: "com.example.app",
        action: "Float",
        workspace: "Any",
        launchOnly: false,
      },
    ]);
    setSelected(id);
  };
  const remove = () => {
    const rest = list.filter((r) => r.id !== selected);
    setList(rest);
    setSelected(rest[0]?.id ?? -1);
  };

  return (
    <>
      <PageHeader
        path="rules"
        title="rules"
        detail="Tell AeroSpace what to do when an app opens a window."
        right={
          <Button onClick={add}>
            + new rule <span className="text-[var(--dim)]">n</span>
          </Button>
        }
      />
      <div className="grid grid-cols-[1fr_330px] gap-4">
        <div className="min-w-0">
          <div className="grid grid-cols-[18px_1fr_140px_44px] gap-2 border-b border-[var(--line2)] px-2 pb-1.5 font-mono text-[10.5px] uppercase tracking-wider text-[var(--dim)]">
            <span />
            <span>app</span>
            <span>action</span>
            <span className="text-right">ws</span>
          </div>
          {list.map((r) => {
            const on = r.id === selected;
            return (
              <button
                key={r.id}
                type="button"
                onClick={() => setSelected(r.id)}
                className={cx(
                  "grid w-full grid-cols-[18px_1fr_140px_44px] items-center gap-2 border-b border-[var(--line)] px-2 py-1.5 text-left",
                  on ? "bg-[var(--sel)]" : "hover:bg-[var(--bg3)]",
                )}
              >
                <span
                  className={cx(
                    "font-mono text-[12px]",
                    on ? "text-[var(--acc)]" : "text-transparent",
                  )}
                >
                  ›
                </span>
                <span className="min-w-0">
                  <span className="block truncate font-sans text-[13px] text-[var(--fg)]">
                    {r.app}
                  </span>
                  <span className="block truncate font-mono text-[10.5px] text-[var(--mut)]">
                    {r.bundle}
                  </span>
                </span>
                <span
                  className={cx(
                    "font-mono text-[11.5px]",
                    r.action === "Float"
                      ? "text-[var(--mag)]"
                      : r.action === "Tile"
                        ? "text-[var(--cyan)]"
                        : "text-[var(--warn)]",
                  )}
                >
                  {r.action.toLowerCase()}
                </span>
                <span className="text-right font-mono text-[12px] text-[var(--fg2)]">
                  {r.workspace === "Any" ? "*" : r.workspace}
                </span>
              </button>
            );
          })}
          <div className="px-2 pt-2 font-mono text-[11px] text-[var(--dim)]">
            {list.length} rules · first match wins · <Hint k="j/k">move</Hint>
          </div>
        </div>

        <div className="rounded-[3px] border border-[var(--line2)] bg-[var(--bg2)] p-3">
          {!rule ? (
            <p className="font-mono text-[12px] text-[var(--mut)]">no rule selected</p>
          ) : (
            <>
              <div className="mb-3 font-mono text-[11px] text-[var(--dim)]">
                edit rule #{rule.id + 1}
              </div>
              <Field label="app name">
                <input
                  value={rule.app}
                  onChange={(e) => patch({ app: e.target.value })}
                  className="h-[26px] w-full rounded-[3px] border border-[var(--line2)] bg-[var(--bg)] px-2 font-sans text-[13px] text-[var(--fg)] outline-none focus:border-[var(--acc)]"
                />
              </Field>
              <Field label="bundle id">
                <input
                  value={rule.bundle}
                  onChange={(e) => patch({ bundle: e.target.value })}
                  className="h-[26px] w-full rounded-[3px] border border-[var(--line2)] bg-[var(--bg)] px-2 font-mono text-[12px] text-[var(--fg)] outline-none focus:border-[var(--acc)]"
                />
              </Field>
              <Field label="action">
                <Segmented
                  options={actions}
                  value={rule.action}
                  onChange={(a) =>
                    patch({
                      action: a,
                      workspace:
                        a === "Move to workspace"
                          ? rule.workspace === "Any"
                            ? "1"
                            : rule.workspace
                          : "Any",
                    })
                  }
                />
              </Field>
              {rule.action === "Move to workspace" && (
                <Field label="workspace">
                  <div className="flex gap-1">
                    {Array.from({ length: 9 }, (_, i) => String(i + 1)).map((w) => (
                      <button
                        key={w}
                        type="button"
                        onClick={() => patch({ workspace: w })}
                        className={cx(
                          "h-[24px] flex-1 rounded-[2px] border font-mono text-[11.5px]",
                          w === rule.workspace
                            ? "border-[var(--acc)] bg-[var(--acc)] font-semibold text-[var(--accfg)]"
                            : "border-[var(--line2)] text-[var(--fg2)] hover:border-[var(--acc)]",
                        )}
                      >
                        {w}
                      </button>
                    ))}
                  </div>
                </Field>
              )}
              <div className="mb-3 flex items-center justify-between">
                <span className="font-sans text-[12.5px] text-[var(--fg)]">
                  Only when the app launches
                </span>
                <Toggle on={rule.launchOnly} onChange={(v) => patch({ launchOnly: v })} />
              </div>

              <pre className="mb-3 overflow-hidden rounded-[3px] border border-[var(--line)] bg-[var(--bg)] px-2.5 py-2 font-mono text-[10.5px] leading-[16px] text-[var(--fg2)]">
                <span className="text-[var(--mag)]">[[on-window-detected]]</span>
                {"\n"}if.app-id = <span className="text-[var(--ok)]">'{rule.bundle}'</span>
                {rule.launchOnly && (
                  <>
                    {"\n"}if.during-aerospace-startup ={" "}
                    <span className="text-[var(--warn)]">false</span>
                  </>
                )}
                {"\n"}run = <span className="text-[var(--ok)]">'{runFor(rule)}'</span>
              </pre>

              <div className="flex justify-between">
                <Button danger onClick={remove}>
                  delete
                </Button>
                <Button primary onClick={() => setSaved(true)}>
                  {saved ? "saved" : "save"} <span className="opacity-70">⌘S</span>
                </Button>
              </div>
            </>
          )}
        </div>
      </div>
    </>
  );
}

function Field({ label, children }: { label: string; children: ReactNode }) {
  return (
    <label className="mb-3 block">
      <span className="mb-1 block font-mono text-[10.5px] uppercase tracking-wider text-[var(--dim)]">
        {label}
      </span>
      {children}
    </label>
  );
}

/* ------------------------------------------------------------- shortcuts */

export function Shortcuts({ focusToken }: { focusToken: number }) {
  const [query, setQuery] = useState("");
  const [recording, setRecording] = useState<string | null>(null);
  const [leader, setLeader] = useState(true);
  const input = useRef<HTMLInputElement>(null);

  useEffect(() => {
    if (focusToken > 0) input.current?.focus();
  }, [focusToken]);

  const filtered = useMemo(() => {
    const q = query.trim().toLowerCase();
    return shortcuts
      .map((g) => ({
        ...g,
        items: g.items.filter(
          (i) =>
            !q ||
            i.action.toLowerCase().includes(q) ||
            g.group.toLowerCase().includes(q) ||
            i.keys.join(" ").toLowerCase().includes(q),
        ),
      }))
      .filter((g) => g.items.length > 0);
  }, [query]);
  const total = filtered.reduce((n, g) => n + g.items.length, 0);

  return (
    <>
      <PageHeader
        path="shortcuts"
        title="shortcuts"
        detail="Every binding in one place. Click a row to record a new combination."
        right={
          <span className="flex items-center gap-2 font-sans text-[12px] text-[var(--mut)]">
            Use ⌥ as leader <Toggle on={leader} onChange={setLeader} />
          </span>
        }
      />
      <div className="mb-3 flex h-[30px] items-center gap-2 rounded-[3px] border border-[var(--line2)] bg-[var(--bg2)] px-2.5 focus-within:border-[var(--acc)] focus-within:shadow-[0_0_0_1px_var(--acc)]">
        <span className="font-mono text-[12px] text-[var(--acc)]">/</span>
        <input
          ref={input}
          value={query}
          onChange={(e) => setQuery(e.target.value)}
          placeholder="filter shortcuts"
          className="flex-1 bg-transparent font-mono text-[12.5px] text-[var(--fg)] outline-none placeholder:text-[var(--dim)]"
        />
        <Search size={13} className="text-[var(--dim)]" />
        <span className="font-mono text-[11px] text-[var(--dim)]">{total} matches</span>
      </div>

      {filtered.length === 0 && (
        <div className="py-8 text-center font-mono text-[12px] text-[var(--mut)]">
          no shortcuts match "{query}" · esc to clear
        </div>
      )}
      {filtered.map((g) => (
        <div key={g.group}>
          <Heading right={<span>{g.items.length}</span>}>{g.group}</Heading>
          {g.items.map((i) => {
            const id = `${g.group}:${i.action}`;
            const rec = recording === id;
            return (
              <button
                key={id}
                type="button"
                onClick={() => setRecording(rec ? null : id)}
                onKeyDown={(e) => {
                  if (rec && e.key === "Escape") {
                    e.stopPropagation();
                    setRecording(null);
                  }
                }}
                className={cx(
                  "flex h-[36px] w-full items-center justify-between border-b border-[var(--line)] px-2 text-left last:border-b-0",
                  rec ? "bg-[var(--tint)]" : "hover:bg-[var(--bg3)]",
                )}
              >
                <span className="font-sans text-[13px] text-[var(--fg)]">{i.action}</span>
                {rec ? (
                  <span className="font-mono text-[11.5px] text-[var(--acc)]">
                    <span className="animate-pulse">●</span> press keys…{" "}
                    <span className="text-[var(--dim)]">esc cancel</span>
                  </span>
                ) : (
                  <span className="flex items-center gap-1">
                    {i.keys.map((k, n) => (
                      <span key={n} className="flex items-center gap-1">
                        {n > 0 && (
                          <span className="font-mono text-[10px] text-[var(--dim)]">+</span>
                        )}
                        <Kbd>{k}</Kbd>
                      </span>
                    ))}
                  </span>
                )}
              </button>
            );
          })}
        </div>
      ))}
    </>
  );
}

/* ---------------------------------------------------------------- health */

export function Health({
  items,
  setItems,
}: {
  items: HealthItem[];
  setItems: (fn: (all: HealthItem[]) => HealthItem[]) => void;
}) {
  const [fixing, setFixing] = useState<string | null>(null);
  const [checking, setChecking] = useState(false);
  const spin = useSpinner(fixing !== null || checking);
  const passing = items.filter((i) => i.ok).length;

  const fix = (name: string) => {
    setFixing(name);
    setTimeout(() => {
      setItems((all) =>
        all.map((i) => (i.name === name ? { ...i, ok: true, detail: "Fixed just now" } : i)),
      );
      setFixing(null);
    }, 1100);
  };
  const recheck = () => {
    setChecking(true);
    setTimeout(() => setChecking(false), 900);
  };

  return (
    <>
      <PageHeader
        path="health"
        title="setup health"
        detail="Checks that every part of Macarchy is installed, permitted and running."
        right={
          <Button onClick={recheck}>
            {checking ? `${spin} checking` : "run checks"}{" "}
            <span className="text-[var(--dim)]">r</span>
          </Button>
        }
      />
      <div className="mb-4 flex items-center justify-between rounded-[3px] border border-[var(--line)] bg-[var(--bg2)] px-3 py-2.5 font-mono">
        <div>
          <div className="text-[13px] text-[var(--fg)]">
            {passing}/{items.length} passing
            {passing < items.length && (
              <span className="text-[var(--warn)]"> · {items.length - passing} need attention</span>
            )}
          </div>
          <AsciiBar value={passing} max={items.length} width={48} />
        </div>
        <span
          className={cx(
            "text-[22px]",
            passing === items.length ? "text-[var(--ok)]" : "text-[var(--warn)]",
          )}
        >
          {passing === items.length ? "✓" : "!"}
        </span>
      </div>

      <Heading>checks</Heading>
      {items.map((c) => {
        const busy = fixing === c.name || checking;
        return (
          <div
            key={c.name}
            className="flex h-[44px] items-center gap-3 border-b border-[var(--line)] px-1 last:border-b-0"
          >
            <span
              className={cx(
                "w-[34px] font-mono text-[12px]",
                busy ? "text-[var(--acc)]" : c.ok ? "text-[var(--ok)]" : "text-[var(--warn)]",
              )}
            >
              {busy ? ` ${spin} ` : c.ok ? "[ok]" : "[!!]"}
            </span>
            <div className="min-w-0 flex-1">
              <div className="font-sans text-[13px] text-[var(--fg)]">{c.name}</div>
              <div
                className={cx(
                  "font-mono text-[11px]",
                  c.ok ? "text-[var(--mut)]" : "text-[var(--warn)]",
                )}
              >
                {c.detail}
              </div>
            </div>
            {!c.ok && (
              <Button primary onClick={() => fix(c.name)} disabled={fixing !== null}>
                {fixing === c.name ? "fixing" : "fix"}
              </Button>
            )}
            {c.ok && <span className="font-mono text-[11px] text-[var(--dim)]">passed</span>}
          </div>
        );
      })}
    </>
  );
}

/* ----------------------------------------------------------- placeholder */

export function Placeholder({ title, icon: Icon }: { title: string; icon: LucideIcon }) {
  return (
    <div className="flex h-full items-center justify-center">
      <div className="w-[360px] rounded-[3px] border border-dashed border-[var(--line2)] bg-[var(--bg2)] p-5 font-mono">
        <div className="mb-3 flex items-center gap-2 text-[13px] text-[var(--fg)]">
          <Icon size={15} className="text-[var(--acc)]" />
          {title.toLowerCase()}
        </div>
        <div className="text-[12px] leading-[20px] text-[var(--mut)]">
          <span className="text-[var(--dim)]">$</span> macarchy open{" "}
          {title.toLowerCase().replace(/ /g, "-")}
          <br />
          <span className="text-[var(--warn)]">!</span> coming in this style
          <br />
          <span className="text-[var(--dim)]"> this pane is not mocked yet</span>
        </div>
        <div className="mt-4 flex gap-3 text-[11px]">
          <Hint k="j/k">another pane</Hint>
          <Hint k="g h">home</Hint>
        </div>
      </div>
    </div>
  );
}
