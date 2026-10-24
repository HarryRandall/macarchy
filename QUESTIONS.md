# Questions from porting the polish fixes

Branch `fix/bar-widgets-polish`: `feat/bar-widgets` plus the core, CLI, skhd and
timing fixes from `fix/autonomous-polish`. The SwiftUI-only changes were left
behind. Delete this file before merging.

## Borders and services

- **Border edits with borders stopped or no theme.** This branch refuses border
  edits unless borders is running and a theme is active. The polish branch saved
  them anyway and applied them at next start, and saved width and corners with no
  theme. Keep the refusal, or port the save-anyway behaviour (bridge and React
  page change)?
- **Services that aren't installed.** Restart All and the service counts now skip
  tools that aren't installed. The React UI doesn't say which ones are missing
  yet; that needs a "not installed" state in the protocol. Advanced still lists
  all four.

## Shortcuts

- **Old disabled shortcuts.** Disable now writes a `# disabled: ` marker so
  headings such as `# Space: ...` stay headings. A binding with no modifier that an
  older build disabled (for example `# f1 : ...`) now reads as a heading. Is that
  acceptable, or do you want a one-off migration?

## Isolation and the CLI

- **`widget run` in an isolated home.** `MACARCHY_HOME=<temp> macarchy widget
  run` no longer drives the real bar, because isolated runs refuse real daemons.
  Without `MACARCHY_HOME` it still works. The bar session's demo (the Dev app with
  `MACARCHY_HOME=widget-demo`) relies on that, so it would need another way to
  reach the live bar. OK?
- **Partial uninstall wording.** The message still starts "Restore did not
  finish; some files or services may already have changed." before listing what
  changed, which is a little redundant.

## React gaps

- **Skipped Ghostty colours.** The Themes page doesn't show which Ghostty colours
  were skipped. They appear only in the command log and the CLI output.
