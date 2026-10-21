import { RotateCw } from "lucide-react";

import { BarChart } from "~/components/charts/bar-chart";
import { Button } from "~/components/ui/button";
import { Card } from "~/components/ui/card";
import { PreviewTag } from "~/components/ui/preview-tag";
import { Stat, StatStrip } from "~/components/ui/stat";

import { type Check, headline } from "./check-list";
import type { Days } from "./check-rows";
import { historyDays, passRate } from "./health-mock";
import { StatusIcon } from "./status-icon";

const legend = [
  { status: "passed", label: "Passed" },
  { status: "warning", label: "Warnings" },
  { status: "failed", label: "Failed" },
] as const;

/** The latest run's verdict and counts over a fortnight of results. */
export function HealthSummaryCard({
  checks,
  problems,
  checkedAt,
  days,
  refreshing,
  onRun,
}: {
  checks: readonly Check[];
  problems: number;
  /** The time of the last run, "10:42". */
  checkedAt: string;
  days: readonly Days[];
  refreshing: boolean;
  onRun: () => void;
}) {
  const count = (status: Check["status"]) =>
    checks.filter((check) => check.status === status).length;
  // Mock: only today's results are real; earlier days are samples.
  const history = historyDays(checks);
  return (
    <Card aria-labelledby="health-headline" className="@container">
      <div className="flex flex-wrap items-start justify-between gap-x-4 gap-y-3 px-5 pt-4">
        <div className="min-w-0">
          <h2 id="health-headline" className="text-card-title text-fg">
            <span role="status">{headline(problems, refreshing)}</span>
          </h2>
          <p className="mt-0.5 text-detail text-fg-secondary">
            {checks.length} checks, last run at {checkedAt}
          </p>
        </div>
        <Button size="sm" variant="primary" busy={refreshing} onClick={onRun}>
          {refreshing ? null : <RotateCw aria-hidden />}
          {refreshing ? "Checking" : "Run all checks"}
        </Button>
      </div>
      <StatStrip className="mt-4 border-y border-hairline">
        {legend.map(({ status, label }) => (
          <Stat
            key={status}
            label={
              <span className="flex items-center gap-1.5">
                <StatusIcon state={status} size={12} />
                {label}
              </span>
            }
            value={count(status)}
          />
        ))}
        <Stat
          label={
            <span className="flex items-center gap-1.5">
              Pass rate, 14 days
              <PreviewTag />
            </span>
          }
          value={passRate(history)}
          unit="%"
        />
      </StatStrip>
      <div className="px-5 pt-3.5 pb-3">
        <div className="mb-2 flex flex-wrap items-center justify-between gap-3">
          <div className="flex items-baseline gap-2">
            <h3 className="text-body font-medium text-fg">Check history</h3>
            <span className="text-meta text-fg-tertiary">Last 14 days</span>
            <PreviewTag />
          </div>
          <div aria-hidden className="flex items-center gap-3 text-meta text-fg-secondary">
            {legend.map(({ status, label }) => (
              <span key={status} className="flex items-center gap-1.5">
                <StatusIcon state={status} size={12} />
                {label}
              </span>
            ))}
          </div>
        </div>
        <BarChart
          label="Check results per day over the last 14 days"
          values={history.map((day) => [day.pass, day.warn, day.fail])}
          labels={days.map((day) => day.long)}
          series={[
            { label: "Passed", tone: "ok" },
            { label: "Warnings", tone: "warn" },
            { label: "Failed", tone: "danger" },
          ]}
          xTicks={days.flatMap((day, index) =>
            (days.length - 1 - index) % 3 === 0 ? [{ index, label: day.short }] : [],
          )}
          height={150}
          maxBarWidth={28}
        />
      </div>
    </Card>
  );
}
