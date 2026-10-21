import type { HealthState } from "~/bridge/protocol";
import type { PageHost } from "~/shell/page";
import { createReadStore } from "~/features/overview/read-store";
export function createHealthStore(host: PageHost) {
  const store = createReadStore<HealthState>(() => host.request("health.getState"));
  host.subscribe("health.changed", () => store.invalidate());
  return {
    ...store,
    copyFix: (id: string) => store.action(() => host.request("health.copyFix", { id })),
    reveal: () => store.action(() => host.request("health.revealSettings")),
  };
}
export type HealthStore = ReturnType<typeof createHealthStore>;
