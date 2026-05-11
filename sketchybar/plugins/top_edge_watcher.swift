#!/usr/bin/env swift

import AppKit
import Foundation

struct Config {
  var sketchybarPath = "/opt/homebrew/bin/sketchybar"
  var topZone = 34
  var hiddenYOffset = -40
  var pollInterval = 0.05
  var runOnce = false
}

func parseArgs() -> Config {
  var config = Config()
  let args = Array(CommandLine.arguments.dropFirst())
  var index = 0

  while index < args.count {
    switch args[index] {
    case "--sketchybar":
      index += 1
      if index < args.count { config.sketchybarPath = args[index] }
    case "--top-zone":
      index += 1
      if index < args.count, let value = Int(args[index]) { config.topZone = value }
    case "--hidden-offset":
      index += 1
      if index < args.count, let value = Int(args[index]) { config.hiddenYOffset = value }
    case "--poll-interval":
      index += 1
      if index < args.count, let value = Double(args[index]) { config.pollInterval = value }
    case "--once":
      config.runOnce = true
    default:
      break
    }

    index += 1
  }

  return config
}

func shouldHide(topZone: Int) -> Bool {
  let point = NSEvent.mouseLocation
  let screen = NSScreen.screens.first(where: { NSMouseInRect(point, $0.frame, false) }) ?? NSScreen.main
  let distanceFromTop = Int((screen?.frame.maxY ?? point.y) - point.y)
  return distanceFromTop <= topZone
}

func setBar(hidden: Bool, using config: Config) {
  let process = Process()
  process.executableURL = URL(fileURLWithPath: config.sketchybarPath)
  process.arguments = [
    "--animate", "tanh", "2",
    "--bar", "y_offset=\(hidden ? config.hiddenYOffset : 0)",
  ]

  try? process.run()
  process.waitUntilExit()
}

let config = parseArgs()
var lastHiddenState: Bool?

while true {
  autoreleasepool {
    let hidden = shouldHide(topZone: config.topZone)

    if hidden != lastHiddenState {
      setBar(hidden: hidden, using: config)
      lastHiddenState = hidden
    }
  }

  if config.runOnce {
    break
  }

  Thread.sleep(forTimeInterval: config.pollInterval)
}
