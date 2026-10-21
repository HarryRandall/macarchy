import { errorMessage } from "~/bridge/client";
import type { BridgeEvent, BridgeMethods, LogEntry } from "~/bridge/protocol";
import { createListeners } from "~/lib/store";

import { chronological } from "./log-filter";

interface LogSnapshot {
  status: "idle" | "loading" | "ready" | "failed";
  entries: readonly LogEntry[];
  error: string | null;
  /** Entries shown while the panel was open, so the unread dot can leave them out. */
  seen: ReadonlySet<string>;
}

type Request = <M extends "shell.getLog" | "shell.clearLog">(
  method: M,
  params: BridgeMethods[M]["params"],
) => Promise<BridgeMethods[M]["result"]>;

/**
 * The app's command log. `shell.logChanged` only says it changed, so the
 * store reads it again, coalescing a burst of events into one read after the
 * one in flight.
 */
export function createLogStore(deps: {
  request: Request;
  subscribe(
    type: "shell.logChanged",
    handler: (event: Extract<BridgeEvent, { type: "shell.logChanged" }>) => void,
  ): () => void;
}) {
  const listeners = createListeners();
  let snapshot: LogSnapshot = { status: "idle", entries: [], error: null, seen: new Set() };
  let reading: Promise<void> | null = null;
  let again = false;

  function set(patch: Partial<LogSnapshot>) {
    snapshot = { ...snapshot, ...patch };
    listeners.notify();
  }

  async function read() {
    do {
      again = false;
      try {
        const { entries } = await deps.request("shell.getLog", {});
        set({ status: "ready", entries: chronological(entries), error: null });
      } catch (error) {
        set({
          status: snapshot.status === "ready" ? "ready" : "failed",
          error: errorMessage(error),
        });
      }
    } while (again);
  }

  function load(): Promise<void> {
    if (reading) {
      again = true;
      return reading;
    }
    if (snapshot.status === "idle") set({ status: "loading" });
    reading = read().finally(() => {
      reading = null;
    });
    return reading;
  }

  deps.subscribe("shell.logChanged", () => {
    if (snapshot.status !== "idle") void load();
  });

  return {
    subscribe: listeners.subscribe,
    getSnapshot: () => snapshot,
    load,

    /** Rejects with the host's reason; the entries stay until the host has cleared them. */
    async clear() {
      await deps.request("shell.clearLog", {});
      set({ entries: [], seen: new Set() });
      await load();
    },

    markSeen() {
      if (snapshot.entries.every((entry) => snapshot.seen.has(entry.id))) return;
      set({ seen: new Set(snapshot.entries.map((entry) => entry.id)) });
    },
  };
}

export type LogStore = ReturnType<typeof createLogStore>;
