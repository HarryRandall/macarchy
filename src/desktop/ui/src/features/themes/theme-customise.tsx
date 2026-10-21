import { MoreHorizontal } from "lucide-react";
import { useState } from "react";
import type { ThemeColour, ThemeDetail } from "~/bridge/protocol";
import { Badge } from "~/components/ui/badge";
import { Card, CardHeader, Row } from "~/components/ui/card";
import { ColourWell } from "~/components/ui/colour-well";
import { ConfirmDialog } from "~/components/ui/confirm-dialog";
import { IconButton } from "~/components/ui/icon-button";
import { Menu, MenuItem, MenuPopup, MenuTrigger } from "~/components/ui/menu";
import { Select } from "~/components/ui/select";
import { Switch } from "~/components/ui/switch";
import type { ThemesStore } from "./themes-store";

const colourRows: { field: ThemeColour; label: string }[] = [
  { field: "borderActive", label: "Border active" },
  { field: "borderInactive", label: "Border inactive" },
  { field: "sketchybarBar", label: "Menu bar background" },
  { field: "sketchybarText", label: "Menu bar text" },
  { field: "firefoxAccent", label: "Firefox accent" },
];

/** The theme's own settings in theme.json: dark mode, its colours and Neovim's colourscheme. */
export function ThemeCustomise({
  store,
  theme,
  colourschemes,
  busy,
}: {
  store: ThemesStore;
  theme: ThemeDetail;
  colourschemes: readonly string[];
  busy: boolean;
}) {
  const name = theme.summary.name;
  const chosen = theme.values.nvimColorscheme;
  const schemes = [
    ...new Set([chosen, ...colourschemes].filter((value): value is string => value !== null)),
  ];
  return (
    <Card>
      <CardHeader
        title={
          <span className="flex items-center gap-2">
            Customise
            {theme.modified ? <Badge>Edited</Badge> : null}
          </span>
        }
        description="Saved to theme.json as you edit"
        action={<ThemeMenu store={store} theme={theme} busy={busy} />}
      />
      <Row
        title="Dark mode"
        control={
          <Switch
            aria-label="Dark mode"
            checked={theme.values.dark}
            onCheckedChange={(value) => void store.edit(name, "dark", value)}
          />
        }
      />
      {colourRows.map(({ field, label }) => (
        <Row
          key={field}
          title={label}
          control={
            <ColourWell
              label={label}
              format={field === "firefoxAccent" ? "rgb" : "argb"}
              value={theme.values[field]}
              onValueChange={(value) => store.preview(name, field, value)}
              onValueCommit={(value) => void store.commit(name, field, value)}
            />
          }
        />
      ))}
      <Row
        title="Neovim colourscheme"
        description="Found in your Neovim config and plugins. Neovim needs a small hook to follow it."
        control={
          <Select
            label="Neovim colourscheme"
            value={chosen ?? ""}
            options={[
              { value: "", label: `Theme default (${theme.defaultColourscheme})` },
              ...schemes.map((value) => ({
                value,
                label: colourschemes.includes(value) ? value : `${value} (not found)`,
              })),
            ]}
            onValueChange={(value) => void store.edit(name, "nvimColorscheme", value || null)}
          />
        }
      />
    </Card>
  );
}

function ThemeMenu({
  store,
  theme,
  busy,
}: {
  store: ThemesStore;
  theme: ThemeDetail;
  busy: boolean;
}) {
  const name = theme.summary.name;
  const [resetting, setResetting] = useState(false);
  return (
    <>
      <Menu>
        <MenuTrigger render={<IconButton label="More actions" size="sm" />}>
          <MoreHorizontal aria-hidden />
        </MenuTrigger>
        <MenuPopup>
          {theme.modified && theme.hasDefault ? (
            <MenuItem disabled={busy} onClick={() => setResetting(true)}>
              Reset to shipped version…
            </MenuItem>
          ) : null}
          <MenuItem disabled={busy} onClick={() => void store.exportFolder(name)}>
            Export as a folder…
          </MenuItem>
          <MenuItem disabled={busy} onClick={() => void store.reveal(name)}>
            Show in Finder
          </MenuItem>
        </MenuPopup>
      </Menu>
      <ConfirmDialog
        open={resetting}
        onOpenChange={setResetting}
        title={`Reset ${theme.summary.title} to its shipped version?`}
        description="Your edits to this theme's dark mode, colours and Neovim colourscheme are replaced. The current theme.json is kept in a backup you can restore from Advanced."
        confirmLabel="Reset theme"
        busyLabel="Resetting…"
        tone="danger"
        onConfirm={() => store.reset(name)}
      />
    </>
  );
}
