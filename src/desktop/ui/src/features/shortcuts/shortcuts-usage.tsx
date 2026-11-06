import { useState } from "react";

import type { ShortcutBinding } from "~/bridge/protocol";
import { BarList } from "~/components/charts/bar-list";
import { LineChart } from "~/components/charts/line-chart";
import { Card } from "~/components/ui/card";
import { PreviewTag } from "~/components/ui/preview-tag";

import { dayLabels, mostUsed, pressesPerDay } from "./usage-mock";

const number = (value: number) => value.toLocaleString("en-GB");

/** Weekends are the 3rd, 4th, 10th, 11th and last of the 14 days in the sample. */
const weekends = new Set([2, 3, 9, 10, 13]);

/** Presses over a fortnight and the busiest actions. A click on one searches for it. */
export function UsageCard({
  bindings,
  onPick,
}: {
  bindings: readonly ShortcutBinding[];
  onPick: (name: string) => void;
}) {
  // Mock: the labels count back from when the page opened, to match the sample figures.
  const [labels] = useState(() => dayLabels(new Date(), pressesPerDay.length));
  // Mock: skhd does not count presses; these are sample figures.
  const total = pressesPerDay.reduce((sum, value) => sum + value, 0);
  const weekdays = pressesPerDay.filter((_, index) => !weekends.has(index));
  const typical = Math.round(weekdays.reduce((sum, value) => sum + value, 0) / weekdays.length);
  // Mock: per-action counts are generated from the real bindings.
  const top = mostUsed(bindings);
  const all = top.reduce((sum, item) => sum + item.count, 0);
  return (
    <Card aria-labelledby="shortcuts-usage" className="@container">
      <div className="flex items-start justify-between gap-4 px-5 pt-4">
        <div className="min-w-0">
          <h2 id="shortcuts-usage" className="flex items-center gap-2 text-card-title text-fg">
            Usage
            <PreviewTag />
          </h2>
          <p className="mt-0.5 text-detail text-fg-secondary">
            Last 14 days, about {typical} a weekday
          </p>
        </div>
        <div className="text-right">
          <div className="text-stat text-fg tabular-nums">{number(total)}</div>
          <div className="mt-1 text-caption text-fg-tertiary">presses</div>
        </div>
      </div>
      <div className="grid grid-cols-1 gap-7 px-5 pt-3 pb-4 @[560px]:grid-cols-[minmax(0,1fr)_240px]">
        <LineChart
          label="Shortcut presses per day over the last 14 days"
          values={pressesPerDay}
          labels={labels.map((label) => label.long)}
          xTicks={[
            { index: 0, label: labels[0]?.short ?? "" },
            { index: labels.length - 1, label: "Today" },
          ]}
          height={180}
          format={(value) => `${number(value)} presses`}
          tickFormat={(value) => (value >= 1000 ? `${value / 1000}k` : String(value))}
          valueLabel="Presses"
        />
        <div className="min-w-0">
          <h3 className="mb-1 px-1.5 text-meta font-medium text-fg-secondary">Most used</h3>
          <BarList
            label="Most used shortcuts"
            layout="stacked"
            items={top.map((item) => ({
              key: item.name,
              label: item.name,
              value: item.count,
              detail: `${Math.round((100 * item.count) / Math.max(1, all))}%`,
            }))}
            format={number}
            onSelect={onPick}
          />
        </div>
      </div>
    </Card>
  );
}
