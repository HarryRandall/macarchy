import Foundation
import Testing

@testable import Macarchy

@Suite("Keeping startup files")
struct StartupAdoptionTests {
    @Test("shells can be kept; other interpreters cannot")
    func interpreters() {
        let interpreter = Setup.foreignInterpreter
        #expect(interpreter("#!/bin/bash\nsketchybar --bar height=30") == nil)
        #expect(interpreter("#!/usr/bin/env bash\necho") == nil)
        #expect(interpreter("#!/bin/sh\necho") == nil)
        #expect(interpreter("#!/usr/bin/env -S bash -e\necho") == nil)
        #expect(interpreter("sketchybar --bar height=30") == nil)
        #expect(interpreter("#!/usr/bin/env lua\nsbar = require(\"sketchybar\")") == "lua")
        #expect(interpreter("#!/bin/zsh\nsetopt extendedglob") == "zsh")
        #expect(interpreter("#!/opt/homebrew/bin/fish\n") == "fish")
    }

    @Test("bash syntax is checked")
    func bashSyntax() async {
        #expect(await Setup.bashSyntaxProblem("sketchybar --bar height=30\n") == nil)
        let problem = await Setup.bashSyntaxProblem(
            "sbar = require(\"sketchybar\")\nsbar.bar({ height = 30 })\n")
        #expect(problem?.contains("line") == true)
    }
}
