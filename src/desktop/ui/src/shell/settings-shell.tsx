import { PanelLeft } from "lucide-react";
import { type ReactNode, useEffect, useRef } from "react";

import { request } from "~/bridge/client";
import type { Rect, ShellState } from "~/bridge/protocol";
import { Button } from "~/components/ui/button";
import { Notice } from "~/components/ui/notice";
import { Tooltip } from "~/components/ui/tooltip";

import { reactPaneFor } from "./panes";
import type { ShellStore } from "./shell-store";
import { SIDEBAR_WIDTH, Sidebar } from "./sidebar";
import { TopBar } from "./top-bar";
import { TITLEBAR_HEIGHT, titlebarControl, useTitlebarReport } from "./use-titlebar-report";

/** Room for the close, minimise and zoom buttons macOS draws over the page. */
const TRAFFIC_LIGHT_GUTTER = 78;
/** The corner box when collapsed: the gutter, the toggle and its margins. */
const COLLAPSED_CORNER = TRAFFIC_LIGHT_GUTTER + 28 + 16;

function reportTitlebar(params: { height: number; controls: Rect[] }) {
  request("shell.setTitlebar", params).catch((error: unknown) => console.error(error));
}

export function SettingsShell({
  store,
  state,
  error,
  children,
}: {
  store: ShellStore;
  state: ShellState;
  error: string | null;
  children: ReactNode;
}) {
  const rootRef = useRef<HTMLDivElement>(null);
  const visible = state.sidebarVisible;
  useTitlebarReport(rootRef, reportTitlebar);

  useEffect(() => {
    const onKeyDown = (event: KeyboardEvent) => {
      const key = event.key.toLowerCase();
      if (event.metaKey && !event.ctrlKey && !event.altKey && key === "k") {
        event.preventDefault();
        store.openClassic({ show: "search" });
      } else if (event.metaKey && event.ctrlKey && key === "s") {
        event.preventDefault();
        store.setSidebarVisible(!store.getSnapshot().state?.sidebarVisible);
      }
    };
    window.addEventListener("keydown", onKeyDown);
    return () => window.removeEventListener("keydown", onKeyDown);
  }, [store]);

  return (
    <div ref={rootRef} className="relative flex h-full overflow-hidden bg-page">
      {/*
       * The top-left box: the window buttons' gutter, then the toggle against
       * the sidebar's line. Open, it is as wide as the sidebar; collapsed, it
       * shrinks to what it holds, and the width animates so the toggle slides. It comes first in the document
       * so Tab reaches it where it sits on screen, before the sidebar.
       */}
      <div
        data-titlebar-region
        className="absolute top-0 left-0 flex items-center justify-end pr-2 transition-[width] duration-snappy"
        style={{
          height: TITLEBAR_HEIGHT,
          width: visible ? SIDEBAR_WIDTH : COLLAPSED_CORNER,
        }}
      >
        <Tooltip content="Show the section names" side="right" disabled={visible} describe={false}>
          <Button
            {...titlebarControl}
            variant="bar"
            size="icon-bar"
            aria-label={visible ? "Collapse sidebar" : "Expand sidebar"}
            aria-expanded={visible}
            aria-keyshortcuts="Meta+Control+S"
            onClick={() => store.setSidebarVisible(!visible)}
          >
            <PanelLeft aria-hidden strokeWidth={2} />
          </Button>
        </Tooltip>
      </div>
      <Sidebar
        visible={visible}
        selected={reactPaneFor(state.selectedPane)}
        onSelect={(pane) => store.selectPane(pane)}
      />

      <div className="flex min-w-0 flex-1 flex-col">
        <TopBar
          services={state.services}
          onSearch={() => store.openClassic({ show: "search" })}
          onServices={() => store.openClassic({ pane: "advanced" })}
          onConsole={() => store.openClassic({ show: "console" })}
        />
        <main className="min-h-0 flex-1 overflow-y-auto">
          <div className="mx-auto flex max-w-[1008px] flex-col gap-4 px-6 pt-8 pb-10">
            {error ? (
              <Notice.Root variant="error">
                <div className="flex items-start gap-2">
                  <div className="flex min-w-0 flex-1 flex-col gap-0.5">
                    <Notice.Title>Something went wrong</Notice.Title>
                    <Notice.Description>{error}</Notice.Description>
                  </div>
                  <Notice.Dismiss onClick={() => store.dismissError()} />
                </div>
              </Notice.Root>
            ) : null}
            {state.setupRequired ? (
              <Notice.Root variant="warning">
                <Notice.Title>Finish setting up Macarchy</Notice.Title>
                <Notice.Description>
                  Setup has not run yet, so your desktop is not managed. It runs in the classic
                  window.
                </Notice.Description>
                <Notice.Actions>
                  <Button variant="primary" onClick={() => store.openClassic({})}>
                    Open setup
                  </Button>
                </Notice.Actions>
              </Notice.Root>
            ) : null}
            {children}
          </div>
        </main>
      </div>
    </div>
  );
}
