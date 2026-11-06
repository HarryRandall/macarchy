/**
 * One listener at a time, for a request that crosses from a page to the shell
 * without either holding the other's state.
 */
export interface Signal {
  emit(): void;
  /** Replaces any earlier listener; returns the unsubscribe. */
  listen(listener: () => void): () => void;
}

export function createSignal(): Signal {
  let current: (() => void) | null = null;
  return {
    emit: () => current?.(),
    listen(listener) {
      current = listener;
      return () => {
        if (current === listener) current = null;
      };
    },
  };
}
