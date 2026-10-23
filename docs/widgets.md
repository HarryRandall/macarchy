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
| `source` | A reading Macarchy provides: `date`, `battery` or `cpu`. |
| `provider` | A script in the folder. A widget has a source or a provider, or neither. |
| `label` | What the bar shows, with readings and settings in braces. |
| `settings` | Things a person can change, each drawn as a control in the editor: `text`, `number`, `toggle`, `choice`, `colour` or `format`. |
| `style` | `box` (`none`, `outline`, `fill`), `size`, colours (`text`, `accent`, `muted` or a hex value), `radius` and padding. |
| `update` | `every` (`2s`, `5m`, `1h`, `second` or `minute`) and `events` (`system_woke`, `power_source_changed`, `timezone_changed`, `space_changed`, `front_app_switched`, `display_changed`). |
| `click` | One of `open` (an app or URL), `run` (a command) or `dropdown` (rows). |
| `samples` | `widest` and `unavailable`, for the editor's previews. |
| `permissions` | Needs to show before adding it. Only `network` for now; nothing enforces it. |

Dropdown rows have a `type`: `heading`, `text`, `reading`, `action`, `toggle`,
`choice`, `graph`, `cores`, `apps` or `divider`. An action runs or opens
something; a toggle or choice changes one of the widget's settings.

A widget whose provider, click or dropdown runs a command is a scripted
widget. It runs as the person, and the interface marks it with a Script badge.

## On the bar

A bar component that shows a widget names it in `widget`, with `settings` and
`menu` holding only what differs from the widget's own. `WidgetMigration`
turns a bar saved before widgets into one: the clock, CPU and battery items
become built-in widgets, and command items become personal widgets whose
provider runs the same command. It is not run yet; the bar starts using
widgets when the runtime that updates them lands.
