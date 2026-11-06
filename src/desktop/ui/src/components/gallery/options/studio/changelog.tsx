import { Bell, Sparkles, X } from "lucide-react";
import { useEffect, useRef, useState } from "react";

import { realThemes, wallpaperUrl } from "../real";
import {
  Badge,
  Card,
  EmptyState,
  ImageFill,
  PageHeader,
  Segmented,
  Switch,
  cx,
  focusRing,
} from "./ui";

/* ------------------------------------------------------------------ */
/* Releases                                                            */
/* ------------------------------------------------------------------ */

type EntryKind = "new" | "improved" | "fixed";

interface Entry {
  kind: EntryKind;
  text: string;
}

interface Release {
  version: string;
  /** ISO date. */
  date: string;
  title: string;
  summary: string;
  /** A theme whose wallpaper illustrates a big release. */
  hero?: { theme: string; caption: string };
  entries: Entry[];
}

const latest: Release = {
  version: "0.9.2",
  date: "2026-10-14",
  title: "Themes everywhere",
  summary:
    "Ghostty and Neovim now follow your theme, and every theme remembers its own wallpaper, so one click restyles the whole desktop.",
  hero: { theme: "lumon", caption: "Lumon theme" },
  entries: [
    {
      kind: "new",
      text: "Ghostty follows the active theme. Open windows pick up the new palette without a restart.",
    },
    {
      kind: "new",
      text: "Neovim switches colourscheme when the theme changes, through a small bundled plugin.",
    },
    {
      kind: "new",
      text: "Each theme keeps its own wallpaper. Choose one per theme from the Themes pane.",
    },
    {
      kind: "improved",
      text: "Switching themes is roughly twice as fast because services now reload in parallel.",
    },
    {
      kind: "improved",
      text: "Theme cards show the chosen wallpaper and the terminal palette.",
    },
    {
      kind: "fixed",
      text: "SketchyBar no longer flashes its default colours during a theme change.",
    },
    { kind: "fixed", text: "Borders keep the theme colour after the Mac wakes from sleep." },
  ],
};

const releases: Release[] = [
  latest,
  {
    version: "0.9.1",
    date: "2026-09-30",
    title: "Polish for the new window",
    summary:
      "Small fixes and refinements following the 0.9.0 redesign, thanks to everyone who sent reports.",
    entries: [
      {
        kind: "improved",
        text: "The sidebar collapses to an icon rail with ⌘\\ and remembers its state.",
      },
      { kind: "improved", text: "Search now matches settings inside panes, not just pane names." },
      { kind: "fixed", text: "The settings window reopens at its last size and position." },
      {
        kind: "fixed",
        text: "Login items failed to register when the home folder had a space in it.",
      },
      { kind: "fixed", text: "Back and forward no longer skip a pane after using search." },
    ],
  },
  {
    version: "0.9.0",
    date: "2026-09-16",
    title: "A new settings window",
    summary:
      "The settings window has been rebuilt from scratch in React, with search, a live log and changes that apply as you make them.",
    hero: { theme: "midnight", caption: "Midnight theme" },
    entries: [
      { kind: "new", text: "A redesigned settings window with a Home overview of your desktop." },
      { kind: "new", text: "Search settings and run commands from anywhere with ⌘K." },
      {
        kind: "new",
        text: "A Logs panel shows every command Macarchy runs and what each service says back.",
      },
      {
        kind: "improved",
        text: "Every change applies immediately. There is no Save button any more.",
      },
      {
        kind: "improved",
        text: "Light and dark appearance follow the system, or can be set by hand.",
      },
      { kind: "fixed", text: "Reloading AeroSpace no longer moves windows between monitors." },
    ],
  },
  {
    version: "0.8.4",
    date: "2026-08-26",
    title: "Setup health checks",
    summary:
      "Macarchy now checks that AeroSpace, SketchyBar, JankyBorders and skhd are installed, running and starting at login.",
    entries: [
      {
        kind: "new",
        text: "Setup health lists each check with a one-click fix, such as starting skhd or adding a login item.",
      },
      { kind: "new", text: "Health problems show as a badge in the sidebar until they are fixed." },
      {
        kind: "improved",
        text: "Report an issue attaches the health results and recent log lines.",
      },
      {
        kind: "fixed",
        text: "The accessibility permission check gave a false warning on macOS 26.",
      },
    ],
  },
  {
    version: "0.8.2",
    date: "2026-08-05",
    title: "Menu Bar editor",
    summary:
      "Arrange SketchyBar visually: drag items between sides, hide the ones you do not use and preview the result.",
    entries: [
      {
        kind: "new",
        text: "Drag menu bar items to reorder them or move them between the left and right.",
      },
      {
        kind: "new",
        text: "Show or hide items such as Network, Memory and GPU with a single toggle.",
      },
      {
        kind: "improved",
        text: "Item scripts that time out keep their last value instead of going blank.",
      },
      { kind: "fixed", text: "The battery item showed the wrong icon while charging." },
    ],
  },
  {
    version: "0.8.0",
    date: "2026-07-15",
    title: "JankyBorders support",
    summary:
      "Window borders join the theme. Macarchy installs and configures JankyBorders, and colours it from the active theme.",
    hero: { theme: "carbonfox", caption: "Carbonfox theme" },
    entries: [
      { kind: "new", text: "A Borders pane for width, style and active and inactive colours." },
      { kind: "new", text: "Border colours come from the theme unless you set your own." },
      {
        kind: "new",
        text: "Exclude apps that draw their own frames, such as Zoom or screen recorders.",
      },
      {
        kind: "improved",
        text: "Theme changes now reload AeroSpace, SketchyBar and borders together.",
      },
      { kind: "fixed", text: "Borders were drawn behind full-screen video in some browsers." },
    ],
  },
  {
    version: "0.7.3",
    date: "2026-06-24",
    title: "Rules for floating apps",
    summary:
      "Decide which apps float above the tiling layout and which workspace they open on, without editing TOML.",
    entries: [
      {
        kind: "new",
        text: "Rules lets you float apps such as System Settings, TablePlus and Calculator.",
      },
      { kind: "new", text: "Send an app to a workspace when it opens." },
      {
        kind: "improved",
        text: "Pick apps from a list of what is installed instead of typing bundle IDs.",
      },
      { kind: "fixed", text: "Rules with a dot in the app name were ignored." },
    ],
  },
  {
    version: "0.7.0",
    date: "2026-06-03",
    title: "Workshop preview",
    summary:
      "An early look at Workshop: browse Omarchy community themes and install them into Macarchy in one step.",
    entries: [
      { kind: "new", text: "Workshop lists community themes with their wallpapers and palettes." },
      { kind: "new", text: "Install a community theme and switch to it straight away." },
      {
        kind: "improved",
        text: "Themes now install into ~/.config/macarchy/themes so they survive updates.",
      },
      { kind: "fixed", text: "Installing a theme with an uppercase name failed silently." },
    ],
  },
];

export const latestVersion = latest.version;

/** True when version a is newer than version b. */
export function isNewer(a: string, b: string): boolean {
  const pa = a.split(".").map(Number);
  const pb = b.split(".").map(Number);
  for (let i = 0; i < Math.max(pa.length, pb.length); i++) {
    const d = (pa[i] ?? 0) - (pb[i] ?? 0);
    if (d !== 0) return d > 0;
  }
  return false;
}

function art(themeId: string) {
  const t = realThemes.find((x) => x.id === themeId);
  return {
    src: t ? wallpaperUrl(t.id, t.wallpaper) : undefined,
    from: t?.background ?? "#18181b",
    to: t?.accent ?? "#6366f1",
  };
}

const dateFormat = new Intl.DateTimeFormat("en-GB", {
  day: "numeric",
  month: "short",
  year: "numeric",
});
const formatDate = (iso: string) => dateFormat.format(new Date(`${iso}T12:00:00`));

const kinds: Record<EntryKind, { label: string; tag: string; dot: string }> = {
  new: {
    label: "New",
    tag: "bg-[var(--st-accent-soft)] text-[var(--st-accent-text)]",
    dot: "bg-[var(--st-accent)]",
  },
  improved: {
    label: "Improved",
    tag: "bg-[var(--st-ok-soft)] text-[var(--st-ok)]",
    dot: "bg-[var(--st-ok)]",
  },
  fixed: {
    label: "Fixed",
    tag: "bg-[var(--st-warn-soft)] text-[var(--st-warn)]",
    dot: "bg-[var(--st-warn)]",
  },
};
const kindOrder: EntryKind[] = ["new", "improved", "fixed"];

function Tag({ kind }: { kind: EntryKind }) {
  const k = kinds[kind];
  return (
    <span
      className={cx(
        "inline-flex h-[19px] items-center gap-[5px] rounded-[5px] px-[6px] text-[11px] font-semibold tracking-[0.01em] whitespace-nowrap",
        k.tag,
      )}
    >
      <span className={cx("size-[5px] rounded-full", k.dot)} />
      {k.label}
    </span>
  );
}

/* ------------------------------------------------------------------ */
/* Sidebar card                                                        */
/* ------------------------------------------------------------------ */

/**
 * The release card above the sidebar footer. It keeps a fixed width so the
 * sidebar's width transition clips it rather than reflowing it.
 */
export function WhatsNewCard({
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
  const image = art("lumon");
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
            "w-[232px] px-[8px] pt-[4px] pb-[12px] transition-[opacity,transform] duration-200 ease-out",
            visible
              ? "translate-y-0 scale-100 opacity-100"
              : "translate-y-[6px] scale-[0.97] opacity-0",
          )}
        >
          <div className="group relative pt-[8px]">
            {/* Two earlier releases peeking out behind the card. */}
            <div
              aria-hidden
              className="absolute inset-x-[14px] top-0 h-[24px] rounded-[10px] border border-[var(--st-border)] bg-[var(--st-bg)] opacity-60 transition-transform duration-200 ease-out group-hover:-translate-y-[2px]"
            />
            <div
              aria-hidden
              className="absolute inset-x-[7px] top-[4px] h-[24px] rounded-[10px] border border-[var(--st-border)] bg-[var(--st-bg)] opacity-85 shadow-[var(--st-shadow)] transition-transform duration-200 ease-out group-hover:-translate-y-[1px]"
            />
            <article className="relative overflow-hidden rounded-[10px] border border-[var(--st-border)] bg-[var(--st-bg)] shadow-[0_1px_2px_rgba(9,9,11,0.06),0_8px_20px_-12px_rgba(9,9,11,0.25)] transition-[border-color,box-shadow,transform] duration-200 ease-out group-hover:-translate-y-px group-hover:border-[var(--st-border-strong)] group-hover:shadow-[0_1px_2px_rgba(9,9,11,0.06),0_14px_28px_-14px_rgba(9,9,11,0.35)]">
              <div className="relative m-[4px] h-[56px] overflow-hidden rounded-[7px] ring-1 ring-black/5 ring-inset">
                <ImageFill
                  src={image.src}
                  from={image.from}
                  to={image.to}
                  className="transition-transform duration-500 ease-out group-hover:scale-[1.04]"
                />
                <div className="absolute inset-0 bg-gradient-to-t from-black/45 via-black/5 to-transparent" />
                <span className="absolute bottom-[6px] left-[7px] inline-flex h-[18px] items-center gap-[4px] rounded-[5px] bg-black/40 px-[6px] text-[10.5px] font-semibold text-white ring-1 ring-white/15 backdrop-blur-[6px]">
                  <Sparkles size={10} strokeWidth={2} />
                  What's new
                </span>
              </div>
              <div className="px-[10px] pt-[6px] pb-[10px]">
                <div className="flex items-center gap-[6px]">
                  {fresh ? (
                    <span className="size-[6px] shrink-0 rounded-full bg-[var(--st-accent)]" />
                  ) : null}
                  <h3 className="truncate text-[12.5px] leading-[17px] font-semibold tracking-[-0.01em] text-[var(--st-fg)]">
                    {latest.version}: {latest.title}
                  </h3>
                </div>
                <p className="mt-[3px] line-clamp-2 text-[11.5px] leading-[16px] text-[var(--st-fg2)]">
                  {latest.summary}
                </p>
              </div>
              <button
                type="button"
                onClick={onOpen}
                aria-label={`What's new in Macarchy ${latest.version}: ${latest.title}. Open the changelog`}
                className="absolute inset-0 rounded-[10px] focus-visible:ring-2 focus-visible:ring-[var(--st-accent)] focus-visible:outline-none focus-visible:ring-inset"
              />
              <button
                type="button"
                onClick={onDismiss}
                aria-label="Dismiss what's new"
                title="Dismiss"
                className="absolute top-[9px] right-[9px] grid size-[20px] place-items-center rounded-full bg-black/40 text-white/85 opacity-0 ring-1 ring-white/15 backdrop-blur-[6px] transition-[opacity,background-color] duration-150 group-hover:opacity-100 hover:bg-black/60 hover:text-white focus-visible:opacity-100 focus-visible:ring-2 focus-visible:ring-[var(--st-accent)] focus-visible:outline-none"
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

/* ------------------------------------------------------------------ */
/* Page                                                                */
/* ------------------------------------------------------------------ */

const filters = ["All", "New", "Improved", "Fixed"] as const;
type Filter = (typeof filters)[number];
const filterKind: Record<Filter, EntryKind | null> = {
  All: null,
  New: "new",
  Improved: "improved",
  Fixed: "fixed",
};

export function ChangelogPage({ lastSeen, onSeen }: { lastSeen: string; onSeen: () => void }) {
  // Keep what was unseen on arrival so the markers stay for this visit.
  const [baseline] = useState(lastSeen);
  const [filter, setFilter] = useState<Filter>("All");
  const [subscribed, setSubscribed] = useState(true);
  const [active, setActive] = useState(latest.version);
  const list = useRef<HTMLDivElement>(null);

  useEffect(() => onSeen(), [onSeen]);

  const kind = filterKind[filter];
  const shown = releases
    .map((r) => ({ ...r, entries: kind ? r.entries.filter((e) => e.kind === kind) : r.entries }))
    .filter((r) => r.entries.length > 0);
  const unseen = releases.filter((r) => isNewer(r.version, baseline)).length;

  useEffect(() => {
    const scroller = list.current?.closest("main");
    if (!scroller || !list.current) return;
    const items = [...list.current.querySelectorAll<HTMLElement>("[data-version]")];
    const update = () => {
      const top = scroller.getBoundingClientRect().top;
      let current = items[0];
      for (const el of items) if (el.getBoundingClientRect().top - top <= 120) current = el;
      if (scroller.scrollTop + scroller.clientHeight >= scroller.scrollHeight - 2) {
        current = items[items.length - 1];
      }
      if (current?.dataset.version) setActive(current.dataset.version);
    };
    update();
    scroller.addEventListener("scroll", update, { passive: true });
    return () => scroller.removeEventListener("scroll", update);
  }, [filter]);

  const jump = (version: string) =>
    list.current
      ?.querySelector(`[data-version="${version}"]`)
      ?.scrollIntoView({ behavior: "smooth", block: "start" });

  return (
    <div>
      <PageHeader title="Changelog" />

      <div className="grid grid-cols-[minmax(0,1fr)_176px] items-start gap-[40px]">
        <div ref={list}>
          <div className="mb-[20px] flex items-center justify-between gap-[12px] border-b border-[var(--st-border)] pb-[12px]">
            <span className="flex items-center gap-[8px] text-[12.5px] text-[var(--st-fg2)]">
              {unseen > 0 ? (
                <>
                  <span aria-hidden className="size-[6px] rounded-full bg-[var(--st-accent)]" />
                  {unseen} new {unseen === 1 ? "release" : "releases"}
                </>
              ) : (
                `${shown.length} ${shown.length === 1 ? "release" : "releases"}`
              )}
            </span>
            <Segmented options={filters} value={filter} onChange={setFilter} size="sm" />
          </div>
          {shown.length === 0 ? (
            <EmptyState title="No matching releases" />
          ) : (
            shown.map((r, i) => {
              const isNew = isNewer(r.version, baseline);
              const last = i === shown.length - 1;
              const hero = r.hero ? art(r.hero.theme) : null;
              return (
                <article
                  key={r.version}
                  data-version={r.version}
                  aria-labelledby={`changelog-${r.version}`}
                  className="grid scroll-mt-[24px] grid-cols-[92px_minmax(0,1fr)]"
                >
                  <div className="sticky top-[20px] flex flex-col items-start gap-[6px] self-start pt-[1px] pr-[16px]">
                    <span className="rounded-[6px] border border-[var(--st-border)] bg-[var(--st-side)] px-[7px] py-[1px] font-mono text-[12px] font-medium tabular-nums text-[var(--st-fg)]">
                      {r.version}
                    </span>
                    <time
                      dateTime={r.date}
                      className="text-[11.5px] tabular-nums text-[var(--st-fg3)]"
                    >
                      {formatDate(r.date)}
                    </time>
                    {isNew ? (
                      <Badge tone="accent" dot>
                        New
                      </Badge>
                    ) : null}
                  </div>

                  <div
                    className={cx(
                      "relative border-l border-[var(--st-border)] pl-[28px]",
                      last ? "pb-[8px]" : "pb-[44px]",
                    )}
                  >
                    <span
                      aria-hidden
                      className={cx(
                        "absolute top-[7px] -left-[5px] size-[9px] rounded-full ring-4 ring-[var(--st-bg)]",
                        isNew ? "bg-[var(--st-accent)]" : "bg-[var(--st-border-strong)]",
                      )}
                    />
                    <h2
                      id={`changelog-${r.version}`}
                      className="text-[17px] leading-[24px] font-semibold tracking-[-0.015em] text-[var(--st-fg)]"
                    >
                      {r.title}
                    </h2>
                    <p className="mt-[4px] text-[13px] leading-[20px] text-[var(--st-fg2)]">
                      {r.summary}
                    </p>

                    {hero && r.hero ? (
                      <figure className="relative mt-[16px] aspect-[12/5] overflow-hidden rounded-[10px] border border-[var(--st-border)] shadow-[var(--st-shadow)]">
                        <ImageFill
                          src={hero.src}
                          from={hero.from}
                          to={hero.to}
                          alt={r.hero.caption}
                        />
                        <div className="absolute inset-0 bg-gradient-to-t from-black/35 to-transparent to-50%" />
                        <figcaption className="absolute bottom-[10px] left-[12px] rounded-[5px] bg-black/40 px-[7px] py-[2px] text-[11px] font-medium text-white ring-1 ring-white/15 backdrop-blur-[6px]">
                          {r.hero.caption}
                        </figcaption>
                      </figure>
                    ) : null}

                    <div className="mt-[16px] flex flex-col gap-[14px]">
                      {kindOrder.map((k) => {
                        const items = r.entries.filter((e) => e.kind === k);
                        if (items.length === 0) return null;
                        return (
                          <section key={k} aria-label={kinds[k].label}>
                            <Tag kind={k} />
                            <ul className="mt-[8px] flex flex-col gap-[6px]">
                              {items.map((e) => (
                                <li
                                  key={e.text}
                                  className="relative pl-[14px] text-[13px] leading-[19px] text-[var(--st-fg)]"
                                >
                                  <span
                                    aria-hidden
                                    className="absolute top-[8px] left-[2px] size-[4px] rounded-full bg-[var(--st-fg3)]"
                                  />
                                  {e.text}
                                </li>
                              ))}
                            </ul>
                          </section>
                        );
                      })}
                    </div>
                  </div>
                </article>
              );
            })
          )}
        </div>

        <aside className="sticky top-[20px] flex flex-col gap-[16px]">
          <nav aria-label="Releases">
            <div className="mb-[8px] px-[8px] text-[11.5px] font-semibold tracking-[0.04em] text-[var(--st-fg3)] uppercase">
              Releases
            </div>
            <ul className="relative flex flex-col gap-[1px] before:absolute before:inset-y-[6px] before:left-0 before:w-px before:bg-[var(--st-border)]">
              {shown.map((r) => {
                const on = active === r.version;
                return (
                  <li key={r.version} className="relative">
                    {on ? (
                      <span
                        aria-hidden
                        className="absolute inset-y-[6px] left-0 w-[2px] rounded-full bg-[var(--st-fg)]"
                      />
                    ) : null}
                    <button
                      type="button"
                      aria-current={on ? "location" : undefined}
                      onClick={() => jump(r.version)}
                      className={cx(
                        "flex h-[28px] w-full items-center gap-[8px] rounded-[6px] pr-[8px] pl-[12px] text-left text-[12.5px] transition-colors",
                        focusRing,
                        on
                          ? "font-medium text-[var(--st-fg)]"
                          : "text-[var(--st-fg2)] hover:text-[var(--st-fg)]",
                      )}
                    >
                      <span className="w-[38px] shrink-0 font-mono text-[12px] tabular-nums">
                        {r.version}
                      </span>
                      <span className="min-w-0 flex-1 truncate text-[11.5px] text-[var(--st-fg3)]">
                        {formatDate(r.date).replace(/ \d{4}$/, "")}
                      </span>
                      {isNewer(r.version, baseline) ? (
                        <span className="size-[6px] shrink-0 rounded-full bg-[var(--st-accent)]">
                          <span className="sr-only">New</span>
                        </span>
                      ) : null}
                    </button>
                  </li>
                );
              })}
            </ul>
          </nav>

          <Card className="p-[12px]">
            <div className="flex items-center gap-[10px]">
              <span className="grid size-[26px] shrink-0 place-items-center rounded-[7px] border border-[var(--st-border)] bg-[var(--st-side)] text-[var(--st-fg2)]">
                <Bell size={13} strokeWidth={1.75} />
              </span>
              <span className="min-w-0 flex-1 text-[12.5px] leading-[18px] font-medium text-[var(--st-fg)]">
                Notify on release
              </span>
              <Switch checked={subscribed} onChange={setSubscribed} label="Notify on release" />
            </div>
          </Card>
        </aside>
      </div>
    </div>
  );
}
