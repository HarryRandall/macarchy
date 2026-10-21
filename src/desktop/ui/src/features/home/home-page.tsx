import {
  Clock,
  Command,
  LayoutPanelLeft,
  Palette,
  PanelTop,
  Puzzle,
  SquareDashed,
  type LucideIcon,
} from "lucide-react";
import { PageHeader } from "~/components/layout/page-header";
import { SectionHeading } from "~/components/layout/section-heading";
import { SettingRow } from "~/components/layout/setting-row";
import { SettingsSection } from "~/components/layout/settings-section";
import { Button } from "~/components/ui/button";
import { HeroCard } from "~/components/ui/hero-card";
import { type Tint } from "~/components/ui/icon-tile";
import { OverviewActionCard } from "~/components/ui/overview-action-card";
import { StatTile } from "~/components/ui/stat-tile";
import { StatusChip } from "~/components/ui/status-chip";
import { Spinner } from "~/components/ui/spinner";
import { ReadNotice } from "~/features/overview/read-notice";
import { useStore } from "~/lib/store";
import type { PageContext } from "~/shell/page";
import type { PaneId } from "~/bridge/protocol";
import type { HomeStore } from "./home-store";

const actions: {
  pane: PaneId;
  title: string;
  icon: LucideIcon;
  detail: string;
  tint: Tint;
  preview?: boolean;
}[] = [
  {
    pane: "themes",
    title: "Themes",
    icon: Palette,
    detail: "Wallpaper, colours and the whole look",
    tint: "purple",
  },
  {
    pane: "menuBar",
    title: "Menu Bar",
    icon: PanelTop,
    detail: "Your essentials, arranged your way",
    tint: "blue",
  },
  {
    pane: "borders",
    title: "Borders",
    icon: SquareDashed,
    detail: "A little definition for your windows",
    tint: "teal",
  },
  {
    pane: "layout",
    title: "Layout",
    icon: LayoutPanelLeft,
    detail: "Give every window a place",
    tint: "orange",
  },
  {
    pane: "shortcuts",
    title: "Shortcuts",
    icon: Command,
    detail: "Less reaching, more doing",
    tint: "pink",
  },
  {
    pane: "plugins",
    title: "Plugins",
    icon: Puzzle,
    detail: "A preview of tools for your desktop",
    tint: "green",
    preview: true,
  },
];

export function lastChangeLabel(timestamp: number | null) {
  if (timestamp === null) return "Never";
  const minutes = Math.max(0, Math.floor((Date.now() / 1000 - timestamp) / 60));
  if (minutes === 0) return "Just now";
  const formatter = new Intl.RelativeTimeFormat("en-GB", { style: "short" });
  if (minutes < 60) return formatter.format(-minutes, "minute");
  if (minutes < 1440) return formatter.format(-Math.floor(minutes / 60), "hour");
  return formatter.format(-Math.floor(minutes / 1440), "day");
}

export function HomePage({ store, context }: { store: HomeStore; context: PageContext }) {
  const snapshot = useStore(store);
  const state = snapshot.state;
  return (
    <>
      <PageHeader title="Home" subtitle={state?.subtitle ?? "A space that works for you."} />
      <ReadNotice
        error={snapshot.error}
        retry={() => void store.load()}
        busy={snapshot.refreshing}
      />
      {!state ? (
        snapshot.status === "loading" ? (
          <Spinner label="Loading your desktop" />
        ) : null
      ) : (
        <>
          <HeroCard
            layout="overlay"
            artworkHeight={210}
            eyebrow="Your desktop"
            title={state.theme ?? "Make room for your next idea."}
            artwork={
              <div className="size-full bg-[linear-gradient(135deg,var(--accent),#141414)]">
                {state.wallpaper ? (
                  <img src={state.wallpaper} alt="" className="size-full object-cover" />
                ) : null}
              </div>
            }
            meta={
              <>
                <StatusChip
                  tone={state.running === state.total ? "success" : "warning"}
                  label={`${state.running}/${state.total} services`}
                  live={state.running === state.total}
                />
                <StatusChip label={`${state.themeCount} themes`} />
              </>
            }
            actions={<Button onClick={() => context.navigate("themes")}>Browse themes</Button>}
          />
          <div className="grid grid-cols-[repeat(auto-fit,minmax(140px,1fr))] gap-3">
            <StatTile
              icon={<Palette />}
              value={String(state.themeCount)}
              caption="Themes"
              tint="purple"
              emphasis
            />
            <StatTile
              icon={<Command />}
              value={String(state.shortcutsCount)}
              caption="Shortcuts"
              tint="blue"
              emphasis
            />
            <StatTile
              icon={<LayoutPanelLeft />}
              value={{ bsp: "Tiled", stack: "Stacked", float: "Freeform" }[state.layout]}
              caption="Layout"
              tint="teal"
            />
            <StatTile
              icon={<Clock />}
              value={lastChangeLabel(state.lastChange)}
              caption="Last change"
              tint="orange"
            />
          </div>
          <SectionHeading title="Make it feel right" />
          <div className="grid grid-cols-[repeat(auto-fit,minmax(220px,1fr))] gap-3">
            {actions.map(({ pane, title, icon: Icon, detail, tint, preview }) => {
              const label = `${title}${preview ? " (preview)" : ""}`;
              return (
                <OverviewActionCard
                  key={pane}
                  title={label}
                  detail={detail}
                  icon={<Icon aria-hidden />}
                  tint={tint}
                  onClick={() => context.navigate(pane)}
                  aria-label={`${label}. ${detail}`}
                />
              );
            })}
          </div>
          <SettingsSection title="Explore">
            <SettingRow title="Workshop (preview)" help="Preview themes and menu bar designs.">
              <Button onClick={() => context.navigate("workshop")}>Open Workshop preview</Button>
            </SettingRow>
          </SettingsSection>
        </>
      )}
    </>
  );
}
