import { createListeners } from "~/lib/store";
import { isNewer } from "~/lib/version";

import { latestRelease, releases } from "./changelog-mock";

/**
 * Which release notes the person has read, and which release's sidebar card
 * they dismissed. Kept in the page's own storage: losing it only brings the
 * card back, so it is not worth a bridge method.
 */
export interface ChangelogSeen {
  /** The newest version read; null when the changelog has never been opened. */
  lastSeen: string | null;
  /** The version whose card was dismissed. */
  dismissed: string | null;
}

const key = "macarchy.changelog";

interface StorageLike {
  getItem(key: string): string | null;
  setItem(key: string, value: string): void;
}

function storage(): StorageLike | null {
  try {
    return globalThis.localStorage ?? null;
  } catch {
    return null;
  }
}

function read(store: StorageLike | null): ChangelogSeen {
  try {
    const raw: unknown = JSON.parse(store?.getItem(key) ?? "null");
    if (typeof raw !== "object" || raw === null) return { lastSeen: null, dismissed: null };
    const { lastSeen, dismissed } = raw as Record<string, unknown>;
    return {
      lastSeen: typeof lastSeen === "string" ? lastSeen : null,
      dismissed: typeof dismissed === "string" ? dismissed : null,
    };
  } catch {
    return { lastSeen: null, dismissed: null };
  }
}

/**
 * The version the "new" markers count from. Someone who has never opened the
 * changelog sees only the latest release as new, not the whole history.
 */
export function seenBaseline(lastSeen: string | null): string {
  return lastSeen ?? releases[1]?.version ?? "0";
}

export function hasUnseenRelease(seen: ChangelogSeen): boolean {
  return isNewer(latestRelease.version, seenBaseline(seen.lastSeen));
}

export function createChangelogSeen(store: StorageLike | null = storage()) {
  const listeners = createListeners();
  let snapshot = read(store);

  function save(patch: Partial<ChangelogSeen>) {
    snapshot = { ...snapshot, ...patch };
    try {
      store?.setItem(key, JSON.stringify(snapshot));
    } catch {
      // Private browsing or a full store; the choice still holds for this session.
    }
    listeners.notify();
  }

  return {
    subscribe: listeners.subscribe,
    getSnapshot: () => snapshot,
    markSeen() {
      if (snapshot.lastSeen !== latestRelease.version) save({ lastSeen: latestRelease.version });
    },
    dismissCard() {
      save({ dismissed: latestRelease.version });
    },
  };
}
