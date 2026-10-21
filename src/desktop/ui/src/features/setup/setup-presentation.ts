import { createListeners } from "~/lib/store";
import type { PageHost } from "~/shell/page";
import { createSetupStore, type SetupStore } from "./setup-store";

const listeners = createListeners();
let store: SetupStore | null = null;
/** Keeps results visible after setup creates settings and changes shell state. */
export const setupPresentation = {
  subscribe: listeners.subscribe,
  getSnapshot: () => store,
  open(host: PageHost) {
    if (store) return;
    store = createSetupStore(host);
    listeners.notify();
    void store.load();
  },
  close() {
    store = null;
    listeners.notify();
  },
};
