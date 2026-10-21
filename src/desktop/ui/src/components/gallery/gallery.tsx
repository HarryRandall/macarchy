import "~/styles/index.css";

import {
  AppWindow,
  ArrowLeft,
  ArrowUpRight,
  Clock,
  Command,
  Hammer,
  Keyboard,
  LayoutGrid,
  Minus,
  MoreHorizontal,
  Palette,
  Pencil,
  Plus,
  RotateCw,
  Search,
  Square,
} from "lucide-react";
import { type ReactNode, StrictMode, useLayoutEffect, useState } from "react";
import { createRoot } from "react-dom/client";

import {
  CardContent,
  SectionAction,
  SettingsCard,
  SettingsSection,
} from "~/components/layout/settings-section";
import { PageHeader } from "~/components/layout/page-header";
import { SectionHeading } from "~/components/layout/section-heading";
import { SettingRow } from "~/components/layout/setting-row";
import { ActionBar } from "~/components/ui/action-bar";
import { AppIcon } from "~/components/ui/app-icon";
import { Badge, CountBadge } from "~/components/ui/badge";
import { Button } from "~/components/ui/button";
import { CodeBlock } from "~/components/ui/code-block";
import { ColourWell } from "~/components/ui/colour-well";
import { ConfirmDialog } from "~/components/ui/confirm-dialog";
import { CopyButton } from "~/components/ui/copy-button";
import { Dialog } from "~/components/ui/dialog";
import { EmptyState } from "~/components/ui/empty-state";
import { HeroCard } from "~/components/ui/hero-card";
import { ActionCluster, IconButton } from "~/components/ui/icon-button";
import { IconTile, type Tint } from "~/components/ui/icon-tile";
import { InlineStatus } from "~/components/ui/inline-status";
import { Kbd, KbdGroup } from "~/components/ui/kbd";
import { ListGroupHeader, ListRow } from "~/components/ui/list-row";
import {
  Menu,
  MenuCheckboxItem,
  MenuGroup,
  MenuGroupLabel,
  MenuItem,
  MenuPopup,
  MenuRadioGroup,
  MenuRadioItem,
  MenuSeparator,
  MenuTrigger,
} from "~/components/ui/menu";
import { OverviewActionCard } from "~/components/ui/overview-action-card";
import { Notice } from "~/components/ui/notice";
import { RadioGroup } from "~/components/ui/radio-group";
import { SearchField } from "~/components/ui/search-field";
import { SegmentedControl } from "~/components/ui/segmented-control";
import { Select } from "~/components/ui/select";
import { Spinner } from "~/components/ui/spinner";
import { StatTile } from "~/components/ui/stat-tile";
import { StatusChip } from "~/components/ui/status-chip";
import { Switch } from "~/components/ui/switch";
import { Input, TextareaField, TextField } from "~/components/ui/text-field";
import { TooltipProvider } from "~/components/ui/tooltip";
import { ValueSlider } from "~/components/ui/value-slider";
import { accentVariables } from "~/lib/accent";

type Appearance = "system" | "light" | "dark";

const accents = [
  { value: "#0a84ff", label: "System blue" },
  { value: "#f2f2ee", label: "Near white (Lumon)" },
  { value: "#1e1e5a", label: "Near black" },
  { value: "#ff9f0a", label: "Orange" },
] as const;

const tints: Tint[] = ["accent", "blue", "purple", "pink", "teal", "orange", "green", "red"];

const report = `### Environment
- Mac: Mac15,3 · arm64
- macOS: 26.1
- Macarchy: 0.9.0 (412)

### Checks
- [x] yabai 7.1.25 is installed
- [x] skhd is running
- [ ] SketchyBar is not running: launchctl kickstart -k gui/$UID/homebrew.mxcl.sketchybar
- [x] borders is running`;

const wait = (ms: number) => new Promise<void>((resolve) => setTimeout(resolve, ms));

function Gallery() {
  const [appearance, setAppearance] = useState<Appearance>("system");
  const [accent, setAccent] = useState<string>(accents[0].value);

  useLayoutEffect(() => {
    const root = document.documentElement;
    if (appearance === "system") delete root.dataset.theme;
    else root.dataset.theme = appearance;
  }, [appearance]);

  useLayoutEffect(() => {
    const style = document.documentElement.style;
    for (const key of ["--accent", "--accent-fg", "--accent-stroke-light", "--accent-stroke-dark"])
      style.removeProperty(key);
    for (const [key, value] of Object.entries(accentVariables(accent)))
      style.setProperty(key, value);
  }, [accent]);

  return (
    <TooltipProvider>
      <div className="h-full overflow-y-auto bg-page">
        <header className="sticky top-0 z-40 flex flex-wrap items-center gap-4 border-b border-hairline bg-bar/90 px-6 py-3 backdrop-blur-xl">
          <h1 className="text-section-title text-fg">Components</h1>
          <a href="options/" className="text-meta text-accent hover:underline">
            Design options
          </a>
          <SegmentedControl
            label="Window appearance"
            value={appearance}
            options={[
              { value: "system", label: "System" },
              { value: "light", label: "Light" },
              { value: "dark", label: "Dark" },
            ]}
            onValueChange={setAppearance}
          />
          <Select
            label="Accent"
            value={accent}
            options={accents.map((option) => ({ ...option }))}
            onValueChange={setAccent}
          />
          <p className="text-meta text-fg-secondary">
            Panels force their appearance; popups and dialogs follow the window's.
          </p>
        </header>
        <div className="grid grid-cols-1 xl:grid-cols-2">
          <div data-appearance="light" className="min-w-0 bg-page px-6 py-8">
            <Showcase appearance="Light" />
          </div>
          <div data-appearance="dark" className="min-w-0 bg-page px-6 py-8">
            <Showcase appearance="Dark" />
          </div>
        </div>
      </div>
    </TooltipProvider>
  );
}

function Group({ title, children }: { title: string; children: ReactNode }) {
  return (
    <section className="flex flex-col gap-3">
      <SectionHeading title={title} />
      {children}
    </section>
  );
}

function Row({ children }: { children: ReactNode }) {
  return <div className="flex flex-wrap items-center gap-3">{children}</div>;
}

function Showcase({ appearance }: { appearance: string }) {
  return (
    <div className="mx-auto flex max-w-[720px] flex-col gap-8">
      <PageHeader
        title={appearance}
        subtitle="Every shared control, in each variant and state."
        actions={
          <ActionBar>
            <Button>
              <RotateCw aria-hidden className="size-3.5" />
              Check again
            </Button>
            <Menu>
              <MenuTrigger render={<IconButton label="More actions" />}>
                <MoreHorizontal aria-hidden />
              </MenuTrigger>
              <FilterMenu />
            </Menu>
          </ActionBar>
        }
      />
      <Buttons />
      <Status />
      <Fields />
      <Colours />
      <Lists />
      <Tiles />
      <Heroes />
      <Empty />
      <Code />
      <Dialogs />
      <Existing />
    </div>
  );
}

function Buttons() {
  const [busy, setBusy] = useState(false);
  return (
    <Group title="Buttons">
      <Row>
        <Button>Default</Button>
        <Button variant="primary">Primary</Button>
        <Button variant="ghost">Ghost</Button>
        <Button variant="danger">Danger</Button>
        <Button variant="bar" size="icon-bar" aria-label="Bar">
          <LayoutGrid aria-hidden />
        </Button>
        <Button disabled>Disabled</Button>
      </Row>
      <Row>
        <Button variant="field" className="w-56 gap-2">
          <Search aria-hidden className="size-3" strokeWidth={2.25} />
          <span>Search</span>
          <Kbd className="ml-auto">⌘K</Kbd>
        </Button>
        <Button variant="pill" size="sm">
          3/4
        </Button>
        <Button variant="quiet" size="xs">
          <RotateCw aria-hidden />
          Reset
        </Button>
        <Button variant="bar" size="inline">
          Actions
        </Button>
        <Button variant="translucent" size="icon-md" aria-label="Back">
          <ArrowLeft aria-hidden strokeWidth={2.5} />
        </Button>
      </Row>
      <Row>
        <Button size="sm">Small</Button>
        <Button>Default</Button>
        <Button variant="primary" size="lg">
          Set up Macarchy
        </Button>
        <Button disabled>
          <Spinner size="sm" />
          Saving…
        </Button>
      </Row>
      <Row>
        <IconButton label="Edit rule for Finder">
          <Pencil aria-hidden />
        </IconButton>
        <IconButton label="Remove rule for Finder" tone="danger">
          <Minus aria-hidden />
        </IconButton>
        <IconButton label="Restart" size="sm">
          <RotateCw aria-hidden />
        </IconButton>
        <IconButton label="Restarting" busy>
          <RotateCw aria-hidden />
        </IconButton>
        <IconButton label="Disabled" disabled>
          <Square aria-hidden />
        </IconButton>
        <ActionCluster aria-label="Window arrangement">
          <IconButton
            label="Restart window arrangement"
            busy={busy}
            onClick={() => {
              setBusy(true);
              void wait(1500).then(() => setBusy(false));
            }}
          >
            <RotateCw aria-hidden />
          </IconButton>
          <IconButton label="Stop window arrangement" tone="danger">
            <Square aria-hidden className="fill-current" />
          </IconButton>
        </ActionCluster>
      </Row>
      <Row>
        <CopyButton text="brew install yabai" label="Copy command" tooltip="brew install yabai" />
        <CopyButton text="x" label="Copy fix" size="sm" />
        <CopyButton
          text="x"
          label="Copy report"
          write={() => Promise.reject(new Error("blocked"))}
        />
        <CopyButton text="x" label="Copy command" iconOnly />
        <Spinner size="sm" />
        <Spinner />
        <Spinner size="lg" label="Loading" />
      </Row>
    </Group>
  );
}

function Status() {
  return (
    <Group title="Status">
      <Row>
        <StatusChip tone="success" label="Running" live />
        <StatusChip tone="neutral" label="Stopped" />
        <StatusChip tone="warning" label="Needs repair" />
        <StatusChip tone="danger" label="Failed" />
        <StatusChip tone="success" label="Everything is working" variant="plain" />
      </Row>
      <Row>
        <Badge>Edited</Badge>
        <Badge>Read only</Badge>
        <Badge tone="accent">Active</Badge>
        <Badge tone="success">Current</Badge>
        <Badge tone="warning">Modified</Badge>
        <Badge tone="danger">Missing</Badge>
        <CountBadge count={7} />
        <CountBadge count={128} tone="accent" />
      </Row>
      <div className="flex flex-col gap-1.5">
        <InlineStatus tone="success">Copied</InlineStatus>
        <InlineStatus tone="warning">Already used by Spaces</InlineStatus>
        <InlineStatus tone="danger">
          Could not save the rule: the title is not a valid pattern.
        </InlineStatus>
        <InlineStatus icon={false}>Checked 10:42</InlineStatus>
      </div>
      <Notice.Root variant="warning">
        <Notice.Title>Notice, for comparison</Notice.Title>
        <Notice.Description>Status that needs a title or an action.</Notice.Description>
      </Notice.Root>
    </Group>
  );
}

function Fields() {
  const [app, setApp] = useState("Finder");
  const [title, setTitle] = useState("^Copy$|^Move$");
  const [search, setSearch] = useState("");
  const [query, setQuery] = useState("focus");
  const [existing, setExisting] = useState<"keep" | "replace">("keep");
  const [description, setDescription] = useState("");
  return (
    <Group title="Fields">
      <SettingsCard>
        <CardContent className="grid grid-cols-1 gap-4 sm:grid-cols-2">
          <TextField
            label="Application"
            placeholder="For example, Finder"
            value={app}
            onValueChange={setApp}
            description="The display name, exactly"
          />
          <TextField
            label="Window title"
            variant="mono"
            placeholder="All windows"
            value={title}
            onValueChange={setTitle}
          />
          <TextField
            label="Pattern"
            variant="mono"
            defaultValue="^Copy$|("
            error="The pattern has an unclosed bracket."
          />
          <TextField label="Disabled" defaultValue="Read only" disabled />
          <TextareaField
            fieldClassName="sm:col-span-2"
            label="What happened, and what you expected"
            value={description}
            onChange={(event) => setDescription(event.currentTarget.value)}
          />
        </CardContent>
      </SettingsCard>
      <SettingsCard>
        <SettingRow title="Application" controlId="row-input">
          <Input id="row-input" className="w-60" placeholder="For example, Finder" />
        </SettingRow>
        <SettingRow title="Small mono">
          <Input
            aria-label="Small mono"
            size="sm"
            variant="mono"
            className="w-40"
            defaultValue="0xff89b4fa"
          />
        </SettingRow>
      </SettingsCard>
      <Row>
        <SearchField
          className="w-[230px]"
          label="Find a shortcut"
          help="Search keys, source comments and commands"
          value={search}
          onValueChange={setSearch}
        />
        <SearchField className="w-[230px]" label="Search" value={query} onValueChange={setQuery} />
        <SearchField
          className="w-[180px]"
          label="Disabled"
          value=""
          onValueChange={() => {}}
          disabled
        />
      </Row>
      <SettingsCard>
        <CardContent>
          <RadioGroup
            label="Existing configuration"
            value={existing}
            onValueChange={setExisting}
            options={[
              {
                value: "keep",
                label: "Keep mine and add Macarchy",
                description: "Your shortcuts and bar stay as they are.",
              },
              { value: "replace", label: "Start fresh with Macarchy's defaults" },
            ]}
          />
        </CardContent>
      </SettingsCard>
    </Group>
  );
}

function Colours() {
  const [active, setActive] = useState<string | null>("0xff89b4fa");
  const [committed, setCommitted] = useState<string | null>(null);
  const [accent, setAccent] = useState<string | null>("#E66868");
  const [unset, setUnset] = useState<string | null>(null);
  return (
    <Group title="Colour">
      <SettingsSection
        title="Colour"
        help="Edit colour, opacity or hex values."
        action={
          <SectionAction disabled={active === "0xff89b4fa"} onClick={() => setActive("0xff89b4fa")}>
            Theme colours
          </SectionAction>
        }
      >
        <SettingRow title="Active" detail={`Committed: ${committed ?? "nothing yet"}`}>
          <ColourWell
            label="Active border colour"
            format="argb"
            value={active}
            onValueChange={setActive}
            onValueCommit={setCommitted}
            swatches={["#89b4fa", "#f38ba8", "#a6e3a1", "#f9e2af", "0x80cdd6f4"]}
          />
        </SettingRow>
        <SettingRow
          title="Firefox accent"
          detail="#rrggbb: no opacity strip; passed through unchanged until edited"
        >
          <ColourWell
            label="Firefox accent"
            format="rgb"
            value={accent}
            onValueChange={setAccent}
          />
        </SettingRow>
        <SettingRow title="Not set">
          <ColourWell label="Menu bar text" format="argb" value={unset} onValueChange={setUnset} />
        </SettingRow>
        <SettingRow title="Unreadable">
          <ColourWell label="Broken colour" format="argb" value="teal" onValueChange={() => {}} />
        </SettingRow>
        <SettingRow title="Swatch only, and disabled">
          <div className="flex gap-2">
            <ColourWell
              label="Swatch"
              size="swatch"
              format="argb"
              value="0x80f38ba8"
              onValueChange={() => {}}
            />
            <ColourWell
              label="Disabled"
              format="argb"
              value="0xff000000"
              onValueChange={() => {}}
              disabled
            />
          </div>
        </SettingRow>
      </SettingsSection>
    </Group>
  );
}

function Lists() {
  const [selected, setSelected] = useState("finder");
  return (
    <Group title="Lists">
      <SettingsSection
        title="Custom rules"
        help="Match an application and optional window title pattern."
        action={<SectionAction icon={null}>Clear all</SectionAction>}
      >
        <ListRow
          leading={<AppIcon />}
          title="Finder"
          detail="^Copy$|^Move$|^Delete$|^Trash$"
          detailMono
          onSelect={() => setSelected("finder")}
          selected={selected === "finder"}
          selectLabel="Edit rule for Finder"
          revealActions
          actions={
            <IconButton label="Remove rule for Finder" tone="danger">
              <Minus aria-hidden />
            </IconButton>
          }
        />
        <ListRow
          leading={<AppIcon />}
          title="Calculator"
          detail="All windows"
          onSelect={() => setSelected("calculator")}
          selected={selected === "calculator"}
          revealActions
          actions={
            <>
              <IconButton label="Edit rule for Calculator">
                <Pencil aria-hidden />
              </IconButton>
              <IconButton label="Remove rule for Calculator" tone="danger">
                <Minus aria-hidden />
              </IconButton>
            </>
          }
        />
        <ListRow
          leading={<AppIcon />}
          title="System Settings"
          detail="Windows matching ^General$"
          trailing={<Badge>Read only</Badge>}
        />
        <ListRow
          leading={
            <IconTile tint="neutral">
              <Clock />
            </IconTile>
          }
          title="21 Oct 2026 at 10:42"
          detail="3 saved files"
          help="Saved before the theme changed"
          trailing={<Button size="sm">Restore</Button>}
        />
        <ListRow leading={<AppIcon />} title="Disabled row" onSelect={() => {}} disabled />
      </SettingsSection>
      <SettingsCard className="overflow-hidden">
        <ListGroupHeader title="Focus and move windows" count={2} />
        <ListRow
          size="compact"
          title="Focus the window to the left"
          trailing={
            <>
              <KbdGroup variant="key" keys={["⌃", "⌥", "←"]} label="Control Option Left" />
              <IconButton label="Show command details">
                <Plus aria-hidden />
              </IconButton>
            </>
          }
        />
        <ListRow
          size="compact"
          titleMono
          title="yabai -m window --swap west"
          detail="Per app"
          trailing={
            <KbdGroup variant="key" keys={["⌃", "⌥", "⇧", "←"]} label="Control Option Shift Left" />
          }
        />
      </SettingsCard>
    </Group>
  );
}

function Tiles() {
  return (
    <Group title="Tiles">
      <OverviewActionCard
        title="Themes"
        detail="Wallpaper, colours and the whole look"
        icon={<Palette aria-hidden />}
        tint="purple"
      />
      <div className="grid grid-cols-[repeat(auto-fill,minmax(160px,1fr))] gap-3">
        <StatTile
          icon={<Command />}
          value="4/4"
          caption="Services"
          tint="green"
          emphasis
          detail={
            <div className="flex w-full gap-[3px]">
              {[0, 1, 2, 3].map((index) => (
                <span key={index} className="h-[5px] flex-1 rounded-[2px] bg-success/85" />
              ))}
            </div>
          }
        />
        <StatTile icon={<Clock />} value="12" caption="Backups" emphasis />
        <StatTile icon={<RotateCw />} value="3 min ago" caption="Last backup" tint="teal" />
        <StatTile
          icon={<Palette />}
          value="Catppuccin Mocha Extended Edition"
          caption="Active theme"
          tint="purple"
          detail={<span className="text-badge text-fg-meta">8 installed</span>}
        />
      </div>
      <Row>
        {tints.map((tint) => (
          <IconTile key={tint} tint={tint} size="lg">
            <Palette />
          </IconTile>
        ))}
      </Row>
      <Row>
        <IconTile size="sm">
          <Keyboard />
        </IconTile>
        <IconTile>
          <Keyboard />
        </IconTile>
        <IconTile size="lg">
          <Keyboard />
        </IconTile>
        <AppIcon />
        <AppIcon size={28} src="missing.png" />
      </Row>
    </Group>
  );
}

const artwork = (
  <div className="size-full bg-[linear-gradient(135deg,#1e1e2e,#45475a_45%,#89b4fa)]" />
);

function Heroes() {
  return (
    <Group title="Hero">
      <HeroCard
        artwork={artwork}
        eyebrow="Current theme"
        title="Catppuccin Mocha"
        subtitle="Your wallpaper, palette and finishing touches."
        badge={<StatusChip tone="success" label="Applied" live />}
        actions={<Button>Customise</Button>}
      />
      <HeroCard
        layout="overlay"
        artwork={artwork}
        eyebrow="Your desktop"
        title="Catppuccin Mocha"
        meta={
          <>
            <StatusChip tone="success" label="4/4 services" live />
            <StatusChip label="8 themes" />
          </>
        }
        actions={
          <Button>
            Browse themes
            <ArrowUpRight aria-hidden className="size-3.5" />
          </Button>
        }
      />
    </Group>
  );
}

function Empty() {
  return (
    <Group title="Empty states">
      <EmptyState
        icon={<Palette />}
        title="Your collection starts here"
        description="Import a theme folder to make it your own."
        action={<Button variant="primary">Import…</Button>}
      />
      <SettingsCard>
        <EmptyState
          variant="plain"
          icon={<Keyboard />}
          title="No shortcuts found"
          description="Try a different search or clear the filters."
        />
      </SettingsCard>
    </Group>
  );
}

function Code() {
  return (
    <Group title="Code">
      <CodeBlock code={report} label="Report to be sent" copyLabel="Copy report" maxHeight={140} />
      <CodeBlock
        variant="card"
        wrap={false}
        code="config-file = ?/Users/you/.config/macarchy/generated/ghostty.conf"
        label="Ghostty line"
        copyLabel="Copy line"
      />
      <SettingsCard>
        <ListRow
          leading={
            <IconTile tint="neutral">
              <Hammer />
            </IconTile>
          }
          title="Install everything"
          detail="Paste into Terminal. Needs Homebrew from brew.sh."
          trailing={
            <CopyButton
              text="brew install yabai skhd jq"
              label="Copy command"
              tooltip="brew install yabai skhd jq"
            />
          }
        />
      </SettingsCard>
    </Group>
  );
}

function Dialogs() {
  const [ruleOpen, setRuleOpen] = useState(false);
  const [app, setApp] = useState("");
  return (
    <Group title="Dialogs">
      <Row>
        <Dialog.Root open={ruleOpen} onOpenChange={setRuleOpen} dismissOnOutsidePress={false}>
          <Dialog.Trigger render={<Button />}>Add custom rule…</Dialog.Trigger>
          <Dialog.Popup>
            <Dialog.Header>
              <Dialog.Title help="Matching windows float outside the tiled layout. Nothing changes until you Save.">
                Add custom rule
              </Dialog.Title>
            </Dialog.Header>
            <Dialog.Body>
              <SettingsSection title="Match windows">
                <SettingRow title="Application" controlId="dialog-app">
                  <Input
                    id="dialog-app"
                    className="w-60"
                    placeholder="For example, Finder"
                    value={app}
                    onValueChange={setApp}
                  />
                </SettingRow>
                <SettingRow title="Window title" controlId="dialog-title">
                  <Input
                    id="dialog-title"
                    className="w-60"
                    variant="mono"
                    placeholder="All windows"
                  />
                </SettingRow>
              </SettingsSection>
              <InlineStatus tone="warning">Already floating: Finder</InlineStatus>
            </Dialog.Body>
            <Dialog.Footer>
              <Dialog.Close render={<Button />}>Cancel</Dialog.Close>
              <Button
                variant="primary"
                disabled={app.trim() === ""}
                onClick={() => setRuleOpen(false)}
              >
                Save
              </Button>
            </Dialog.Footer>
          </Dialog.Popup>
        </Dialog.Root>

        <Dialog.Root>
          <Dialog.Trigger render={<Button />}>Edit shortcut…</Dialog.Trigger>
          <Dialog.Popup size="default" className="h-[480px]">
            <Dialog.Header
              actions={
                <KbdGroup variant="key" keys={["⌃", "⌥", "↩"]} label="Control Option Return" />
              }
            >
              <Dialog.Title>Edit shortcut</Dialog.Title>
              <Dialog.Description>Open a terminal</Dialog.Description>
            </Dialog.Header>
            <Dialog.Body>
              <SettingsSection title="What it does">
                <SettingRow
                  title="Command"
                  detail={<span className="font-mono">open -na Ghostty</span>}
                />
              </SettingsSection>
            </Dialog.Body>
            <Dialog.Footer
              leading={
                <Button variant="ghost" className="text-danger">
                  Disable
                </Button>
              }
            >
              <Dialog.Close render={<Button />}>Cancel</Dialog.Close>
              <Button variant="primary">Save</Button>
            </Dialog.Footer>
          </Dialog.Popup>
        </Dialog.Root>

        <Dialog.Root>
          <Dialog.Trigger render={<Button />}>Theme (large)…</Dialog.Trigger>
          <Dialog.Popup size="lg" className="h-[560px]">
            <Dialog.Header
              actions={
                <Menu>
                  <MenuTrigger render={<IconButton label="More actions" />}>
                    <MoreHorizontal aria-hidden />
                  </MenuTrigger>
                  <MenuPopup align="end">
                    <MenuItem>Reset to shipped version</MenuItem>
                    <MenuItem>Export as a folder…</MenuItem>
                    <MenuItem>Show in Finder</MenuItem>
                  </MenuPopup>
                </Menu>
              }
            >
              <div className="flex items-center gap-3">
                <span className="size-8 rounded-control border border-hairline bg-[#89b4fa]" />
                <Dialog.Title>Catppuccin Mocha</Dialog.Title>
              </div>
            </Dialog.Header>
            <Dialog.Body>
              <div className="h-[200px] overflow-hidden rounded-card border border-hairline">
                {artwork}
              </div>
              <EmptyState variant="plain" icon={<AppWindow />} title="Long content scrolls here" />
            </Dialog.Body>
          </Dialog.Popup>
        </Dialog.Root>
      </Row>
      <Row>
        <ConfirmDialog
          trigger={<Button variant="danger">Restore original files…</Button>}
          tone="danger"
          title="Restore original files?"
          description="Puts back the configs you had before Macarchy, from ~/.config/macarchy/backups."
          confirmLabel="Restore"
          busyLabel="Restoring…"
          onConfirm={() => wait(1200)}
        />
        <ConfirmDialog
          trigger={<Button>Reset shortcuts (fails)…</Button>}
          title="Reset to default shortcuts?"
          description="Your current shortcuts are saved as a snapshot you can restore from Advanced."
          confirmLabel="Reset"
          busyLabel="Resetting…"
          onConfirm={() => wait(800).then(() => Promise.reject(new Error("skhd did not restart.")))}
        />
      </Row>
    </Group>
  );
}

function FilterMenu() {
  const [scope, setScope] = useState("all");
  const [modifiers, setModifiers] = useState<string[]>(["ctrl"]);
  return (
    <MenuPopup align="end">
      <MenuGroup>
        <MenuGroupLabel>Scope</MenuGroupLabel>
        <MenuRadioGroup value={scope} onValueChange={setScope}>
          <MenuRadioItem value="all">All shortcuts</MenuRadioItem>
          <MenuRadioItem value="global">Global</MenuRadioItem>
          <MenuRadioItem value="app">Per app</MenuRadioItem>
        </MenuRadioGroup>
      </MenuGroup>
      <MenuSeparator />
      <MenuGroup>
        <MenuGroupLabel>Modifiers</MenuGroupLabel>
        {[
          ["cmd", "⌘ Command"],
          ["alt", "⌥ Option"],
          ["ctrl", "⌃ Control"],
        ].map(([value = "", label]) => (
          <MenuCheckboxItem
            key={value}
            checked={modifiers.includes(value)}
            onCheckedChange={(checked) =>
              setModifiers((current) =>
                checked ? [...current, value] : current.filter((item) => item !== value),
              )
            }
          >
            {label}
          </MenuCheckboxItem>
        ))}
      </MenuGroup>
      <MenuSeparator />
      <MenuItem>Refresh shortcuts</MenuItem>
      <MenuItem>Reset to default shortcuts…</MenuItem>
    </MenuPopup>
  );
}

function Existing() {
  const [on, setOn] = useState(true);
  const [width, setWidth] = useState(6);
  const [shape, setShape] = useState<"system" | "square" | "rounded">("system");
  return (
    <Group title="Existing controls">
      <SettingsSection title="For reference" help="These predate the gallery.">
        <SettingRow title="Show borders">
          <Switch checked={on} onCheckedChange={setOn} aria-label="Show borders" />
        </SettingRow>
        <SettingRow title="Width">
          <ValueSlider
            label="Width"
            value={width}
            min={0}
            max={16}
            unit="pt"
            onValueChange={setWidth}
          />
        </SettingRow>
        <SettingRow title="Shape">
          <SegmentedControl
            label="Shape"
            value={shape}
            onValueChange={setShape}
            options={[
              { value: "system", label: "Default" },
              { value: "square", label: "Square" },
              { value: "rounded", label: "Rounded" },
            ]}
          />
        </SettingRow>
        <SettingRow title="Keys">
          <div className="flex items-center gap-3">
            <Kbd>⌘K</Kbd>
            <KbdGroup keys={["⌘", "K"]} label="Command K" />
            <KbdGroup variant="key" keys={["⌃", "⌥", "T"]} label="Control Option T" />
          </div>
        </SettingRow>
      </SettingsSection>
      <ActionBar status={<InlineStatus tone="success">Copied</InlineStatus>}>
        <Button>Copy report</Button>
        <Button variant="primary">Open on GitHub</Button>
      </ActionBar>
    </Group>
  );
}

const root = document.getElementById("root");
if (!root) throw new Error("The gallery has no #root");
createRoot(root).render(
  <StrictMode>
    <Gallery />
  </StrictMode>,
);
