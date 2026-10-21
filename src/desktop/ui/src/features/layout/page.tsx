import { definePage } from "~/shell/page";

import { LayoutPage } from "./layout-page";
import { createLayoutStore } from "./layout-store";

export const layoutPage = definePage({
  id: "layout",
  create: (host) =>
    createLayoutStore({
      getState: () => host.request("layout.getState"),
      apply: (params) => host.request("layout.apply", params),
      subscribe: host.subscribe,
    }),
  render: (store) => <LayoutPage store={store} />,
});
