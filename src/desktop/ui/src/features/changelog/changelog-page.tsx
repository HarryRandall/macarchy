import { Bell } from "lucide-react";
import { useEffect, useRef, useState } from "react";

import { PageHeader } from "~/components/layout/page-header";
import { Badge } from "~/components/ui/badge";
import { Card } from "~/components/ui/card";
import { EmptyState } from "~/components/ui/empty-state";
import { SegmentedControl } from "~/components/ui/segmented-control";
import { Switch } from "~/components/ui/switch";
import { cn } from "~/lib/cn";
import { isNewer } from "~/lib/version";

import { type ChangeKind, releases } from "./changelog-mock";
import { seenBaseline } from "./changelog-seen";
import { ReleaseArt } from "./release-art";

const kinds: Record<ChangeKind, { label: string; tag: string; dot: string }> = {
  new: { label: "New", tag: "bg-accent-soft text-accent-text", dot: "bg-accent" },
  improved: { label: "Improved", tag: "bg-success-soft text-success", dot: "bg-success" },
  fixed: { label: "Fixed", tag: "bg-warning-soft text-warning", dot: "bg-warning" },
};
const kindOrder: ChangeKind[] = ["new", "improved", "fixed"];

type Filter = "all" | ChangeKind;
const filters: { value: Filter; label: string }[] = [
  { value: "all", label: "All" },
  { value: "new", label: "New" },
  { value: "improved", label: "Improved" },
  { value: "fixed", label: "Fixed" },
];

const dateFormat = new Intl.DateTimeFormat("en-GB", {
  day: "numeric",
  month: "short",
  year: "numeric",
});
const shortDateFormat = new Intl.DateTimeFormat("en-GB", { day: "numeric", month: "short" });
const atNoon = (iso: string) => new Date(`${iso}T12:00:00`);

function Tag({ kind }: { kind: ChangeKind }) {
  return (
    <span
      className={cn(
        "inline-flex h-[19px] items-center gap-[5px] rounded-[5px] px-1.5 text-[11px] font-semibold tracking-[0.01em] whitespace-nowrap",
        kinds[kind].tag,
      )}
    >
      <span aria-hidden className={cn("size-[5px] rounded-full", kinds[kind].dot)} />
      {kinds[kind].label}
    </span>
  );
}

/**
 * Release notes, newest first, with a contents rail that follows the scroll.
 * Opening the page marks the latest release as read; the markers stay for
 * the rest of the visit.
 */
export function ChangelogPage({
  lastSeen,
  onSeen,
}: {
  lastSeen: string | null;
  onSeen: () => void;
}) {
  const [baseline] = useState(() => seenBaseline(lastSeen));
  const [filter, setFilter] = useState<Filter>("all");
  // Mock: there is no release notification yet, so the switch only remembers its position here.
  const [notify, setNotify] = useState(true);
  // Mock: releases come from the placeholder changelog until there is a release feed.
  const [active, setActive] = useState(releases[0]?.version ?? "");
  const list = useRef<HTMLDivElement>(null);

  useEffect(() => onSeen(), [onSeen]);

  const shown = releases
    .map((release) => ({
      ...release,
      entries:
        filter === "all" ? release.entries : release.entries.filter((e) => e.kind === filter),
    }))
    .filter((release) => release.entries.length > 0);
  const unseen = releases.filter((release) => isNewer(release.version, baseline)).length;

  useEffect(() => {
    const scroller = list.current?.closest("main");
    if (!scroller || !list.current) return;
    const items = [...list.current.querySelectorAll<HTMLElement>("[data-version]")];
    const update = () => {
      const top = scroller.getBoundingClientRect().top;
      let current = items[0];
      for (const item of items) if (item.getBoundingClientRect().top - top <= 120) current = item;
      if (scroller.scrollTop + scroller.clientHeight >= scroller.scrollHeight - 2) {
        current = items.at(-1);
      }
      if (current?.dataset.version) setActive(current.dataset.version);
    };
    update();
    scroller.addEventListener("scroll", update, { passive: true });
    return () => scroller.removeEventListener("scroll", update);
  }, [filter]);

  const jump = (version: string) => {
    const reduce = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
    list.current
      ?.querySelector(`[data-version="${version}"]`)
      ?.scrollIntoView({ behavior: reduce ? "auto" : "smooth", block: "start" });
  };

  return (
    <div className="@container">
      <PageHeader title="Changelog" />

      <div className="grid grid-cols-1 items-start gap-10 @[620px]:grid-cols-[minmax(0,1fr)_176px]">
        <div ref={list}>
          <div className="mb-5 flex items-center justify-between gap-3 border-b border-hairline pb-3">
            <span className="flex items-center gap-2 text-[12.5px] text-fg-secondary">
              {unseen > 0 ? (
                <>
                  <span aria-hidden className="size-1.5 rounded-full bg-accent" />
                  {unseen} new {unseen === 1 ? "release" : "releases"}
                </>
              ) : (
                `${shown.length} ${shown.length === 1 ? "release" : "releases"}`
              )}
            </span>
            <SegmentedControl
              label="Show changes"
              value={filter}
              options={filters}
              onValueChange={setFilter}
            />
          </div>
          {shown.length === 0 ? (
            <EmptyState title="No matching releases" />
          ) : (
            shown.map((release, index) => {
              const isNew = isNewer(release.version, baseline);
              const last = index === shown.length - 1;
              return (
                <article
                  key={release.version}
                  data-version={release.version}
                  aria-labelledby={`changelog-${release.version}`}
                  className="grid scroll-mt-6 grid-cols-[92px_minmax(0,1fr)]"
                >
                  <div className="sticky top-5 flex flex-col items-start gap-1.5 self-start pt-px pr-4">
                    <span className="rounded-[6px] border border-hairline bg-side px-[7px] py-px font-mono text-[12px] font-medium tabular-nums text-fg">
                      {release.version}
                    </span>
                    <time
                      dateTime={release.date}
                      className="text-[11.5px] tabular-nums text-fg-tertiary"
                    >
                      {dateFormat.format(atNoon(release.date))}
                    </time>
                    {isNew ? <Badge tone="accent">New</Badge> : null}
                  </div>

                  <div
                    className={cn(
                      "relative min-w-0 border-l border-hairline pl-7",
                      last ? "pb-2" : "pb-11",
                    )}
                  >
                    <span
                      aria-hidden
                      className={cn(
                        "absolute top-[7px] -left-[5px] size-[9px] rounded-full ring-4 ring-page",
                        isNew ? "bg-accent" : "bg-line-strong",
                      )}
                    />
                    <h2
                      id={`changelog-${release.version}`}
                      className="text-[17px] leading-6 font-semibold tracking-[-0.015em] text-fg"
                    >
                      {release.title}
                    </h2>
                    <p className="mt-1 text-[13px] leading-5 text-fg-secondary">
                      {release.summary}
                    </p>

                    {release.art ? (
                      <figure className="relative mt-4 aspect-[12/5] overflow-hidden rounded-[10px] border border-hairline shadow-card">
                        <ReleaseArt art={release.art} />
                        <div className="absolute inset-0 bg-gradient-to-t from-black/35 to-transparent to-50%" />
                        <figcaption className="absolute bottom-2.5 left-3 rounded-[5px] bg-black/40 px-[7px] py-0.5 text-[11px] font-medium text-white ring-1 ring-white/15 backdrop-blur-[6px]">
                          {release.art.caption}
                        </figcaption>
                      </figure>
                    ) : null}

                    <div className="mt-4 flex flex-col gap-3.5">
                      {kindOrder.map((kind) => {
                        const items = release.entries.filter((e) => e.kind === kind);
                        if (items.length === 0) return null;
                        return (
                          <section key={kind} aria-label={kinds[kind].label}>
                            <Tag kind={kind} />
                            <ul className="mt-2 flex flex-col gap-1.5">
                              {items.map((item) => (
                                <li
                                  key={item.text}
                                  className="relative pl-3.5 text-[13px] leading-[19px] text-fg select-text"
                                >
                                  <span
                                    aria-hidden
                                    className="absolute top-2 left-0.5 size-1 rounded-full bg-fg-tertiary"
                                  />
                                  {item.text}
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

        <aside className="sticky top-5 hidden flex-col gap-4 @[620px]:flex">
          <nav aria-label="Releases">
            <div className="mb-2 px-2 text-[11.5px] font-semibold tracking-[0.04em] text-fg-tertiary uppercase">
              Releases
            </div>
            <ul className="relative flex flex-col gap-px before:absolute before:inset-y-1.5 before:left-0 before:w-px before:bg-hairline">
              {shown.map((release) => {
                const on = active === release.version;
                return (
                  <li key={release.version} className="relative">
                    {on ? (
                      <span
                        aria-hidden
                        className="absolute inset-y-1.5 left-0 w-0.5 rounded-full bg-fg"
                      />
                    ) : null}
                    <button
                      type="button"
                      aria-current={on ? "location" : undefined}
                      onClick={() => jump(release.version)}
                      className={cn(
                        "flex h-7 w-full items-center gap-2 rounded-[6px] pr-2 pl-3 text-left text-[12.5px] transition-colors focus-visible:ring-2 focus-visible:ring-accent focus-visible:outline-none",
                        on ? "font-medium text-fg" : "text-fg-secondary hover:text-fg",
                      )}
                    >
                      <span className="w-[38px] shrink-0 font-mono text-[12px] tabular-nums">
                        {release.version}
                      </span>
                      <span className="min-w-0 flex-1 truncate text-[11.5px] text-fg-tertiary">
                        {shortDateFormat.format(atNoon(release.date))}
                      </span>
                      {isNewer(release.version, baseline) ? (
                        <span className="size-1.5 shrink-0 rounded-full bg-accent">
                          <span className="sr-only">New</span>
                        </span>
                      ) : null}
                    </button>
                  </li>
                );
              })}
            </ul>
          </nav>

          <Card className="p-3">
            <div className="flex items-center gap-2.5">
              <span
                aria-hidden
                className="grid size-[26px] shrink-0 place-items-center rounded-[7px] border border-hairline bg-side text-fg-secondary"
              >
                <Bell size={13} strokeWidth={1.75} />
              </span>
              <span className="min-w-0 flex-1 text-[12.5px] leading-[18px] font-medium text-fg">
                Notify on release
              </span>
              <Switch
                checked={notify}
                onCheckedChange={(checked) => setNotify(checked)}
                aria-label="Notify on release"
              />
            </div>
          </Card>
        </aside>
      </div>
    </div>
  );
}
