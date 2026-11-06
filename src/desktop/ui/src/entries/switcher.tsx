import "~/styles/index.css";

import { StrictMode } from "react";
import { flushSync } from "react-dom";
import { createRoot } from "react-dom/client";

import { afterNextPaint, bridge, connectHost, request } from "~/bridge/client";
import { SwitcherView } from "~/features/switcher/switcher-view";
import { createSwitcherStore } from "~/features/switcher/switcher-store";

await connectHost();

// Subscribed before the bridge starts, so a willOpen queued during loading
// is not lost.
const store = createSwitcherStore({ request, subscribe: bridge.subscribe });
bridge.start();

const root = document.getElementById("root");
if (!root) throw new Error("switcher.html has no #root");
const reactRoot = createRoot(root);

// Render only once there is state, and report ready only once it is on
// screen, so the panel never shows an empty frame.
await store.load();
flushSync(() =>
  reactRoot.render(
    <StrictMode>
      <SwitcherView store={store} />
    </StrictMode>,
  ),
);
await afterNextPaint();
request("app.ready", { surface: "switcher" }).catch((error: unknown) => console.error(error));
