import { flushSync } from "react-dom";

import type {
  BridgeErrorCode,
  BridgeEvent,
  BridgeMethod,
  NativeEventSink,
  ParamsOf,
  ResultOf,
} from "./protocol";

export class BridgeError extends Error {
  readonly code: BridgeErrorCode;

  constructor(code: BridgeErrorCode, message: string) {
    super(message);
    this.name = "BridgeError";
    this.code = code;
  }
}

const errorCodes = new Set<BridgeErrorCode>([
  "unknown_method",
  "invalid_params",
  "unavailable",
  "operation_failed",
  "internal",
]);

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null;
}

/** Turns the host's JSON reply into a value, or throws the error it carries. */
export function parseReply<T>(raw: unknown): T {
  let reply: unknown;
  try {
    reply = typeof raw === "string" ? JSON.parse(raw) : raw;
  } catch {
    throw new BridgeError("internal", "The app sent a reply that could not be read.");
  }
  if (!isRecord(reply) || typeof reply.ok !== "boolean") {
    throw new BridgeError("internal", "The app sent a reply in an unexpected shape.");
  }
  if (reply.ok) return ("value" in reply ? reply.value : null) as T;

  const error = isRecord(reply.error) ? reply.error : {};
  const code =
    typeof error.code === "string" && errorCodes.has(error.code as BridgeErrorCode)
      ? (error.code as BridgeErrorCode)
      : "internal";
  const message =
    typeof error.message === "string" && error.message
      ? error.message
      : "The app could not complete that request.";
  throw new BridgeError(code, message);
}

export function errorMessage(error: unknown): string {
  return error instanceof Error ? error.message : String(error);
}

type EventType = BridgeEvent["type"];
type EventOf<T extends EventType> = Extract<BridgeEvent, { type: T }>;
type Handler<T extends EventType> = (event: EventOf<T>) => void;

/** The parts of `window` the bridge touches, so tests can pass a fake. */
export interface BridgeHost {
  macarchyBridge?: NativeEventSink;
  webkit?: Window["webkit"];
}

export interface BridgeOptions {
  /** Runs event handlers so their state updates commit synchronously. */
  commit?: (run: () => void) => void;
  /** Resolves once the committed frame has been painted. */
  afterPaint?: () => Promise<void>;
}

/** Methods whose params are all optional may be called without them. */
type ParamsArgs<M extends BridgeMethod> =
  Record<string, never> extends ParamsOf<M> ? [params?: ParamsOf<M>] : [params: ParamsOf<M>];

export function createBridge(host: BridgeHost, options: BridgeOptions = {}) {
  const commit = options.commit ?? ((run: () => void) => run());
  const afterPaint = options.afterPaint ?? (() => Promise.resolve());
  const handlers = new Map<EventType, Set<(event: BridgeEvent) => void>>();
  let started = false;

  async function request<M extends BridgeMethod>(
    method: M,
    ...[params]: ParamsArgs<M>
  ): Promise<ResultOf<M>> {
    const handler = host.webkit?.messageHandlers?.macarchy;
    if (!handler) throw new BridgeError("unavailable", "Macarchy is not connected.");
    let raw: unknown;
    try {
      raw = await handler.postMessage({ method, params: params ?? {} });
    } catch (error) {
      // A reply handler that fails rather than replying rejects the promise.
      throw new BridgeError("internal", errorMessage(error));
    }
    return parseReply<ResultOf<M>>(raw);
  }

  function subscribe<T extends EventType>(type: T, handler: Handler<T>): () => void {
    let set = handlers.get(type);
    if (!set) {
      set = new Set();
      handlers.set(type, set);
    }
    const entry = handler as (event: BridgeEvent) => void;
    set.add(entry);
    return () => {
      set.delete(entry);
    };
  }

  function dispatch(event: BridgeEvent) {
    for (const handler of handlers.get(event.type) ?? []) {
      try {
        handler(event);
      } catch (error) {
        console.error(`Handling ${event.type} failed`, error);
      }
    }
  }

  function receive(raw: string): Promise<void> | undefined {
    let event: BridgeEvent;
    try {
      const parsed: unknown = typeof raw === "string" ? JSON.parse(raw) : raw;
      if (!isRecord(parsed) || typeof parsed.type !== "string") throw new Error("no type");
      event = parsed as BridgeEvent;
    } catch {
      console.error("Ignoring an unreadable event from the app", raw);
      return undefined;
    }
    commit(() => dispatch(event));
    // The host shows the panel when `willOpen` settles and orders it out when
    // `didClose` does, so neither may settle before the frame is on screen.
    if (event.type === "switcher.willOpen" || event.type === "switcher.didClose") {
      return afterPaint();
    }
    return undefined;
  }

  /** Drains events queued during loading, then takes over delivery. */
  function start() {
    if (started) return;
    started = true;
    const sink = host.macarchyBridge ?? { queue: [], receive };
    host.macarchyBridge = sink;
    const queued = sink.queue.splice(0);
    sink.receive = receive;
    for (const raw of queued) void receive(raw);
  }

  return { request, subscribe, receive, start };
}

export type Bridge = ReturnType<typeof createBridge>;

/**
 * Two frames: the first callback runs before the frame containing the commit
 * is painted, the second only after it has been.
 *
 * WebKit may stop delivering animation frames to a window that is ordered
 * out, and the host awaits this before showing the panel, so a timeout
 * guarantees the promise settles rather than leaving the panel hidden.
 */
export function afterNextPaint(timeout = 250): Promise<void> {
  return new Promise((resolve) => {
    const fallback = setTimeout(resolve, timeout);
    requestAnimationFrame(() =>
      requestAnimationFrame(() => {
        clearTimeout(fallback);
        resolve();
      }),
    );
  });
}

export const bridge = createBridge(globalThis as BridgeHost, {
  commit: (run) => flushSync(run),
  afterPaint: () => afterNextPaint(),
});

export const request = bridge.request;

/**
 * Connects to the native host, or in a plain browser during development to
 * the in-memory mock. Stores subscribe before `bridge.start()` so events the
 * host queued during loading reach them.
 */
export async function connectHost(): Promise<void> {
  if (import.meta.env.DEV && !window.webkit?.messageHandlers?.macarchy) {
    const { installMockHost } = await import("./mock");
    installMockHost();
  }
}
