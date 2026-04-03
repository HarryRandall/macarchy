"use strict";
var __defProp = Object.defineProperty;
var __getOwnPropDesc = Object.getOwnPropertyDescriptor;
var __getOwnPropNames = Object.getOwnPropertyNames;
var __hasOwnProp = Object.prototype.hasOwnProperty;
var __export = (target, all) => {
  for (var name in all)
    __defProp(target, name, { get: all[name], enumerable: true });
};
var __copyProps = (to, from, except, desc) => {
  if (from && typeof from === "object" || typeof from === "function") {
    for (let key of __getOwnPropNames(from))
      if (!__hasOwnProp.call(to, key) && key !== except)
        __defProp(to, key, { get: () => from[key], enumerable: !(desc = __getOwnPropDesc(from, key)) || desc.enumerable });
  }
  return to;
};
var __toCommonJS = (mod) => __copyProps(__defProp({}, "__esModule", { value: true }), mod);

var clipboard_history_exports = {};
__export(clipboard_history_exports, {
  default: () => Command
});
module.exports = __toCommonJS(clipboard_history_exports);

var import_api = require("@raycast/api");
var import_fs = require("fs/promises");
var import_react = require("react");
var import_jsx_runtime = require("react/jsx-runtime");
var shared = require("./clipboard-shared");

async function loadHistory() {
  try {
    const raw = await import_fs.readFile(shared.HISTORY_FILE, "utf8");
    return JSON.parse(raw);
  } catch {
    return { items: [], lastNonRaycastApp: null };
  }
}

function formatSubtitle(item) {
  if (item.kind === "image") {
    return item.imagePath;
  }
  return item.text;
}

function formatAccessory(item) {
  if (item.kind === "image") {
    return { tag: { value: "Image", color: import_api.Color.Blue } };
  }
  return { tag: { value: "Text", color: import_api.Color.Green } };
}

function ClipboardItem(props) {
  const { item, targetApp, refresh } = props;
  const onPaste = async () => {
    try {
      await (0, import_api.closeMainWindow)();
      await new Promise((resolve) => setTimeout(resolve, 60));
      await shared.pasteHistoryItem(item, targetApp);
    } catch (error) {
      await (0, import_api.showToast)({
        style: import_api.Toast.Style.Failure,
        title: "Paste failed",
        message: error instanceof Error ? error.message : String(error)
      });
    }
  };
  const copyPath = async () => {
    if (item.kind !== "image") return;
    await import_api.Clipboard.copy(item.imagePath);
    await (0, import_api.showHUD)("Copied image path");
  };
  const clearAll = async () => {
    try {
      shared.clearHistoryState();
      await refresh();
      await (0, import_api.showHUD)("Clipboard history cleared");
    } catch (error) {
      await (0, import_api.showToast)({
        style: import_api.Toast.Style.Failure,
        title: "Clear failed",
        message: error instanceof Error ? error.message : String(error)
      });
    }
  };
  return (0, import_jsx_runtime.jsx)(import_api.List.Item, {
    title: item.preview,
    subtitle: formatSubtitle(item),
    icon: item.kind === "image" ? { source: item.imagePath } : import_api.Icon.Text,
    accessories: [formatAccessory(item)],
    actions: (0, import_jsx_runtime.jsxs)(import_api.ActionPanel, {
      children: [
        (0, import_jsx_runtime.jsx)(import_api.Action, { title: "Paste Item", onAction: onPaste }),
        item.kind === "image" ? (0, import_jsx_runtime.jsx)(import_api.Action, { title: "Copy Image Path", onAction: copyPath, shortcut: { modifiers: ["cmd"], key: "." } }) : null,
        (0, import_jsx_runtime.jsx)(import_api.Action, { title: "Clear All History", style: import_api.Action.Style.Destructive, onAction: clearAll, shortcut: { modifiers: ["cmd", "shift"], key: "backspace" } }),
        (0, import_jsx_runtime.jsx)(import_api.Action, { title: "Refresh", onAction: refresh, shortcut: { modifiers: ["cmd"], key: "r" } })
      ]
    })
  });
}

function Command() {
  const [state, setState] = (0, import_react.useState)({ isLoading: true, items: [], lastNonRaycastApp: null });
  const clearAll = (0, import_react.useCallback)(async () => {
    try {
      shared.clearHistoryState();
      setState((current) => ({ ...current, items: [], isLoading: false }));
      await (0, import_api.showHUD)("Clipboard history cleared");
    } catch (error) {
      await (0, import_api.showToast)({
        style: import_api.Toast.Style.Failure,
        title: "Clear failed",
        message: error instanceof Error ? error.message : String(error)
      });
    }
  }, []);
  const refresh = (0, import_react.useCallback)(async () => {
    setState((current) => ({ ...current, isLoading: true }));
    const data = await loadHistory();
    setState({ isLoading: false, items: data.items || [], lastNonRaycastApp: data.lastNonRaycastApp || null });
  }, []);
  (0, import_react.useEffect)(() => {
    refresh();
  }, [refresh]);
  const emptyTitle = state.isLoading ? "Loading Clipboard History" : "No Clipboard History Yet";
  const emptyDescription = state.items.length === 0
    ? "The watcher has not captured any clipboard items yet. Copy some text or images first."
    : void 0;
  return (0, import_jsx_runtime.jsx)(import_api.List, {
    isLoading: state.isLoading,
    searchBarPlaceholder: state.lastNonRaycastApp ? `Search clipboard history, target ${state.lastNonRaycastApp.name}` : "Search clipboard history",
    actions: (0, import_jsx_runtime.jsxs)(import_api.ActionPanel, {
      children: [
        (0, import_jsx_runtime.jsx)(import_api.Action, { title: "Clear All History", style: import_api.Action.Style.Destructive, onAction: clearAll, shortcut: { modifiers: ["cmd", "shift"], key: "backspace" } }),
        (0, import_jsx_runtime.jsx)(import_api.Action, { title: "Refresh", onAction: refresh, shortcut: { modifiers: ["cmd"], key: "r" } })
      ]
    }),
    children: state.items.length > 0
      ? state.items.map((item) => (0, import_jsx_runtime.jsx)(ClipboardItem, { item, targetApp: state.lastNonRaycastApp, refresh }, item.id))
      : (0, import_jsx_runtime.jsx)(import_api.List.EmptyView, { title: emptyTitle, description: emptyDescription })
  });
}
