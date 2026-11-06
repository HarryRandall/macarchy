import type { ReactNode } from "react";

import { BarList } from "~/components/charts/bar-list";
import { TipRow, TipTitle } from "~/components/charts/chart-tooltip";
import { LineChart } from "~/components/charts/line-chart";
import { Card, CardBody, CardHeader } from "~/components/ui/card";
import { PreviewTag } from "~/components/ui/preview-tag";

import { formatChange, formatDay, formatShortDay, formatSize, plural } from "./advanced-format";
import { configSizes, toolFiles } from "./advanced-mock";

/** A figure at the trailing end of a chart card's title, with a quieter line under it. */
function HeaderFigure({ value, detail }: { value: string; detail: string }) {
  return (
    <div className="text-right">
      <div className="text-card-title text-fg tabular-nums">{value}</div>
      <div className="text-meta text-fg-tertiary tabular-nums">{detail}</div>
    </div>
  );
}

function ChartTitle({ children }: { children: ReactNode }) {
  return (
    <span className="flex items-center gap-2">
      {children}
      <PreviewTag />
    </span>
  );
}

/** The generated configuration's size over the last 30 days, and files per tool. */
export function AdvancedCharts({ starts }: { starts: readonly number[] }) {
  // Mock: sizes and per-tool counts are placeholders until the host reports them.
  const sizes = configSizes;
  const tools = toolFiles;
  const latest = sizes.at(-1) ?? 0;
  const growth = formatChange(latest - (sizes[0] ?? 0));
  const labels = starts.map((start, index) =>
    index === starts.length - 1 ? `Today, ${formatDay(start)}` : formatDay(start),
  );
  const middle = Math.floor((starts.length - 1) / 2);
  const ticks = [
    { index: 0, label: formatShortDay(starts[0] ?? 0) },
    { index: middle, label: formatShortDay(starts[middle] ?? 0) },
    { index: starts.length - 1, label: "Today" },
  ];
  const totalFiles = tools.reduce((sum, tool) => sum + tool.files, 0);

  return (
    <div className="grid grid-cols-1 gap-4 @min-[640px]:grid-cols-2">
      <Card>
        <CardHeader
          title={<ChartTitle>Config size, 30 days</ChartTitle>}
          action={<HeaderFigure value={formatSize(latest)} detail={growth} />}
        />
        <CardBody>
          <LineChart
            label="Config size over the last 30 days"
            values={sizes}
            labels={labels}
            xTicks={ticks}
            domain="fit"
            format={formatSize}
            tickFormat={(value) => `${value} KB`}
            axisWidth={44}
            // oxlint-disable-next-line react/no-unstable-nested-components -- a render prop called per point, not a component.
            tooltip={(index) => {
              const value = sizes[index] ?? 0;
              const before = sizes[index - 1];
              return (
                <>
                  <TipTitle>{labels[index]}</TipTitle>
                  <TipRow label="Config size" value={formatSize(value)} />
                  {before === undefined ? null : (
                    <TipRow label="Change" value={formatChange(value - before)} />
                  )}
                </>
              );
            }}
          />
        </CardBody>
      </Card>
      <Card>
        <CardHeader
          title={<ChartTitle>Generated files by tool</ChartTitle>}
          action={<HeaderFigure value={String(totalFiles)} detail="files" />}
        />
        <CardBody>
          <BarList
            label="Generated files by tool"
            labelWidth={92}
            items={tools.map((tool) => ({
              key: tool.name,
              label: tool.name,
              value: tool.files,
              detail: plural(tool.lines, "line"),
            }))}
          />
        </CardBody>
      </Card>
    </div>
  );
}
