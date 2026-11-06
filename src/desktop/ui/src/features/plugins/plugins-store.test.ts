import { expect, it } from "vitest";

import { createPluginsStore, parseNotify, type PluginsStorage } from "./plugins-store";

function memory(initial: string | null = null): PluginsStorage & { value: string | null } {
  return {
    value: initial,
    read() {
      return this.value;
    },
    write(value) {
      this.value = value;
    },
  };
}

it("recalls saved notify choices on load and saves each toggle", async () => {
  const storage = memory(JSON.stringify(["media"]));
  const store = createPluginsStore(storage);
  expect(store.getSnapshot().status).toBe("loading");
  await store.load();
  expect(store.getSnapshot()).toMatchObject({ status: "ready" });
  expect([...store.getSnapshot().notify]).toEqual(["media"]);
  store.toggleNotify("stack");
  store.toggleNotify("media");
  expect([...store.getSnapshot().notify]).toEqual(["stack"]);
  expect(parseNotify(storage.value)).toEqual(["stack"]);
});

it.each([null, "", "not json", "{}", '"media"', "[1, null]"])(
  "treats %j as no saved choices",
  (raw) => {
    expect(parseNotify(raw)).toEqual([]);
  },
);

it("keeps only the strings from a saved list", () => {
  expect(parseNotify('["media", 3, "stack"]')).toEqual(["media", "stack"]);
});
