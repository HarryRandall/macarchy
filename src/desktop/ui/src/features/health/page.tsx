import { definePage } from "~/shell/page";
import { HealthPage } from "./health-page";
import { createHealthStore } from "./health-store";
export const healthPage = definePage({
  id: "health",
  create: createHealthStore,
  render: (store, context) => <HealthPage store={store} context={context} />,
});
