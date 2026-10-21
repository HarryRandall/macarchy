import { useSyncExternalStore } from "react";

/** The minimum a plain-TypeScript store needs to drive React. */
export interface ReadableStore<T> {
  subscribe(listener: () => void): () => void;
  getSnapshot(): T;
}

export function createListeners() {
  const listeners = new Set<() => void>();
  return {
    subscribe(listener: () => void) {
      listeners.add(listener);
      return () => listeners.delete(listener);
    },
    notify() {
      for (const listener of listeners) listener();
    },
  };
}

export function useStore<T>(store: ReadableStore<T>): T {
  return useSyncExternalStore(store.subscribe, store.getSnapshot);
}
