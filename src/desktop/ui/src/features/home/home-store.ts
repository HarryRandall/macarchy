import type { HomeState } from "~/bridge/protocol";
import type { PageHost } from "~/shell/page";
import { createReadStore } from "~/features/overview/read-store";

export function createHomeStore(host: PageHost) {
  const store = createReadStore<HomeState>(() => host.request("home.getState"));
  host.subscribe("home.changed", () => store.invalidate());
  return store;
}
export type HomeStore = ReturnType<typeof createHomeStore>;
