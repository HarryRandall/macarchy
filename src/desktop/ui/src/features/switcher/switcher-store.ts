import { errorMessage } from "~/bridge/client";
import type { BridgeEvent, BridgeMethods, SwitcherState } from "~/bridge/protocol";
import { createListeners } from "~/lib/store";

import {
  type Command,
  initialModel,
  primaryAction,
  selectedRow,
  type SwitcherAction,
  type SwitcherModel,
  switcherReducer,
} from "./switcher-model";

type SwitcherMethod =
  | "switcher.getState"
  | "switcher.refresh"
  | "switcher.applyTheme"
  | "switcher.useBackground"
  | "switcher.openSettings"
  | "switcher.close";

type Request = <M extends SwitcherMethod>(
  method: M,
  params: BridgeMethods[M]["params"],
) => Promise<BridgeMethods[M]["result"]>;

type Subscribe = <T extends "switcher.willOpen" | "switcher.didClose" | "themes.changed">(
  type: T,
  handler: (event: Extract<BridgeEvent, { type: T }>) => void,
) => () => void;

function fail(error: unknown) {
  console.error(error);
}

export interface SwitcherSnapshot {
  model: SwitcherModel | null;
  /** Bumped on every open and close, so the view can reset focus and scroll. */
  generation: number;
  /** Why themes could not be read, shown in place of the list. */
  error: string | null;
}

export function createSwitcherStore({
  request,
  subscribe,
}: {
  request: Request;
  subscribe: Subscribe;
}) {
  const listeners = createListeners();
  let snapshot: SwitcherSnapshot = { model: null, generation: 0, error: null };
  /** Set once an event has delivered state, which is newer than any pending read. */
  let heardFromHost = false;

  function setModel(model: SwitcherModel, isReset = false, error: string | null = null) {
    snapshot = { model, generation: snapshot.generation + (isReset ? 1 : 0), error };
    listeners.notify();
  }

  function dispatch(action: SwitcherAction) {
    if (!snapshot.model) return;
    const next = switcherReducer(snapshot.model, action);
    if (next !== snapshot.model) setModel(next, action.type === "reset", snapshot.error);
  }

  function reset(data: SwitcherState) {
    heardFromHost = true;
    setModel(initialModel(data), true);
  }

  subscribe("switcher.willOpen", (event) => reset(event.state));
  subscribe("switcher.didClose", () => {
    // Reset now, while hidden, so the next open never shows a stale frame.
    if (snapshot.model) reset(snapshot.model.data);
  });
  subscribe("themes.changed", (event) => {
    heardFromHost = true;
    if (snapshot.model)
      setModel(switcherReducer(snapshot.model, { type: "data", data: event.state }));
    else setModel(initialModel(event.state), true);
  });

  async function refresh() {
    try {
      const data = await request("switcher.refresh", {});
      if (snapshot.model) setModel(switcherReducer(snapshot.model, { type: "data", data }));
    } catch (error) {
      fail(error);
    }
  }

  return {
    subscribe: listeners.subscribe,
    getSnapshot: () => snapshot,
    dispatch,

    /** Settles either way, so the host can be told the panel is ready. */
    async load() {
      try {
        const data = await request("switcher.getState", {});
        if (!heardFromHost) setModel(initialModel(data), true);
      } catch (error) {
        fail(error);
        if (!heardFromHost) {
          setModel(initialModel({ themes: [], current: null }), true, errorMessage(error));
        }
      }
    },

    run(command: Command) {
      const model = snapshot.model;
      if (!model) return;
      dispatch({ type: "closeActions" });
      switch (command) {
        case "primary": {
          const action = primaryAction(model);
          if (action?.kind === "apply") {
            request("switcher.applyTheme", { theme: action.theme }).catch(fail);
          } else if (action?.kind === "openBackgrounds") {
            dispatch({ type: "openBackgrounds", theme: action.theme });
          } else if (action?.kind === "useBackground") {
            request("switcher.useBackground", {
              theme: action.theme,
              path: action.path,
            }).catch(fail);
          }
          return;
        }
        case "switchBackground": {
          const row = selectedRow(model);
          if (model.ui.mode.kind === "themes" && row?.kind === "theme") {
            dispatch({ type: "openBackgrounds", theme: row.name });
          }
          return;
        }
        case "refresh":
          void refresh();
          return;
        case "openSettings":
          request("switcher.openSettings", {}).catch(fail);
          return;
      }
    },

    /** Closes the actions menu, else leaves the grid, else closes the panel. */
    escape() {
      const model = snapshot.model;
      if (!model) return;
      if (model.ui.actionsOpen) dispatch({ type: "closeActions" });
      else if (model.ui.mode.kind === "backgrounds") dispatch({ type: "showThemes" });
      else request("switcher.close", {}).catch(fail);
    },
  };
}

export type SwitcherStore = ReturnType<typeof createSwitcherStore>;
