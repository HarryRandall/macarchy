import { definePage } from "~/shell/page";
import { ThemesPage } from "./themes-page";
import { createThemesStore } from "./themes-store";

export const themesPage = definePage({
  id: "themes",
  create: createThemesStore,
  render: (store, context) => <ThemesPage store={store} context={context} />,
});
