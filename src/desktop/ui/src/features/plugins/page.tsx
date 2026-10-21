import { definePage } from "~/shell/page";

import { PluginsPage } from "./plugins-page";
import { createPluginsStore } from "./plugins-store";

export const pluginsPage = definePage({
  id: "plugins",
  create: () => createPluginsStore(),
  render: (store) => <PluginsPage store={store} />,
});
