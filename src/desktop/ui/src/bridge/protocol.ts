/**
 * The contract between the React interface and the native host.
 *
 * Requests go from the page to Swift as `{ method, params }` through the
 * `macarchy` script message handler, which replies with a JSON envelope.
 * Events go from Swift to the page through `window.macarchyBridge.receive`.
 * Each feature's shapes live in `contract/<feature>.ts`, and the Swift side
 * mirrors them in `src/desktop/native/features/<feature>`; change both
 * together. To add a feature, add its contract file and compose it below.
 */

export type Surface = "settings" | "switcher";

/** Panes in the order the sidebar lists them. */
export type PaneId =
  | "home"
  | "workshop"
  | "plugins"
  | "themes"
  | "borders"
  | "menuBar"
  | "layout"
  | "rules"
  | "shortcuts"
  | "health"
  | "advanced"
  | "report";

export interface Rect {
  x: number;
  y: number;
  width: number;
  height: number;
}

import type { AdvancedEvent, AdvancedMethods } from "./contract/advanced";
import type { BordersEvent, BordersMethods } from "./contract/borders";
import type { HealthEvent, HealthMethods } from "./contract/health";
import type { HomeEvent, HomeMethods } from "./contract/home";
import type { ThemesMethods } from "./contract/themes";
import type { LayoutEvent, LayoutMethods } from "./contract/layout";
import type { ReportMethods } from "./contract/report";
import type { RulesEvent, RulesMethods } from "./contract/rules";
import type { ShortcutsEvent, ShortcutsMethods } from "./contract/shortcuts";
import type { ShellEvent, ShellMethods } from "./contract/shell";
import type { SwitcherEvent, SwitcherMethods } from "./contract/switcher";

export type * from "./contract/advanced";
export type * from "./contract/borders";
export type * from "./contract/health";
export type * from "./contract/home";
export type * from "./contract/themes";
export type * from "./contract/shortcuts";
export type * from "./contract/layout";
export type * from "./contract/report";
export type * from "./contract/rules";
export type * from "./contract/shell";
export type * from "./contract/switcher";

interface AppMethods {
  /** The surface has rendered with real data; the host may show its window. */
  "app.ready": { params: { surface: Surface }; result: null };
}

export interface BridgeMethods
  extends
    AppMethods,
    ShellMethods,
    LayoutMethods,
    SwitcherMethods,
    RulesMethods,
    AdvancedMethods,
    BordersMethods,
    HomeMethods,
    HealthMethods,
    ReportMethods,
    ThemesMethods,
    ShortcutsMethods {}

export type BridgeMethod = keyof BridgeMethods;
export type ParamsOf<M extends BridgeMethod> = BridgeMethods[M]["params"];
export type ResultOf<M extends BridgeMethod> = BridgeMethods[M]["result"];

export type BridgeErrorCode =
  "unknown_method" | "invalid_params" | "unavailable" | "operation_failed" | "internal";

/** What the host replies with, serialised as a JSON string. */
export type Reply<T> =
  { ok: true; value: T } | { ok: false; error: { code: BridgeErrorCode; message: string } };

export type BridgeEvent =
  | ShellEvent
  | LayoutEvent
  | SwitcherEvent
  | RulesEvent
  | AdvancedEvent
  | BordersEvent
  | HomeEvent
  | HealthEvent
  | ShortcutsEvent;

/**
 * Installed by the host at document start, before any page script runs, so
 * events sent during loading are queued rather than lost.
 */
export interface NativeEventSink {
  queue: string[];
  /** Replaced by the page's client; returns a promise for the switcher's open and close. */
  receive: (event: string) => unknown;
}

declare global {
  interface Window {
    macarchyBridge?: NativeEventSink;
    webkit?: {
      messageHandlers?: {
        macarchy?: { postMessage: (message: unknown) => Promise<string> };
      };
    };
  }
}
