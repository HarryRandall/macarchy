import "~/styles/index.css";

import { StrictMode } from "react";
import { createRoot } from "react-dom/client";

import { bridge, connectHost, request } from "~/bridge/client";
import type { PaneId } from "~/bridge/protocol";
import type { PageStore } from "~/shell/page";
import { pages } from "~/shell/pages";
import { SettingsApp } from "~/shell/settings-app";
import { createShellStore } from "~/shell/shell-store";

await connectHost();

// Stores subscribe before the bridge starts, so events the host queued while
// the page loaded reach them. Pages load when first shown.
const host = { request, subscribe: bridge.subscribe };
const shell = createShellStore({ request, subscribe: bridge.subscribe });
const stores = new Map<PaneId, PageStore>(pages.map((page) => [page.id, page.create(host)]));
bridge.start();
void shell.load();

const root = document.getElementById("root");
if (!root) throw new Error("settings.html has no #root");
createRoot(root).render(
  <StrictMode>
    <SettingsApp shell={shell} stores={stores} />
  </StrictMode>,
);
