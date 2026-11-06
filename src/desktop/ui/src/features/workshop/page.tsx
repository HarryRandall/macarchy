import { definePage } from "~/shell/page";

import { WorkshopPage } from "./workshop-page";
import { createWorkshopStore } from "./workshop-store";

export const workshopPage = definePage({
  id: "workshop",
  create: (host) =>
    createWorkshopStore({
      getThemes: () => host.request("themes.getState"),
      subscribe: host.subscribe,
    }),
  render: (store) => <WorkshopPage store={store} />,
});
