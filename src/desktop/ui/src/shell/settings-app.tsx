import { useEffect, useLayoutEffect, useMemo, useRef, useState } from "react";

import { bridge, request } from "~/bridge/client";
import type { PaneId } from "~/bridge/protocol";
import { Button } from "~/components/ui/button";
import { Notice } from "~/components/ui/notice";
import { TooltipProvider } from "~/components/ui/tooltip";
import { latestRelease } from "~/features/changelog/changelog-mock";
import { ChangelogPage } from "~/features/changelog/changelog-page";
import { createChangelogSeen, hasUnseenRelease } from "~/features/changelog/changelog-seen";
import { SetupPage } from "~/features/setup/setup-page";
import { setupPresentation } from "~/features/setup/setup-presentation";
import { themeAccent } from "~/lib/accent";
import { useStore } from "~/lib/store";

import { healthSummary } from "./health-summary";
import { goBack, goForward, type History, startHistory, visit } from "./history";
import type { LogStore } from "./log-store";
import type { PageContext, PageStore } from "./page";
import { pages } from "./pages";
import { reactPaneFor, reactPanes, type Route } from "./panes";
import { SettingsShell } from "./settings-shell";
import type { ShellStore } from "./shell-store";

let announced = false;

/** The host keeps the window hidden until this, so it must happen exactly once. */
function announceReady() {
  if (announced) return;
  announced = true;
  request("app.ready", { surface: "settings" }).catch((error: unknown) => console.error(error));
}

const loaded = new Set<PaneId>();

/** Loads a page's store the first time it is shown. Loading only reads. */
function ensureLoaded(pane: PaneId, store: PageStore) {
  if (loaded.has(pane)) return;
  loaded.add(pane);
  void store.load();
}

/** Stands in until the shell knows which page to show. */
const idle: PageStore = {
  subscribe: () => () => {},
  getSnapshot: () => idleStatus,
  load: () => Promise.resolve(),
};
const idleStatus = { status: "loading" } as const;

const changelogSeen = createChangelogSeen();

interface Navigation {
  history: History<Route> | null;
  /** The host's selected pane this history last followed. */
  selected: PaneId | null;
}

export function SettingsApp({
  shell,
  stores,
  logs,
}: {
  shell: ShellStore;
  stores: Map<PaneId, PageStore>;
  logs: LogStore;
}) {
  const shellSnapshot = useStore(shell);
  const setup = useStore(setupPresentation);
  const seen = useStore(changelogSeen);
  useEffect(() => {
    if (shellSnapshot.state?.setupRequired)
      setupPresentation.open({ request, subscribe: bridge.subscribe });
  }, [shellSnapshot.state?.setupRequired]);
  const accent = shellSnapshot.state?.appearance.accent;
  const mode = shellSnapshot.state?.appearance.mode;
  const selected = shellSnapshot.state ? reactPaneFor(shellSnapshot.state.selectedPane) : null;

  // History follows the host's selection, which can also change from the
  // classic window or the setup flow; going back to a page is not a new visit.
  const [navigation, setNavigation] = useState<Navigation>({ history: null, selected: null });
  if (selected && navigation.selected !== selected) {
    setNavigation({
      selected,
      history: navigation.history ? visit(navigation.history, selected) : startHistory(selected),
    });
  }
  const history = navigation.history;
  const route: Route | null = history?.current ?? selected;

  const showPane = (next: History<Route>) => {
    setNavigation((current) => ({ ...current, history: next }));
    if (next.current !== "changelog") shell.selectPane(next.current);
  };

  const go = (target: Route) => {
    if (target !== "changelog" && !reactPanes.has(target)) {
      shell.selectPane(target);
      return;
    }
    if (history) showPane(visit(history, target));
  };

  // Pages keep the context they were given, so it reads the latest `go`.
  const goRef = useRef(go);
  useLayoutEffect(() => {
    goRef.current = go;
  });

  const pane = route === "changelog" ? null : route;
  const page = pane ? pages.find((candidate) => candidate.id === pane) : undefined;
  const store = setup ?? ((pane && stores.get(pane)) || idle);
  const pageSnapshot = useStore(store);
  const healthStore = stores.get("health");
  const health = healthSummary(useStore(healthStore ?? idle));

  useEffect(() => {
    if (!setup && !shellSnapshot.state?.setupRequired && pane && store !== idle)
      ensureLoaded(pane, store);
  }, [pane, store, setup, shellSnapshot.state?.setupRequired]);

  const context = useMemo<PageContext>(
    () => ({
      navigate: (pane) => goRef.current(pane),
      openClassic: (params) => shell.openClassic(params),
    }),
    [shell],
  );

  // Before paint, so the first frame already carries the theme's accent.
  useLayoutEffect(() => {
    if (accent) document.documentElement.style.setProperty("--theme-accent", themeAccent(accent));
  }, [accent]);

  // System leaves the attribute off, so index.css follows the Mac's appearance.
  useLayoutEffect(() => {
    const root = document.documentElement;
    if (mode === "light" || mode === "dark") root.dataset.theme = mode;
    else delete root.dataset.theme;
  }, [mode]);

  // The window is shown once the first page has something real to draw.
  const settled =
    shellSnapshot.status === "failed" ||
    (shellSnapshot.status === "ready" &&
      (route === "changelog" || pageSnapshot.status !== "loading") &&
      (!shellSnapshot.state?.setupRequired || setup !== null));
  useEffect(() => {
    if (settled) announceReady();
  }, [settled]);

  // Setup health feeds the sidebar's count and the brand menu's model, and
  // the log feeds the Logs button's dot; both wait so the first page loads first.
  useEffect(() => {
    if (!settled || !shellSnapshot.state) return;
    if (healthStore) ensureLoaded("health", healthStore);
    if (logs.getSnapshot().status === "idle") void logs.load();
  }, [settled, shellSnapshot.state, healthStore, logs]);

  if (!settled) return <div className="h-full bg-page" />;

  if (!shellSnapshot.state || !route || !history) {
    return (
      <div className="flex h-full items-center justify-center bg-page p-6">
        <Notice.Root variant="error" className="max-w-md">
          <Notice.Title>Macarchy could not load its settings</Notice.Title>
          <Notice.Description>{shellSnapshot.error}</Notice.Description>
          <Notice.Actions>
            <Button onClick={() => void shell.load()}>Try again</Button>
          </Notice.Actions>
        </Notice.Root>
      </div>
    );
  }

  return (
    <TooltipProvider>
      <SettingsShell
        shell={shell}
        snapshot={shellSnapshot}
        state={shellSnapshot.state}
        logs={logs}
        route={route}
        canBack={history.past.length > 0}
        canForward={history.future.length > 0}
        onBack={() => showPane(goBack(history))}
        onForward={() => showPane(goForward(history))}
        go={go}
        health={health}
        changelog={{
          fresh: hasUnseenRelease(seen),
          dismissed: seen.dismissed === latestRelease.version,
          onDismiss: () => changelogSeen.dismissCard(),
        }}
      >
        {setup ? (
          <SetupPage
            store={setup}
            close={() => {
              setupPresentation.close();
              void shell.load();
            }}
            health={() => {
              setupPresentation.close();
              void shell.load();
              go("health");
            }}
          />
        ) : route === "changelog" ? (
          <ChangelogPage lastSeen={seen.lastSeen} onSeen={() => changelogSeen.markSeen()} />
        ) : page ? (
          page.render(store, context)
        ) : null}
      </SettingsShell>
    </TooltipProvider>
  );
}
