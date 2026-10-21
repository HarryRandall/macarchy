export interface ReportState {
  body: string;
  /** Identifies the exact redacted preview held by the native host. */
  token: string;
}
export interface ReportMethods {
  /**
   * `refresh` collects diagnostics again unless a collection is running;
   * otherwise the last collection is reused, so draft edits stay cheap.
   */
  "report.prepare": { params: { description: string; refresh: boolean }; result: ReportState };
  "report.copy": { params: { token: string }; result: null };
  "report.openIssue": { params: { token: string; title: string }; result: { copied: boolean } };
  "report.openIssues": { params: Record<string, never>; result: null };
}
