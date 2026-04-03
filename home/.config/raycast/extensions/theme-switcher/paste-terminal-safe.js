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

var paste_terminal_safe_exports = {};
__export(paste_terminal_safe_exports, {
  default: () => Command
});
module.exports = __toCommonJS(paste_terminal_safe_exports);

var import_api = require("@raycast/api");
var shared = require("./clipboard-shared");

async function Command() {
  try {
    const previousApp = shared.getLastTargetApp();
    const item = shared.getLatestHistoryItem();
    await (0, import_api.closeMainWindow)();
    await new Promise((resolve) => setTimeout(resolve, 60));
    if (!previousApp || !previousApp.name) {
      throw new Error("No target app recorded yet. Focus the app you want, then try again.");
    }
    if (!item) {
      throw new Error("Clipboard history is empty.");
    }
    if (shared.isTerminalApp(previousApp)) {
      if (item.kind === "image") {
        shared.setClipboardText(shared.shellQuote(item.imagePath || ""));
        shared.pasteWithControlVIntoFrontmost(previousApp);
        await (0, import_api.showHUD)("Pasted image path");
      } else {
        shared.typeTextIntoFrontmost(previousApp, item.text || "");
      }
      return;
    }
    if (item.kind === "image") {
      shared.setClipboardImageFromFile(item.imagePath);
    } else {
      await import_api.Clipboard.copy(item.text || "");
    }
    shared.pasteIntoRestoredFocus(previousApp);
  } catch (error) {
    await (0, import_api.showToast)({
      style: import_api.Toast.Style.Failure,
      title: "Paste failed",
      message: error instanceof Error ? error.message : String(error)
    });
  }
}
