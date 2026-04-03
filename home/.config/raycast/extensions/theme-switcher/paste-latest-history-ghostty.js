#!/opt/homebrew/bin/node
"use strict";

const { execFileSync } = require("child_process");
const fs = require("fs");
const os = require("os");
const path = require("path");

const STATE_DIR = path.join(os.homedir(), "Library", "Application Support", "com.raycast.macos", "extensions", "theme-switcher");
const HISTORY_FILE = path.join(STATE_DIR, "clipboard-history.json");

function readHistoryState() {
  try {
    return JSON.parse(fs.readFileSync(HISTORY_FILE, "utf8"));
  } catch {
    return { items: [] };
  }
}

function escapeAppleScriptString(value) {
  return String(value)
    .replace(/\\/g, "\\\\")
    .replace(/"/g, '\\"')
    .replace(/\n/g, "\\n")
    .replace(/\r/g, "\\r");
}

function runAppleScript(script) {
  execFileSync("/usr/bin/osascript", ["-e", script], {
    stdio: "ignore",
    env: { ...process.env, PATH: "/usr/bin:/bin:/usr/sbin:/sbin" }
  });
}

function shellQuote(value) {
  return `'${String(value).replace(/'/g, `'\\''`)}'`;
}

function setClipboardText(text) {
  execFileSync("/usr/bin/pbcopy", {
    input: text,
    stdio: ["pipe", "ignore", "ignore"],
    env: { ...process.env, PATH: "/usr/bin:/bin:/usr/sbin:/sbin" }
  });
}

function pasteClipboardIntoFrontmost() {
  runAppleScript(`tell application "System Events"
  tell (first application process whose frontmost is true)
    click menu item "Paste" of menu 1 of menu bar item "Edit" of menu bar 1
  end tell
end tell`);
}

function main() {
  const state = readHistoryState();
  const item = Array.isArray(state.items) ? state.items[0] : null;
  if (!item) {
    process.exit(0);
  }

  if (item.kind === "image" && item.imagePath) {
    setClipboardText(shellQuote(item.imagePath));
    pasteClipboardIntoFrontmost();
    return;
  }

  setClipboardText(item.text || "");
  pasteClipboardIntoFrontmost();
}

main();
