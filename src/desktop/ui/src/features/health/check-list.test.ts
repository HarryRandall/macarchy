import { describe, expect, it } from "vitest";

import {
  type Check,
  headline,
  listNames,
  othersTitle,
  partitionChecks,
  runSummary,
} from "./check-list";

const check = (title: string, status: Check["status"]): Check => ({
  id: `Dependencies/${title}`,
  group: "Dependencies",
  title,
  status,
  detail: "",
  advice: null,
  command: null,
  file: null,
});

describe("check list", () => {
  it("puts failures before warnings and keeps unknown checks with the passes", () => {
    const { problems, others } = partitionChecks([
      check("jq", "warning"),
      check("yabai", "passed"),
      check("skhd", "failed"),
      check("addition", "unknown"),
      check("borders", "failed"),
    ]);
    expect(problems.map((c) => c.title)).toEqual(["skhd", "borders", "jq"]);
    expect(others.map((c) => c.title)).toEqual(["addition", "yabai"]);
    expect(othersTitle(others)).toBe("1 check passed, 1 could not be checked");
    expect(othersTitle([check("yabai", "passed"), check("jq", "passed")])).toBe("2 checks passed");
  });

  it("words the headline and long lists of names", () => {
    expect(headline(0, false)).toBe("Everything is set up");
    expect(headline(1, false)).toBe("1 thing needs attention");
    expect(headline(3, false)).toBe("3 things need attention");
    expect(headline(3, true)).toBe("Running checks");
    expect(listNames(["a", "b"])).toBe("a, b");
    expect(listNames(["a", "b", "c", "d", "e"])).toBe("a, b, c and 2 more");
    expect(runSummary(1, "10:42")).toBe("1 check, last run at 10:42");
    expect(runSummary(12, "10:42")).toBe("12 checks, last run at 10:42");
  });
});
