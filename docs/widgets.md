# Widgets

A bar widget is a folder with a `widget.json`. The built-in ones ship in
`resources/widgets`; people's own live in `~/.config/macarchy/widgets`. Both use
the same format, so anything a built-in does, a person's widget can do.

`macarchy widget list` shows every widget and any folder that could not be
loaded. `macarchy widget check <id|folder>` checks one and names the line of
each problem. `resources/widgets/widget.schema.json` gives editors the same
rules.

## A folder

| File | Contents |
|---|---|
| `widget.json` | The manifest. Required. |
| `provider.sh` | Optional, executable. Prints JSON, or plain text to set only the label. |

The folder name and the manifest's `id` match. Ids are unique across built-in
and personal widgets: a personal widget that reuses a built-in id is refused,
not used in its place.

## widget.json

| Field | What it is |
|---|---|
| `schema` | `1`. |
| `id`, `name`, `version` | Lower-case id, a name up to 40 characters, and `1.0.0`-style version. |
| `author`, `description`, `icon` | Optional. `icon` is a glyph, such as an SF Symbol character. |
| `source` | A reading Macarchy takes itself, with nothing installed: `date`, `cpu`, `gpu`, `memory`, `network`, `battery` or `spaces`. Temperatures come from the SMC, as Stats and macmon read them; Spaces and their windows come from yabai. A widget with a `seconds` setting that is on updates every second. |
| `provider` | A script in the folder. A widget has a source or a provider, or neither. |
| `label` | What the bar shows, with readings and settings in braces. |
| `settings` | Things a person can change, each drawn as a control in the editor: `text`, `number`, `toggle`, `choice`, `colour` or `format`. |
| `style` | `box` (`none`, `outline`, `fill`), `size`, colours (`text`, `accent`, `muted` or a hex value), `radius` and padding. `lines: 2` stacks the label's two lines beside the icon; `row: n` draws up to n items instead of one, from the output's `items`. |
| `update` | `every` (`2s`, `5m`, `1h`, `second` or `minute`) and `events` (`system_woke`, `power_source_changed`, `timezone_changed`, `space_changed`, `front_app_switched`, `display_changed`, `windows_changed`). The bar passes events on with `macarchy widget trigger <event>`. |
| `click` | One of `open` (an app or URL), `run` (a command) or `dropdown` (rows). |
| `samples` | `widest` and `unavailable`, for the editor's previews. |
| `permissions` | Needs to show before adding it. Only `network` for now; nothing enforces it. |

Dropdown rows have a `type`: `heading`, `text`, `reading`, `action`, `toggle`,
`choice`, `graph`, `cores`, `apps` or `divider`. An action runs or opens
something; a toggle or choice changes one of the widget's settings. A provider
can print `rows` to replace them, for lists that change.

The richer rows read their `value` as text, usually a reading the provider
fills in:

| Row | Value |
|---|---|
| `graph` | Numbers out of 100, separated by commas: `12,30,45`. |
| `cores` | Two groups of numbers, performance then efficiency cores: `62,48,71\|80,74`. |
| `apps` | `Name:value` pairs separated by commas, such as `Firefox:9%`; the value is optional. Icons come from the app. |

Macarchy draws the dropdown itself, in a panel that never takes focus.

## Rows

A widget with `style.row` draws a row of items, as Spaces draws one per
Space. Its output's `items` has an entry for each item, in order: `label`,
`icon`, `colour`, `iconColour`, `drawing`, `background` (drawn faintly
behind the item), `border` and `display`. An item with no entry, or one
with `drawing: false`, is hidden. A `background` or `border` on the
output itself draws one box around the whole row.

The built-in Spaces widget reads Spaces and windows from yabai and draws
apps with sketchybar-app-font. Its glyphs come from `app-icons.json` in
its folder, which `tools/app-icons.py` makes from the font's
`icon_map.sh`. Its settings choose where boxes go, what each Space shows,
names, the most app icons before `+n`, whether empty Spaces show, and the
colours. Clicking a Space goes straight there through yabai.

A widget whose provider, click or dropdown runs a command is a scripted
widget. It runs as the person, and the interface marks it with a Script badge.

## On the bar

A bar component that shows a widget names it in `widget`, with `settings` and
`menu` holding only what differs from the widget's own. `WidgetMigration`
turns a bar saved before widgets into one: the clock, CPU and battery items
become built-in widgets, and command items become personal widgets whose
provider runs the same command. It is not run yet; the bar starts using
widgets when the runtime that updates them lands.
