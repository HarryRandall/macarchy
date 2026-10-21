import { MoreHorizontal, Palette } from "lucide-react";
import { useState } from "react";
import type { ThemeColour, ThemeDetail } from "~/bridge/protocol";
import { PageHeader } from "~/components/layout/page-header";
import { SectionHeading } from "~/components/layout/section-heading";
import { SettingRow } from "~/components/layout/setting-row";
import { SettingsSection } from "~/components/layout/settings-section";
import { Badge } from "~/components/ui/badge";
import { Button } from "~/components/ui/button";
import { ChoiceCard } from "~/components/ui/choice-card";
import { ColourWell } from "~/components/ui/colour-well";
import { Dialog } from "~/components/ui/dialog";
import { EmptyState } from "~/components/ui/empty-state";
import { HeroCard } from "~/components/ui/hero-card";
import { IconButton } from "~/components/ui/icon-button";
import { Menu, MenuTrigger, MenuPopup, MenuItem } from "~/components/ui/menu";
import { Notice } from "~/components/ui/notice";
import { SegmentedControl } from "~/components/ui/segmented-control";
import { Select } from "~/components/ui/select";
import { StatusChip } from "~/components/ui/status-chip";
import { Switch } from "~/components/ui/switch";
import { Tooltip } from "~/components/ui/tooltip";
import { useStore } from "~/lib/store";
import { TerminalPreview, ThemeArtwork } from "./terminal-preview";
import type { ThemesStore } from "./themes-store";

const colourRows: { field: ThemeColour; label: string }[] = [
  { field: "borderActive", label: "Border active" },
  { field: "borderInactive", label: "Border inactive" },
  { field: "sketchybarBar", label: "Menu bar background" },
  { field: "sketchybarText", label: "Menu bar text" },
  { field: "firefoxAccent", label: "Firefox accent" },
];

function Failure({ message }: { message: string }) {
  return (
    <Notice.Root variant="error">
      <Notice.Title>Could not complete that change</Notice.Title>
      <Notice.Description>{message}</Notice.Description>
    </Notice.Root>
  );
}

export function ThemesPage({ store }: { store: ThemesStore }) {
  const snapshot = useStore(store);
  const [selected, setSelected] = useState<string | null>(null);
  const [tab, setTab] = useState("Look");
  const state = snapshot.state;
  if (snapshot.status === "loading") return null;
  if (!state)
    return (
      <>
        <PageHeader title="Themes" subtitle="A familiar desktop. A different feeling." />
        <Notice.Root variant="error">
          <Notice.Title>Could not read your themes</Notice.Title>
          <Notice.Description>{snapshot.error}</Notice.Description>
          <Notice.Actions>
            <Button onClick={() => void store.load()}>Try again</Button>
          </Notice.Actions>
        </Notice.Root>
      </>
    );
  const current = state.themes.find((theme) => theme.summary.name === state.current);
  const theme = state.themes.find((item) => item.summary.name === selected);
  const open = (name: string) => {
    setSelected(name);
    setTab("Look");
  };
  return (
    <>
      <PageHeader
        title="Themes"
        subtitle="A familiar desktop. A different feeling."
        actions={
          <Button disabled={snapshot.busy} onClick={() => void store.importFolder()}>
            Import…
          </Button>
        }
      />
      {snapshot.error ? <Failure message={snapshot.error} /> : null}
      {snapshot.busy ? (
        <p role="status" className="text-meta text-fg-secondary">
          Saving or applying…
        </p>
      ) : null}
      {state.warnings.length ? (
        <Notice.Root variant="warning">
          <Notice.Title>Some themes could not be read</Notice.Title>
          <Notice.Description>{state.warnings.join("\n")}</Notice.Description>
        </Notice.Root>
      ) : null}
      {current ? (
        <HeroCard
          eyebrow="CURRENT THEME"
          title={current.summary.name}
          subtitle="Your wallpaper, palette and finishing touches."
          artwork={<ThemeArtwork theme={current} />}
          badge={<StatusChip tone="success" label="Applied" live />}
          actions={<Button onClick={() => open(current.summary.name)}>Customise</Button>}
        />
      ) : null}
      <SectionHeading title="Your collection" trailing={`${state.themes.length} installed`} />
      {!state.themes.length ? (
        <EmptyState
          icon={<Palette />}
          title="Your collection starts here"
          description="Import a theme folder to make it your own."
        />
      ) : null}
      <div className="grid grid-cols-[repeat(auto-fit,minmax(250px,1fr))] gap-4">
        {state.themes.map((item) => (
          <div key={item.summary.name} className="flex min-w-0 flex-col gap-2">
            <ChoiceCard
              label={item.summary.name}
              aria-label={`Customise ${item.summary.name}`}
              selected={item.summary.name === selected}
              previewHeight={168}
              preview={<ThemeArtwork theme={item} />}
              onClick={() => open(item.summary.name)}
            />
            <div className="flex min-h-7 items-center justify-between gap-2 px-1">
              <div className="flex gap-2">
                {item.summary.name === state.current ? <Badge tone="success">Current</Badge> : null}
                {item.modified ? <Badge>Edited</Badge> : null}
              </div>
              {item.summary.name !== state.current ? (
                <Button
                  size="sm"
                  disabled={snapshot.busy}
                  aria-label={`Apply ${item.summary.name}`}
                  onClick={() => void store.apply(item.summary.name)}
                >
                  Apply
                </Button>
              ) : null}
            </div>
          </div>
        ))}
      </div>
      <Dialog.Root
        open={!!theme}
        onOpenChange={(value) => {
          if (!value) setSelected(null);
        }}
      >
        {theme ? (
          <Dialog.Popup size="lg">
            <Dialog.Header actions={<ThemeMenu store={store} theme={theme} busy={snapshot.busy} />}>
              <Dialog.Title>{theme.summary.name}</Dialog.Title>
            </Dialog.Header>
            <Dialog.Body>
              <div className="flex flex-wrap items-center justify-between gap-2">
                <SegmentedControl
                  label="Theme details"
                  size="prominent"
                  value={tab}
                  options={["Look", "Wallpaper", "Colours"].map((value) => ({
                    value,
                    label: value,
                  }))}
                  onValueChange={setTab}
                />
                <Tooltip
                  content={
                    theme.summary.name === state.current
                      ? "Apply your edits to the desktop"
                      : "Switch to this theme"
                  }
                >
                  <Button
                    variant="primary"
                    disabled={snapshot.busy}
                    onClick={() => void store.apply(theme.summary.name)}
                  >
                    {snapshot.applying
                      ? "Applying…"
                      : theme.summary.name === state.current
                        ? "Reapply"
                        : "Apply"}
                  </Button>
                </Tooltip>
              </div>
              {snapshot.error ? <Failure message={snapshot.error} /> : null}
              {snapshot.busy ? (
                <p role="status" className="text-meta text-fg-secondary">
                  Saving or applying…
                </p>
              ) : null}
              {tab === "Look" ? (
                <>
                  <div className="h-[200px] overflow-hidden rounded-card border border-hairline">
                    <ThemeArtwork theme={theme} />
                  </div>
                  {theme.terminal ? (
                    <TerminalPreview
                      palette={theme.terminal}
                      name={theme.summary.name}
                      accent={theme.values.borderActive}
                    />
                  ) : null}
                </>
              ) : null}
              {tab === "Wallpaper" ? (
                theme.summary.backgrounds.length ? (
                  <SettingsSection
                    title="Wallpaper"
                    help={`${theme.summary.backgrounds.length} ship with this theme`}
                  >
                    <div className="grid grid-cols-[repeat(auto-fit,minmax(150px,1fr))] gap-2 p-3">
                      {theme.summary.backgrounds.map((background) => (
                        <ChoiceCard
                          key={background.path}
                          label={background.path.split("/").at(-1) ?? background.name}
                          selected={background.path === theme.summary.currentBackground}
                          previewHeight={84}
                          disabled={snapshot.busy}
                          preview={
                            <img
                              src={background.thumbnail}
                              alt=""
                              className="size-full object-cover"
                            />
                          }
                          onClick={() => void store.choose(theme.summary.name, background.path)}
                        />
                      ))}
                    </div>
                  </SettingsSection>
                ) : (
                  <EmptyState
                    variant="plain"
                    title="No wallpapers"
                    description="This theme ships without one."
                  />
                )
              ) : null}
              {tab === "Colours" ? (
                <SettingsSection title="Colours" help="Saved to theme.json as you edit.">
                  <SettingRow title="Dark mode">
                    <Switch
                      aria-label="Dark mode"
                      checked={theme.values.dark}
                      onCheckedChange={(value) =>
                        void store.edit(theme.summary.name, "dark", value)
                      }
                    />
                  </SettingRow>
                  {colourRows.map(({ field, label }) => (
                    <SettingRow key={field} title={label}>
                      <ColourWell
                        label={label}
                        format={field === "firefoxAccent" ? "rgb" : "argb"}
                        value={theme.values[field]}
                        onValueChange={(value) => void store.edit(theme.summary.name, field, value)}
                      />
                    </SettingRow>
                  ))}
                  <SettingRow
                    title="Neovim colourscheme"
                    help="Found in your Neovim config and installed plugins. Neovim needs a small hook to follow it; see the README."
                  >
                    <Select
                      label="Neovim colourscheme"
                      value={theme.values.nvimColorscheme ?? ""}
                      options={[
                        { value: "", label: `Theme default (${theme.defaultColourscheme})` },
                        ...[
                          ...new Set(
                            [theme.values.nvimColorscheme, ...state.colourschemes].filter(
                              (value): value is string => value !== null,
                            ),
                          ),
                        ].map((value) => ({
                          value,
                          label: state.colourschemes.includes(value)
                            ? value
                            : `${value} (not found)`,
                        })),
                      ]}
                      onValueChange={(value) =>
                        void store.edit(theme.summary.name, "nvimColorscheme", value || null)
                      }
                    />
                  </SettingRow>
                </SettingsSection>
              ) : null}
            </Dialog.Body>
          </Dialog.Popup>
        ) : null}
      </Dialog.Root>
    </>
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
  return (
    <Menu>
      <MenuTrigger render={<IconButton label="More actions" />}>
        <MoreHorizontal aria-hidden />
      </MenuTrigger>
      <MenuPopup>
        {theme.modified && theme.hasDefault ? (
          <MenuItem disabled={busy} onClick={() => void store.reset(name)}>
            Reset to shipped version
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
  );
}
