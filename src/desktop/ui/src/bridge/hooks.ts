import { useEffect, useRef } from "react";

import { bridge } from "./client";
import type { BridgeEvent } from "./protocol";

type EventType = BridgeEvent["type"];

/**
 * Calls the latest `handler` for each event of `type` while mounted.
 *
 * Events that arrive before the component mounts are not replayed; state that
 * must not miss early events lives in a store that subscribes before
 * `bridge.start()`.
 */
export function useBridgeEvent<T extends EventType>(
  type: T,
  handler: (event: Extract<BridgeEvent, { type: T }>) => void,
) {
  const latest = useRef(handler);
  useEffect(() => {
    latest.current = handler;
  });
  useEffect(() => bridge.subscribe(type, (event) => latest.current(event)), [type]);
}
