"use strict";

var import_api = require("@raycast/api");
var import_child_process = require("child_process");
var import_fs = require("fs");
var import_os = require("os");
var import_path = require("path");

var STATE_DIR = (0, import_path.join)((0, import_os.homedir)(), "Library", "Application Support", "com.raycast.macos", "extensions", "theme-switcher");
var HISTORY_FILE = (0, import_path.join)(STATE_DIR, "clipboard-history.json");
var IMAGES_DIR = (0, import_path.join)(STATE_DIR, "clipboard-images");

function ensureStateDir() {
  if (!(0, import_fs.existsSync)(STATE_DIR)) {
    import_fs.mkdirSync(STATE_DIR, { recursive: true });
  }
}

function createEmptyHistoryState() {
  return {
    version: 1,
    updatedAt: (/* @__PURE__ */ new Date()).toISOString(),
    lastNonRaycastApp: null,
    items: []
  };
}

function clearHistoryState() {
  ensureStateDir();
  import_fs.rmSync(IMAGES_DIR, { recursive: true, force: true });
  import_fs.writeFileSync(HISTORY_FILE, JSON.stringify(createEmptyHistoryState(), null, 2));
}

function shellQuote(value) {
  return `'${String(value).replace(/'/g, `'\\''`)}'`;
}

function shellEscapePath(value) {
  return String(value).replace(/([^A-Za-z0-9_./-])/g, "\\$1");
}

function escapeAppleScriptString(value) {
  return String(value)
    .replace(/\\/g, "\\\\")
    .replace(/"/g, '\\"')
    .replace(/\n/g, "\\n")
    .replace(/\r/g, "\\r");
}

function runAppleScript(script) {
  return (0, import_child_process.execFileSync)("/usr/bin/osascript", ["-e", script], {
    encoding: "utf8",
    env: { ...process.env, PATH: "/usr/bin:/bin:/usr/sbin:/sbin" }
  }).trim();
}

function readHistoryState() {
  try {
    return JSON.parse(import_fs.readFileSync(HISTORY_FILE, "utf8"));
  } catch {
    return { items: [], lastNonRaycastApp: null };
  }
}

function getLastTargetApp() {
  return readHistoryState().lastNonRaycastApp || null;
}

function getLatestHistoryItem() {
  const state = readHistoryState();
  return Array.isArray(state.items) && state.items.length > 0 ? state.items[0] : null;
}

function activateApp(target) {
  if (target.bundleId) {
    runAppleScript(`tell application id "${escapeAppleScriptString(target.bundleId)}" to activate`);
    return;
  }
  runAppleScript(`tell application "${escapeAppleScriptString(target.name)}" to activate`);
}

function isBrowserApp(target) {
  const browserBundleIds = new Set([
    "com.google.Chrome",
    "com.google.Chrome.canary",
    "com.apple.Safari",
    "org.mozilla.firefox",
    "com.microsoft.edgemac",
    "com.brave.Browser",
    "company.thebrowser.Browser"
  ]);
  const browserNames = new Set(["Google Chrome", "Google Chrome Canary", "Safari", "Firefox", "Microsoft Edge", "Brave Browser", "Arc"]);
  return browserBundleIds.has(target?.bundleId || "") || browserNames.has(target?.name || "");
}

function interactionDelaySeconds(target) {
  if (isBrowserApp(target)) return "0.35";
  return "0.03";
}

function pasteWithCommandV(target) {
  activateApp(target);
  runAppleScript(`delay ${interactionDelaySeconds(target)}
tell application "System Events" to key code 9 using command down`);
}

function pasteWithControlV(target) {
  activateApp(target);
  runAppleScript(`delay ${interactionDelaySeconds(target)}
tell application "System Events" to key code 9 using control down`);
}

function pasteWithControlVIntoFrontmost(target) {
  runAppleScript(`delay ${interactionDelaySeconds(target)}
tell application "System Events" to key code 9 using control down`);
}

function pasteFromEditMenu(target) {
  activateApp(target);
  const appRef = target.bundleId
    ? `application process (first process whose bundle identifier is "${escapeAppleScriptString(target.bundleId)}")`
    : `application process "${escapeAppleScriptString(target.name)}"`;
  runAppleScript(`delay ${interactionDelaySeconds(target)}
tell application "System Events"
  tell ${appRef}
    click menu item "Paste" of menu 1 of menu bar item "Edit" of menu bar 1
  end tell
end tell`);
}

function pasteIntoRestoredFocus(target) {
  runAppleScript(`tell application "System Events"
  tell (first application process whose frontmost is true)
    click menu item "Paste" of menu 1 of menu bar item "Edit" of menu bar 1
  end tell
end tell`);
}

function typeText(target, text) {
  activateApp(target);
  runAppleScript(`delay ${interactionDelaySeconds(target)}
tell application "System Events" to keystroke "${escapeAppleScriptString(text)}"`);
}

function typeTextIntoFrontmost(target, text) {
  runAppleScript(`delay ${interactionDelaySeconds(target)}
tell application "System Events" to keystroke "${escapeAppleScriptString(text)}"`);
}

function isTerminalApp(target) {
  const terminalBundleIds = new Set([
    "com.apple.Terminal",
    "com.googlecode.iterm2",
    "com.mitchellh.ghostty",
    "dev.warp.Warp-Stable",
    "net.kovidgoyal.kitty",
    "co.zeit.hyper"
  ]);
  const terminalNames = new Set(["Terminal", "iTerm2", "Ghostty", "Warp", "kitty", "Hyper"]);
  return terminalBundleIds.has(target?.bundleId || "") || terminalNames.has(target?.name || "");
}

function runSwift(script) {
  return (0, import_child_process.execFileSync)("/Library/Developer/CommandLineTools/usr/bin/swift", ["-e", script], {
    encoding: "utf8",
    env: { ...process.env, PATH: "/usr/bin:/bin:/usr/sbin:/sbin" }
  }).trim();
}

function writeClipboardImageToTempFile() {
  const script = `
import AppKit
import Foundation

let pasteboard = NSPasteboard.general
guard let image = NSImage(pasteboard: pasteboard) else {
  fputs("clipboard does not contain an image\\n", stderr)
  exit(2)
}
guard let tiff = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      let png = bitmap.representation(using: .png, properties: [:]) else {
  fputs("could not encode clipboard image as png\\n", stderr)
  exit(3)
}

let tempRoot = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
let directory = tempRoot.appendingPathComponent("raycast-paste-images", isDirectory: true)
try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

let formatter = ISO8601DateFormatter()
formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
let filename = "clipboard-" + formatter.string(from: Date()).replacingOccurrences(of: ":", with: "-") + ".png"
let destination = directory.appendingPathComponent(filename, isDirectory: false)

try png.write(to: destination)
print(destination.path)
`;
  return runSwift(script);
}

function setClipboardImageFromFile(filePath) {
  const script = `
import AppKit
import Foundation

let filePath = ${JSON.stringify(filePath)}
guard let image = NSImage(contentsOfFile: filePath) else {
  fputs("could not load image\\n", stderr)
  exit(2)
}
let pasteboard = NSPasteboard.general
pasteboard.clearContents()
guard pasteboard.writeObjects([image]) else {
  fputs("could not write image to clipboard\\n", stderr)
  exit(3)
}
`;
  runSwift(script);
}

function setClipboardText(text) {
  (0, import_child_process.execFileSync)("/usr/bin/pbcopy", {
    input: text,
    encoding: "utf8",
    stdio: ["pipe", "ignore", "ignore"],
    env: { ...process.env, PATH: "/usr/bin:/bin:/usr/sbin:/sbin" }
  });
}

async function getCurrentClipboardPasteValue() {
  const text = await import_api.Clipboard.readText();
  if (text) {
    return { value: text, kind: "text" };
  }
  const imagePath = writeClipboardImageToTempFile();
  if (imagePath) {
    return { value: shellEscapePath(imagePath), kind: "image-path", rawPath: imagePath };
  }
  throw new Error("Clipboard does not contain pasteable text or an image");
}

async function pasteHistoryItem(item, target) {
  if (!target || !target.name) {
    throw new Error("No previous app recorded. Launch the picker from the app you want to paste into.");
  }
  if (isTerminalApp(target)) {
    if (item.kind === "image") {
      setClipboardText(shellQuote(item.imagePath || ""));
    } else {
      setClipboardText(item.text || "");
    }
    pasteIntoRestoredFocus(target);
    return;
  }
  if (item.kind === "image") {
    setClipboardImageFromFile(item.imagePath);
  } else {
    await import_api.Clipboard.copy(item.text || "");
  }
  pasteIntoRestoredFocus(target);
}

module.exports = {
  HISTORY_FILE,
  IMAGES_DIR,
  ensureStateDir,
  createEmptyHistoryState,
  clearHistoryState,
  shellQuote,
  shellEscapePath,
  readHistoryState,
  getLastTargetApp,
  getLatestHistoryItem,
  runAppleScript,
  pasteWithCommandV,
  pasteWithControlV,
  pasteWithControlVIntoFrontmost,
  pasteFromEditMenu,
  pasteIntoRestoredFocus,
  typeText,
  typeTextIntoFrontmost,
  isTerminalApp,
  isBrowserApp,
  writeClipboardImageToTempFile,
  setClipboardImageFromFile,
  setClipboardText,
  getCurrentClipboardPasteValue,
  pasteHistoryItem
};
