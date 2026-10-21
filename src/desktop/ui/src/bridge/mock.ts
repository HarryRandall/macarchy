/**
 * An in-memory stand-in for the native host, for `pnpm dev` in a browser.
 * Only ever loaded through a dynamic import behind `import.meta.env.DEV`.
 *
 * Query flags:
 *   ?fail=layout         layout.apply rejects
 *   ?fail=layout-state   layout.getState rejects
 *   ?fail=switcher       applying a theme or background fails and reopens the switcher
 *   ?source=saved        yabai is "not running"; layout is read-only
 *   ?setup               settings have never been written
 *
 * `window.macarchyMock` drives events from the console: openSwitcher(),
 * closeSwitcher(), changeLayout({ windowGap: 20 }), setAccent("#ff9f0a"),
 * setServices(2).
 */
import { createThemesMock } from "~/features/themes/themes-mock";
import { shortcutsMock } from "~/features/shortcuts/shortcuts-mock";

import type {
  AdvancedState,
  Background,
  BordersState,
  BridgeEvent,
  BridgeMethod,
  LayoutState,
  LayoutValues,
  ParamsOf,
  Reply,
  RulesState,
  ResultOf,
  ShellState,
  SwitcherFailure,
  SwitcherState,
  TerminalColours,
  ThemeSummary,
} from "./protocol";

const latency = 120;

function sleep(ms: number) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function tile(colours: TerminalColours, accent: string, seed: number): string {
  const angle = (seed * 47) % 360;
  const svg = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 160 90"><defs><linearGradient id="g" gradientTransform="rotate(${angle} .5 .5)"><stop offset="0" stop-color="${colours.background}"/><stop offset="1" stop-color="${accent}"/></linearGradient></defs><rect width="160" height="90" fill="url(#g)"/><circle cx="${40 + seed * 23}" cy="${30 + seed * 9}" r="${18 + seed * 4}" fill="${colours.foreground}" fill-opacity=".12"/></svg>`;
  return `data:image/svg+xml,${encodeURIComponent(svg)}`;
}

function title(name: string) {
  return name
    .split(/[-_ ]/)
    .map((part) => part.charAt(0).toUpperCase() + part.slice(1))
    .join(" ");
}

function backgroundName(path: string) {
  const base =
    path
      .split("/")
      .pop()
      ?.replace(/\.[^.]+$/, "") ?? path;
  return title(base.replace(/^[0-9]+[-_. ]*/, "").replace(/[-_.]+/g, "-"));
}

function theme(
  name: string,
  isDark: boolean,
  colours: TerminalColours,
  backgroundFiles: string[],
): ThemeSummary {
  const backgrounds: Background[] = backgroundFiles.map((file, index) => ({
    path: `backgrounds/${file}`,
    name: backgroundName(file),
    thumbnail: tile(colours, colours.blue, index + 1),
  }));
  return {
    name,
    title: title(name),
    isDark,
    ring: colours.blue,
    colours,
    currentBackground: backgrounds[0]?.path ?? null,
    preview: null,
    backgrounds,
  };
}

const themes: ThemeSummary[] = [
  theme(
    "awakening",
    true,
    {
      background: "#11131a",
      foreground: "#d7dae0",
      red: "#e06c75",
      green: "#98c379",
      blue: "#61afef",
      cyan: "#56b6c2",
    },
    ["1-first-light.png", "2-hand-of-adam.png", "3-still-water.jpg"],
  ),
  theme(
    "blackgold",
    true,
    {
      background: "#0b0b0b",
      foreground: "#e6d3a3",
      red: "#c0504d",
      green: "#a3be8c",
      blue: "#d4af37",
      cyan: "#e0c068",
    },
    ["1-gilded.png"],
  ),
  theme(
    "carbonfox",
    true,
    {
      background: "#161616",
      foreground: "#f2f4f8",
      red: "#ee5396",
      green: "#25be6a",
      blue: "#78a9ff",
      cyan: "#33b1ff",
    },
    ["1-carbon-fibre.png", "2-fox-den.jpg", "3-ember.png", "4-night-shift.png"],
  ),
  theme(
    "city-783",
    true,
    {
      background: "#1a1b26",
      foreground: "#c0caf5",
      red: "#f7768e",
      green: "#9ece6a",
      blue: "#7aa2f7",
      cyan: "#7dcfff",
    },
    ["1-skyline.png", "2-rain-on-glass.png"],
  ),
  theme(
    "lumon",
    false,
    {
      background: "#e8ecef",
      foreground: "#1f2a33",
      red: "#b5463c",
      green: "#3f7d4e",
      blue: "#2f6f9f",
      cyan: "#2c8a91",
    },
    ["1-macrodata-refinement.png", "2-break-room.png"],
  ),
  theme(
    "matte-black",
    true,
    {
      background: "#121212",
      foreground: "#bebebe",
      red: "#d35f5f",
      green: "#7fa57f",
      blue: "#8a8a8d",
      cyan: "#a0a0a0",
    },
    [],
  ),
  theme(
    "midnight",
    true,
    {
      background: "#0b1020",
      foreground: "#cbd5f5",
      red: "#ff6b81",
      green: "#7bd88f",
      blue: "#5c9cff",
      cyan: "#4fd1c5",
    },
    ["1-aurora.png"],
  ),
  theme(
    "turbonite",
    true,
    {
      background: "#1b1d1e",
      foreground: "#d6d6d6",
      red: "#ff5f5f",
      green: "#a6e22e",
      blue: "#66d9ef",
      cyan: "#5fd7d7",
    },
    ["1-turbine.png", "2-nitro.png", "3-exhaust.png"],
  ),
];

function deliver(event: BridgeEvent) {
  const result = window.macarchyBridge?.receive(JSON.stringify(event));
  if (result instanceof Promise) {
    void result.then(() => console.debug(`[mock] ${event.type} painted`));
  }
}

export function installMockHost() {
  const query = new URLSearchParams(window.location.search);
  const failures = new Set((query.get("fail") ?? "").split(",").filter(Boolean));
  const saved = query.get("source") === "saved";

  let shell: ShellState = {
    selectedPane: "layout",
    sidebarVisible: true,
    setupRequired: query.has("setup"),
    appearance: { accent: "#61afef" },
    services: { running: 3, total: 4 },
  };

  let daemon: LayoutValues = {
    layout: "bsp",
    splitType: "auto",
    windowPlacement: "second_child",
    autoBalance: false,
    windowGap: 8,
    padding: 8,
    mouseModifier: "ctrl",
    mouseFollowsFocus: false,
    mouseDropAction: "stack",
  };

  const rules: RulesState = {
    floatingApps: ["Messages"],
    customRules: [],
    externalRules: [],
    icons: {},
    unavailableReason: saved
      ? "yabai isn't responding, so these are your saved rules. Editing is off because rules apply through yabai."
      : null,
  };

  let switcher: SwitcherState = { themes, current: "awakening" };

  function layoutState(): LayoutState {
    return {
      values: { ...daemon },
      source: saved ? "saved" : "daemon",
      unavailableReason: saved
        ? "yabai is not running, so these are your saved settings. Start yabai from Advanced to change them."
        : null,
      wallpaper: null,
    };
  }

  let reopen: ReturnType<typeof setTimeout> | undefined;
  function closeSwitcher(error: SwitcherFailure | null = null) {
    deliver({ type: "switcher.didClose" });
    // A browser tab has no panel to hide, so reopen to keep working.
    clearTimeout(reopen);
    reopen = setTimeout(
      () => deliver({ type: "switcher.willOpen", state: { ...switcher, error } }),
      600,
    );
  }

  function failSwitcher(failureTitle: string): never {
    const reason = "The mock host was asked to fail.";
    closeSwitcher({ title: failureTitle, reason });
    throw new MockFailure("operation_failed", reason);
  }

  type Handlers = {
    [M in BridgeMethod]: (params: ParamsOf<M>) => ResultOf<M> | Promise<ResultOf<M>>;
  };

  const advanced: AdvancedState = {
    services: ["yabai", "borders", "sketchybar", "skhd"].map((id) => ({
      id: id as AdvancedState["services"][number]["id"],
      state: "running",
    })),
    snapshots: [],
    theme: "awakening",
    installedThemes: themes.length,
    addition: "missing",
    additionExplanation: "The scripting addition is optional.",
    wakeHelpers: true,
    backupsDirectory: "~/.config/macarchy/backups",
  };
  let borders: BordersState = {
    appearance: {
      width: 6,
      visible: true,
      excludedApps: ["iPhone Mirroring"],
      radius: null,
      activeColour: "0xff45e8ff",
      inactiveColour: null,
    },
    applicationIcons: {},
    theme: "awakening",
    defaults: null,
    unavailableReason: saved ? "borders is not running." : null,
    wallpaper: null,
  };
  const handlers: Handlers = {
    "rules.getState": () => rules,
    "rules.addApplication": () => {
      rules.floatingApps.push("Calculator");
      return null;
    },
    "rules.removeFloating": ({ app }) => {
      rules.floatingApps = rules.floatingApps.filter((name) => name !== app);
      return null;
    },
    "rules.saveCustom": ({ rule }) => {
      rules.customRules = [...rules.customRules.filter((entry) => entry.id !== rule.id), rule];
      return null;
    },
    "rules.removeCustom": ({ id }) => {
      rules.customRules = rules.customRules.filter((rule) => rule.id !== id);
      return null;
    },
    "advanced.getState": () => advanced,
    "advanced.restartService": ({ daemon: serviceId }) => {
      advanced.services.find((service) => service.id === serviceId)!.state = "running";
      return null;
    },
    "advanced.stopService": ({ daemon: serviceId }) => {
      advanced.services.find((service) => service.id === serviceId)!.state = "stopped";
      return null;
    },
    "advanced.rebuild": () => ({ outcome: "Rebuilt" }),
    "advanced.restoreSnapshot": () => null,
    "advanced.repairAddition": () => null,
    "advanced.restoreOriginals": () => ({
      lines: ["Restored original files"],
      failures: [],
      failure: null,
    }),
    "setup.getPlan": () => ({
      tools: [],
      changes: [
        {
          path: "~/.config/yabai/yabairc",
          action: "create",
          detail: "Starts tiling with Macarchy's layout and rules",
        },
      ],
      hasExisting: true,
      canClose: !shell.setupRequired,
    }),
    "setup.run": () => {
      if (failures.has("setup")) {
        return {
          lines: ["Installed themes", "Installed default shortcuts"],
          failures: [],
          failure:
            "Setup did not finish; some files may already have changed. The menu bar file could not be written.",
        };
      }
      shell = { ...shell, setupRequired: false };
      deliver({ type: "shell.changed", state: shell });
      return { lines: ["Installed themes", "Prepared startup files"], failures: [], failure: null };
    },
    "setup.openAccessibility": () => null,
    "borders.getState": () => {
      if (failures.has("borders-state"))
        throw new MockFailure("unavailable", "Could not read borders.");
      return borders;
    },
    "borders.apply": ({ appearance, theme: themeName }) => {
      if (saved || failures.has("borders"))
        throw new MockFailure("operation_failed", "borders rejected the change.");
      borders = { ...borders, appearance, theme: themeName };
      return null;
    },
    "borders.pickApplication": () => ({ name: "Example", icon: null }),
    ...createThemesMock(() => switcher),
    ...shortcutsMock(deliver, failures),
    "app.ready": ({ surface }) => {
      console.info(`[mock] ${surface} ready`);
      return null;
    },
    "shell.getState": () => shell,
    "shell.setPreferences": (params) => {
      shell = { ...shell, ...params };
      return null;
    },
    "shell.openClassic": (params) => {
      console.info("[mock] open classic window", params);
      return null;
    },
    "shell.setTitlebar": (params) => {
      if (query.has("debug")) console.debug("[mock] titlebar", params);
      return null;
    },
    "home.getState": () => ({
      theme: switcher.current,
      themeCount: themes.length,
      shortcutsCount: 24,
      layout: daemon.layout,
      running: shell.services.running,
      total: shell.services.total,
      lastChange: null,
      wallpaper: null,
      subtitle: "A space that works for you.",
    }),
    "health.getState": () => ({
      checks: [
        {
          id: "Configuration/Setup",
          group: "Configuration",
          title: "Setup",
          status: "failed",
          detail: "Macarchy has not been set up",
          fix: "Open Macarchy, or run: macarchy setup",
        },
      ],
      environment: {
        model: "Mac",
        architecture: "Apple Silicon",
        macOS: "26.0",
        app: "development build",
        settingsFolder: "~/.config/macarchy",
      },
      checkedAt: Date.now() / 1000,
    }),
    "health.copyFix": () => null,
    "health.revealSettings": () => null,
    "report.prepare": ({ description }) => ({
      body: `## What happened\n\n${description || "_Not described_"}\n\n## Environment\n\nBrowser preview`,
      token: "preview",
    }),
    "report.copy": () => null,
    "report.openIssue": () => ({ copied: false }),
    "report.openIssues": () => null,
    "layout.getState": () => {
      if (failures.has("layout-state")) {
        throw new MockFailure("unavailable", "Could not read the layout from yabai.");
      }
      return layoutState();
    },
    "layout.apply": ({ changes }) => {
      if (saved) throw new MockFailure("unavailable", "yabai is not running.");
      if (failures.has("layout")) {
        throw new MockFailure(
          "operation_failed",
          "yabai rejected the change: could not apply window_gap.",
        );
      }
      daemon = { ...daemon, ...changes };
      console.info("[mock] layout.apply", changes);
      return null;
    },
    "switcher.getState": () => switcher,
    "switcher.refresh": () => switcher,
    "switcher.applyTheme": ({ theme: name }) => {
      if (failures.has("switcher")) failSwitcher(`Could not apply ${title(name)}`);
      switcher = { ...switcher, current: name };
      shell = {
        ...shell,
        appearance: {
          accent: themes.find((entry) => entry.name === name)?.ring ?? "#0a84ff",
        },
      };
      closeSwitcher();
      setTimeout(() => deliver({ type: "themes.changed", state: switcher }), 200);
      return null;
    },
    "switcher.useBackground": ({ theme: name, path }) => {
      if (failures.has("switcher")) {
        failSwitcher(`Could not use the ${backgroundName(path)} background`);
      }
      switcher = {
        ...switcher,
        themes: switcher.themes.map((entry) =>
          entry.name === name ? { ...entry, currentBackground: path } : entry,
        ),
      };
      closeSwitcher();
      setTimeout(() => deliver({ type: "themes.changed", state: switcher }), 200);
      return null;
    },
    "switcher.openSettings": () => {
      console.info("[mock] open settings");
      closeSwitcher();
      return null;
    },
    "switcher.close": () => {
      closeSwitcher();
      return null;
    },
  };

  async function postMessage(message: unknown): Promise<string> {
    const { method, params } = message as { method: BridgeMethod; params: never };
    await sleep(latency);
    const handler = handlers[method] as ((params: unknown) => unknown) | undefined;
    let reply: Reply<unknown>;
    if (!handler) {
      reply = {
        ok: false,
        error: { code: "unknown_method", message: `No method ${method}.` },
      };
    } else {
      try {
        reply = { ok: true, value: await handler(params) };
      } catch (error) {
        reply =
          error instanceof MockFailure
            ? { ok: false, error: { code: error.code, message: error.message } }
            : { ok: false, error: { code: "internal", message: String(error) } };
      }
    }
    return JSON.stringify(reply);
  }

  window.webkit = { messageHandlers: { macarchy: { postMessage } } };
  window.macarchyBridge ??= {
    queue: [],
    receive: (event) => window.macarchyBridge?.queue.push(event),
  };

  Object.assign(window, {
    macarchyMock: {
      openSwitcher: () =>
        deliver({ type: "switcher.willOpen", state: { ...switcher, error: null } }),
      closeSwitcher: () => closeSwitcher(),
      changeLayout(changes: Partial<LayoutValues>) {
        daemon = { ...daemon, ...changes };
        deliver({ type: "layout.changed", state: layoutState() });
      },
      setAccent(accent: string) {
        shell = { ...shell, appearance: { accent } };
        deliver({ type: "shell.changed", state: shell });
      },
      setServices(running: number) {
        shell = { ...shell, services: { ...shell.services, running } };
        deliver({ type: "shell.changed", state: shell });
      },
    },
  });
  console.info("[mock] Macarchy mock host installed. Try window.macarchyMock.");
}

class MockFailure extends Error {
  readonly code: "unavailable" | "operation_failed";

  constructor(code: "unavailable" | "operation_failed", message: string) {
    super(message);
    this.code = code;
  }
}
