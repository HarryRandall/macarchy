import { useState } from "react";
import { PageHeader } from "~/components/layout/page-header";
import { Card, SectionLabel } from "~/components/ui/card";
import { Notice } from "~/components/ui/notice";
import { Spinner } from "~/components/ui/spinner";
import { Stat, StatStrip } from "~/components/ui/stat";
import { ReadNotice } from "~/features/overview/read-notice";
import { themeLook } from "~/features/themes/theme-look";
import type { ThemesStore } from "~/features/themes/themes-store";
import { useStore } from "~/lib/store";
import type { PageContext } from "~/shell/page";
import { relativeTime } from "./home-activity";
import { HomeActivity } from "./home-activity-card";
import { HomeHero } from "./home-hero";
import { HomeInsights } from "./home-insights";
import { HomeIntegrations, layoutNames } from "./home-integrations";
import type { HomeStore } from "./home-store";
import type { ActivityStores, ServiceSwitches } from "./services-store";

export function HomePage({
  store,
  themes,
  activity,
  switches,
  context,
}: {
  store: HomeStore;
  themes: ThemesStore;
  activity: ActivityStores;
  switches: ServiceSwitches;
  context: PageContext;
}) {
  const snapshot = useStore(store);
  const themesSnapshot = useStore(themes);
  const shell = useStore(activity.shell);
  const log = useStore(activity.log);
  const switching = useStore(switches);
  const [today] = useState(() => new Date());
  const [wallpaperError, setWallpaperError] = useState<string | null>(null);
  const state = snapshot.state;
  const now = today.getTime() / 1000;

  const installed = themesSnapshot.state?.themes ?? [];
  const current = installed.find(
    (theme) => theme.summary.name === (themesSnapshot.state?.current ?? state?.theme),
  );
  const look = current ? themeLook(current) : null;

  return (
    <>
      <PageHeader title="Home" />
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
          <HomeHero
            title={state.theme}
            wallpaper={state.wallpaper}
            theme={current}
            busy={themesSnapshot.busy}
            onNextWallpaper={async (path) => {
              if (!current) return;
              setWallpaperError(null);
              await themes.choose(current.summary.name, path);
              setWallpaperError(themes.getSnapshot().error);
            }}
            onChangeTheme={() => context.navigate("themes")}
          />
          {wallpaperError ? (
            <Notice.Root variant="error" className="mb-6">
              <Notice.Header onDismiss={() => setWallpaperError(null)}>
                <Notice.Title>Could not change the wallpaper</Notice.Title>
                <Notice.Description>{wallpaperError}</Notice.Description>
              </Notice.Header>
            </Notice.Root>
          ) : null}

          <SectionLabel>At a glance</SectionLabel>
          <Card className="mb-6">
            <StatStrip aria-label="At a glance">
              <Stat label="Themes" value={state.themeCount} />
              <Stat label="Shortcuts" value={state.shortcutsCount} />
              <Stat label="Layout" value={layoutNames[state.layout]} />
              <Stat label="Last change" value={relativeTime(state.lastChange, now)} />
            </StatStrip>
          </Card>

          <SectionLabel>Enabled</SectionLabel>
          <HomeIntegrations
            state={state}
            look={look}
            services={shell.state?.serviceList ?? null}
            pending={switching.pending}
            error={switching.error}
            onToggle={(service, running) => void switches.setRunning(service, running)}
            onDismiss={switches.dismiss}
            onOpen={(pane) => context.navigate(pane)}
          />

          <HomeActivity
            entries={log.state}
            error={log.error}
            now={now}
            onLogs={() => context.openLogs()}
          />

          <HomeInsights
            today={today}
            titles={installed.map((theme) => theme.summary.title)}
            current={look?.title ?? null}
          />
        </>
      )}
    </>
  );
}
