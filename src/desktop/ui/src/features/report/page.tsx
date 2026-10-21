import { definePage } from "~/shell/page";
import { ReportPage } from "./report-page";
import { createReportStore } from "./report-store";
export const reportPage = definePage({
  id: "report",
  create: createReportStore,
  render: (store) => <ReportPage store={store} />,
});
