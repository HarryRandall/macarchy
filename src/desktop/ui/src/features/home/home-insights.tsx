import { type ReactNode, useMemo, useState } from "react";
import { BarChart } from "~/components/charts/bar-chart";
import { BarList } from "~/components/charts/bar-list";
import { TipNote, TipTitle, TipValue } from "~/components/charts/chart-tooltip";
import { HeatScale, HeatStrip } from "~/components/charts/heat-strip";
import { LineChart } from "~/components/charts/line-chart";
import { Card, CardHeader, SectionLabel } from "~/components/ui/card";
import { SegmentedControl } from "~/components/ui/segmented-control";
import {
  focusTime,
  hoursAndMinutes,
  lastDays,
  mostApplied,
  serviceLoad,
  themeChanges,
  workspaceWindows,
} from "./home-mock";

type Metric = "cpu" | "memory";

function ChartCard({
  title,
  description,
  action,
  className,
  children,
}: {
  title: string;
  description?: string;
  action?: ReactNode;
  className?: string;
  children: ReactNode;
}) {
  return (
    <Card className={className}>
      <CardHeader title={title} description={description} action={action} />
      <div className="px-5 pb-4">{children}</div>
    </Card>
  );
}

const plural = (count: number, word: string) => `${count} ${word}${count === 1 ? "" : "s"}`;

function WorkspaceCard() {
  // Mock: Macarchy does not count windows per workspace yet.
  const total = workspaceWindows.reduce((sum, entry) => sum + entry.windows, 0);
  return (
    <ChartCard title="Windows per workspace" description={`${total} open`}>
      <BarChart
        label="Open windows on workspaces 1 to 9"
        values={workspaceWindows.map((entry) => entry.windows)}
        labels={workspaceWindows.map((entry) => `Workspace ${entry.workspace}`)}
        xTicks={workspaceWindows.map((entry, index) => ({
          index,
          label: String(entry.workspace),
        }))}
        height={176}
        axisWidth={22}
        maxBarWidth={22}
        format={(value) => plural(value, "window")}
        // oxlint-disable-next-line react/no-unstable-nested-components -- a render prop the chart calls for its hover card, never mounted as a component.
        tooltip={(index) => {
          const entry = workspaceWindows[index]!;
          return (
            <>
              <TipTitle>Workspace {entry.workspace}</TipTitle>
              <TipValue>{entry.windows ? plural(entry.windows, "window") : "No windows"}</TipValue>
              {entry.apps ? <TipNote>{entry.apps}</TipNote> : null}
            </>
          );
        }}
      />
    </ChartCard>
  );
}

function FocusCard() {
  // Mock: Macarchy does not record focus time yet.
  const total = focusTime.reduce((sum, entry) => sum + entry.minutes, 0);
  return (
    <ChartCard title="Focus time by app this week" description={`${hoursAndMinutes(total)} total`}>
      <BarList
        label="Focus time by app this week"
        labelWidth={72}
        format={hoursAndMinutes}
        items={focusTime.map((entry) => ({
          key: entry.app,
          label: entry.app,
          value: entry.minutes,
          detail: `${Math.round((entry.minutes / total) * 100)}%, ${entry.sessions} sessions`,
        }))}
      />
    </ChartCard>
  );
}

function ServicesCard({ today }: { today: Date }) {
  const [metric, setMetric] = useState<Metric>("cpu");
  const days = useMemo(() => lastDays(today, 30), [today]);
  // Mock: Macarchy does not sample its services' CPU and memory over time yet.
  const load = useMemo(() => serviceLoad(days), [days]);
  const cpu = metric === "cpu";
  const values = load.map((reading) => (cpu ? reading.cpu : reading.memory));
  const average = values.reduce((sum, value) => sum + value, 0) / values.length;
  const format = (value: number) => (cpu ? `${value.toFixed(1)}%` : `${Math.round(value)} MB`);
  const last = days.length - 1;
  return (
    <ChartCard
      className="@[680px]:col-span-2"
      title="CPU and memory of Macarchy services"
      description={`${format(average)} daily average, 30 days`}
      action={
        <SegmentedControl
          label="Measure"
          size="sm"
          value={metric}
          options={[
            { value: "cpu", label: "CPU" },
            { value: "memory", label: "Memory" },
          ]}
          onValueChange={setMetric}
        />
      }
    >
      <LineChart
        label={`Daily ${cpu ? "CPU" : "memory"} use by Macarchy services over 30 days`}
        values={values}
        labels={days.map((day, index) => (index === last ? `Today, ${day.short}` : day.long))}
        xTicks={[0, 7, 14, 21, last].map((index) => ({
          index,
          label: index === last ? "Today" : days[index]!.short,
        }))}
        height={188}
        axisWidth={46}
        format={format}
        tickFormat={(value) => (cpu ? `${value}%` : `${value} MB`)}
        valueLabel={cpu ? "CPU" : "Memory"}
      />
    </ChartCard>
  );
}

function ThemeChangesCard({
  today,
  titles,
  current,
}: {
  today: Date;
  titles: readonly string[];
  current: string | null;
}) {
  // Mock: Macarchy does not keep a theme history yet.
  const changes = useMemo(
    () => themeChanges(lastDays(today, 30), titles, current),
    [today, titles, current],
  );
  const total = changes.reduce((sum, change) => sum + change.themes.length, 0);
  const favourite = mostApplied(changes);
  const last = changes.length - 1;
  return (
    <ChartCard
      className="@[680px]:col-span-2"
      title="Theme changes over the last 30 days"
      description={`${plural(total, "change")}${favourite ? `, ${favourite} applied most often` : ""}`}
      action={<HeatScale />}
    >
      <HeatStrip
        label="Theme changes per day over the last 30 days"
        startLabel={changes[0]?.day.short}
        cells={changes.map((change, index) => ({
          label: index === last ? `Today, ${change.day.short}` : change.day.long,
          value: change.themes.length ? plural(change.themes.length, "change") : "No changes",
          level: Math.min(change.themes.length, 3),
          note: change.themes.length ? change.themes.join(", ") : undefined,
        }))}
      />
    </ChartCard>
  );
}

/** Desktop figures over time. Every figure here is a stand-in until Macarchy records them. */
export function HomeInsights({
  today,
  titles,
  current,
}: {
  today: Date;
  /** The installed themes' names, for the change history. */
  titles: readonly string[];
  current: string | null;
}) {
  return (
    <section aria-labelledby="home-insights">
      <SectionLabel>
        <span id="home-insights">Insights</span>
      </SectionLabel>
      <div className="@container">
        <div className="grid grid-cols-1 gap-4 @[680px]:grid-cols-2">
          <WorkspaceCard />
          <FocusCard />
          <ServicesCard today={today} />
          <ThemeChangesCard today={today} titles={titles} current={current} />
        </div>
      </div>
    </section>
  );
}
