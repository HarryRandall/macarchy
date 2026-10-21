import type { HealthState } from "~/bridge/protocol";

export type Check = HealthState["checks"][number];

const rank: Record<Check["status"], number> = { failed: 0, warning: 1, unknown: 2, passed: 3 };

/**
 * Failures and warnings to fix, worst first, and the rest. These are the
 * checks the sidebar's badge counts, so the page and the badge agree; a
 * check that could not run sits with the passes, marked as such.
 */
export function partitionChecks(checks: readonly Check[]) {
  const byRank = checks.toSorted((a, b) => rank[a.status] - rank[b.status]);
  return {
    problems: byRank.filter((check) => check.status === "failed" || check.status === "warning"),
    others: byRank.filter((check) => check.status === "passed" || check.status === "unknown"),
  };
}

export function headline(problems: number, checking: boolean) {
  if (checking) return "Running checks";
  if (problems === 0) return "Everything is set up";
  return `${problems} ${problems === 1 ? "thing needs" : "things need"} attention`;
}

/** "yabai, skhd, jq and 2 more". */
export function listNames(names: readonly string[], shown = 3) {
  if (names.length <= shown) return names.join(", ");
  return `${names.slice(0, shown).join(", ")} and ${names.length - shown} more`;
}

export function othersTitle(others: readonly Check[]) {
  const passed = others.filter((check) => check.status === "passed").length;
  const unknown = others.length - passed;
  const text = `${passed} ${passed === 1 ? "check" : "checks"} passed`;
  return unknown ? `${text}, ${unknown} could not be checked` : text;
}
