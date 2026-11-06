import { definePage } from "~/shell/page";

import { MenuBarPage } from "./menu-bar-page";
import { createMenuBarStore } from "./menu-bar-store";

export const menuBarPage = definePage({
  id: "menuBar",
  wide: true,
  create: (host) =>
    createMenuBarStore({
      getThemes: () => host.request("themes.getState"),
      getState: () => host.request("menuBar.getState"),
      apply: (items, bar) => host.request("menuBar.apply", { items, bar }),
      reveal: (widget) => host.request("menuBar.revealWidget", { widget }),
      openFile: (widget, file) => host.request("menuBar.openWidgetFile", { widget, file }),
      duplicate: (widget) => host.request("menuBar.duplicateWidget", { widget }),
      subscribe: host.subscribe,
    }),
  render: (store, context) => <MenuBarPage store={store} context={context} />,
});
