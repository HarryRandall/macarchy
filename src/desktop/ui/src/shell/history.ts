/**
 * Visited routes, kept the way a browser keeps them: going somewhere new
 * drops anything ahead, and back and forward step through the rest.
 */
export interface History<T> {
  readonly past: readonly T[];
  readonly current: T;
  readonly future: readonly T[];
}

/** Long enough for any real session without growing without bound. */
const limit = 50;

export function startHistory<T>(route: T): History<T> {
  return { past: [], current: route, future: [] };
}

/** Going to the route already shown changes nothing, so back never repeats a page. */
export function visit<T>(history: History<T>, route: T): History<T> {
  if (route === history.current) return history;
  return { past: [...history.past, history.current].slice(-limit), current: route, future: [] };
}

export function goBack<T>(history: History<T>): History<T> {
  const previous = history.past.at(-1);
  if (previous === undefined) return history;
  return {
    past: history.past.slice(0, -1),
    current: previous,
    future: [history.current, ...history.future],
  };
}

export function goForward<T>(history: History<T>): History<T> {
  const [next, ...rest] = history.future;
  if (next === undefined) return history;
  return { past: [...history.past, history.current], current: next, future: rest };
}
