import "~/styles/index.css";

import {
  AppWindow,
  ArrowLeft,
  ArrowUpRight,
  ChevronRight,
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
  ScrollText,
  Search,
  Square,
  Stethoscope,
} from "lucide-react";
import { type ReactNode, StrictMode, useId, useLayoutEffect, useMemo, useState } from "react";
import { createRoot } from "react-dom/client";

import { BarChart } from "~/components/charts/bar-chart";
import { BarList } from "~/components/charts/bar-list";
import { HeatScale, HeatStrip } from "~/components/charts/heat-strip";
import { LineChart } from "~/components/charts/line-chart";
import { rampLevel } from "~/components/charts/scale";
import { ServiceRing } from "~/components/charts/service-ring";
import { Sparkline } from "~/components/charts/sparkline";
import { StatusDot } from "~/components/charts/status-dot";
import { type PageSearch, PageChromeContext, usePageSearch } from "~/components/layout/page-chrome";
import { PageHeader } from "~/components/layout/page-header";
import { SectionHeading } from "~/components/layout/section-heading";
import { SettingRow } from "~/components/layout/setting-row";
import {
  CardContent,
  SectionAction,
  SettingsCard,
  SettingsSection,
} from "~/components/layout/settings-section";
import { ActionBar } from "~/components/ui/action-bar";
import { AppIcon } from "~/components/ui/app-icon";
import { Badge, CountBadge } from "~/components/ui/badge";
import { Button } from "~/components/ui/button";
import { Card, CardBody, CardHeader, CardRows, Row, SectionLabel } from "~/components/ui/card";
import { Chip } from "~/components/ui/chip";
import { ChoiceCard } from "~/components/ui/choice-card";
import { CodeBlock } from "~/components/ui/code-block";
import { ColourField } from "~/components/ui/colour-field";
import { ColourWell } from "~/components/ui/colour-well";
import { ConfirmDialog } from "~/components/ui/confirm-dialog";
import { CopyButton } from "~/components/ui/copy-button";
import { Dialog } from "~/components/ui/dialog";
import { EmptyState } from "~/components/ui/empty-state";
import { HelpTooltip } from "~/components/ui/help-tooltip";
import { HeroCard } from "~/components/ui/hero-card";
import { HexValue } from "~/components/ui/hex-value";
import { ActionCluster, IconButton } from "~/components/ui/icon-button";
import { IconTile, type Tint } from "~/components/ui/icon-tile";
import { ImageFill } from "~/components/ui/image-fill";
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
import { Notice } from "~/components/ui/notice";
import { NumberField, Stepper } from "~/components/ui/number-field";
import { OverviewActionCard } from "~/components/ui/overview-action-card";
import { PreviewTag } from "~/components/ui/preview-tag";
import { RadioGroup } from "~/components/ui/radio-group";
import { SearchField } from "~/components/ui/search-field";
import { SegmentedControl } from "~/components/ui/segmented-control";
import { Select } from "~/components/ui/select";
import { Slider } from "~/components/ui/slider";
import { Spinner } from "~/components/ui/spinner";
import { Stat, StatStrip } from "~/components/ui/stat";
import { StatTile } from "~/components/ui/stat-tile";
import { StatusChip } from "~/components/ui/status-chip";
import { Swatches } from "~/components/ui/swatches";
import { Switch } from "~/components/ui/switch";
import { TabPanel, Tabs } from "~/components/ui/tabs";
import { Input, TextareaField, TextField } from "~/components/ui/text-field";
import { Tooltip, TooltipProvider } from "~/components/ui/tooltip";
import { TruncatedText } from "~/components/ui/truncated-text";
import { ValueSlider } from "~/components/ui/value-slider";

type Appearance = "system" | "light" | "dark";

/** The active theme's own colour, which only previews and swatches of the theme use. */
const themeAccents = [
  { value: "#89b4fa", label: "Catppuccin blue" },
  { value: "#f2f2ee", label: "Near white (Lumon)" },
  { value: "#1e1e5a", label: "Near black" },
  { value: "#ff9f0a", label: "Orange" },
] as const;

const tints: Tint[] = [
  "accent",
  "blue",
  "purple",
  "pink",
  "teal",
  "orange",
  "green",
  "red",
  "danger",
  "neutral",
];

const terminal = [
  "#45475a",
  "#f38ba8",
  "#a6e3a1",
  "#f9e2af",
  "#89b4fa",
  "#f5c2e7",
  "#94e2d5",
  "#bac2de",
];

const report = `### Environment
- Mac: Mac15,3, arm64
- macOS: 26.1
- Macarchy: 0.9.0 (412)

### Checks
- [x] yabai 7.1.25 is installed
- [x] skhd is running
- [ ] SketchyBar is not running: launchctl kickstart -k gui/$UID/homebrew.mxcl.sketchybar
- [x] borders is running`;

const wait = (ms: number) => new Promise<void>((resolve) => setTimeout(resolve, ms));

/** Deterministic noise in [0, 1), so the sample series look plausible and never change. */
function noise(seed: number, index: number) {
  const value = Math.sin(seed * 12.9898 + index * 78.233) * 43758.5453;
  return value - Math.floor(value);
}

const pad = (value: number) => String(value).padStart(2, "0");
const sampleTimes = Array.from({ length: 31 }, (_, index) => {
  const minutes = 17 * 60 + 44 - (30 - index) * 2;
  return `${pad(Math.floor(minutes / 60))}:${pad(minutes % 60)}`;
});
const cpu = sampleTimes.map(
  (_, index) => Math.round((0.9 + 1.3 * noise(1, index) + (index === 29 ? 4.4 : 0)) * 10) / 10,
);
const cpuRecent = cpu.map((value, index) => (index < 24 ? null : value));
const percent = (value: number) => `${value}%`;

const days = Array.from({ length: 30 }, (_, index) => `${index + 1} Oct`);
const configSize = days.map((_, index) =>
  index === 12 ? null : 40 + Math.round(index * 0.6 + 4 * noise(2, index)),
);
const backups = days.map((_, index) => Math.floor(noise(3, index) * 4));
const checkRuns = days.map((_, index) => [
  6 + Math.floor(noise(4, index) * 3),
  noise(5, index) > 0.7 ? 1 : 0,
  noise(6, index) > 0.85 ? 1 : 0,
]);
const themeChanges = days.map((_, index) => Math.floor(noise(7, index) ** 2 * 6));
const mostChanges = Math.max(...themeChanges);
const focusTime = [
  { key: "ghostty", label: "Ghostty", value: 192 },
  { key: "zed", label: "Zed", value: 141 },
  { key: "safari", label: "Safari", value: 88 },
  { key: "slack", label: "Slack", value: 34 },
  { key: "finder", label: "Finder", value: 9 },
];
const hours = (minutes: number) =>
  minutes >= 60 ? `${Math.floor(minutes / 60)}h ${minutes % 60}m` : `${minutes}m`;

/** Each type role in index.css with a sample of what it sets; full class strings so Tailwind sees them. */
const typeRoles = [
  ["hero-title", "text-hero-title", "Catppuccin Mocha"],
  ["stat", "text-stat", "4/4 running"],
  ["title", "text-title", "Add custom rule"],
  ["card-title", "text-card-title", "Tiling"],
  ["emphasis", "text-emphasis font-medium", "No shortcuts found"],
  ["body", "text-body", "Space between tiled windows"],
  ["detail", "text-detail text-fg-secondary", "A description under a card title"],
  ["small", "text-small text-fg-secondary", "A row's hint or a field label"],
  ["meta", "text-meta text-fg-secondary", "Badges, chips, tooltips"],
  ["caption", "text-caption text-fg-tertiary", "Stat labels and column headings"],
  ["axis", "text-axis text-fg-tertiary tabular-nums", "1 Oct  15 Oct  Today"],
  ["tag", "text-tag text-preview", "Preview"],
  ["label", "text-label uppercase text-fg-tertiary", "Other themes"],
  ["mono", "font-mono text-mono text-fg-secondary", "yabai -m window --focus west"],
  ["mono-value", "font-mono text-mono-value uppercase", "#89b4fa"],
] as const;

function Gallery() {
  const [appearance, setAppearance] = useState<Appearance>("system");
  const [themeAccent, setThemeAccent] = useState<string>(themeAccents[0].value);

  useLayoutEffect(() => {
    const root = document.documentElement;
    if (appearance === "system") delete root.dataset.theme;
    else root.dataset.theme = appearance;
  }, [appearance]);

  useLayoutEffect(() => {
    document.documentElement.style.setProperty("--theme-accent", themeAccent);
  }, [themeAccent]);

  return (
    <TooltipProvider>
      <div className="h-full overflow-y-auto bg-page [scrollbar-gutter:stable]">
        <header className="sticky top-0 z-40 flex flex-wrap items-center gap-4 border-b border-hairline bg-bar/90 px-6 py-3 backdrop-blur-xl">
          <h1 className="text-title text-fg">Components</h1>
          <a href="options/" className="text-meta text-accent-text hover:underline">
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
            label="Theme accent"
            value={themeAccent}
            options={themeAccents.map((option) => ({ ...option }))}
            onValueChange={setThemeAccent}
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

function Line({ children }: { children: ReactNode }) {
  return <div className="flex flex-wrap items-center gap-3">{children}</div>;
}

/**
 * Each column stands in for the window: a top bar that the page's actions
 * and search are portalled into, as the shell's is.
 */
function Showcase({ appearance }: { appearance: string }) {
  const [slot, setSlot] = useState<HTMLElement | null>(null);
  const [search, setSearch] = useState<PageSearch | null>(null);
  const chrome = useMemo(() => ({ actionsSlot: slot, setSearch }), [slot]);
  return (
    <PageChromeContext value={chrome}>
      <div className="mx-auto flex max-w-[720px] flex-col gap-8">
        <TopBar title={appearance} search={search} onSlot={setSlot} />
        <PageHeader
          title={`${appearance} components`}
          actions={
            <>
              <Button size="sm">
                <RotateCw aria-hidden />
                Check again
              </Button>
              <Menu>
                <MenuTrigger render={<IconButton label="More actions" />}>
                  <MoreHorizontal aria-hidden />
                </MenuTrigger>
                <FilterMenu />
              </Menu>
            </>
          }
        />
        <SearchProbe />
        <Typography />
        <Buttons />
        <Tooltips />
        <Status />
        <Cards />
        <TabsDemo />
        <Fields />
        <Colours />
        <Lists />
        <Tiles />
        <Heroes />
        <Empty />
        <Code />
        <Dialogs />
        <Charts />
      </div>
    </PageChromeContext>
  );
}

function TopBar({
  title,
  search,
  onSlot,
}: {
  title: string;
  search: PageSearch | null;
  onSlot: (element: HTMLDivElement | null) => void;
}) {
  return (
    <div className="flex h-12 min-w-0 items-center gap-4 rounded-card border border-hairline bg-bar px-4 shadow-card">
      <nav aria-label="Breadcrumb" className="flex min-w-0 flex-1 basis-0 items-center gap-1.5">
        <span className="truncate text-body text-fg-tertiary">Gallery</span>
        <ChevronRight aria-hidden className="size-3 shrink-0 text-fg-tertiary" />
        <span aria-current="page" className="truncate text-body font-medium text-fg">
          {title}
        </span>
        <PreviewTag size="md" />
      </nav>
      {search ? (
        <SearchField
          className="w-52"
          label={search.placeholder}
          value={search.value}
          onValueChange={search.onChange}
          hint={<Kbd variant="hint">⌘K</Kbd>}
        />
      ) : null}
      <div ref={onSlot} className="flex flex-1 basis-0 items-center justify-end gap-1.5" />
    </div>
  );
}

function SearchProbe() {
  const [query] = usePageSearch("Search the gallery");
  return (
    <p className="text-small text-fg-secondary">
      {query
        ? `This page would filter for "${query}".`
        : "The top bar's field is this page's own search while the page is open; the actions beside it come from PageHeader."}
    </p>
  );
}

function Typography() {
  return (
    <Group title="Typography">
      <Card>
        <CardRows>
          {typeRoles.map(([role, className, sample]) => (
            <div key={role} className="flex min-w-0 items-baseline gap-4 px-5 py-2.5">
              <span className="w-24 shrink-0 font-mono text-mono text-fg-tertiary">{role}</span>
              <span className={`min-w-0 truncate text-fg ${className}`}>{sample}</span>
            </div>
          ))}
        </CardRows>
      </Card>
    </Group>
  );
}

function Buttons() {
  const [busy, setBusy] = useState(false);
  const run = () => {
    setBusy(true);
    void wait(1500).then(() => setBusy(false));
  };
  return (
    <Group title="Buttons">
      <Line>
        <Button variant="primary">Primary</Button>
        <Button>Secondary</Button>
        <Button variant="accent">Accent</Button>
        <Button variant="ghost">Ghost</Button>
        <Button variant="danger">Danger</Button>
        <Button disabled>Disabled</Button>
        <Button busy={busy} onClick={run}>
          {busy ? "Restarting..." : "Busy on click"}
        </Button>
      </Line>
      <Line>
        <Button size="xs">Extra small</Button>
        <Button size="sm">
          <RotateCw aria-hidden />
          Small
        </Button>
        <Button>Medium</Button>
        <Button variant="primary" size="lg">
          Set up Macarchy
        </Button>
        <Button variant="ghost" size="inline">
          Inline
        </Button>
      </Line>
      <Line>
        <Button variant="field" className="w-56 gap-2">
          <Search aria-hidden className="size-3.5" />
          <span className="flex-1 text-left">Search settings...</span>
          <Kbd variant="hint">⌘K</Kbd>
        </Button>
        <Button variant="pill" size="sm">
          <ServiceRing segments={["on", "on", "on", "off"]} label="3 of 4 services running" />
          3/4
        </Button>
        <Button variant="pill">
          <ScrollText aria-hidden />
          Logs
        </Button>
        <Button variant="translucent" size="icon-md" aria-label="Back">
          <ArrowLeft aria-hidden strokeWidth={2.5} />
        </Button>
      </Line>
      <Line>
        <IconButton label="Edit rule for Finder">
          <Pencil aria-hidden />
        </IconButton>
        <IconButton label="Remove rule for Finder" tone="danger">
          <Minus aria-hidden />
        </IconButton>
        <IconButton label="Restart" size="sm">
          <RotateCw aria-hidden />
        </IconButton>
        <IconButton label="Show sidebar" keys="⌘\" pressed>
          <LayoutGrid aria-hidden />
        </IconButton>
        <IconButton label="Open the setup checks" size="md">
          <Stethoscope aria-hidden />
        </IconButton>
        <IconButton label="Restarting" busy>
          <RotateCw aria-hidden />
        </IconButton>
        <IconButton label="Disabled" disabled>
          <Square aria-hidden />
        </IconButton>
        <ActionCluster aria-label="Window arrangement">
          <IconButton label="Restart window arrangement" busy={busy} onClick={run}>
            <RotateCw aria-hidden />
          </IconButton>
          <IconButton label="Stop window arrangement" tone="danger">
            <Square aria-hidden className="fill-current" />
          </IconButton>
        </ActionCluster>
      </Line>
      <Line>
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
      </Line>
    </Group>
  );
}

function Tooltips() {
  return (
    <Group title="Tooltips">
      <Line>
        <Tooltip content="Show logs" keys="⇧⌘L">
          <Button size="sm">With keys</Button>
        </Tooltip>
        {(["top", "right", "bottom", "left"] as const).map((side) => (
          <Tooltip key={side} content={`Opens ${side}`} side={side} describe={false}>
            <Button size="sm" variant="ghost">
              {side}
            </Button>
          </Tooltip>
        ))}
        <Tooltip content="Disabled tooltips never open" disabled>
          <Button size="sm">Disabled tooltip</Button>
        </Tooltip>
        <HelpTooltip text="Help text is the button's description, so its name stays short." />
      </Line>
      <div className="flex min-w-0 items-center gap-3">
        <span className="shrink-0 text-small text-fg-secondary">Truncated name:</span>
        <TruncatedText
          className="w-44 text-body font-medium text-fg"
          text="Catppuccin Mocha Extended Edition for long evenings"
        />
        <TruncatedText className="w-44 text-body text-fg-secondary" text="Fits, no tooltip" />
      </div>
    </Group>
  );
}

function Status() {
  return (
    <Group title="Status">
      <Line>
        <StatusChip tone="success" label="Running" live />
        <StatusChip tone="neutral" label="Stopped" />
        <StatusChip tone="warning" label="Needs repair" />
        <StatusChip tone="danger" label="Failed" />
        <StatusChip tone="success" label="Everything is working" variant="plain" />
      </Line>
      <Line>
        <Badge>Neutral</Badge>
        <Badge tone="ok">Current</Badge>
        <Badge tone="warn">Modified</Badge>
        <Badge tone="accent">Active</Badge>
        <Badge tone="danger">Missing</Badge>
        <Badge tone="ok" dot>
          Running
        </Badge>
        <Badge tone="warn" dot>
          2 to review
        </Badge>
        <CountBadge count={7} />
        <CountBadge count={128} tone="accent" />
        <PreviewTag />
        <PreviewTag size="md" />
      </Line>
      <Line>
        <Chip>Battery</Chip>
        <Chip colour="#f38ba8">Workspace 2</Chip>
        <Chip icon={<Clock aria-hidden />}>Clock</Chip>
        <Chip className="max-w-32">A chip with a very long name</Chip>
      </Line>
      <Line>
        {(["ok", "warn", "error", "idle"] as const).map((tone) => (
          <span key={tone} className="flex items-center gap-2 text-small text-fg-secondary">
            <StatusDot tone={tone} />
            {tone}
          </span>
        ))}
        <span className="flex items-center gap-2 text-small text-fg-secondary">
          <StatusDot tone="idle" pulse />
          busy
        </span>
      </Line>
      <div className="flex flex-col gap-1.5">
        <InlineStatus tone="success">Copied</InlineStatus>
        <InlineStatus tone="warning">Already used by Spaces</InlineStatus>
        <InlineStatus tone="danger">
          Could not save the rule: the title is not a valid pattern.
        </InlineStatus>
        <InlineStatus icon={false}>Checked 10:42</InlineStatus>
      </div>
      <Notice.Root variant="info">
        <Notice.Title>Information</Notice.Title>
        <Notice.Description>Status that needs a title or an action.</Notice.Description>
      </Notice.Root>
      <Notice.Root variant="warning">
        <Notice.Title>skhd is not running</Notice.Title>
        <Notice.Description>Shortcuts do nothing until it starts.</Notice.Description>
        <Notice.Actions>
          <Button size="sm">Start skhd</Button>
        </Notice.Actions>
      </Notice.Root>
      <Notice.Root variant="error">
        <Notice.Title>Could not read your layout</Notice.Title>
        <Notice.Description>The yabai config has a syntax error on line 12.</Notice.Description>
      </Notice.Root>
    </Group>
  );
}

function Cards() {
  const [layout, setLayout] = useState<"bsp" | "stack" | "float">("bsp");
  const [gap, setGap] = useState(8);
  const [padding, setPadding] = useState(6);
  const [workspaces, setWorkspaces] = useState(6);
  const [balance, setBalance] = useState(true);
  const [colour, setColour] = useState("#6366f1");
  return (
    <Group title="Cards">
      <div>
        <SectionLabel
          action={
            <Button size="sm" variant="ghost">
              Edit
            </Button>
          }
        >
          Section label
        </SectionLabel>
        <Card>
          <CardHeader
            icon={
              <IconTile tint="blue">
                <LayoutGrid />
              </IconTile>
            }
            title="Tiling"
            description="How windows share the screen."
            help="These settings are written to yabai and applied at once."
            action={<SectionAction>Reset</SectionAction>}
          />
          <CardRows>
            <Row
              title="Layout"
              control={
                <SegmentedControl
                  size="sm"
                  label="Layout"
                  value={layout}
                  onValueChange={setLayout}
                  options={[
                    { value: "bsp", label: "Tiled" },
                    { value: "stack", label: "Stacked" },
                    { value: "float", label: "Floating" },
                  ]}
                />
              }
            />
            <Row
              title="Window gap"
              description="Space between tiled windows"
              control={
                <div className="flex items-center gap-3">
                  <Slider
                    aria-label="Window gap"
                    className="w-40"
                    value={gap}
                    min={0}
                    max={32}
                    onValueChange={setGap}
                  />
                  <NumberField
                    aria-label="Window gap in pixels"
                    value={gap}
                    min={0}
                    max={32}
                    onValueChange={setGap}
                  />
                </div>
              }
            />
            <Row title="Screen padding">
              <ValueSlider
                label="Screen padding"
                value={padding}
                min={0}
                max={24}
                unit="px"
                onValueChange={setPadding}
              />
            </Row>
            <Row
              title="Workspaces"
              control={
                <Stepper
                  label="Workspaces"
                  value={workspaces}
                  min={1}
                  max={10}
                  onValueChange={setWorkspaces}
                />
              }
            />
            <Row
              title="Auto balance"
              description="Equal window sizes"
              control={
                <Switch checked={balance} onCheckedChange={setBalance} aria-label="Auto balance" />
              }
            />
            <Row
              title="Active colour"
              control={
                <ColourField
                  label="Active colour"
                  value={colour}
                  presets={["#6366f1", "#89b4fa", "#a6e3a1", "#f38ba8"]}
                  onValueChange={setColour}
                />
              }
            />
            <Row
              title="Excluded apps"
              description="Borders are not drawn around these."
              control={
                <Button size="sm">
                  <Plus aria-hidden />
                  Add app
                </Button>
              }
            >
              <div className="flex flex-wrap gap-1.5">
                {["Finder", "System Settings", "Calculator", "TablePlus"].map((app) => (
                  <Chip key={app}>{app}</Chip>
                ))}
              </div>
            </Row>
            <Row
              title="HiDPI"
              description="Needs a restart of borders"
              control={
                <Switch checked={false} onCheckedChange={() => {}} aria-label="HiDPI" disabled />
              }
            />
          </CardRows>
        </Card>
      </div>
      <Card>
        <CardHeader title="Card body" action={<Badge tone="accent">Free content</Badge>} />
        <CardBody>
          <p className="text-small text-fg-secondary">
            A chart, a form or a code block, padded to the rows' text column.
          </p>
        </CardBody>
      </Card>
      <SettingsSection
        title="Settings section (earlier API)"
        help="SettingsSection and SettingRow now draw a Card and Rows."
        action={<SectionAction icon={null}>Clear all</SectionAction>}
      >
        <SettingRow title="Show borders" detail="Around the focused window">
          <Switch checked onCheckedChange={() => {}} aria-label="Show borders" />
        </SettingRow>
        <SettingRow title="Keys">
          <div className="flex items-center gap-3">
            <Kbd>⌘K</Kbd>
            <KbdGroup keys={["⌘", "K"]} label="Command K" />
            <KbdGroup variant="key" keys={["⌃", "⌥", "T"]} label="Control Option T" />
          </div>
        </SettingRow>
      </SettingsSection>
      <SettingsSection title="Disabled section" disabled>
        <SettingRow title="Everything in here is dimmed" />
      </SettingsSection>
    </Group>
  );
}

function TabsDemo() {
  const [tab, setTab] = useState<"installed" | "discover" | "updates">("installed");
  const id = useId();
  return (
    <Group title="Tabs">
      <div>
        <Tabs
          id={id}
          label="Plugin views"
          value={tab}
          onChange={setTab}
          className="mb-4"
          tabs={[
            { id: "installed", label: "Installed", count: 6 },
            { id: "discover", label: "Discover" },
            { id: "updates", label: "Updates", count: 0, disabled: true },
          ]}
        />
        <TabPanel tabs={id} value={tab}>
          <p className="text-small text-fg-secondary">
            {tab === "installed"
              ? "Six plugins are installed. Arrow keys move between tabs; Updates is disabled."
              : "Plugins from the community, once the directory opens."}
          </p>
        </TabPanel>
      </div>
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
  const [layout, setLayout] = useState("bsp");
  const [opacity, setOpacity] = useState(0.9);
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
        <SettingRow title="Layout">
          <Select
            label="Layout"
            value={layout}
            onValueChange={setLayout}
            options={[
              { value: "bsp", label: "Tiled" },
              { value: "stack", label: "Stacked" },
              { value: "float", label: "Floating" },
            ]}
          />
        </SettingRow>
        <SettingRow title="Opacity" detail="Two decimals; anything else snaps back">
          <NumberField
            aria-label="Opacity"
            className="w-14"
            value={opacity}
            min={0}
            max={1}
            decimals={2}
            onValueChange={setOpacity}
          />
        </SettingRow>
      </SettingsCard>
      <Line>
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
      </Line>
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
  const [hex, setHex] = useState("#89b4fa");
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
        <SettingRow title="Colour field" detail="Swatch, hex and presets">
          <ColourField
            label="Accent colour"
            value={hex}
            presets={["#89b4fa", "#f38ba8", "#a6e3a1", "#f9e2af"]}
            onValueChange={setHex}
          />
        </SettingRow>
        <SettingRow title="Colour field, disabled">
          <ColourField label="Inactive colour" value="#45475a" onValueChange={() => {}} disabled />
        </SettingRow>
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
        <SettingRow title="Firefox accent" detail="#rrggbb: no opacity strip">
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
        <SettingRow title="Palette" detail="Swatches, then read-only hex values">
          <div className="flex flex-col items-end gap-2">
            <Swatches colours={terminal} label="Catppuccin terminal colours" />
            <div className="flex gap-3">
              <HexValue value="#1e1e2e" />
              <HexValue value="#cdd6f4" />
              <HexValue value="#89b4fa" swatch={false} />
            </div>
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
          leading={<AppIcon name="Finder" size={28} />}
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
          leading={<AppIcon name="Calculator" size={28} />}
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
          leading={<AppIcon size={28} />}
          title="System Settings"
          detail="Windows matching ^General$"
          trailing={<Badge>Read only</Badge>}
        />
        <ListRow
          leading={
            <IconTile variant="outline">
              <Clock />
            </IconTile>
          }
          title="21 Oct 2026 at 10:42"
          detail="3 saved files"
          help="Saved before the theme changed"
          trailing={<Button size="sm">Restore</Button>}
        />
        <ListRow
          leading={<AppIcon name="Disabled" size={28} />}
          title="Disabled row"
          onSelect={() => {}}
          disabled
        />
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
      <div className="grid grid-cols-[repeat(auto-fit,minmax(220px,1fr))] gap-3">
        <OverviewActionCard
          title="Themes"
          detail="Wallpaper, colours and the whole look"
          icon={<Palette aria-hidden />}
          tint="purple"
        />
        <OverviewActionCard
          title="Plugins"
          detail="Widgets for your menu bar"
          icon={<Command aria-hidden />}
          tint="teal"
          trailing={<PreviewTag />}
        />
      </div>
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
          detail="8 installed"
        />
      </div>
      <Card>
        <StatStrip>
          <Stat label="Runs" value="412" detail="Last 30 days" />
          <Stat label="Passed" value="97" unit="%" />
          <Stat label="Average" value="84" unit="ms" />
        </StatStrip>
      </Card>
      <Card className="bg-side">
        <StatStrip>
          <Stat size="sm" label="CPU now" value="3.1" unit="%" />
          <Stat size="sm" label="Memory" value="212" unit="MB" />
          <Stat size="sm" label="Longest uptime" value="2d 4h" />
        </StatStrip>
      </Card>
      <Line>
        {tints.map((tint) => (
          <IconTile key={tint} tint={tint} size="lg">
            <Palette />
          </IconTile>
        ))}
      </Line>
      <Line>
        <IconTile size="sm">
          <Keyboard />
        </IconTile>
        <IconTile>
          <Keyboard />
        </IconTile>
        <IconTile size="lg">
          <Keyboard />
        </IconTile>
        <IconTile variant="outline">
          <Keyboard />
        </IconTile>
        <AppIcon />
        <AppIcon size={28} src="missing.png" />
        <AppIcon size={28} name="Ghostty" />
        <AppIcon size={28} name="Zed" />
        <AppIcon size={28} name="1Password" />
      </Line>
    </Group>
  );
}

const artwork = <ImageFill src="missing.jpg" from="#1e1e2e" to="#89b4fa" />;

function Heroes() {
  const [layout, setLayout] = useState<"bsp" | "stack">("bsp");
  return (
    <Group title="Hero and artwork">
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
      <div className="grid grid-cols-2 gap-3">
        {(
          [
            ["bsp", "Tiled", "Windows split the screen"],
            ["stack", "Stacked", "One window at a time"],
          ] as const
        ).map(([value, label, detail]) => (
          <ChoiceCard
            key={value}
            label={label}
            detail={detail}
            selected={layout === value}
            onClick={() => setLayout(value)}
            preview={<ImageFill from="#11111b" to={value === "bsp" ? "#a6e3a1" : "#f5c2e7"} />}
          />
        ))}
      </div>
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
        action={<Button variant="primary">Import...</Button>}
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
            <IconTile variant="outline">
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
      <ActionBar status={<InlineStatus tone="success">Copied</InlineStatus>}>
        <Button>Copy report</Button>
        <Button variant="primary">Open on GitHub</Button>
      </ActionBar>
    </Group>
  );
}

function Dialogs() {
  const [ruleOpen, setRuleOpen] = useState(false);
  const [app, setApp] = useState("");
  return (
    <Group title="Dialogs and menus">
      <Line>
        <Dialog.Root open={ruleOpen} onOpenChange={setRuleOpen} dismissOnOutsidePress={false}>
          <Dialog.Trigger render={<Button />}>Add custom rule...</Dialog.Trigger>
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
          <Dialog.Trigger render={<Button />}>Edit shortcut...</Dialog.Trigger>
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
          <Dialog.Trigger render={<Button />}>Theme (large)...</Dialog.Trigger>
          <Dialog.Popup size="lg" className="h-[560px]">
            <Dialog.Header
              actions={
                <Menu>
                  <MenuTrigger render={<IconButton label="More actions" />}>
                    <MoreHorizontal aria-hidden />
                  </MenuTrigger>
                  <MenuPopup align="end">
                    <MenuItem>Reset to shipped version</MenuItem>
                    <MenuItem>Export as a folder...</MenuItem>
                    <MenuItem>Show in Finder</MenuItem>
                  </MenuPopup>
                </Menu>
              }
            >
              <div className="flex items-center gap-3">
                <span className="size-8 rounded-control border border-hairline bg-theme-accent" />
                <Dialog.Title>Catppuccin Mocha</Dialog.Title>
              </div>
            </Dialog.Header>
            <Dialog.Body>
              <div className="relative h-[200px] overflow-hidden rounded-card border border-hairline">
                {artwork}
              </div>
              <EmptyState variant="plain" icon={<AppWindow />} title="Long content scrolls here" />
            </Dialog.Body>
          </Dialog.Popup>
        </Dialog.Root>

        <Menu>
          <MenuTrigger render={<Button />}>Filter menu</MenuTrigger>
          <FilterMenu />
        </Menu>
      </Line>
      <Line>
        <ConfirmDialog
          trigger={<Button variant="danger">Restore original files...</Button>}
          tone="danger"
          title="Restore original files?"
          description="Puts back the configs you had before Macarchy, from ~/.config/macarchy/backups."
          confirmLabel="Restore"
          busyLabel="Restoring..."
          onConfirm={() => wait(1200)}
        />
        <ConfirmDialog
          trigger={<Button>Reset shortcuts (fails)...</Button>}
          title="Reset to default shortcuts?"
          description="Your current shortcuts are saved as a snapshot you can restore from Advanced."
          confirmLabel="Reset"
          busyLabel="Resetting..."
          onConfirm={() => wait(800).then(() => Promise.reject(new Error("skhd did not restart.")))}
        />
      </Line>
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
      <MenuItem>Reset to default shortcuts...</MenuItem>
    </MenuPopup>
  );
}

function Charts() {
  const [day, setDay] = useState<number | null>(null);
  const [app, setApp] = useState<string | null>(null);
  return (
    <Group title="Charts">
      <Card>
        <CardHeader
          title="Services"
          action={
            <ServiceRing size={40} segments={["on", "on", "busy", "off"]} label="2 of 4 running">
              <span className="text-small leading-none font-semibold tabular-nums">
                2<span className="font-medium text-fg-tertiary">/4</span>
              </span>
            </ServiceRing>
          }
        />
        <CardRows>
          <Row
            leading={<StatusDot tone="ok" />}
            title="yabai"
            description="Up 2d 4h"
            control={
              <Sparkline
                label="yabai CPU over the last hour"
                values={cpu}
                times={sampleTimes}
                format={percent}
              />
            }
          />
          <Row
            leading={<StatusDot tone="ok" />}
            title="sketchybar"
            description="Restarted just now"
            control={
              <Sparkline
                label="sketchybar CPU over the last hour"
                values={cpuRecent}
                times={sampleTimes}
                format={percent}
              />
            }
          />
          <Row
            leading={<StatusDot tone="idle" pulse />}
            title="borders"
            description="Restarting..."
            control={
              <Sparkline
                label="borders CPU over the last hour"
                values={cpu}
                times={sampleTimes}
                live={false}
              />
            }
          />
          <Row
            leading={<StatusDot tone="warn" />}
            title="skhd"
            description="Stopped"
            control={
              <Sparkline
                label="skhd CPU over the last hour"
                values={[]}
                times={sampleTimes}
                live={false}
              />
            }
          />
        </CardRows>
      </Card>
      <Line>
        <ServiceRing segments={["on", "on", "on", "on"]} label="4 of 4 services running" />
        <ServiceRing segments={["on", "busy", "on", "off"]} label="2 of 4 running, 1 starting" />
        <ServiceRing segments={["off", "off", "off", "off"]} label="No services running" />
        <ServiceRing size={28} segments={["on", "on", "off"]} label="2 of 3 services running" />
      </Line>
      <Card>
        <CardHeader title="Config size" description="Line chart with a gap on 13 Oct" />
        <CardBody>
          <LineChart
            label="Config size over the last 30 days"
            values={configSize}
            labels={days}
            domain="fit"
            format={(value) => `${value} KB`}
            valueLabel="Size"
          />
        </CardBody>
      </Card>
      <Card>
        <CardHeader
          title="Check results"
          description={day === null ? "Choose a day to filter" : `Showing ${days[day]}`}
          action={
            day === null ? null : (
              <Button size="sm" variant="ghost" onClick={() => setDay(null)}>
                Clear
              </Button>
            )
          }
        />
        <CardBody>
          <BarChart
            label="Check results per day over the last 30 days"
            values={checkRuns}
            labels={days}
            series={[
              { label: "Passed", tone: "ok" },
              { label: "Warned", tone: "warn" },
              { label: "Failed", tone: "danger" },
            ]}
            selected={day}
            onSelect={setDay}
          />
        </CardBody>
      </Card>
      <Card>
        <CardHeader title="Backups" description="Single series, latest emphasised" />
        <CardBody>
          <BarChart
            label="Backups per day over the last 30 days"
            values={backups}
            labels={days}
            emphasiseLast
            format={(value) => `${value} ${value === 1 ? "backup" : "backups"}`}
          />
        </CardBody>
      </Card>
      <Card>
        <CardHeader title="Focus time" description="Bar list, inline and stacked" />
        <CardBody className="flex flex-col gap-4">
          <BarList
            label="Focus time by app today"
            items={focusTime}
            format={hours}
            selected={app}
            onSelect={(key) => setApp((current) => (current === key ? null : key))}
          />
          <BarList
            label="Files written per tool"
            layout="stacked"
            items={[
              { key: "yabai", label: "yabai", value: 4, detail: "files", tone: "accent" },
              { key: "sketchybar", label: "sketchybar", value: 12, detail: "files", tone: "ok" },
              { key: "ghostty", label: "Ghostty", value: 2, detail: "files", tone: "muted" },
            ]}
          />
        </CardBody>
      </Card>
      <Card>
        <CardHeader title="Theme changes" action={<HeatScale />} />
        <CardBody>
          <HeatStrip
            label="Theme changes per day over the last 30 days"
            cells={themeChanges.map((count, index) => ({
              label: days[index] ?? "",
              value: `${count} ${count === 1 ? "change" : "changes"}`,
              level: rampLevel(count, mostChanges, 4),
            }))}
          />
          <div className="mt-4">
            <HeatStrip
              label="Daily result of the borders check"
              cellHeight={16}
              startLabel="14 days ago"
              cells={days.slice(-14).map((label, index) => {
                const failed = noise(8, index) > 0.85;
                return {
                  label,
                  value: failed ? "Failed" : "Passed",
                  tone: failed ? ("danger" as const) : ("ok" as const),
                };
              })}
            />
          </div>
        </CardBody>
      </Card>
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
