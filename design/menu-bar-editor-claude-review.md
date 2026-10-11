I've read everything I needed and made no edits. Below is the specification, about 1,500 words. It confirms every finding from your audit. It also adds two that the audit missed: `hydrate()` leaves unsaved changes as soon as it finishes, and Apply sends `background.drawing=off` to every bracket.

# Menu bar component editor: specification

## 0. Priorities

| P | Work | Why |
|---|---|---|
| P0 | Correct the renderer: measured member frames, flip the `y_offset` sign, choose the display deterministically, one font parser | The preview is wrong today, so nothing else can be checked against it |
| P0 | Apply sends only what changed; clearing an override restores the original | Today Apply resets the user's own widget styling |
| P0 | Observation runs separately from hydration; the status badge tells the truth | The readings are stale and the "Live" badge says they aren't |
| P1 | Explicit source and presentation model; effective values with their origin and a reset | Fixes spacing being added twice and every component reflowing |
| P1 | Editor layout, measured canvas, sample states | The main user-facing goal |
| P2 | Checked icon catalogue, choice between PNG and glyph | Glyph catalogue is empty; PNG icons can't be coloured |
| P2 | Presentation presets; static templates split from metric templates | Templates currently create static fakes |
| P3 | New metric sources (weather, media) | Staged separately |

**Hidden P0 bug:** `MenuBarModel.hydrate()` sets `applied = draft` and then writes `componentPadding` and `componentSpacing` into `draft`. Any saved configuration without those values therefore opens as a draft with "Unsaved changes", Refresh is disabled, and every later hydrate is blocked (`MenuBarModel.swift:79-86`).

## 1. User flow and hierarchy

1. On the Menu Bar page, select a component on the stage, then choose **Edit…** or double-click. Nothing else changes.
2. The editor opens as a 640 x 680 sheet with three parts.
   - **Header** (fixed): title, a source chip (`Built-in · CPU`, `Static text` or `Spacer`), a freshness chip, the Visible switch, a ⋯ menu ("Revert component", "Remove" for custom components only) and Close.
   - **Preview** (fixed, does not scroll):
     - a context strip showing the real bar slice with one neighbour on each side, the edited component highlighted;
     - a 2x canvas with labelled layout boxes;
     - a sample-state strip.
   - **Tabs** (`SegmentedPill`):
     - **Look**: Preset, Icon, Colours, then Text and format for custom components only.
     - **Layout**: Spacing, Size, Alignment.
     - **Source**: read-only. Linked items, their observed values, when each was last seen, and why something is unavailable. For custom components it holds the text and format fields.
3. A footer line reads "Draft only. Apply from the Menu Bar page." In Live mode it reads "Applies as you edit." Apply stays where it is now.

## 2. Model (core)

```swift
enum ComponentSource: Codable { case builtIn(BarMetric?), staticText, spacer }
enum BarMetric: String, Codable, CaseIterable { case cpu, gpu, memory, network, battery, clock }
```

- `BarMetric` comes from the bracket stem, using the same table as `MenuBarComponents.title`. Unknown built-ins get `.builtIn(nil)`.
- The existing `kind` is kept for decoding; `source` is derived from it.
- `BarPresentation` holds only optional overrides, so nil means "not touched":
  - `iconColour`, `labelColour`, `background`, `cornerRadius`;
  - `iconSize`, `labelSize`, `iconYOffset`, `labelYOffset`;
  - `padding`, `gap`, `icon: IconChoice?`.
- `BarComponent` gains `presentation` and `originals: [String: String]`.
  - `originals` is keyed by `member/property` (for example `cpu.label/label.color`).
  - An original is recorded from the observed snapshot the first time that property is overridden, and only then.
  - Existing loose fields (`colour`, `iconColour`, `paddingOverride` and so on) are decoded into `presentation`. They stay readable for one release.
- In `BarConfiguration`, `componentPadding` and `componentSpacing` stay `Double?`.
  - nil means "use each widget's own values". Remove the `?? 2` and `?? 4` defaults.
- Effective value: `Effective<T> { value, origin: .component | .bar | .widget }`.
  - Resolution order is component override, then bar global, then the observed widget value.
  - `.widget` means the value the widget's script set.

## 3. Observation and hydration

- Add `MenuBarObserver`, an `@Observable` `@MainActor` class.
  - It owns `items`, `observedAt[id]` and `unavailable[id]: Reason`.
  - It only queries, using `--query` through the shared runner.
  - It never touches `draft`.
- Polling cadence:
  - the selected component's members every 2 s while the editor is open;
  - a full sweep every 15 s while the pane is visible;
  - the polling task is cancelled when the view disappears.
- `hydrate()` keeps ownership of `draft` and `applied` only, and reads the snapshot through the observer.
- Freshness chip states:
  - **Live · 2 s ago**: observed within 2x the cadence.
  - **Stale · 41 s ago**
  - **Unavailable**: the item is missing, `drawing=off`, or the query failed. The reason is shown.
  - **Static text** or **Spacer**: never claims to be live.
- **Script-controlled detection:** if an observed `icon`, `icon.color` or `label.color` changes between polls without an Apply, mark that property "Set by the widget's script". Show a warning on the matching row: "Your script may replace this on its next update." The battery icon and battery colour rules are the likely cases.

## 4. Preview: observed baseline plus draft overlay

- **Baseline:** the queried `bounding_rects`, unchanged.
  - Members sit at `memberFrame.minX - unionFrame.minX`. Never stack them in enumeration order with an HStack; that is the bug that swaps the network arrow and its data.
  - With no edits, the preview must match the queried frames exactly.
- **Display choice:** parse every `display-N` key. Use the key that matches `NSScreen.main`'s index in `CGGetActiveDisplayList`, falling back to the lowest N. Every item uses the same key, and screen width and notch come from the same screen.
- **Vertical offset:** `.offset(y: -layer.yOffset)`, because SketchyBar treats positive as up. Layers are centred in the bar height before the offset is applied.
- **Fonts:** one `SketchybarFont` parser covering family, style (Regular, Medium, Semibold, Bold, Heavy) and size. Both the renderer and the width measurement use it.
- **Draft overlay:** for each component, `delta = effective(padding or gap) - observed`.
  - Untouched components have a delta of zero and do not move.
  - Left and centre: deltas push later components right. Right side: deltas push earlier components left.
  - A reorder repacks components using their measured widths, each including its own observed padding, starting from the bar edge padding.
- **Custom components** go through the same `MenuBarItemView`. `SketchybarItem.synthesised(from:value:)` builds the item from shared `BarStyle` constants (fonts and layer paddings), and `BarCommands` emits those same constants. Delete the separate `ComponentChip` padding of 8 pt and its monospaced font.

## 5. Canvas, boxes, sizing references

`ComponentCanvas`:
- 2x scale, drawn on the bar colour.
- Toggleable labelled boxes:
  - `padding L` and `padding R` (hatched);
  - `icon`, `label` (outlined);
  - `background` (dashed);
  - `gap` (amber), each box labelled with its value in pt.
- Reference lines for bar height and the centre baseline. A small ruler shows total width in pt.
- An optional ghost of the applied baseline at 30% opacity, so the draft can be compared with what is on screen now.

`SampleStateStrip` shows: Now · 0% · 100% · Widest · Unavailable.
- For built-ins, copy the observed `SketchybarItem` and replace each digit run in `label.value` with the sample. For example `"12%"` becomes `"0%"` or `"100%"`.
- **Widest** fills every digit position with `8` at the metric's maximum digit count: CPU and GPU `100`, network `888.8`, clock taken from the observed format. Unavailable shows `--`.
- Each sample is measured with `SketchybarFont` and laid out with the real layer paddings. Every sample carries a "Sample" marker.
- Show the maximum width across all samples ("Reserve 46 pt to avoid reflow"). That is the visible sizing reference.

## 6. Spacing, sizing, reset semantics

Add `InheritedValueRow` (in controls), built from `SettingRow`, `ValueSlider` and `IconButton("arrow.uturn.backward")`.
- The detail line shows the value's origin: "Inherited from bar: 4 pt" or "Widget's own: 6 pt".
- The reset button only appears when the component overrides the value.

Bar-wide Spacing card:
- each row offers "Use each widget's own", which sets nil, or a value;
- reset returns to nil.

Layout tab:
- **Spacing:** padding and gap.
- **Size:** icon size, label size, background height, corner radius. Size changes rewrite the font as `<observed family>:<observed style>:<size>`.
- **Alignment:** icon and label vertical offset, with the hint "Up is positive, as in SketchyBar".

Reset sends the recorded original. If no original was recorded (see §11), the row says "Original unknown. Restarting SketchyBar restores your script's value" and sends nothing. Never run `sketchybar --reload` or scripts on the user's behalf.

## 7. Apply that sends only differences

- `BarCommands.settings(new, previous:, observed:)` sends:
  - changed overrides;
  - restorations for overrides that have been cleared;
  - `--move` only when the order changed;
  - `drawing` only when visibility changed.
- Gap items are touched only when their gap is overridden. `background.drawing=off` is sent only to restore a recorded original.
- Startup replay sends overrides that are set, plus positions and order. Nothing else.
- Never send `script=`, `update_freq=`, `click_script=`, `--subscribe` or `--remove` for built-ins.

## 8. Presets and templates

- `PresentationPreset` values are shown as `ChoiceCard` previews:
  - Icon and value
  - Value only
  - Compact (padding 2 and gap 4 as overrides)
  - Pill (background and radius)
  - Monochrome (label colour equals icon colour)
- Presets write only `presentation` fields, as one undoable edit.
- The template gallery is split in two:
  - **Show a built-in widget:** re-shows hidden built-ins, which already have real sources.
  - **Add a static element:** Text, Icon, Spacer.
- Remove the static templates for CPU, Network, Battery, Clock, Spotify and Weather. Weather and Media appear disabled with "Needs a data source, coming later" (P3).

## 9. Icons

`IconChoice` has two cases:
- `.observed`: keep the widget's own icon, whether PNG or glyph.
- `.glyph(scalar, font)`: sends `icon=`, `icon.font=`, `icon.drawing=on` and `background.image.drawing=off` on the icon member. The previous image state goes into `originals`.

When the icon is a PNG, the Icon colour row is disabled with "This icon is an image and cannot be tinted. Choose a glyph to colour it."

`BarGlyphs` (core) is the catalogue:
- Entries are `(name, scalar, font)`.
- Scalars are written as `\u{...}` escapes. The empty System, Media and Status entries came from literal private-use characters being lost.
- Each metric gets two or three recommendations, listed first.
- At runtime, `CTFontGetGlyphsForCharacters` checks each entry against its font, and entries whose font has no glyph are hidden.
- Free text input is kept, but only accepted if the bar font can draw it.

## 10. Reused and new components

**Reuse:** `SettingsCard`, `SettingRow`, `SegmentedPill`, `ColorWell` (`isUnset`), `ValueSlider`, `NumberField` (exact pt), `ChoiceCard` (presets), `StatusChip` (freshness), `IconButton`, `IconMenu`, `CloseButton`, `HelpTooltip`, `MenuBarItemView` (corrected).

**New:** `InheritedValueRow`, `ComponentCanvas`, `SampleStateStrip`, `IconPicker`, `MenuBarObserver`, `SketchybarFont`. No new framework and no protocols.

## 11. File layout

**Core (`macarchy/core/integrations/sketchybar/`)**

- **Retain:** `BarConfiguration.swift`, `BarConfigurationStore.swift`.
- **Modify:**
  - `BarComponent.swift`: add `source`, `presentation`, `originals`; keep decoding the legacy fields.
  - `BarCommands.swift`: replay and order.
- **Add:**
  - `BarPresentation.swift`
  - `BarMetric.swift`
  - `BarGlyphs.swift`
  - `BarStyle.swift`: constants shared by the renderer and the commands.
  - `BarCommands+Presentation.swift`: emits differences and restorations.

**App (`macarchy/app/menu-bar/`)**

- **Retain:**
  - `MenuBarModel.swift`: remove snapshot ownership; fix hydrate.
  - `MenuBarModel+Runtime.swift`
  - `MenuBarComponents.swift`
  - `MenuBarStage.swift`
  - `MenuBarPane.swift`
- **Rewrite:**
  - `MenuBarLayout.swift`: baseline plus deltas.
  - `MenuBarItemView.swift`: offset sign, font.
  - `SketchybarItem.swift`: all display rects, `synthesised`.
- **Add:**
  - `MenuBarObserver.swift`
  - `SketchybarFont.swift`
  - `ComponentCanvas.swift`
  - `SampleStateStrip.swift`
  - `IconPicker.swift`
  - `TemplateGallery.swift`
  - `PresentationPreset.swift`
- **Split** `ComponentEditor.swift` into:
  - `ComponentEditor.swift`: the shell and preview region;
  - `ComponentEditor+Look.swift`
  - `ComponentEditor+Layout.swift`
  - `ComponentEditor+Source.swift`
  - Keep `ComponentEditor+Bindings.swift`.
- **Delete:**
  - `ComponentStudio.swift`: its contents move into the files above.
  - The static metric templates in `ComponentTemplate.swift`; that file keeps Text, Icon and Spacer.
- **Update:** `MenuBarPane+Inspector.swift`: the bar-wide spacing card uses `InheritedValueRow`.

**Controls (`macarchy/app/controls/`)**

- **Add:** `InheritedValueRow.swift`.

## 12. Migration risks

1. **Global spacing ambiguity.** Saved files may contain `componentPadding: 2` and `componentSpacing: 4` that hydrate wrote, not the user. Migration has to be explicit: show a banner, "2 pt / 4 pt is applied to every widget. Keep, or use each widget's own?" Don't change it silently.
2. **Originals that were never recorded.** Components that Macarchy has already styled have no script baseline to record. Mark those originals as unknown (§6). Don't record Macarchy's own output as the original.
3. **Startup behaviour changes.** Once replay sends only differences, untouched widgets get their script values back after the next restart, including backgrounds the user sees today. Mention this in the release notes and in the migration banner.
4. **Existing static "CPU" and similar custom components.** Keep them and label them "Static text (no data source)". Offer to show the matching built-in instead. Never delete automatically.
5. **Scripts that rewrite properties** can override presentation. Section 3's detection surfaces this; don't try to fight it.
6. **Display key mapping** needs checking on a two-display setup before release.
7. **Generated outputs:** per CONTRIBUTING, check what reads the replay output before changing how much it sends.

## 13. Acceptance checks

All automated checks use temporary directories and `MenuBarTestBackend`. None touch the desktop.

1. **Network fixture:** `network.up` is listed first but sits at a larger x. The canvas places `down` to the left of `up`.
2. **Vertical offset:** a layer with `y_offset=3` resolves 3 pt above centre. Test the geometry function, not the view.
3. **Unedited baseline:** with no edits, every preview frame equals its queried rect within 0.5 pt, and `settings(previous:)` returns no arguments.
4. **Single change:** changing only the CPU label colour produces exactly `--set <cpu label member> label.color=…`.
5. **Clearing an override:** with a recorded original, clearing sends the original. With an unknown original, it sends nothing and the row shows the "Original unknown" message.
6. **Global spacing nil:** no `padding_*` arguments and no gap-item arguments are sent.
7. **Observer:** with `hasChanges == true`, the observer updates `items` and `observedAt` and leaves `draft` unchanged. The chip becomes Stale after the threshold.
8. **Fresh hydrate:** a configuration without global spacing gives `hasChanges == false`.
9. **Presets:** applying each preset to a built-in never produces `script`, `update_freq`, `click_script`, `--subscribe` or `--remove`.
10. **Glyph catalogue:** every entry is non-empty and is a single scalar. Where the font is installed, the glyph exists.
11. **Custom components:** the synthesised preview width equals the `BarStyle` measurement used by the commands.
12. **Display choice:** a fixture with two `display-N` keys gives the same choice for every item.
13. **Manual check** (by you, on the installed build, when no other session is using the desktop): a screenshot of the real bar and the 1x preview overlaid differ by at most 1 pt for CPU, GPU, Memory, Network, Battery and Clock.
