import { definePage } from "~/shell/page";
import { HomePage } from "./home-page";
import { createHomeStore } from "./home-store";
export const homePage = definePage({
  id: "home",
  create: createHomeStore,
  render: (store, context) => <HomePage store={store} context={context} />,
});
