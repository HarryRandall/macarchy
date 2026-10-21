import { definePage } from "~/shell/page";

import { RulesPage } from "./rules-page";
import { createRulesStore } from "./rules-store";

export const rulesPage = definePage({
  id: "rules",
  create: (host) =>
    createRulesStore({
      getState: () => host.request("rules.getState"),
      addApplication: () => host.request("rules.addApplication"),
      removeFloating: (app) => host.request("rules.removeFloating", { app }),
      saveCustom: (rule) => host.request("rules.saveCustom", { rule }),
      removeCustom: (id) => host.request("rules.removeCustom", { id }),
      subscribe: host.subscribe,
    }),
  render: (store) => <RulesPage store={store} />,
});
