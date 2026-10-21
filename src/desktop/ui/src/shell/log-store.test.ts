import { describe, expect, it, vi } from "vitest";

import type { LogEntry } from "~/bridge/protocol";

import { createLogStore } from "./log-store";

function entry(id: string, at: number, ok = true): LogEntry {
  return { id, command: `command ${id}`, detail: "", ok, at, status: 0, category: "System" };
}

function harness() {
  let handler: (() => void) | null = null;
  let log: LogEntry[] = [entry("b", 20, false), entry("a", 10)];
  const reads: (() => void)[] = [];
  const methods: string[] = [];
  const store = createLogStore({
    request: ((method: string) => {
      methods.push(method);
      if (method === "shell.clearLog") {
        log = [];
        return Promise.resolve(null);
      }
      const answer = { entries: log };
      return new Promise((resolve) => reads.push(() => resolve(answer)));
    }) as never,
    subscribe: (_type, next) => {
      handler = () => next({ type: "shell.logChanged" });
      return () => {};
    },
  });
  return {
    store,
    reads,
    methods,
    append: (next: LogEntry) => {
      log = [...log, next];
      handler?.();
    },
    answer: () => reads.shift()?.(),
  };
}

const ids = (entries: readonly LogEntry[]) => entries.map((item) => item.id);

describe("log store", () => {
  it("ignores changes until it has been loaded", () => {
    const { store, append, methods } = harness();
    append(entry("c", 30));
    expect(methods).toEqual([]);
    expect(store.getSnapshot().status).toBe("idle");
  });

  it("reads oldest first", async () => {
    const { store, answer } = harness();
    const loading = store.load();
    expect(store.getSnapshot().status).toBe("loading");
    answer();
    await loading;
    expect(ids(store.getSnapshot().entries)).toEqual(["a", "b"]);
  });

  it("folds changes during a read into one more read", async () => {
    const { store, append, answer, methods } = harness();
    const loading = store.load();
    append(entry("c", 30));
    append(entry("d", 40));
    answer();
    await vi.waitFor(() => expect(reads).toHaveLength(1));
    answer();
    await loading;
    expect(methods).toEqual(["shell.getLog", "shell.getLog"]);
    expect(ids(store.getSnapshot().entries)).toEqual(["a", "b", "c", "d"]);
  });

  it("forgets seen entries once cleared", async () => {
    const { store, answer, methods } = harness();
    const loading = store.load();
    answer();
    await loading;
    store.markSeen();
    expect(store.getSnapshot().seen).toEqual(new Set(["a", "b"]));

    const clearing = store.clear();
    await vi.waitFor(() => expect(reads).toHaveLength(1));
    answer();
    await clearing;
    expect(methods).toEqual(["shell.getLog", "shell.clearLog", "shell.getLog"]);
    expect(store.getSnapshot().entries).toEqual([]);
    expect(store.getSnapshot().seen).toEqual(new Set());
  });
});
