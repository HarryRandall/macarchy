export interface HealthSummary {
  /** Checks that failed or warn; null until Setup health has been read. */
  issues: number | null;
  /** The Mac's model name, such as "MacBook Pro". */
  model: string | null;
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null;
}

/**
 * Reads the sidebar's badge and the brand menu's subtitle from the Setup
 * health page's store. The shell only holds that store as a `PageStore`, so
 * its snapshot is checked rather than cast.
 */
export function healthSummary(snapshot: unknown): HealthSummary {
  const state = isRecord(snapshot) ? snapshot.state : null;
  if (!isRecord(state) || !Array.isArray(state.checks)) return { issues: null, model: null };
  const checks: unknown[] = state.checks;
  const issues = checks.filter((check) => {
    const status = isRecord(check) ? check.status : null;
    return status === "failed" || status === "warning";
  }).length;
  const environment = isRecord(state.environment) ? state.environment : {};
  const model = typeof environment.model === "string" && environment.model ? environment.model : null;
  return { issues, model };
}
