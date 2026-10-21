import {
  Keyboard,
  LayoutGrid,
  type LucideIcon,
  PanelTop,
  RotateCw,
  Square,
  SquareDashed,
} from "lucide-react";
import { useState } from "react";

import type { AdvancedState, ServiceId } from "~/bridge/protocol";
import { StatusDot } from "~/components/charts/status-dot";
import { Card, CardHeader, CardRows, Row } from "~/components/ui/card";
import { ConfirmDialog } from "~/components/ui/confirm-dialog";
import { ActionCluster, IconButton } from "~/components/ui/icon-button";
import { IconTile } from "~/components/ui/icon-tile";

/** What each service is called, what it does and what stopping it turns off. */
export const serviceNames: Record<
  ServiceId,
  { title: string; tool: string; detail: string; stops: string; icon: LucideIcon }
> = {
  yabai: {
    title: "Window arrangement",
    tool: "yabai",
    detail: "Keeps your windows arranged across the desktop.",
    stops: "automatic window arrangement and your window rules",
    icon: LayoutGrid,
  },
  borders: {
    title: "Window outlines",
    tool: "borders",
    detail: "Highlights the window you are working in.",
    stops: "the outline around the active window",
    icon: SquareDashed,
  },
  sketchybar: {
    title: "Menu bar",
    tool: "sketchybar",
    detail: "Shows your custom menu bar and its widgets.",
    stops: "your custom menu bar and its widgets",
    icon: PanelTop,
  },
  skhd: {
    title: "Keyboard shortcuts",
    tool: "skhd",
    detail: "Responds to the keyboard shortcuts in your setup.",
    stops: "your keyboard shortcuts",
    icon: Keyboard,
  },
};

const stateWords = { running: "Running", stopped: "Stopped", unknown: "Unavailable" } as const;
const stateTone = { running: "ok", stopped: "warn", unknown: "idle" } as const;

/** Each desktop service with its state, a restart, and a stop that asks first. */
export function ServicesCard({
  services,
  busy,
  pending,
  onRestart,
  onStop,
}: {
  services: AdvancedState["services"];
  busy: boolean;
  /** The id of the service whose restart is running, for its spinner. */
  pending: string | null;
  onRestart: (id: ServiceId) => void;
  onStop: (id: ServiceId) => Promise<void>;
}) {
  // The target outlives the open flag so the dialog keeps its wording while it closes.
  const [stopTarget, setStopTarget] = useState<ServiceId>("yabai");
  const [stopOpen, setStopOpen] = useState(false);
  const target = serviceNames[stopTarget];
  return (
    <Card>
      <CardHeader
        title="Desktop services"
        help="Restart a service if its feature stops responding. Stop turns that feature off."
      />
      <CardRows>
        {services.map((service) => {
          const names = serviceNames[service.id];
          const Icon = names.icon;
          const name = names.title.toLowerCase();
          return (
            <Row
              key={service.id}
              title={names.title}
              description={<span className="font-mono text-mono">{names.tool}</span>}
              help={names.detail}
              leading={
                <IconTile variant="outline">
                  <Icon strokeWidth={1.75} />
                </IconTile>
              }
              control={
                <>
                  <span className="flex items-center gap-2 text-small text-fg-secondary">
                    <StatusDot tone={stateTone[service.state]} pulse={pending === service.id} />
                    {pending === service.id ? "Restarting…" : stateWords[service.state]}
                  </span>
                  <ActionCluster aria-label={`${names.title} actions`}>
                    <IconButton
                      size="sm"
                      label={`Restart ${name}`}
                      busy={pending === service.id}
                      disabled={busy}
                      onClick={() => onRestart(service.id)}
                    >
                      <RotateCw aria-hidden />
                    </IconButton>
                    <IconButton
                      size="sm"
                      tone="danger"
                      label={`Stop ${name}`}
                      disabled={busy || service.state !== "running"}
                      onClick={() => {
                        setStopTarget(service.id);
                        setStopOpen(true);
                      }}
                    >
                      <Square aria-hidden />
                    </IconButton>
                  </ActionCluster>
                </>
              }
            />
          );
        })}
      </CardRows>
      <ConfirmDialog
        open={stopOpen}
        onOpenChange={setStopOpen}
        title={`Stop ${target.title.toLowerCase()}?`}
        description={`Stopping ${stopTarget} turns off ${target.stops} until you restart it here.`}
        confirmLabel={`Stop ${stopTarget}`}
        busyLabel="Stopping…"
        tone="danger"
        onConfirm={() => onStop(stopTarget)}
      />
    </Card>
  );
}
