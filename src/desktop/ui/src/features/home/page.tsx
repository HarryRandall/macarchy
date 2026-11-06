import { createThemesStore } from "~/features/themes/themes-store";
import { definePage, type PageHost } from "~/shell/page";
import { HomePage } from "./home-page";
import { createHomeStore } from "./home-store";
import { createActivityStores, createServiceSwitches } from "./services-store";

/**
 * The home summary, plus the reads Home draws on beside it: the applied
 * theme's look, the service list and the activity log.
 */
function createHomePageStore(host: PageHost) {
  const summary = createHomeStore(host);
  const themes = createThemesStore(host);
  const activity = createActivityStores(host);
  const switches = createServiceSwitches(host, () => activity.shell.load());
  return {
    summary,
    themes,
    activity,
    switches,
    subscribe: summary.subscribe,
    getSnapshot: summary.getSnapshot,
    async load() {
      // The page is ready once the summary is read; the rest fills in after.
      void themes.load();
      void activity.shell.load();
      void activity.log.load();
      await summary.load();
    },
  };
}

export const homePage = definePage({
  id: "home",
  create: createHomePageStore,
  render: (store, context) => (
    <HomePage
      store={store.summary}
      themes={store.themes}
      activity={store.activity}
      switches={store.switches}
      context={context}
    />
  ),
});
