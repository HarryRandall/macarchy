import { ChevronRight, Clock, RotateCw } from "lucide-react";
import { type ReactNode, useId } from "react";

import { HeatStrip } from "~/components/charts/heat-strip";
import { LineChart } from "~/components/charts/line-chart";
import { Button } from "~/components/ui/button";
import { CodeBlock } from "~/components/ui/code-block";
import { Tooltip } from "~/components/ui/tooltip";
import { cn } from "~/lib/cn";

import type { Check } from "./check-list";
import { dailyResults, type Result, runTimes } from "./health-mock";
import { type IconState, resultStatus, resultText, StatusIcon, statusText } from "./status-icon";

export interface Days {
  short: string;
  long: string;
}

const tone: Record<Result, "ok" | "warn" | "danger"> = { pass: "ok", warn: "warn", fail: "danger" };
const pastTense: Record<Result, string> = { pass: "passed", warn: "warned", fail: "failed" };
const ms = (value: number) => `${value.toLocaleString("en-GB")} ms`;

/**
 * A check's row. The whole row is one button that shows or hides its
 * detail; `action` sits above it, so a Copy or Open press does not toggle.
 */
export function CheckRow({
  check,
  state,
  expanded,
  onToggle,
  compact = false,
  trailing,
  action,
  children,
}: {
  check: Check;
  state: IconState;
  expanded: boolean;
  onToggle: () => void;
  /** One line, for a check in the passed list. */
  compact?: boolean;
  /** Quiet text before the chevron: when it ran. */
  trailing?: ReactNode;
  action?: ReactNode;
  children?: ReactNode;
}) {
  const detailId = useId();
  return (
    <div data-row="" data-check-id={check.id} className="min-w-0">
      <div
        className={cn(
          "relative flex min-w-0 items-center gap-4 px-5 transition-colors duration-150 hover:bg-hover",
          "has-[[data-row-primary]:focus-visible]:ring-2 has-[[data-row-primary]:focus-visible]:ring-accent has-[[data-row-primary]:focus-visible]:ring-inset",
          compact ? "py-2.5" : "py-3",
        )}
      >
        <button
          type="button"
          data-row-primary
          aria-expanded={expanded}
          aria-controls={expanded ? detailId : undefined}
          onClick={onToggle}
          // The box stretches over the row, under the action, so the row is one target.
          className={cn(
            "flex min-w-0 flex-1 gap-3 text-left outline-none after:absolute after:inset-0",
            compact ? "items-center" : "items-start",
          )}
        >
          <span className={cn(!compact && "mt-0.5")}>
            <StatusIcon state={state} />
          </span>
          {compact ? (
            <span className="flex min-w-0 items-baseline gap-3">
              <span className="shrink-0 text-body font-medium text-fg">{check.title}</span>
              <span className="truncate text-small text-fg-secondary">{check.detail}</span>
            </span>
          ) : (
            <span className="min-w-0">
              <span className="flex min-w-0 items-baseline gap-2">
                <span className="truncate text-body font-medium text-fg">{check.title}</span>
                <span className="shrink-0 text-meta text-fg-tertiary">{check.group}</span>
              </span>
              <span className="mt-0.5 block truncate text-small text-fg-secondary">
                <span className="font-medium text-fg">
                  {state === "checking" ? "Checking" : statusText[check.status]}
                </span>
                <span className="text-fg-tertiary"> · </span>
                {check.detail}
              </span>
            </span>
          )}
        </button>
        {trailing ? (
          <span className="hidden shrink-0 text-meta text-fg-tertiary tabular-nums @[520px]:inline">
            {trailing}
          </span>
        ) : null}
        {action ? <div className="relative z-10 shrink-0">{action}</div> : null}
        <ChevronRight
          aria-hidden
          size={14}
          className={cn(
            "shrink-0 text-fg-tertiary transition-transform duration-150 motion-reduce:transition-none",
            expanded && "rotate-90",
          )}
        />
      </div>
      {expanded ? <div id={detailId}>{children}</div> : null}
    </div>
  );
}

function StripSummary({ results }: { results: readonly Result[] }) {
  const counts = (["pass", "warn", "fail"] as const)
    .map((result) => ({ result, count: results.filter((each) => each === result).length }))
    .filter((entry) => entry.count > 0);
  return (
    <span className="flex items-center gap-2.5 text-caption text-fg-secondary tabular-nums">
      {counts.map(({ result, count }) => (
        <span key={result} className="flex items-center gap-1">
          <StatusIcon state={resultStatus[result]} size={11} />
          {count} {pastTense[result]}
        </span>
      ))}
    </span>
  );
}

/** What a check found, what to do in words and any command, and its fortnight. */
export function CheckDetail({
  check,
  days,
  checkedAt,
  busy,
  onRun,
}: {
  check: Check;
  days: readonly Days[];
  /** The time of the last run, "10:42". */
  checkedAt: string;
  busy: boolean;
  onRun: () => void;
}) {
  // Mock: Setup health keeps only the latest run; past days and timings are samples.
  const results = dailyResults(check.id, check.status);
  const times = runTimes(check.id);
  const average = Math.round(times.reduce((sum, value) => sum + value, 0) / times.length);
  return (
    <div className="space-y-3 pt-0.5 pr-5 pb-4 pl-12">
      {check.status !== "passed" && check.advice ? (
        <p className="text-small text-fg">{check.advice}</p>
      ) : null}
      {check.status !== "passed" && check.command ? (
        <CodeBlock code={check.command} label={`Command for ${check.title}`} />
      ) : null}
      <div className="grid grid-cols-1 gap-6 @[560px]:grid-cols-2">
        <div className="min-w-0">
          <div className="mb-1 flex flex-wrap items-center justify-between gap-2">
            <span className="text-meta font-medium text-fg-secondary">Last 14 days</span>
            <StripSummary results={results} />
          </div>
          <HeatStrip
            label={`Daily results of the ${check.title} check over the last 14 days`}
            cells={results.map((result, index) => ({
              label: days[index]?.long ?? "",
              value: resultText[result],
              tone: tone[result],
            }))}
            cellHeight={30}
            startLabel={days[0]?.short}
          />
        </div>
        <div className="min-w-0">
          <div className="mb-1 flex flex-wrap items-center justify-between gap-2">
            <span className="text-meta font-medium text-fg-secondary">Run time</span>
            <span className="text-caption text-fg-tertiary tabular-nums">
              Average {ms(average)}
            </span>
          </div>
          <LineChart
            label={`Run time of the ${check.title} check over the last 14 days`}
            values={times}
            labels={days.map((day) => day.long)}
            xTicks={[
              { index: 0, label: days[0]?.short ?? "" },
              { index: times.length - 1, label: "Today" },
            ]}
            height={84}
            format={ms}
            tickFormat={String}
            valueLabel="Run time"
          />
        </div>
      </div>
      <div className="flex flex-wrap items-center justify-between gap-3">
        <span className="flex items-center gap-1.5 text-small text-fg-secondary tabular-nums">
          <Clock aria-hidden size={12} className="text-fg-tertiary" />
          {/* Mock: the duration is a sample; the time is the real last run. */}
          Last ran {checkedAt}, took {ms(times.at(-1) ?? 0)}
        </span>
        <Tooltip content="Checks run together, so this runs every check.">
          <Button size="sm" variant="secondary" busy={busy} onClick={onRun}>
            {busy ? null : <RotateCw aria-hidden />}
            Check again
          </Button>
        </Tooltip>
      </div>
    </div>
  );
}
