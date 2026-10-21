export interface ReportState {
  body: string;
  /** Identifies the exact redacted preview held by the native host. */
  token: string;
}
export interface ReportMethods {
  "report.prepare": { params: { description: string }; result: ReportState };
  "report.copy": { params: { token: string }; result: null };
  "report.openIssue": { params: { token: string; title: string }; result: { copied: boolean } };
  "report.openIssues": { params: Record<string, never>; result: null };
}
