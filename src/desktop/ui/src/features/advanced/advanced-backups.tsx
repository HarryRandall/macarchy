import { Archive, CalendarDays, Check, RotateCcw, X } from "lucide-react";
import { useState } from "react";

import type { AdvancedState } from "~/bridge/protocol";
import { BarChart } from "~/components/charts/bar-chart";
import { TipNote, TipRow, TipTitle } from "~/components/charts/chart-tooltip";
import { Badge } from "~/components/ui/badge";
import { Button } from "~/components/ui/button";
import { Card, CardBody, CardHeader } from "~/components/ui/card";
import { ConfirmDialog } from "~/components/ui/confirm-dialog";
import { EmptyState } from "~/components/ui/empty-state";
import { focusRingInset } from "~/components/ui/focus-ring";
import { IconButton } from "~/components/ui/icon-button";
import { IconTile } from "~/components/ui/icon-tile";
import { cn } from "~/lib/cn";

import {
  backupsByDay,
  dayOf,
  formatDay,
  formatShortDay,
  formatWhen,
  plural,
} from "./advanced-format";

type Snapshot = AdvancedState["snapshots"][number];

/** Rows shown before "Show all", so the card stays short. */
const preview = 5;

function fullDate(created: number) {
  return new Date(created).toLocaleString("en-GB", { dateStyle: "medium", timeStyle: "short" });
}

function BackupRow({
  backup,
  now,
  busy,
  restored,
  onRestore,
}: {
  backup: Snapshot;
  now: number;
  busy: boolean;
  restored: boolean;
  onRestore: () => Promise<void>;
}) {
  return (
    <li className="group flex h-[52px] items-center gap-3 border-t border-hairline px-5 transition-colors hover:bg-side">
      <IconTile variant="outline" className="size-[26px]">
        <Archive strokeWidth={1.75} />
      </IconTile>
      <div className="min-w-0 flex-1">
        <div className="truncate text-body text-fg">{backup.reason || "Backup"}</div>
        <div className="text-meta text-fg-tertiary tabular-nums">
          {plural(backup.files, "saved file")}
        </div>
      </div>
      <span className="shrink-0 text-detail text-fg-secondary tabular-nums">
        {formatWhen(backup.created, now)}
      </span>
      <div className="flex w-[100px] shrink-0 items-center justify-end">
        {restored ? (
          <Badge tone="ok">
            <Check aria-hidden size={11} />
            Restored
          </Badge>
        ) : (
          <div className="opacity-0 transition-opacity group-focus-within:opacity-100 group-hover:opacity-100">
            <ConfirmDialog
              title="Restore a previous setup?"
              description="Restore replaces current settings after backing them up. Changes create backups automatically."
              confirmLabel="Restore"
              busyLabel="Restoring…"
              tone="danger"
              onConfirm={onRestore}
              trigger={
                <Button
                  size="sm"
                  disabled={busy}
                  aria-label={`Restore backup from ${fullDate(backup.created)}`}
                >
                  <RotateCcw aria-hidden />
                  Restore
                </Button>
              }
            />
          </div>
        )}
      </div>
    </li>
  );
}

/**
 * Snapshots per day over the last 30 days, and the list of them. Choosing a
 * day in the chart filters the list to it.
 */
export function BackupsCard({
  snapshots,
  now,
  busy,
  onRestore,
}: {
  snapshots: AdvancedState["snapshots"];
  now: number;
  busy: boolean;
  onRestore: (id: string) => Promise<void>;
}) {
  const [day, setDay] = useState<number | null>(null);
  const [showAll, setShowAll] = useState(false);
  const [restored, setRestored] = useState<string | null>(null);
  const days = backupsByDay(snapshots, now);
  const starts = days.map((entry) => entry.start);
  const labels = starts.map(formatDay);
  const chosen = day === null ? undefined : days[day];
  const listed = chosen
    ? snapshots.filter((backup) => dayOf(starts, backup.created) === day)
    : snapshots;
  const shown = chosen || showAll ? listed : listed.slice(0, preview);
  const totalFiles = snapshots.reduce((sum, backup) => sum + backup.files, 0);
  const ticks = [
    ...[1, 8, 15, 22].map((index) => ({ index, label: formatShortDay(starts[index] ?? 0) })),
    { index: days.length - 1, label: "Today" },
  ];

  const choose = (next: number | null) => {
    setDay(next);
    setShowAll(false);
  };

  return (
    <Card className="overflow-hidden">
      <CardHeader
        title="Backups"
        help="Every change saves a backup first. Restore replaces current settings after backing them up."
        action={
          <span className="text-small text-fg-tertiary tabular-nums">
            {plural(snapshots.length, "snapshot")}, {plural(totalFiles, "file")}
          </span>
        }
      />
      <CardBody>
        <BarChart
          label="Snapshots per day over the last 30 days"
          values={days.map((entry) => entry.count)}
          labels={labels}
          xTicks={ticks}
          emphasiseLast
          selected={day}
          onSelect={choose}
          axisWidth={24}
          // oxlint-disable-next-line react/no-unstable-nested-components -- a render prop called per bar, not a component.
          tooltip={(index) => {
            const entry = days[index];
            return (
              <>
                <TipTitle>{labels[index]}</TipTitle>
                <TipRow label="Snapshots" value={entry?.count ?? 0} />
                <TipRow label="Files saved" value={entry?.files ? entry.files : "None"} />
                <TipNote>
                  {day === index ? "Click to clear the filter" : "Click to show this day"}
                </TipNote>
              </>
            );
          }}
        />
      </CardBody>
      {chosen && day !== null ? (
        <div className="flex items-center gap-2 border-t border-hairline bg-side px-5 py-2">
          <span className="text-small text-fg-secondary">Showing</span>
          <span className="inline-flex h-6 items-center gap-1.5 rounded-small border border-hairline bg-card pr-0.5 pl-2 text-small font-medium text-fg shadow-card">
            <CalendarDays aria-hidden size={12} className="text-fg-tertiary" />
            {labels[day]}
            <IconButton
              size="sm"
              label="Clear day filter"
              className="size-5"
              onClick={() => choose(null)}
            >
              <X aria-hidden />
            </IconButton>
          </span>
          <span className="ml-auto text-small text-fg-tertiary tabular-nums">
            {plural(listed.length, "backup")}
            {listed.length ? `, ${plural(chosen.files, "file")}` : ""}
          </span>
        </div>
      ) : null}
      {listed.length === 0 ? (
        <div className="border-t border-hairline p-4">
          {chosen ? (
            <EmptyState
              icon={<CalendarDays aria-hidden />}
              title={`No backups on ${labels[day ?? 0]}`}
            />
          ) : (
            <EmptyState
              icon={<Archive aria-hidden />}
              title="No backups yet"
              description="Your saved setups appear here when settings change."
            />
          )}
        </div>
      ) : (
        <ul aria-label={chosen ? `Backups on ${labels[day ?? 0]}` : "Backups"}>
          {shown.map((backup) => (
            <BackupRow
              key={backup.id}
              backup={backup}
              now={now}
              busy={busy}
              restored={restored === backup.id}
              onRestore={async () => {
                await onRestore(backup.id);
                setRestored(backup.id);
              }}
            />
          ))}
        </ul>
      )}
      {!chosen && snapshots.length > preview ? (
        <button
          type="button"
          onClick={() => setShowAll((current) => !current)}
          className={cn(
            "flex h-9 w-full items-center justify-center border-t border-hairline text-detail font-medium text-fg-secondary transition-colors hover:bg-hover hover:text-fg",
            focusRingInset,
          )}
        >
          {showAll ? "Show fewer" : `Show all ${snapshots.length} backups`}
        </button>
      ) : null}
    </Card>
  );
}
