import type { ReactNode } from "react";

import type { Bridge } from "~/bridge/client";
import type { BridgeMethods, PaneId } from "~/bridge/protocol";
import type { ReadableStore } from "~/lib/store";

/** What the shell needs to know about any page's store. */
export interface PageStatus {
  status: "loading" | "ready" | "failed";
}

export interface PageStore extends ReadableStore<PageStatus> {
  /** Reads the page's state. Must never change the desktop. */
  load(): Promise<void>;
}

export interface PageHost {
  request: Bridge["request"];
  subscribe: Bridge["subscribe"];
}

/** What a page may ask of the window around it. */
export interface PageContext {
  /** Shows another pane: a React page here, anything else in the classic window. */
  navigate(pane: PaneId): void;
  openClassic(params: BridgeMethods["shell.openClassic"]["params"]): void;
  /** Opens the window's logs panel, as ⇧⌘L does. */
  openLogs(): void;
}

/**
 * One React page. Its store is created when the window loads, so it hears
 * events from the start, and loaded the first time the page is shown.
 */
export interface PageDefinition<S extends PageStore> {
  id: PaneId;
  create(host: PageHost): S;
  render(store: S, context: PageContext): ReactNode;
}

export interface RegisteredPage {
  id: PaneId;
  create(host: PageHost): PageStore;
  render(store: PageStore, context: PageContext): ReactNode;
}

/**
 * Erases the page's store type for the registry. Each page only ever renders
 * the store its own `create` made, so the cast cannot mix them up.
 */
export function definePage<S extends PageStore>(page: PageDefinition<S>): RegisteredPage {
  return {
    id: page.id,
    create: (host) => page.create(host),
    render: (store, context) => page.render(store as S, context),
  };
}
