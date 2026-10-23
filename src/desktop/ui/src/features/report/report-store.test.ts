import { expect, it, vi } from "vitest";
import type { PageHost } from "~/shell/page";
import { createReportStore } from "./report-store";

function host() {
  const request = vi
    .fn<(...args: unknown[]) => Promise<unknown>>()
    .mockResolvedValue({ token: "one", body: "Redacted facts" });
  return { request, subscribe: vi.fn<PageHost["subscribe"]>() };
}

it("opening reads only, title edits persist and actions use the exact native preview token", async () => {
  const deps = host();
  const store = createReportStore(deps as PageHost);
  await store.load();
  expect(deps.request.mock.calls).toEqual([["report.prepare", { description: "", refresh: true }]]);
  store.setTitle("Bar disappears");
  await store.copy();
  expect(deps.request).toHaveBeenLastCalledWith("report.copy", { token: "one" });
  deps.request.mockResolvedValueOnce({ copied: true });
  await store.open();
  expect(deps.request).toHaveBeenLastCalledWith("report.openIssue", {
    token: "one",
    title: "Bar disappears",
  });
  expect(store.getSnapshot().notice).toContain("clipboard");
});

it("serialises draft previews, protects edits during collection and disables stale actions", async () => {
  const deps = host();
  let finish!: (value: unknown) => void;
  deps.request.mockReturnValueOnce(
    new Promise((resolve) => {
      finish = resolve;
    }),
  );
  const store = createReportStore(deps as PageHost);
  const loading = store.load();
  store.setTitle("Keep this title");
  store.setDescription("first");
  store.setDescription("latest");
  await store.copy();
  expect(deps.request).toHaveBeenCalledTimes(1);
  deps.request.mockResolvedValueOnce({ token: "two", body: "Latest redacted facts" });
  finish({ token: "one", body: "Old facts" });
  await loading;
  expect(deps.request).toHaveBeenLastCalledWith("report.prepare", {
    description: "latest",
    refresh: false,
  });
  expect(store.getSnapshot()).toMatchObject({
    title: "Keep this title",
    description: "latest",
    preview: { token: "two" },
  });
});

it("typing reuses diagnostics while refreshing and reopening collect them again", async () => {
  const deps = host();
  const store = createReportStore(deps as PageHost);
  const settled = () => vi.waitFor(() => expect(store.getSnapshot().preparing).toBe(false));
  store.opened();
  await store.load();
  store.setDescription("typed");
  await settled();
  deps.request.mockResolvedValueOnce({ token: "two", body: "Fixed facts" });
  await store.load();
  expect(store.getSnapshot().preview).toEqual({ token: "two", body: "Fixed facts" });
  store.opened();
  await settled();
  expect(deps.request.mock.calls.map((call) => call[1])).toEqual([
    { description: "", refresh: true },
    { description: "typed", refresh: false },
    { description: "typed", refresh: true },
    { description: "typed", refresh: true },
  ]);
});

it("a refresh while a collection is running shares it instead of asking again", async () => {
  const deps = host();
  let finish!: (value: unknown) => void;
  deps.request.mockReturnValueOnce(
    new Promise((resolve) => {
      finish = resolve;
    }),
  );
  const store = createReportStore(deps as PageHost);
  const first = store.load();
  const second = store.load();
  expect(second).toBe(first);
  finish({ token: "one", body: "Facts" });
  await first;
  expect(deps.request).toHaveBeenCalledTimes(1);
});

it("shows preparation and action failures without claiming a copy or open succeeded", async () => {
  const deps = host();
  deps.request.mockRejectedValueOnce(new Error("Collection unavailable"));
  const store = createReportStore(deps as PageHost);
  await store.load();
  expect(store.getSnapshot()).toMatchObject({ status: "failed", error: "Collection unavailable" });
  await store.copy();
  expect(deps.request).toHaveBeenCalledTimes(1);
  await store.load();
  deps.request.mockRejectedValueOnce(new Error("Clipboard unavailable"));
  await store.copy();
  expect(store.getSnapshot()).toMatchObject({
    error: null,
    actionError: "Clipboard unavailable",
    notice: null,
    busy: false,
  });
});

it("a failed action keeps a preparation failure and its retry apart", async () => {
  const deps = host();
  const store = createReportStore(deps as PageHost);
  deps.request.mockRejectedValueOnce(new Error("Collection unavailable"));
  await store.load();
  deps.request.mockRejectedValueOnce(new Error("No browser"));
  await expect(store.openIssues()).resolves.toBe(false);
  expect(store.getSnapshot()).toMatchObject({
    error: "Collection unavailable",
    stale: true,
    actionError: "No browser",
  });
  await store.load();
  deps.request.mockResolvedValueOnce(null);
  await expect(store.copy()).resolves.toBe(true);
  expect(store.getSnapshot()).toMatchObject({ error: null, stale: false, actionError: null });
});

it("copy and open can be tried again straight after they fail, but not on a stale preview", async () => {
  const deps = host();
  const store = createReportStore(deps as PageHost);
  await store.load();
  store.setTitle("Bar disappears");
  deps.request.mockRejectedValueOnce(new Error("Clipboard unavailable"));
  await expect(store.copy()).resolves.toBe(false);
  deps.request.mockResolvedValueOnce(null);
  await expect(store.copy()).resolves.toBe(true);
  expect(store.getSnapshot()).toMatchObject({ actionError: null, notice: "Copied" });
  deps.request.mockRejectedValueOnce(new Error("No browser"));
  await expect(store.open()).resolves.toBe(false);
  deps.request.mockResolvedValueOnce({ copied: false });
  await expect(store.open()).resolves.toBe(true);
  deps.request.mockRejectedValueOnce(new Error("Collection unavailable"));
  await store.load();
  const calls = deps.request.mock.calls.length;
  await expect(store.copy()).resolves.toBe(false);
  await expect(store.open()).resolves.toBe(false);
  expect(deps.request).toHaveBeenCalledTimes(calls);
});

it("clearing the draft keeps the diagnostics and prepares a preview without the old text", async () => {
  const deps = host();
  const store = createReportStore(deps as PageHost);
  await store.load();
  store.setTitle("Bar disappears");
  store.setDescription("It went away");
  await vi.waitFor(() => expect(store.getSnapshot().preparing).toBe(false));
  store.clear();
  await vi.waitFor(() => expect(store.getSnapshot().preparing).toBe(false));
  expect(store.getSnapshot()).toMatchObject({ title: "", description: "" });
  expect(deps.request).toHaveBeenLastCalledWith("report.prepare", {
    description: "",
    refresh: false,
  });
});
