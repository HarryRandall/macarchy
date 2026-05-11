#!/Library/Developer/CommandLineTools/usr/bin/swift

import AppKit
import CryptoKit
import Foundation

struct AppInfo: Codable {
  let name: String
  let bundleId: String?
}

struct ClipboardItem: Codable {
  let id: String
  let kind: String
  let createdAt: String
  let hash: String
  let preview: String
  let text: String?
  let imagePath: String?
}

struct Store: Codable {
  var version: Int
  var updatedAt: String
  var lastNonRaycastApp: AppInfo?
  var items: [ClipboardItem]
}

let home = FileManager.default.homeDirectoryForCurrentUser
let stateDir = home
  .appendingPathComponent("Library", isDirectory: true)
  .appendingPathComponent("Application Support", isDirectory: true)
  .appendingPathComponent("com.raycast.macos", isDirectory: true)
  .appendingPathComponent("extensions", isDirectory: true)
  .appendingPathComponent("theme-switcher", isDirectory: true)
let imagesDir = stateDir.appendingPathComponent("clipboard-images", isDirectory: true)
let historyFile = stateDir.appendingPathComponent("clipboard-history.json", isDirectory: false)

let maxItems = 100
let raycastBundleId = "com.raycast.macos"
let pollIntervalSeconds = 0.1
let isoFormatter = ISO8601DateFormatter()
isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

func sha256Hex(_ data: Data) -> String {
  SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
}

func loadStore() -> Store {
  guard let data = try? Data(contentsOf: historyFile) else {
    return Store(version: 1, updatedAt: isoFormatter.string(from: Date()), lastNonRaycastApp: nil, items: [])
  }
  guard let store = try? JSONDecoder().decode(Store.self, from: data) else {
    return Store(version: 1, updatedAt: isoFormatter.string(from: Date()), lastNonRaycastApp: nil, items: [])
  }
  return store
}

func saveStore(_ store: Store) {
  do {
    try FileManager.default.createDirectory(at: imagesDir, withIntermediateDirectories: true)
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(store)
    try data.write(to: historyFile, options: .atomic)
  } catch {
    fputs("clipboard watcher save failed: \(error)\n", stderr)
  }
}

func emptyStore() -> Store {
  Store(version: 1, updatedAt: isoFormatter.string(from: Date()), lastNonRaycastApp: nil, items: [])
}

func resetStoreOnStartup() -> Store {
  do {
    if FileManager.default.fileExists(atPath: imagesDir.path) {
      try FileManager.default.removeItem(at: imagesDir)
    }
    try FileManager.default.createDirectory(at: imagesDir, withIntermediateDirectories: true)
  } catch {
    fputs("clipboard watcher startup reset failed: \(error)\n", stderr)
  }

  let store = emptyStore()
  saveStore(store)
  return store
}

func previewText(_ text: String) -> String {
  let normalized = text
    .replacingOccurrences(of: "\r\n", with: "\n")
    .replacingOccurrences(of: "\r", with: "\n")
    .replacingOccurrences(of: "\n", with: " ")
    .trimmingCharacters(in: .whitespacesAndNewlines)
  if normalized.isEmpty {
    return "(empty text)"
  }
  return String(normalized.prefix(120))
}

func captureText(_ text: String) -> ClipboardItem? {
  guard !text.isEmpty else { return nil }
  guard let data = text.data(using: .utf8) else { return nil }
  let hash = sha256Hex(data)
  return ClipboardItem(
    id: hash,
    kind: "text",
    createdAt: isoFormatter.string(from: Date()),
    hash: hash,
    preview: previewText(text),
    text: text,
    imagePath: nil
  )
}

func captureImage(_ image: NSImage) -> ClipboardItem? {
  guard
    let tiff = image.tiffRepresentation,
    let bitmap = NSBitmapImageRep(data: tiff),
    let png = bitmap.representation(using: .png, properties: [:])
  else {
    return nil
  }

  let hash = sha256Hex(png)
  let imagePath = imagesDir.appendingPathComponent("\(hash).png", isDirectory: false)
  if !FileManager.default.fileExists(atPath: imagePath.path) {
    do {
      try FileManager.default.createDirectory(at: imagesDir, withIntermediateDirectories: true)
      try png.write(to: imagePath, options: .atomic)
    } catch {
      fputs("clipboard watcher image write failed: \(error)\n", stderr)
      return nil
    }
  }

  return ClipboardItem(
    id: hash,
    kind: "image",
    createdAt: isoFormatter.string(from: Date()),
    hash: hash,
    preview: "Image \(String(hash.prefix(8)))",
    text: nil,
    imagePath: imagePath.path
  )
}

func updateLastNonRaycastApp(store: inout Store) {
  guard let app = NSWorkspace.shared.frontmostApplication else { return }
  guard app.bundleIdentifier != raycastBundleId else { return }
  let name = app.localizedName ?? app.bundleIdentifier ?? "Unknown App"
  store.lastNonRaycastApp = AppInfo(name: name, bundleId: app.bundleIdentifier)
}

func upsertItem(store: inout Store, item: ClipboardItem) {
  store.items.removeAll { $0.hash == item.hash && $0.kind == item.kind }
  store.items.insert(item, at: 0)
  if store.items.count > maxItems {
    store.items = Array(store.items.prefix(maxItems))
  }
  store.updatedAt = isoFormatter.string(from: Date())
}

func captureClipboardItem() -> ClipboardItem? {
  let pasteboard = NSPasteboard.general
  if let text = pasteboard.string(forType: .string), let item = captureText(text) {
    return item
  }
  if let image = NSImage(pasteboard: pasteboard), let item = captureImage(image) {
    return item
  }
  return nil
}

do {
  try FileManager.default.createDirectory(at: stateDir, withIntermediateDirectories: true)
  try FileManager.default.createDirectory(at: imagesDir, withIntermediateDirectories: true)
} catch {
  fputs("clipboard watcher setup failed: \(error)\n", stderr)
  exit(1)
}

var store = resetStoreOnStartup()
var lastChangeCount = NSPasteboard.general.changeCount
let initialApp = store.lastNonRaycastApp
updateLastNonRaycastApp(store: &store)
if store.lastNonRaycastApp?.bundleId != initialApp?.bundleId || store.lastNonRaycastApp?.name != initialApp?.name {
  saveStore(store)
}

while true {
  let previousApp = store.lastNonRaycastApp
  updateLastNonRaycastApp(store: &store)
  var didMutate = previousApp?.bundleId != store.lastNonRaycastApp?.bundleId || previousApp?.name != store.lastNonRaycastApp?.name

  let currentChangeCount = NSPasteboard.general.changeCount
  if currentChangeCount != lastChangeCount {
    lastChangeCount = currentChangeCount
    if let item = captureClipboardItem() {
      upsertItem(store: &store, item: item)
      didMutate = true
    }
  }

  if didMutate {
    saveStore(store)
  }

  Thread.sleep(forTimeInterval: pollIntervalSeconds)
}
