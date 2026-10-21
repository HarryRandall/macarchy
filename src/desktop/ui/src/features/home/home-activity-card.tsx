import { History } from "lucide-react";
import type { LogEntry } from "~/bridge/protocol";
import { Badge } from "~/components/ui/badge";
import { Card, SectionLabel } from "~/components/ui/card";
import { EmptyState } from "~/components/ui/empty-state";
import { KbdGroup } from "~/components/ui/kbd";
import { cn } from "~/lib/cn";
import { recentActivity } from "./home-activity";

/** The last few commands Macarchy ran, from the same log as the Logs panel. */
export function HomeActivity({
  entries,
  error,
  now,
}: {
  /** Null until the log has been read. */
  entries: readonly LogEntry[] | null;
  error: string | null;
  /** Seconds since the Unix epoch. */
  now: number;
}) {
  const items = entries ? recentActivity(entries, now) : [];
  return (
    <>
      <SectionLabel
        action={
          <span className="flex items-center gap-1.5 text-meta text-fg-tertiary">
            All activity in Logs
            <KbdGroup keys={["⇧", "⌘", "L"]} label="Shift Command L" variant="hint" />
          </span>
        }
      >
        Recent activity
      </SectionLabel>
      <Card className="mb-6">
        {items.length ? (
          <ul aria-label="Recent activity">
            {items.map((item) => (
              <li
                key={item.id}
                className="flex items-center gap-3 border-b border-hairline px-5 py-2.5 text-detail last:border-b-0"
              >
                <span className="w-[76px] shrink-0 text-fg-tertiary tabular-nums">{item.when}</span>
                <span
                  className={cn(
                    "min-w-0 shrink truncate font-mono text-mono",
                    item.ok ? "text-fg" : "text-danger",
                  )}
                >
                  {item.command}
                </span>
                <span className="min-w-0 flex-1 truncate text-fg-secondary">{item.detail}</span>
                {item.ok ? null : (
                  <Badge tone="danger" className="shrink-0">
                    Failed
                  </Badge>
                )}
              </li>
            ))}
          </ul>
        ) : entries || error ? (
          <EmptyState
            variant="plain"
            icon={<History />}
            title={error ? "Could not read the activity log" : "Nothing has run yet"}
            description={
              error ??
              "Changes you make here, and the commands they run, are listed as they happen."
            }
          />
        ) : (
          <p className="px-5 py-3 text-detail text-fg-tertiary">Reading the activity log…</p>
        )}
      </Card>
    </>
  );
}
