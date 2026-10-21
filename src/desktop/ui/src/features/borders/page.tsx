import { definePage } from "~/shell/page";
import { BordersPage } from "./borders-page";
import { createBordersStore } from "./borders-store";
export const bordersPage = definePage({
  id: "borders",
  create: createBordersStore,
  render: (store) => <BordersPage store={store} />,
});
