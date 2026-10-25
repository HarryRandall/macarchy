import type { Background, SwitcherFailure, SwitcherState, ThemeSummary } from "~/bridge/protocol";

export type Row = { kind: "backgrounds" } | { kind: "theme"; name: string };
export type Mode = { kind: "themes" } | { kind: "backgrounds"; theme: string };

export type Command = "primary" | "switchBackground" | "refresh" | "openSettings";

export interface SwitcherUI {
  search: string;
  mode: Mode;
  /** The list row in theme mode, kept while the grid is showing. */
  selection: string | null;
  /** The background path selected in the grid. */
  tile: string | null;
  actionsOpen: boolean;
  /** Highlighted item in the actions menu. */
  action: number;
  /** The action that reopened the panel by failing, until dismissed or the next open. */
  failure: SwitcherFailure | null;
}

export interface SwitcherModel {
  data: SwitcherState;
  ui: SwitcherUI;
}

export type PrimaryAction =
  | { kind: "apply"; theme: string }
  | { kind: "openBackgrounds"; theme: string }
  | { kind: "useBackground"; theme: string; path: string };

export interface ActionItem {
  command: Command;
  title: string;
  keys: string[];
}

const preferred = ["awakening", "lumon"];

export function rowKey(row: Row): string {
  return row.kind === "backgrounds" ? "backgrounds" : `theme:${row.name}`;
}

function matches(text: string, search: string) {
  return text.toLocaleLowerCase().includes(search.toLocaleLowerCase());
}

/** Awakening and Lumon first, then by name. */
function rank(name: string) {
  const index = preferred.indexOf(name);
  return index === -1 ? preferred.length : index;
}

export function orderThemes(themes: readonly ThemeSummary[]): ThemeSummary[] {
  return themes.toSorted(
    (a, b) => rank(a.name) - rank(b.name) || (a.name < b.name ? -1 : a.name > b.name ? 1 : 0),
  );
}

/** The applied theme, or the first one when nothing has been applied. */
export function activeTheme(data: SwitcherState): ThemeSummary | undefined {
  return data.themes.find((theme) => theme.name === data.current) ?? data.themes[0];
}

/** "1 option", "3 options". */
export function plural(amount: number, noun: string): string {
  return `${amount} ${noun}${amount === 1 ? "" : "s"}`;
}

export function findTheme(data: SwitcherState, name: string | null): ThemeSummary | undefined {
  return name === null ? undefined : data.themes.find((theme) => theme.name === name);
}

export function buildRows(data: SwitcherState, search: string): Row[] {
  const themes = orderThemes(data.themes).filter(
    (theme) => !search || matches(theme.title, search),
  );
  const showBackgrounds =
    activeTheme(data) !== undefined && (!search || matches("switch background", search));
  return [
    ...(showBackgrounds ? [{ kind: "backgrounds" } as const] : []),
    ...themes.map((theme): Row => ({ kind: "theme", name: theme.name })),
  ];
}

/** The theme's backgrounds, the one in force first, filtered by name. */
export function backgroundsFor(theme: ThemeSummary, search: string): Background[] {
  const current = theme.backgrounds.filter((bg) => bg.path === theme.currentBackground);
  const rest = theme.backgrounds.filter((bg) => bg.path !== theme.currentBackground);
  return [...current, ...rest].filter((bg) => !search || matches(bg.name, search));
}

/** "backgrounds/2-hand-of-adam.png" reads as "Hand Of Adam". */
export function backgroundName(path: string): string {
  const base = (path.split("/").pop() ?? path).replace(/\.[^.]+$/, "");
  return base
    .replace(/^[0-9]+[-_. ]*/, "")
    .split(/[-_.]+/)
    .filter(Boolean)
    .map((word) => word.charAt(0).toUpperCase() + word.slice(1).toLowerCase())
    .join(" ");
}

function rowFromKey(key: string | null): Row | null {
  if (key === "backgrounds") return { kind: "backgrounds" };
  if (key?.startsWith("theme:")) return { kind: "theme", name: key.slice("theme:".length) };
  return null;
}

export function selectedRow(model: SwitcherModel): Row | null {
  return rowFromKey(model.ui.selection);
}

function gridTheme(model: SwitcherModel): ThemeSummary | undefined {
  return model.ui.mode.kind === "backgrounds"
    ? findTheme(model.data, model.ui.mode.theme)
    : undefined;
}

export function visibleTiles(model: SwitcherModel): Background[] {
  const theme = gridTheme(model);
  return theme ? backgroundsFor(theme, model.ui.search) : [];
}

/** Keeps `current` if it is still listed, otherwise takes the first. */
function keepOrFirst(current: string | null, keys: string[]): string | null {
  return current !== null && keys.includes(current) ? current : (keys[0] ?? null);
}

function initialSelection(data: SwitcherState): string | null {
  const rows = buildRows(data, "").map(rowKey);
  const current = data.current === null ? null : `theme:${data.current}`;
  return keepOrFirst(current, rows);
}

export function initialModel(
  data: SwitcherState,
  failure: SwitcherFailure | null = null,
): SwitcherModel {
  return {
    data,
    ui: {
      search: "",
      mode: { kind: "themes" },
      selection: initialSelection(data),
      tile: null,
      actionsOpen: false,
      action: 0,
      failure,
    },
  };
}

/** After data or search changes, puts every selection back on something visible. */
function reconcile(model: SwitcherModel): SwitcherModel {
  let { ui } = model;
  if (ui.mode.kind === "backgrounds" && !findTheme(model.data, ui.mode.theme)) {
    ui = { ...ui, mode: { kind: "themes" }, search: "", tile: null };
  }
  // While the grid shows, the search filters backgrounds; the hidden list
  // keeps its selection for when the grid is left.
  const listSearch = ui.mode.kind === "themes" ? ui.search : "";
  const selection = keepOrFirst(ui.selection, buildRows(model.data, listSearch).map(rowKey));
  const tile =
    ui.mode.kind === "backgrounds"
      ? keepOrFirst(
          ui.tile,
          visibleTiles({ ...model, ui }).map((bg) => bg.path),
        )
      : null;
  const action = Math.min(ui.action, actionItems({ ...model, ui }).length - 1);
  return { ...model, ui: { ...ui, selection, tile, action: Math.max(action, 0) } };
}

export function primaryAction(model: SwitcherModel): PrimaryAction | null {
  const { ui, data } = model;
  if (ui.mode.kind === "backgrounds") {
    return ui.tile === null ? null : { kind: "useBackground", theme: ui.mode.theme, path: ui.tile };
  }
  const row = selectedRow(model);
  if (row?.kind === "theme") return { kind: "apply", theme: row.name };
  if (row?.kind === "backgrounds") {
    const active = activeTheme(data);
    return active ? { kind: "openBackgrounds", theme: active.name } : null;
  }
  return null;
}

export function primaryTitle(model: SwitcherModel): string {
  if (model.ui.mode.kind === "backgrounds") return "Use Background";
  return selectedRow(model)?.kind === "backgrounds" ? "Open Backgrounds" : "Apply Theme";
}

export function actionItems(model: SwitcherModel): ActionItem[] {
  const items: ActionItem[] = [{ command: "primary", title: primaryTitle(model), keys: ["↵"] }];
  if (model.ui.mode.kind === "themes" && selectedRow(model)?.kind === "theme") {
    items.push({ command: "switchBackground", title: "Switch Background", keys: ["⌘", "B"] });
  }
  items.push({ command: "refresh", title: "Refresh Themes", keys: ["⌘", "R"] });
  items.push({ command: "openSettings", title: "Open Macarchy", keys: ["⌘", ","] });
  return items;
}

export type SwitcherAction =
  | { type: "reset"; data: SwitcherState; failure?: SwitcherFailure | null }
  | { type: "data"; data: SwitcherState }
  | { type: "search"; search: string }
  | { type: "select"; key: string }
  | { type: "selectTile"; path: string }
  /** Up and Down: the list by one, the grid by a row, or the actions menu. */
  | { type: "step"; delta: -1 | 1 }
  /** Left and Right, in the grid only. */
  | { type: "gridStep"; delta: -1 | 1 }
  | { type: "openBackgrounds"; theme: string }
  | { type: "showThemes" }
  | { type: "toggleActions" }
  | { type: "closeActions" }
  | { type: "highlightAction"; index: number }
  | { type: "dismissFailure" };

const GRID_COLUMNS = 2;

function clamp(value: number, max: number) {
  return Math.min(Math.max(value, 0), max);
}

export function switcherReducer(model: SwitcherModel, action: SwitcherAction): SwitcherModel {
  const { ui } = model;
  switch (action.type) {
    case "reset":
      return initialModel(action.data, action.failure);
    case "data":
      return reconcile({ ...model, data: action.data });
    case "search":
      return reconcile({ ...model, ui: { ...ui, search: action.search } });
    case "select":
      return { ...model, ui: { ...ui, selection: action.key } };
    case "selectTile":
      return { ...model, ui: { ...ui, tile: action.path } };
    case "step": {
      if (ui.actionsOpen) {
        const count = actionItems(model).length;
        return {
          ...model,
          ui: { ...ui, action: clamp(ui.action + action.delta, count - 1) },
        };
      }
      if (ui.mode.kind === "backgrounds") return moveTile(model, action.delta * GRID_COLUMNS);
      const keys = buildRows(model.data, ui.search).map(rowKey);
      if (keys.length === 0) return model;
      const index = ui.selection === null ? -1 : keys.indexOf(ui.selection);
      const next = keys[clamp(index + action.delta, keys.length - 1)] ?? null;
      return { ...model, ui: { ...ui, selection: next } };
    }
    case "gridStep":
      return ui.mode.kind === "backgrounds" && !ui.actionsOpen
        ? moveTile(model, action.delta)
        : model;
    case "openBackgrounds": {
      if (!findTheme(model.data, action.theme)) return model;
      const next: SwitcherModel = {
        ...model,
        ui: {
          ...ui,
          mode: { kind: "backgrounds", theme: action.theme },
          search: "",
          tile: null,
          actionsOpen: false,
        },
      };
      return reconcile(next);
    }
    case "showThemes":
      return reconcile({
        ...model,
        ui: { ...ui, mode: { kind: "themes" }, search: "", tile: null },
      });
    case "toggleActions":
      return { ...model, ui: { ...ui, actionsOpen: !ui.actionsOpen, action: 0 } };
    case "closeActions":
      return ui.actionsOpen ? { ...model, ui: { ...ui, actionsOpen: false } } : model;
    case "highlightAction":
      return { ...model, ui: { ...ui, action: action.index } };
    case "dismissFailure":
      return ui.failure ? { ...model, ui: { ...ui, failure: null } } : model;
  }
}

function moveTile(model: SwitcherModel, offset: number): SwitcherModel {
  const paths = visibleTiles(model).map((bg) => bg.path);
  if (paths.length === 0) return model;
  const index = model.ui.tile === null ? 0 : Math.max(paths.indexOf(model.ui.tile), 0);
  const tile = paths[clamp(index + offset, paths.length - 1)] ?? null;
  return { ...model, ui: { ...model.ui, tile } };
}
