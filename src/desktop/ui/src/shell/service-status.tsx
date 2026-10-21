import { Popover } from "@base-ui/react/popover";
import { Play, RotateCw, ScrollText, Square, Stethoscope } from "lucide-react";
import { useMemo, useRef, useState } from "react";

import type { ServiceId, ShellState } from "~/bridge/protocol";
import { ServiceRing } from "~/components/charts/service-ring";
import { Sparkline } from "~/components/charts/sparkline";
import { StatusDot } from "~/components/charts/status-dot";
import { Button } from "~/components/ui/button";
import { ConfirmDialog } from "~/components/ui/confirm-dialog";
import { IconButton } from "~/components/ui/icon-button";
import { Tooltip } from "~/components/ui/tooltip";
import { cn } from "~/lib/cn";

import { formatUptime, serviceUsage, usageTimes } from "./services-mock";
import type { ServiceAction } from "./shell-store";
import { titlebarControl } from "./use-titlebar-report";

type Service = ShellState["serviceList"][number];

/** What stopping each service turns off, for the confirmation. */
const stops: Record<ServiceId, string> = {
  yabai: "window tiling",
  borders: "window borders",
  sketchybar: "the menu bar",
  skhd: "keyboard shortcuts",
};

const columns = "grid grid-cols-[minmax(0,1fr)_128px_36px_auto] items-center gap-x-3";

function Stat({ label, value, unit }: { label: string; value: string; unit?: string }) {
  return (
    <div className="min-w-0 border-r border-hairline px-2.5 py-[7px]">
      <div className="truncate text-[11px] leading-[14px] text-fg-tertiary">{label}</div>
      <div className="mt-0.5 flex items-baseline gap-[3px] text-[13px] leading-[18px] font-semibold tracking-[-0.01em] text-fg tabular-nums">
        <span className="truncate">{value}</span>
        {unit ? <span className="text-[11px] font-medium text-fg-tertiary">{unit}</span> : null}
      </div>
    </div>
  );
}

function stateText(service: Service, pending: ServiceAction | undefined) {
  if (pending === "restart") return "Restarting…";
  if (pending === "start") return "Starting…";
  if (pending === "stop") return "Stopping…";
  // Mock: the host does not report uptime yet.
  if (service.state === "running") return `Up ${formatUptime(serviceUsage[service.id].uptime)}`;
  return service.state === "stopped" ? "Stopped" : "State unknown";
}

function dotTone(service: Service, pending: ServiceAction | undefined): "ok" | "warn" | "idle" {
  if (pending) return "idle";
  if (service.state === "running") return "ok";
  return service.state === "stopped" ? "warn" : "idle";
}

/**
 * The top bar's service summary and its panel: each desktop service with
 * its state, a restart, start or stop, and its recent CPU use.
 */
export function ServiceStatus({
  services,
  pending,
  restartingAll,
  open,
  onOpenChange,
  onRestart,
  onStop,
  onRestartAll,
  onHealth,
  onLogs,
}: {
  services: ShellState["serviceList"];
  pending: Partial<Record<ServiceId, ServiceAction>>;
  restartingAll: boolean;
  open: boolean;
  onOpenChange: (open: boolean) => void;
  /** Restarts a running service or starts a stopped one. */
  onRestart: (service: Service) => void;
  /** Rejects with the reason, which the confirmation shows. */
  onStop: (service: Service) => Promise<void>;
  onRestartAll: () => void;
  onHealth: () => void;
  onLogs: () => void;
}) {
  const trigger = useRef<HTMLButtonElement>(null);
  const [stopping, setStopping] = useState<Service | null>(null);
  // Mock: CPU samples are placeholders, so their clock labels are made when the panel opens.
  const times = useMemo(() => (open ? usageTimes(new Date()) : []), [open]);

  const running = services.filter((service) => service.state === "running").length;
  const total = services.length;
  const busy = restartingAll || services.some((service) => pending[service.id]);
  const segments = services.map((service): "on" | "off" | "busy" =>
    pending[service.id] || restartingAll ? "busy" : service.state === "running" ? "on" : "off",
  );
  const live = services.filter((service) => service.state === "running" && !pending[service.id]);
  // Mock: usage figures are placeholders until the host reports them.
  const cpuNow = live.reduce((sum, service) => sum + (serviceUsage[service.id].cpu.at(-1) ?? 0), 0);
  const memory = live.reduce((sum, service) => sum + serviceUsage[service.id].memory, 0);
  const longest = live.reduce<Service | undefined>(
    (best, service) =>
      !best || serviceUsage[service.id].uptime > serviceUsage[best.id].uptime ? service : best,
    undefined,
  );
  const summary = running === total ? "All running" : `${running} of ${total} running`;

  const close = (then: () => void) => {
    onOpenChange(false);
    then();
  };

  return (
    <>
      <Popover.Root open={open} onOpenChange={(next) => onOpenChange(next)}>
        <Popover.Trigger
          ref={trigger}
          {...titlebarControl}
          aria-label={`Services: ${running} of ${total} running`}
          className={cn(
            "flex h-7 items-center gap-2 rounded-[7px] px-[9px] text-[12.5px] font-medium whitespace-nowrap transition-colors focus-visible:ring-2 focus-visible:ring-accent focus-visible:outline-none",
            open
              ? "bg-muted text-fg ring-1 ring-hairline"
              : "text-fg-secondary hover:bg-hover hover:text-fg",
          )}
        >
          <ServiceRing segments={segments} size={16} label={summary} />
          <span aria-hidden className="tabular-nums">
            {running}/{total}
          </span>
        </Popover.Trigger>
        <Popover.Portal>
          <Popover.Positioner
            side="bottom"
            align="end"
            sideOffset={6}
            collisionPadding={8}
            className="z-50 outline-none"
          >
            <Popover.Popup className="w-[436px] max-w-[calc(100vw-16px)] origin-(--transform-origin) overflow-hidden rounded-[12px] border border-hairline bg-popover text-fg shadow-pop outline-none transition-[opacity,scale] duration-120 ease-out data-ending-style:opacity-0 data-starting-style:scale-98 data-starting-style:opacity-0">
              <div className="border-b border-hairline px-3.5 py-3">
                <div className="flex items-center gap-3">
                  <span className="relative grid shrink-0 place-items-center">
                    <ServiceRing segments={segments} size={40} label={summary} />
                    <span
                      aria-hidden
                      className="absolute text-[12px] leading-none font-semibold text-fg tabular-nums"
                    >
                      {running}
                      <span className="font-medium text-fg-tertiary">/{total}</span>
                    </span>
                  </span>
                  <div className="min-w-0 flex-1">
                    <Popover.Title className="text-[13px] leading-[18px] font-semibold tracking-[-0.01em] text-fg">
                      Services
                    </Popover.Title>
                    <p className="mt-0.5 truncate text-[12px] leading-[17px] text-fg-secondary">
                      {summary}
                    </p>
                  </div>
                  <div className="flex shrink-0 items-center gap-1.5">
                    <Button size="sm" onClick={() => close(onHealth)}>
                      <Stethoscope aria-hidden size={13} strokeWidth={1.75} />
                      Setup health
                    </Button>
                    <Tooltip content="Show logs" keys="⇧⌘L" describe={false}>
                      <Button size="sm" onClick={() => close(onLogs)}>
                        <ScrollText aria-hidden size={13} strokeWidth={1.75} />
                        Logs
                      </Button>
                    </Tooltip>
                  </div>
                </div>

                <div className="mt-3 grid grid-cols-[repeat(3,minmax(0,1fr))_auto] items-stretch rounded-[9px] border border-hairline bg-side">
                  <Stat label="CPU now" value={cpuNow.toFixed(1)} unit="%" />
                  <Stat label="Memory" value={String(memory)} unit="MB" />
                  <Stat
                    label="Longest uptime"
                    value={longest ? formatUptime(serviceUsage[longest.id].uptime) : "None"}
                  />
                  <div className="grid place-items-center px-2">
                    <Tooltip content="Restart running services and start stopped ones">
                      <Button size="sm" disabled={busy} onClick={onRestartAll}>
                        <RotateCw
                          aria-hidden
                          size={12}
                          strokeWidth={2}
                          className={cn(restartingAll && "animate-spin")}
                        />
                        Restart all
                      </Button>
                    </Tooltip>
                  </div>
                </div>
              </div>

              <div
                aria-hidden
                className={cn(
                  columns,
                  "px-3.5 pt-2.5 pb-1 text-[11px] leading-[14px] font-medium text-fg-tertiary",
                )}
              >
                <span>Service</span>
                <span>CPU, last hour</span>
                <span className="text-right">Now</span>
                <span />
              </div>
              <ul aria-label="Services" className="px-1.5 pb-1.5">
                {services.map((service) => {
                  const action = pending[service.id];
                  const up = service.state === "running";
                  // Mock: CPU samples are placeholders until the host reports them.
                  const cpu = serviceUsage[service.id].cpu;
                  const now = up ? cpu.at(-1) : undefined;
                  return (
                    <li
                      key={service.id}
                      className={cn(columns, "rounded-[8px] px-2 py-1.5 transition-colors hover:bg-side")}
                    >
                      <div className="flex min-w-0 items-center gap-2.5">
                        <StatusDot tone={dotTone(service, action)} pulse={Boolean(action)} />
                        <div className="min-w-0">
                          <div className="truncate text-[13px] leading-[18px] font-medium text-fg">
                            {service.name}
                          </div>
                          <div
                            className={cn(
                              "truncate text-[11.5px] leading-4",
                              !up && !action ? "text-warning" : "text-fg-tertiary",
                            )}
                          >
                            {stateText(service, action)}
                          </div>
                        </div>
                      </div>
                      <Sparkline
                        label={`${service.name} CPU over the last hour`}
                        values={cpu}
                        times={times}
                        live={up}
                        width={128}
                        height={34}
                        format={(value) => `${value}%`}
                      />
                      <span className="text-right text-[12px] text-fg-secondary tabular-nums">
                        {typeof now === "number" ? `${now}%` : <span className="text-fg-tertiary">Off</span>}
                      </span>
                      <div className="flex items-center justify-end gap-0.5">
                        <Button
                          size="sm"
                          disabled={Boolean(action) || restartingAll}
                          onClick={() => onRestart(service)}
                        >
                          {up ? (
                            <RotateCw
                              aria-hidden
                              size={12}
                              strokeWidth={2}
                              className={cn(action === "restart" && "animate-spin")}
                            />
                          ) : (
                            <Play aria-hidden size={12} strokeWidth={2} />
                          )}
                          {up ? "Restart" : "Start"}
                          <span className="sr-only"> {service.name}</span>
                        </Button>
                        {up ? (
                          <IconButton
                            label={`Stop ${service.name}`}
                            tone="danger"
                            size="sm"
                            disabled={Boolean(action) || restartingAll}
                            onClick={() => {
                              onOpenChange(false);
                              setStopping(service);
                            }}
                          >
                            <Square aria-hidden />
                          </IconButton>
                        ) : null}
                      </div>
                    </li>
                  );
                })}
              </ul>
            </Popover.Popup>
          </Popover.Positioner>
        </Popover.Portal>
      </Popover.Root>
      {stopping ? (
        <ConfirmDialog
          open
          onOpenChange={(next) => {
            if (next) return;
            setStopping(null);
            requestAnimationFrame(() => trigger.current?.focus());
          }}
          title={`Stop ${stopping.name}?`}
          description={`Stopping ${stopping.name} turns off ${stops[stopping.id]} until you restart it.`}
          confirmLabel={`Stop ${stopping.name}`}
          busyLabel="Stopping…"
          tone="danger"
          onConfirm={() => onStop(stopping)}
        />
      ) : null}
    </>
  );
}
