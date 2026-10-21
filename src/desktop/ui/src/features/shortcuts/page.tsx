import { definePage } from "~/shell/page";

import { ShortcutsPage } from "./shortcuts-page";
import { createShortcutsStore } from "./shortcuts-store";

export const shortcutsPage = definePage({
  id: "shortcuts",
  create: createShortcutsStore,
  render: (store) => <ShortcutsPage store={store} />,
});
