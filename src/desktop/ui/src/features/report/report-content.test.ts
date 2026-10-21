import { describe, expect, it } from "vitest";

import { formatBytes, issuesFor, knownIssues, withSteps } from "./report-content";

describe("issuesFor", () => {
  it("narrows to the chosen area and lists every issue for Other", () => {
    expect(issuesFor("shortcuts").map((issue) => issue.title)).toEqual(["Shortcuts stop working"]);
    expect(issuesFor("menu-bar")).toEqual([]);
    expect(issuesFor("other")).toBe(knownIssues);
  });
});

describe("withSteps", () => {
  it("starts an empty description with the outline", () => {
    expect(withSteps("")).toBe("Steps to reproduce:\n1. \n2. \n3. \n\nExpected:\n");
  });

  it("adds the outline after a blank line and only once", () => {
    const added = withSteps("The bar went away  \n");
    expect(added.startsWith("The bar went away\n\nSteps to reproduce:\n")).toBe(true);
    expect(withSteps(added)).toBe(added);
  });
});

describe("formatBytes", () => {
  it("rounds to whole kilobytes, never below one, and uses megabytes from 1000 KB", () => {
    expect(formatBytes(12)).toBe("1 KB");
    expect(formatBytes(860 * 1024)).toBe("860 KB");
    expect(formatBytes(1.5 * 1024 * 1024)).toBe("1.5 MB");
  });
});
