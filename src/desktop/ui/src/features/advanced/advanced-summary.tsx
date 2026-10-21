import { Activity, Archive, Clock, HardDrive, type LucideIcon, Palette } from "lucide-react";
import type { ReactNode } from "react";

import type { AdvancedState } from "~/bridge/protocol";
import { Card } from "~/components/ui/card";
import { PreviewTag } from "~/components/ui/preview-tag";
import { Stat } from "~/components/ui/stat";
import { cn } from "~/lib/cn";

import { formatAgo, formatChange, formatSize, plural } from "./advanced-format";
import { configSizes } from "./advanced-mock";
import { serviceNames } from "./advanced-services";

function Label({ icon: Icon, children }: { icon: LucideIcon; children: ReactNode }) {
  return (
    <span className="flex min-w-0 items-center gap-1.5">
      <Icon aria-hidden size={13} strokeWidth={1.75} className="shrink-0 text-fg-tertiary" />
      {children}
    </span>
  );
}

/**
 * The page's figures at a glance. The grid's gap shows the hairline behind
 * it, so the dividers follow the cells as they wrap from five columns to two.
 */
export function AdvancedSummary({ state, now }: { state: AdvancedState; now: number }) {
  const running = state.services.filter((service) => service.state === "running");
  const down = state.services.filter((service) => service.state !== "running");
  const latest = state.snapshots[0];
  // Mock: the host does not report the configuration's size yet.
  const size = configSizes.at(-1) ?? 0;
  const growth = formatChange(size - (configSizes[0] ?? 0));
  const cell = "bg-card";
  return (
    <Card className="overflow-hidden">
      <dl className="grid grid-cols-2 gap-px bg-hairline @min-[700px]:grid-cols-5">
        <Stat
          className={cell}
          label={<Label icon={Activity}>Services</Label>}
          value={`${running.length} of ${state.services.length} running`}
          detail={
            down.length ? (
              <span className="text-warning">
                {down.map((service) => serviceNames[service.id].tool).join(", ")}{" "}
                {down.length === 1 ? "is" : "are"} not running
              </span>
            ) : (
              "All running"
            )
          }
        />
        <Stat
          className={cell}
          label={<Label icon={Archive}>Backups</Label>}
          value={String(state.snapshots.length)}
          detail="Kept for the last 20 changes"
        />
        <Stat
          className={cell}
          label={<Label icon={Clock}>Last backup</Label>}
          value={latest ? formatAgo(latest.created, now) : "None"}
          detail={latest ? latest.reason || plural(latest.files, "file") : "None yet"}
        />
        <Stat
          className={cell}
          label={<Label icon={Palette}>Theme</Label>}
          value={state.theme}
          detail={`${plural(state.installedThemes, "theme")} installed`}
        />
        <Stat
          className={cn(cell, "col-span-2 @min-[700px]:col-span-1")}
          label={
            <Label icon={HardDrive}>
              Config size
              <PreviewTag />
            </Label>
          }
          value={formatSize(size)}
          detail={`${growth} in 30 days`}
        />
      </dl>
    </Card>
  );
}
