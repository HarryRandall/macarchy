# Contributing

These are the rules for working in this repo — they apply to anyone, human or
agent.

The app owns the configuration of a **daily-driver desktop**. It is not a
sandbox: a bad change breaks the machine someone is working on. That constraint
is why the gates below are not optional.

`Docs/HANDOVER.md` orients you. `Docs/MIGRATION.md` is the plan. This file is
the rules.

## Before and after every change

```sh
swift build          # must compile
./Scripts/test.sh    # swift test — 20 unit tests
./Scripts/doctor.sh  # 35 machine assertions — THE GATE, must be 0 failed
./Scripts/lint.sh    # swift-format + swiftlint
```

A change that leaves `doctor` failing is reverted, not patched forward. When you
hit a new failure mode, add an assertion for it — nearly every check encodes a
bug that actually happened.

## Architecture rules

**Read live from the daemons; persist to env files; never parse an rc script.**
yabai and sketchybar answer queries, so the UI hydrates from what is running.
borders has no query verb — `settings.env` is authoritative for it alone.

**Every process call goes through `StackBackend`.** No model, view or CLI command
calls `CommandRunner` directly. That protocol is the seam that keeps "four
daemons or one" a later decision, and it has been quietly bypassed before — if a
call needs a new verb, add the verb.

**Strangler, never dual ownership.** Build the new path, run it beside the old
one, diff, cut over, then *delete* the old path. Two things writing one file is
this project's recurring failure, and it does not announce itself.

**Ported shell goes in `MacarchyKit`.** Theme switching has two entry points —
the GUI and `cmd+ctrl+=` bound to `theme-switch`. Logic in the app alone makes
them disagree. The Kit is shared by the app and the `macarchy` CLI.

**The GUI is never in the boot path.** Generated rc files resolve `settings.env`
and the active theme *at run time*, so login works whether or not the app starts.

**Porting a shell surface follows one recipe.** Implement in the Kit → extract
the original shell verbatim as a `reference.sh` → diff across all 8 themes and
the edge cases → only then delete the bash and point `theme-switch` at the CLI →
add a `doctor` assertion that it stays delegated.

## Code conventions

Follows [Apple's API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/)
with [Google's](https://google.github.io/swift/) file rules and
[Airbnb's](https://swift.airbnb.tech/) 100-column limit. Enforced by
`.swift-format` and `.swiftlint.yml`.

- **One primary type per file, named for it.** Extensions adding protocol
  conformance or a feature get `Type+Feature.swift`.
- **Swift 6 language mode**, strict concurrency. Models are `@MainActor
  @Observable`; anything in the Kit is `Sendable` and free of UI imports.
- **Kit = pure and portable. App = observable and UI.** If a type has no
  SwiftUI/Observation import, it belongs in the Kit.
- **No force unwraps** (`force_unwrapping` is on).
- **Named types over tuples** of more than two members.
- Files under 300 lines, functions under 60, types under 250. Where a rule is
  genuinely wrong — a shell template that must stay one document — use a
  targeted `swiftlint:disable:next` *with the reason written above it*.

## Comments

Explain **why**, never what. The valuable comments in this codebase record
constraints that cost something to learn: why sketchybar's invocation must not be
split, why `set-wallpaper` is not ported, why snapshot ids carry milliseconds.
Do not write comments that restate the code.

## Things that will bite you

See the traps section of `Docs/HANDOVER.md` — all of them actually happened.
The short version: `theme-switch` regenerates files wholesale; SketchyBar's
chained invocation must not be split; `set-wallpaper` is off-limits;
`.backgrounds.json` overrides `theme.env`; `grep -c` exits non-zero on no match;
zsh does not word-split unquoted expansions.

## Git

Commit messages explain why a change was
made and what was verified, not just what changed.
