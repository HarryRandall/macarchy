import {
  type LucideIcon,
  Monitor,
  Moon,
  PanelLeft,
  Play,
  RotateCw,
  Sparkles,
  Sun,
} from "lucide-react";
import { type ReactNode, useEffect, useLayoutEffect, useMemo, useRef, useState } from "react";

import { errorMessage, request } from "~/bridge/client";
import type { AppearanceMode, LogEntry, PaneId, Rect, ShellState } from "~/bridge/protocol";
import {
  type PageChrome,
  PageChromeContext,
  type PageSearch,
} from "~/components/layout/page-chrome";
import { Notice } from "~/components/ui/notice";
import { copyText } from "~/lib/clipboard";
import { useStore } from "~/lib/store";

import { AboutDialog } from "./about-dialog";
import { type ShellAction, shellActions } from "./actions";
import { CommandPalette, type PaletteCommand } from "./command-palette";
import { logText, unreadFailures } from "./log-filter";
import type { LogStore } from "./log-store";
import { formatLogTime, LogsPanel } from "./logs-panel";
import { groups, overview, panes, type Route, routeTitle } from "./panes";
import { ServiceStatus } from "./service-status";
import type { ShellSnapshot, ShellStore } from "./shell-store";
import { type ShellShortcut, shortcutFor } from "./shortcuts";
import type { Signal } from "./signal";
import { Sidebar } from "./sidebar";
import { ToastHost } from "./toast-host";
import { createToasts } from "./toasts";
import { TopBar } from "./top-bar";
import { useTitlebarReport } from "./use-titlebar-report";

type Service = ShellState["serviceList"][number];

function reportTitlebar(params: { height: number; controls: Rect[] }) {
  request("shell.setTitlebar", params).catch((error: unknown) => console.error(error));
}

const logsHeightKey = "macarchy.logsHeight";
const defaultLogsHeight = 260;

function savedLogsHeight(): number {
  try {
    const saved = Number(localStorage.getItem(logsHeightKey));
    return Number.isFinite(saved) && saved > 0 ? saved : defaultLogsHeight;
  } catch {
    return defaultLogsHeight;
  }
}

function saveLogsHeight(height: number) {
  try {
    localStorage.setItem(logsHeightKey, String(height));
  } catch {
    // Private browsing or a full store; the height still holds for this session.
  }
}

const modes: { id: AppearanceMode; label: string; icon: LucideIcon }[] = [
  { id: "system", label: "System", icon: Monitor },
  { id: "light", label: "Light", icon: Sun },
  { id: "dark", label: "Dark", icon: Moon },
];

/** Escape belongs to whatever overlay or field has focus before it closes the logs. */
const escapeOwners = '[role="dialog"], [role="alertdialog"], [role="menu"], [role="listbox"]';
const modal = '[role="dialog"], [role="alertdialog"]';

function isFilledField(element: Element | null) {
  return (
    (element instanceof HTMLInputElement || element instanceof HTMLTextAreaElement) &&
    element.value !== ""
  );
}

/**
 * The window frame: the top bar, the sidebar, the scrolling page, and the
 * logs, palette, dialogs and toasts over them. Navigation is the caller's;
 * this owns what the frame itself opens and the window's shortcuts.
 */
export function SettingsShell({
  shell,
  snapshot,
  state,
  logs,
  route,
  canBack,
  canForward,
  onBack,
  onForward,
  go,
  logsRequest,
  health,
  changelog,
  children,
}: {
  shell: ShellStore;
  snapshot: ShellSnapshot;
  state: ShellState;
  logs: LogStore;
  route: Route;
  canBack: boolean;
  canForward: boolean;
  onBack: () => void;
  onForward: () => void;
  go: (route: Route) => void;
  /** Pages ask for the logs panel through their context. */
  logsRequest: Signal;
  health: { issues: number | null; model: string | null };
  changelog: { fresh: boolean; dismissed: boolean; onDismiss: () => void };
  children: ReactNode;
}) {
  const rootRef = useRef<HTMLDivElement>(null);
  const columnRef = useRef<HTMLDivElement>(null);
  const mainRef = useRef<HTMLElement>(null);
  const logsButton = useRef<HTMLButtonElement>(null);
  const [toasts] = useState(createToasts);
  const [search, setSearch] = useState<PageSearch | null>(null);
  const [actionsSlot, setActionsSlot] = useState<HTMLDivElement | null>(null);
  const [paletteOpen, setPaletteOpen] = useState(false);
  const [aboutOpen, setAboutOpen] = useState(false);
  const [menuOpen, setMenuOpen] = useState(false);
  const [servicesOpen, setServicesOpen] = useState(false);
  const [logsOpen, setLogsOpen] = useState(false);
  const [logsHeight, setLogsHeight] = useState(savedLogsHeight);
  const log = useStore(logs);
  const collapsed = !state.sidebarVisible;
  useTitlebarReport(rootRef, reportTitlebar);

  const chrome = useMemo<PageChrome>(() => ({ actionsSlot, setSearch }), [actionsSlot]);

  useEffect(() => {
    mainRef.current?.scrollTo({ top: 0 });
    // oxlint-disable-next-line react/exhaustive-effect-dependencies -- each route starts at the top.
  }, [route]);

  useEffect(() => {
    if (logsOpen) logs.markSeen();
    // oxlint-disable-next-line react/exhaustive-effect-dependencies -- entries that arrive while the panel is open are seen.
  }, [logs, logsOpen, log.entries]);

  const fail = (error: unknown) => {
    console.error(error);
    toasts.push(errorMessage(error), "danger");
  };

  const openLogs = () => {
    setLogsOpen(true);
    if (log.status === "idle") void logs.load();
  };

  const closeLogs = () => {
    setLogsOpen(false);
    const panel = document.getElementById("logs-panel");
    if (panel?.contains(document.activeElement)) logsButton.current?.focus();
  };

  const toggleLogs = () => (logsOpen ? closeLogs() : openLogs());

  // Latest handlers, so a page's request opens the panel as it stands now.
  const logsHandler = useRef(openLogs);
  useLayoutEffect(() => {
    logsHandler.current = openLogs;
  });
  useEffect(() => logsRequest.listen(() => logsHandler.current()), [logsRequest]);

  const toggleSidebar = () => shell.setSidebarVisible(collapsed);

  const reload = () => {
    if (snapshot.restartingAll) return;
    shell.restartAll().then((outcome) => toasts.push(outcome), fail);
  };

  const restart = (service: Service) => {
    const action = service.state === "running" ? "restart" : "start";
    shell
      .restartService(service.id, action)
      .then(
        () => toasts.push(`${service.name} ${action === "start" ? "started" : "restarted"}`),
        fail,
      );
  };

  const stop = (service: Service) =>
    shell.stopService(service.id).then(() => toasts.push(`${service.name} stopped`));

  const runAction = (action: ShellAction) => {
    switch (action) {
      case "updates":
        // Mock: there is no release feed yet, so the check always finds this version current.
        toasts.push(`Macarchy ${state.version} is up to date`);
        break;
      case "folder":
        shell.revealSettings().catch(fail);
        break;
      case "reload":
        reload();
        break;
      case "logs":
        openLogs();
        break;
      case "changelog":
        go("changelog");
        break;
      case "shortcuts":
        go("shortcuts");
        break;
      case "about":
        setAboutOpen(true);
        break;
      case "quit":
        shell.quit().catch(fail);
        break;
    }
  };

  const copyLogs = (entries: LogEntry[]) => {
    const text = entries.map((entry) => logText(entry, formatLogTime(entry.at))).join("\n");
    copyText(text).then(
      () => toasts.push(`Copied ${entries.length} ${entries.length === 1 ? "line" : "lines"}`),
      fail,
    );
  };

  const clearLogs = () => {
    logs.clear().then(() => toasts.push("Logs cleared"), fail);
  };

  const resizeLogs = (height: number) => {
    setLogsHeight(height);
    saveLogsHeight(height);
  };

  // The window's shortcuts read the latest render through refs, so the
  // listeners are added once.
  const keys = useRef<(event: KeyboardEvent) => void>(() => {});
  const runShortcut = useRef<(shortcut: ShellShortcut) => void>(() => {});
  /** The last shortcut the page took from the keyboard, so the menu's echo of it is ignored. */
  const lastKey = useRef<{ shortcut: ShellShortcut; at: number } | null>(null);
  useEffect(() => {
    runShortcut.current = (shortcut) => {
      switch (shortcut) {
        case "palette":
          setPaletteOpen((open) => !open);
          break;
        case "sidebar":
          toggleSidebar();
          break;
        case "back":
          if (canBack) onBack();
          break;
        case "forward":
          if (canForward) onForward();
          break;
        case "shortcuts":
          go("shortcuts");
          break;
        case "logs":
          toggleLogs();
          break;
        case "reload":
          reload();
          break;
        case "folder":
          runAction("folder");
          break;
      }
    };
    keys.current = (event) => {
      if (event.key === "Escape") {
        if (!logsOpen || event.defaultPrevented) return;
        if (paletteOpen || aboutOpen || menuOpen || servicesOpen) return;
        const active = document.activeElement;
        if (active?.closest(escapeOwners) || isFilledField(active)) return;
        event.preventDefault();
        closeLogs();
        return;
      }
      const shortcut = shortcutFor(event);
      if (!shortcut) return;
      // A dialog keeps the window's shortcuts from acting behind it, bar the palette's own.
      if (shortcut !== "palette" && document.activeElement?.closest(modal)) return;
      event.preventDefault();
      lastKey.current = { shortcut, at: performance.now() };
      runShortcut.current(shortcut);
    };
  });
  useEffect(() => {
    const onKeyDown = (event: KeyboardEvent) => keys.current(event);
    window.addEventListener("keydown", onKeyDown);
    return () => window.removeEventListener("keydown", onKeyDown);
  }, []);
  useEffect(
    () =>
      shell.onShortcut((shortcut) => {
        const last = lastKey.current;
        if (last?.shortcut === shortcut && performance.now() - last.at < 150) return;
        if (shortcut !== "palette" && document.activeElement?.closest(modal)) return;
        runShortcut.current(shortcut);
      }),
    [shell],
  );

  const commands: PaletteCommand[] = [
    ...[...overview, ...groups.flatMap((group) => group.panes)].map((id): PaletteCommand => ({
      id: `go-${id}`,
      label: panes[id].title,
      hint: groups.find((group) => group.panes.includes(id))?.title ?? "Overview",
      section: "Go to",
      icon: panes[id].icon,
      run: () => go(id),
    })),
    {
      id: "go-changelog",
      label: "Changelog",
      hint: "What's new",
      keywords: ["release", "version"],
      section: "Go to",
      icon: Sparkles,
      run: () => go("changelog"),
    },
    ...(Object.keys(shellActions) as ShellAction[]).map((action): PaletteCommand => ({
      id: `action-${action}`,
      label: shellActions[action].label,
      keys: shellActions[action].keys,
      section: "Actions",
      icon: shellActions[action].icon,
      run: () => runAction(action),
    })),
    {
      id: "toggle-sidebar",
      label: collapsed ? "Show sidebar" : "Hide sidebar",
      keys: "⌘\\",
      section: "Actions",
      icon: PanelLeft,
      run: toggleSidebar,
    },
    ...modes.map(({ id, label, icon }): PaletteCommand => ({
      id: `appearance-${id}`,
      label: `Appearance: ${label}`,
      hint: state.appearance.mode === id ? "Current" : undefined,
      keywords: ["theme", "mode"],
      section: "Actions",
      icon,
      run: () => shell.setAppearance(id),
    })),
    ...state.serviceList.map((service): PaletteCommand => ({
      id: `service-${service.id}`,
      label: `${service.state === "running" ? "Restart" : "Start"} ${service.name}`,
      keywords: ["service"],
      section: "Actions",
      icon: service.state === "running" ? RotateCw : Play,
      run: () => restart(service),
    })),
  ];

  const selectPane = (pane: PaneId) => go(pane);

  return (
    <div
      ref={rootRef}
      className="relative flex h-full flex-col overflow-hidden bg-page text-fg antialiased"
    >
      <a
        href="#page-content"
        onClick={(event) => {
          event.preventDefault();
          mainRef.current?.focus();
        }}
        className="sr-only z-50 rounded-[7px] bg-popover px-3 py-1.5 text-[13px] font-medium text-fg shadow-pop focus:not-sr-only focus:fixed focus:top-14 focus:left-1/2 focus:-translate-x-1/2 focus:ring-2 focus:ring-accent focus:outline-none"
      >
        Skip to page content
      </a>
      <TopBar
        collapsed={collapsed}
        onToggleSidebar={toggleSidebar}
        canBack={canBack}
        canForward={canForward}
        onBack={onBack}
        onForward={onForward}
        route={route}
        search={search}
        onPalette={() => setPaletteOpen(true)}
        services={
          <ServiceStatus
            services={state.serviceList}
            pending={snapshot.pending}
            restartingAll={snapshot.restartingAll}
            open={servicesOpen}
            onOpenChange={setServicesOpen}
            onRestart={restart}
            onStop={stop}
            onRestartAll={reload}
            onHealth={() => go("health")}
            onLogs={openLogs}
          />
        }
        setActionsSlot={setActionsSlot}
        logsOpen={logsOpen}
        logFailures={unreadFailures(log.entries, log.seen)}
        logsButton={logsButton}
        onLogs={toggleLogs}
      />

      <div className="flex min-h-0 flex-1">
        <Sidebar
          collapsed={collapsed}
          route={route}
          issues={health.issues}
          onSelect={selectPane}
          version={state.version}
          model={health.model}
          fresh={changelog.fresh}
          cardDismissed={changelog.dismissed}
          mode={state.appearance.mode}
          menuOpen={menuOpen}
          onMenuOpenChange={setMenuOpen}
          onMode={(mode) => shell.setAppearance(mode)}
          onAction={runAction}
          onChangelog={() => go("changelog")}
          onDismissCard={changelog.onDismiss}
        />

        <div ref={columnRef} className="flex min-w-0 flex-1 flex-col">
          {/* A classic scrollbar would otherwise push the centred column sideways. */}
          <main
            ref={mainRef}
            id="page-content"
            tabIndex={-1}
            className="min-h-0 flex-1 overflow-y-auto outline-none [scrollbar-gutter:stable_both-edges]"
          >
            <div key={route} className="mx-auto flex max-w-[900px] flex-col gap-4 px-8 pt-7 pb-10">
              {snapshot.error ? (
                <Notice.Root variant="error">
                  <Notice.Header onDismiss={() => shell.dismissError()}>
                    <Notice.Title>Something went wrong</Notice.Title>
                    <Notice.Description>{snapshot.error}</Notice.Description>
                  </Notice.Header>
                </Notice.Root>
              ) : null}
              <PageChromeContext value={chrome}>{children}</PageChromeContext>
            </div>
          </main>
          <div id="logs-panel">
            <LogsPanel
              open={logsOpen}
              height={logsHeight}
              onHeight={resizeLogs}
              entries={log.entries}
              error={log.error}
              onCopy={copyLogs}
              onClear={clearLogs}
              onClose={closeLogs}
              containerRef={columnRef}
            />
          </div>
        </div>
      </div>

      <CommandPalette
        open={paletteOpen}
        onOpenChange={setPaletteOpen}
        commands={commands}
        pageFilter={
          search ? { title: routeTitle(route), apply: (query) => search.onChange(query) } : null
        }
      />
      <AboutDialog open={aboutOpen} onOpenChange={setAboutOpen} version={state.version} />
      <ToastHost toasts={toasts} offset={logsOpen ? logsHeight : 0} />
    </div>
  );
}
