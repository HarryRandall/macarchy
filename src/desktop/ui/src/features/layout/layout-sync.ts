import type { LayoutApplyParams, LayoutValues } from "~/bridge/protocol";

export type LayoutField = keyof LayoutValues;

/**
 * Takes what the host reports, except for fields the person is still
 * editing: those keep the local value so a refresh or an external change
 * cannot yank a slider out from under the pointer.
 */
export function mergeLayoutValues(
  local: LayoutValues,
  incoming: LayoutValues,
  keepLocal: ReadonlySet<LayoutField>,
): LayoutValues {
  const merged = { ...incoming };
  for (const field of keepLocal) {
    (merged as Record<LayoutField, unknown>)[field] = local[field];
  }
  return merged;
}

export interface Timers {
  setTimeout(run: () => void, ms: number): unknown;
  clearTimeout(handle: unknown): void;
}

interface FieldState {
  timer: unknown;
  queued: LayoutApplyParams | null;
  inFlight: number;
  /** Clock reading when the last send for this field settled. */
  settledAt: number;
}

export interface EditQueueOptions {
  delay: number;
  timers: Timers;
  send(params: LayoutApplyParams): Promise<unknown>;
  /** `sentAt` is the clock reading when this send left, to order it against other events. */
  onSettled?(field: LayoutField, error: unknown, sentAt: number): void;
}

/**
 * Debounces edits per field, so a slider drag sends a few coalesced applies
 * while a select changed in the same moment still goes on its own beat.
 *
 * A logical clock orders sends against reads: a read started before a send
 * settled may predate it, so `protectedFields(since)` keeps that field local.
 */
export function createEditQueue({ delay, timers, send, onSettled }: EditQueueOptions) {
  const fields = new Map<LayoutField, FieldState>();
  let clock = 0;

  function state(field: LayoutField): FieldState {
    let entry = fields.get(field);
    if (!entry) {
      entry = { timer: null, queued: null, inFlight: 0, settledAt: 0 };
      fields.set(field, entry);
    }
    return entry;
  }

  function flush(field: LayoutField) {
    const entry = state(field);
    entry.timer = null;
    const params = entry.queued;
    entry.queued = null;
    if (!params) return;
    entry.inFlight += 1;
    const sentAt = ++clock;
    send(params).then(
      () => settle(field, null, sentAt),
      (error: unknown) => settle(field, error ?? new Error("Apply failed"), sentAt),
    );
  }

  function settle(field: LayoutField, error: unknown, sentAt: number) {
    const entry = state(field);
    entry.inFlight -= 1;
    entry.settledAt = ++clock;
    onSettled?.(field, error, sentAt);
  }

  return {
    /** Reads the clock; pass the result to `protectedFields` when the read returns. */
    now: () => ++clock,

    /** `linkPadding` is captured here, at the moment of the edit. */
    edit<F extends LayoutField>(field: F, value: LayoutValues[F], linkPadding: boolean) {
      const entry = state(field);
      if (entry.timer !== null) timers.clearTimeout(entry.timer);
      entry.queued = { changes: { [field]: value }, linkPadding };
      entry.timer = timers.setTimeout(() => flush(field), delay);
    },

    isBusy(field: LayoutField) {
      const entry = fields.get(field);
      return !!entry && (entry.timer !== null || entry.inFlight > 0);
    },

    /** Fields whose local value must win over a read that started at `since`. */
    protectedFields(since: number): Set<LayoutField> {
      const result = new Set<LayoutField>();
      for (const [field, entry] of fields) {
        if (entry.timer !== null || entry.inFlight > 0 || entry.settledAt > since) {
          result.add(field);
        }
      }
      return result;
    },
  };
}

export type EditQueue = ReturnType<typeof createEditQueue>;
