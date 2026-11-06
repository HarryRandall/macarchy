import { ChevronRight, Search } from "lucide-react";
import { useEffect, useMemo, useState } from "react";

import { usePageSearch } from "~/components/layout/page-chrome";
import { PageHeader } from "~/components/layout/page-header";
import { Button } from "~/components/ui/button";
import { SectionLabel } from "~/components/ui/card";
import { EmptyState } from "~/components/ui/empty-state";
import { focusRing } from "~/components/ui/focus-ring";
import { Notice } from "~/components/ui/notice";
import { TabPanel, Tabs } from "~/components/ui/tabs";
import { cn } from "~/lib/cn";
import { useStore } from "~/lib/store";

import { ItemCard, type ItemStatus, WallpaperTile } from "./workshop-cards";
import { Cover } from "./workshop-cover";
import { DetailDialog, type Opened } from "./workshop-detail";
import { WorkshopHero } from "./workshop-hero";
import {
  appliedOnDesktop,
  buildCatalogue,
  matchesQuery,
  readInstalled,
  siblingsOf,
  writeInstalled,
} from "./workshop-items";
import type { Kind, WorkshopItem } from "./workshop-mock";
import type { WorkshopStore } from "./workshop-store";

type Tab = "all" | Kind;

const tabs: { id: Tab; label: string }[] = [
  { id: "all", label: "All" },
  { id: "theme", label: "Themes" },
  { id: "wallpaper", label: "Wallpapers" },
  { id: "layout", label: "Layouts" },
  { id: "bar", label: "Bars" },
];

/** How many of each kind the All view shows before "See all". */
const previewLimits: Record<Kind, number> = { theme: 9, wallpaper: 12, layout: 6, bar: 6 };

const cardGrid = "grid grid-cols-2 gap-3 @[600px]:grid-cols-3";
const tileGrid = "grid grid-cols-3 gap-2.5 @[600px]:grid-cols-4";

function browserStorage(): Storage | undefined {
  try {
    return globalThis.localStorage;
  } catch {
    return undefined;
  }
}

/**
 * Community themes, wallpapers, layouts and bars to try on. A preview: the
 * themes and wallpapers already on this Mac are real, the rest is a
 * placeholder catalogue, and nothing here changes the desktop.
 */
export function WorkshopPage({ store }: { store: WorkshopStore }) {
  const snapshot = useStore(store);
  const [tab, setTab] = useState<Tab>("all");
  const [query, setQuery] = usePageSearch("Search the Workshop");
  // Mock: installing only records the item here, since there is nothing to download.
  const [saved, setSaved] = useState<string[]>(() => readInstalled(browserStorage()));
  const [kept, setKept] = useState<Partial<Record<Kind, string>>>({});
  const [trying, setTrying] = useState<string | null>(null);
  const [opened, setOpened] = useState<Opened | null>(null);

  useEffect(() => writeInstalled(browserStorage(), saved), [saved]);

  const { installed, current: inUse } = snapshot;
  const catalogue = useMemo(() => buildCatalogue(installed), [installed]);
  const applied = useMemo(
    () => ({ ...appliedOnDesktop(installed, inUse), ...kept }),
    [installed, inUse, kept],
  );
  const installedIds = useMemo(() => {
    const local = catalogue.all.filter((item) => item.local).map((item) => item.id);
    return new Set([...local, ...saved]);
  }, [catalogue, saved]);

  if (snapshot.status === "loading") return null;

  const searching = query.trim().length > 0;
  const matches = catalogue.all.filter((item) => matchesQuery(item, query));
  const byKind = (kind: Kind) => matches.filter((item) => item.kind === kind);
  const counts: Record<Tab, number> = {
    all: matches.length,
    theme: byKind("theme").length,
    wallpaper: byKind("wallpaper").length,
    layout: byKind("layout").length,
    bar: byKind("bar").length,
  };

  const isInUse = (item: WorkshopItem) => applied[item.kind] === item.id && trying !== item.id;
  const status = (item: WorkshopItem): ItemStatus => ({
    installed: installedIds.has(item.id),
    inUse: isInUse(item),
    trying: trying === item.id,
  });
  const tryingItem = catalogue.all.find((item) => item.id === trying);
  const openItem = opened ? catalogue.all.find((item) => item.id === opened.id) : undefined;

  const install = (id: string) =>
    setSaved((current) => (current.includes(id) ? current : [...current, id]));
  const keep = (item: WorkshopItem) => {
    if (!installedIds.has(item.id)) install(item.id);
    setKept((current) => ({ ...current, [item.kind]: item.id }));
    setTrying(null);
  };
  const open = (item: WorkshopItem, index = 0) =>
    setOpened((current) => ({
      id: item.id,
      index,
      open: true,
      opening: (current?.opening ?? 0) + 1,
    }));

  const card = (item: WorkshopItem) => (
    <ItemCard
      key={item.id}
      item={item}
      status={status(item)}
      onOpen={() => open(item)}
      onTry={() => setTrying(item.id)}
    />
  );
  const tile = (item: WorkshopItem) => (
    <WallpaperTile key={item.id} item={item} status={status(item)} onOpen={() => open(item)} />
  );

  const section = (kind: Kind) => {
    const list = byKind(kind);
    if (list.length === 0) return null;
    const limit = searching ? list.length : previewLimits[kind];
    const shown = list.slice(0, limit);
    const label = tabs.find((entry) => entry.id === kind)?.label ?? kind;
    return (
      <section key={kind} className="mb-7">
        <SectionLabel
          action={
            list.length > limit ? (
              <button
                type="button"
                onClick={() => setTab(kind)}
                className={cn(
                  "flex items-center gap-0.5 rounded-[4px] text-small font-medium text-accent-text hover:underline",
                  focusRing,
                )}
              >
                See all {list.length}
                <span className="sr-only"> {label.toLowerCase()}</span>
                <ChevronRight aria-hidden size={12} />
              </button>
            ) : (
              <span className="text-meta text-fg-tertiary tabular-nums">{list.length}</span>
            )
          }
        >
          {label}
        </SectionLabel>
        {kind === "wallpaper" ? (
          <ul aria-label={label} className={tileGrid}>
            {shown.map(tile)}
          </ul>
        ) : (
          <ul aria-label={label} className={cardGrid}>
            {shown.map(card)}
          </ul>
        )}
      </section>
    );
  };

  const empty = matches.length === 0 || (tab !== "all" && counts[tab] === 0);
  const wallpapers = byKind("wallpaper");
  const lead = catalogue.featured;

  return (
    <>
      <PageHeader title="Workshop" />

      <div className="@container flex flex-col">
        {snapshot.error ? (
          <Notice.Root variant="warning" className="mb-4">
            <Notice.Title>Could not read your installed themes</Notice.Title>
            <Notice.Description>{snapshot.error}</Notice.Description>
            <Notice.Actions>
              <Button size="sm" onClick={() => void store.load()}>
                Try again
              </Button>
            </Notice.Actions>
          </Notice.Root>
        ) : null}

        {tryingItem ? (
          <div
            role="status"
            className="sticky top-2 z-10 mb-4 flex items-center gap-3 rounded-card border border-accent bg-card px-3 py-2 shadow-pop"
          >
            <div
              aria-hidden
              className="relative h-8 w-12 shrink-0 overflow-hidden rounded-[5px] border border-hairline"
            >
              <Cover item={tryingItem} labelMissing={false} />
            </div>
            <span
              aria-hidden
              className="size-2 shrink-0 animate-pulse rounded-full bg-accent motion-reduce:animate-none"
            />
            <div className="min-w-0 flex-1">
              <p className="truncate text-body text-fg">
                Trying <span className="font-semibold">{tryingItem.name}</span>
              </p>
              <p className="truncate text-small text-fg-tertiary">
                A preview: your desktop stays as it is.
              </p>
            </div>
            <Button size="sm" variant="ghost" onClick={() => setTrying(null)}>
              Revert
            </Button>
            <Button size="sm" variant="primary" onClick={() => keep(tryingItem)}>
              Keep it
            </Button>
          </div>
        ) : null}

        {!searching && lead ? (
          <WorkshopHero
            item={lead}
            image={catalogue.featuredImage}
            status={status(lead)}
            onTry={() => setTrying(lead.id)}
            onOpen={(index) => open(lead, index)}
          />
        ) : null}

        <Tabs
          id="workshop"
          label="Workshop views"
          className="mb-5"
          tabs={tabs.map((entry) => ({ ...entry, count: counts[entry.id] }))}
          value={tab}
          onChange={setTab}
        />

        <TabPanel tabs="workshop" value={tab}>
          {empty ? (
            <EmptyState
              icon={<Search />}
              title="Nothing matches"
              action={
                searching ? (
                  <Button size="sm" onClick={() => setQuery("")}>
                    Clear search
                  </Button>
                ) : undefined
              }
            />
          ) : tab === "all" ? (
            <>
              {section("theme")}
              {section("wallpaper")}
              {section("layout")}
              {section("bar")}
            </>
          ) : tab === "wallpaper" ? (
            <>
              <p className="mb-3 text-small text-fg-tertiary">
                {counts.wallpaper} backgrounds from{" "}
                {new Set(wallpapers.map((item) => item.group)).size} themes
              </p>
              <ul aria-label="Wallpapers" className={tileGrid}>
                {wallpapers.map(tile)}
              </ul>
            </>
          ) : (
            <ul aria-label={tabs.find((entry) => entry.id === tab)?.label} className={cardGrid}>
              {byKind(tab).map(card)}
            </ul>
          )}
        </TabPanel>
      </div>

      <DetailDialog
        opened={opened}
        item={openItem}
        siblings={openItem ? siblingsOf(catalogue.all, openItem) : []}
        isInstalled={(item) => installedIds.has(item.id)}
        isInUse={isInUse}
        onClose={() => setOpened((current) => (current ? { ...current, open: false } : null))}
        onInstall={(item) => install(item.id)}
        onTry={(item) => {
          setTrying(item.id);
          setOpened((current) => (current ? { ...current, open: false } : null));
        }}
      />
    </>
  );
}
