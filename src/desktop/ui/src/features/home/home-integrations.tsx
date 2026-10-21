import {
  AppWindow,
  ChevronRight,
  Command,
  LayoutPanelLeft,
  PanelTop,
  SquareDashed,
  SquareTerminal,
} from "lucide-react";
import type { ReactNode } from "react";
import type { HomeState, PaneId, ServiceId } from "~/bridge/protocol";
import { Badge } from "~/components/ui/badge";
import { Button } from "~/components/ui/button";
import { Card } from "~/components/ui/card";
import { Notice } from "~/components/ui/notice";
import { Switch } from "~/components/ui/switch";
import { Tooltip } from "~/components/ui/tooltip";
import type { ThemeLook } from "~/features/themes/theme-look";
import { cn } from "~/lib/cn";
import { floatingApps, menuBarSummary } from "./home-mock";
import type { Service } from "./services-store";

export const layoutNames: Record<HomeState["layout"], string> = {
  bsp: "Tiled",
  stack: "Stacked",
  float: "Freeform",
};

const paneTitles: Partial<Record<PaneId, string>> = {
  layout: "Layout",
  menuBar: "Menu Bar",
  borders: "Borders",
  shortcuts: "Shortcuts",
  rules: "Window Rules",
  themes: "Themes",
};

function ServiceBadge({ service, pending }: { service: Service; pending?: boolean }) {
  if (pending !== undefined) return <Badge>{pending ? "Starting…" : "Stopping…"}</Badge>;
  if (service.state === "running")
    return (
      <Badge tone="ok" dot>
        Running
      </Badge>
    );
  if (service.state === "stopped") return <Badge>Off</Badge>;
  return (
    <Badge tone="warn" dot>
      Unknown
    </Badge>
  );
}

function IntegrationRow({
  icon,
  name,
  summary,
  pane,
  service,
  pending,
  unavailable,
  onToggle,
  onOpen,
}: {
  icon: ReactNode;
  name: string;
  summary: ReactNode;
  pane: PaneId;
  /** The service behind the row, when it has one and the list has been read. */
  service?: Service;
  /** The state a start or stop is heading for. */
  pending?: boolean;
  /** Shows an on switch that cannot be turned off yet. */
  unavailable?: boolean;
  onToggle?: (service: Service, running: boolean) => void;
  onOpen(pane: PaneId): void;
}) {
  const off = service?.state === "stopped" && pending === undefined;
  return (
    <li
      data-integration={service?.id}
      className="flex items-start gap-3.5 border-b border-hairline px-5 py-3.5 last:border-b-0"
    >
      <div
        aria-hidden
        className={cn(
          "mt-0.5 grid size-8 shrink-0 place-items-center rounded-tile border border-hairline bg-side text-fg-secondary transition-opacity motion-reduce:transition-none [&_svg]:size-[15px]",
          off && "opacity-50",
        )}
      >
        {icon}
      </div>
      <div
        className={cn(
          "min-w-0 flex-1 transition-opacity motion-reduce:transition-none",
          off && "opacity-50",
        )}
      >
        <div className="flex flex-wrap items-center gap-2">
          <h3 className="text-emphasis font-medium text-fg">{name}</h3>
          {service ? <ServiceBadge service={service} pending={pending} /> : null}
        </div>
        <div className="mt-0.5 text-detail text-fg-secondary">{summary}</div>
      </div>
      <div className="flex shrink-0 items-center gap-2 pt-0.5">
        {service && onToggle ? (
          <Switch
            aria-label={`${name} running`}
            checked={pending ?? service.state === "running"}
            disabled={pending !== undefined}
            onCheckedChange={(running) => onToggle(service, running)}
          />
        ) : unavailable ? (
          <Tooltip content="Turning this off is not available yet">
            <Switch
              aria-label={`${name} enabled`}
              aria-disabled
              checked
              readOnly
              className="opacity-50"
            />
          </Tooltip>
        ) : null}
        <Button
          size="sm"
          variant="ghost"
          aria-label={`Open ${paneTitles[pane] ?? name}`}
          onClick={() => onOpen(pane)}
        >
          Open <ChevronRight aria-hidden />
        </Button>
      </div>
    </li>
  );
}

/** What Macarchy runs and sets up, each with its service switch and a way to its page. */
export function HomeIntegrations({
  state,
  look,
  services,
  pending,
  error,
  onToggle,
  onDismiss,
  onOpen,
}: {
  state: HomeState;
  look: ThemeLook | null;
  /** Null until the service list has been read. */
  services: readonly Service[] | null;
  pending: Partial<Record<ServiceId, boolean>>;
  error: string | null;
  onToggle(service: Service, running: boolean): void;
  onDismiss(): void;
  onOpen(pane: PaneId): void;
}) {
  const find = (id: ServiceId) => services?.find((service) => service.id === id);
  const named = (id: ServiceId, fallback: string) => find(id)?.name ?? fallback;
  const row = (id: ServiceId) => ({
    service: find(id),
    pending: pending[id],
    onToggle,
    onOpen,
  });

  return (
    <>
      {error ? (
        <Notice.Root variant="error" className="mb-3">
          <Notice.Header onDismiss={onDismiss}>
            <Notice.Title>Could not change that service</Notice.Title>
            <Notice.Description>{error}</Notice.Description>
          </Notice.Header>
        </Notice.Root>
      ) : null}
      <Card className="mb-6">
        <ul aria-label="Enabled">
          <IntegrationRow
            {...row("yabai")}
            icon={<LayoutPanelLeft />}
            name={named("yabai", "yabai")}
            pane="layout"
            summary={`${layoutNames[state.layout]} layout`}
          />
          <IntegrationRow
            {...row("sketchybar")}
            icon={<PanelTop />}
            name={named("sketchybar", "SketchyBar")}
            pane="menuBar"
            // Mock: the menu bar's position, height and items are not in the home summary.
            summary={`At the ${menuBarSummary.position}, ${menuBarSummary.height} pt tall, ${menuBarSummary.items} items`}
          />
          <IntegrationRow
            {...row("borders")}
            icon={<SquareDashed />}
            name={named("borders", "borders")}
            pane="borders"
            summary={
              look ? (
                <span className="inline-flex items-center gap-1.5">
                  Frames the focused window, theme accent
                  <span
                    aria-hidden
                    className="size-2.5 rounded-full ring-1 ring-black/15"
                    style={{ background: look.accent }}
                  />
                  <span className="font-mono text-mono">{look.accent}</span>
                </span>
              ) : (
                "A frame around the focused window"
              )
            }
          />
          <IntegrationRow
            {...row("skhd")}
            icon={<Command />}
            name={named("skhd", "skhd")}
            pane="shortcuts"
            summary={`${state.shortcutsCount} shortcut${state.shortcutsCount === 1 ? "" : "s"}`}
          />
          <IntegrationRow
            icon={<AppWindow />}
            name="Floating apps"
            pane="rules"
            onOpen={onOpen}
            // Mock: the floating apps live in the window rules, which Home does not read.
            summary={`${floatingApps.length} apps: ${floatingApps.join(", ")}`}
          />
          <IntegrationRow
            icon={<SquareTerminal />}
            name="Ghostty and Neovim"
            pane="themes"
            onOpen={onOpen}
            unavailable
            summary={
              look
                ? `${look.title} in Ghostty, ${look.nvim} in Neovim`
                : "Themed with the rest of your desktop"
            }
          />
        </ul>
      </Card>
    </>
  );
}
