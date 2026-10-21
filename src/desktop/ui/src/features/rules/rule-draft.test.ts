import { expect, it } from "vitest";

import { createRuleDraft } from "./rule-draft";

it("makes a stable version 4 identifier for each new unsaved draft", () => {
  const first = createRuleDraft("Finder", "^Copy$");
  const second = createRuleDraft();
  expect(first).toMatchObject({ app: "Finder", title: "^Copy$" });
  expect(first.id).toMatch(/^[\da-f]{8}-[\da-f]{4}-4[\da-f]{3}-[89ab][\da-f]{3}-[\da-f]{12}$/);
  expect(second.id).not.toBe(first.id);
  expect(second).toMatchObject({ app: "", title: "" });
});
