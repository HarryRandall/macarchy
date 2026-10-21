import { describe, expect, it } from "vitest";

import { latestRelease } from "./changelog-mock";
import { createChangelogSeen, hasUnseenRelease, seenBaseline } from "./changelog-seen";

function memory(initial: Record<string, string> = {}) {
  const items = new Map(Object.entries(initial));
  return {
    getItem: (key: string) => items.get(key) ?? null,
    setItem: (key: string, value: string) => void items.set(key, value),
  };
}

describe("changelog seen state", () => {
  it("shows only the latest release as new before the changelog is opened", () => {
    expect(seenBaseline(null)).toBe("0.9.1");
    expect(hasUnseenRelease({ lastSeen: null, dismissed: null })).toBe(true);
    expect(hasUnseenRelease({ lastSeen: latestRelease.version, dismissed: null })).toBe(false);
  });

  it("remembers what was read and which card was dismissed", () => {
    const store = memory();
    const seen = createChangelogSeen(store);
    seen.markSeen();
    seen.dismissCard();
    expect(createChangelogSeen(store).getSnapshot()).toEqual({
      lastSeen: latestRelease.version,
      dismissed: latestRelease.version,
    });
  });

  it("starts fresh from storage it cannot read", () => {
    const seen = createChangelogSeen(memory({ "macarchy.changelog": "{not json" }));
    expect(seen.getSnapshot()).toEqual({ lastSeen: null, dismissed: null });
  });

  it("keeps working when storage refuses writes", () => {
    const seen = createChangelogSeen({
      getItem: () => null,
      setItem: () => {
        throw new Error("quota");
      },
    });
    seen.markSeen();
    expect(seen.getSnapshot().lastSeen).toBe(latestRelease.version);
  });
});
