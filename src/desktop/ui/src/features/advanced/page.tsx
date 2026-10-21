import { bridge, request } from "~/bridge/client";
import { definePage } from "~/shell/page";
import { setupPresentation } from "~/features/setup/setup-presentation";
import { AdvancedPage } from "./advanced-page";
import { createAdvancedStore } from "./advanced-store";

export const advancedPage = definePage({
  id: "advanced",
  create: createAdvancedStore,
  render: (store) => (
    <AdvancedPage
      store={store}
      openSetup={() => setupPresentation.open({ request, subscribe: bridge.subscribe })}
    />
  ),
});
