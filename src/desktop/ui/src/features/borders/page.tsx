import { createThemesStore } from "~/features/themes/themes-store";
import { definePage, type PageHost } from "~/shell/page";
import { BordersPage } from "./borders-page";
import { createBordersStore } from "./borders-store";

/** The borders store, plus the themes store for the preview's palette and the colour presets. */
function createBordersPageStore(host: PageHost) {
  const borders = createBordersStore(host);
  const themes = createThemesStore(host);
  return {
    borders,
    themes,
    subscribe: borders.subscribe,
    getSnapshot: borders.getSnapshot,
    async load() {
      // The palette is decoration, so the page is ready once the borders are read.
      void themes.load();
      await borders.load();
    },
  };
}

export const bordersPage = definePage({
  id: "borders",
  create: createBordersPageStore,
  render: (store) => <BordersPage store={store.borders} themes={store.themes} />,
});
