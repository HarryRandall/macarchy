import { useEffect, useLayoutEffect, useMemo } from "react";

import { request } from "~/bridge/client";
import { Button } from "~/components/ui/button";
import { Notice } from "~/components/ui/notice";
import { TooltipProvider } from "~/components/ui/tooltip";
import type { PaneId } from "~/bridge/protocol";
import { accentVariables } from "~/lib/accent";
import { useStore } from "~/lib/store";

import type { PageContext, PageStore } from "./page";
import { pages } from "./pages";
import { reactPaneFor } from "./panes";
import { SettingsShell } from "./settings-shell";
import type { ShellStore } from "./shell-store";

const accentKeys = ["--accent", "--accent-fg", "--accent-stroke-light", "--accent-stroke-dark"];

/** Clears every derived variable first, so an unreadable accent leaves no stale strokes. */
function applyAccent(style: CSSStyleDeclaration, accent: string) {
  for (const key of accentKeys) style.removeProperty(key);
  for (const [key, value] of Object.entries(accentVariables(accent))) {
    style.setProperty(key, value);
  }
}

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

export function SettingsApp({
  shell,
  stores,
}: {
  shell: ShellStore;
  stores: Map<PaneId, PageStore>;
}) {
  const shellSnapshot = useStore(shell);
  const accent = shellSnapshot.state?.appearance.accent;
  const selected = shellSnapshot.state ? reactPaneFor(shellSnapshot.state.selectedPane) : null;
  const page = selected ? pages.find((candidate) => candidate.id === selected) : undefined;
  const store = (selected && stores.get(selected)) || idle;
  const pageSnapshot = useStore(store);

  useEffect(() => {
    if (selected && store !== idle) ensureLoaded(selected, store);
  }, [selected, store]);

  const context = useMemo<PageContext>(
    () => ({
      navigate: (pane) => shell.selectPane(pane),
      openClassic: (params) => shell.openClassic(params),
    }),
    [shell],
  );

  // Before paint, so the first frame already carries the theme's accent.
  useLayoutEffect(() => {
    if (accent) applyAccent(document.documentElement.style, accent);
  }, [accent]);

  // The window is shown once the first page has something real to draw.
  const settled =
    shellSnapshot.status === "failed" ||
    (shellSnapshot.status === "ready" && pageSnapshot.status !== "loading");
  useEffect(() => {
    if (settled) announceReady();
  }, [settled]);

  if (!settled) return <div className="h-full bg-page" />;

  if (!shellSnapshot.state) {
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
      <SettingsShell store={shell} state={shellSnapshot.state} error={shellSnapshot.error}>
        {page ? page.render(store, context) : null}
      </SettingsShell>
    </TooltipProvider>
  );
}
