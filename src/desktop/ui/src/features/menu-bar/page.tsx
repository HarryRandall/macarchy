import { definePage } from "~/shell/page";

import { MenuBarPage } from "./menu-bar-page";
import { createMenuBarStore } from "./menu-bar-store";

export const menuBarPage = definePage({
  id: "menuBar",
  create: (host) =>
    createMenuBarStore({
      getThemes: () => host.request("themes.getState"),
      subscribe: host.subscribe,
    }),
  render: (store, context) => <MenuBarPage store={store} context={context} />,
});
