import { Copy, Info, ListOrdered, RotateCw, Send, ShieldCheck } from "lucide-react";
import { useEffect, useId, useState } from "react";

import { PageHeader } from "~/components/layout/page-header";
import { Button } from "~/components/ui/button";
import { Card, Row } from "~/components/ui/card";
import { CodeBlock } from "~/components/ui/code-block";
import { Notice } from "~/components/ui/notice";
import { SegmentedControl } from "~/components/ui/segmented-control";
import { Spinner } from "~/components/ui/spinner";
import { Switch } from "~/components/ui/switch";
import { Field, Input, Textarea } from "~/components/ui/text-field";
import { Tooltip } from "~/components/ui/tooltip";
import { cn } from "~/lib/cn";
import { useStore } from "~/lib/store";

import { type Area, areas, issuesFor, summaryMax, withSteps } from "./report-content";
import { ReportSent } from "./report-sent";
import { ScreenshotsField, useShots } from "./report-shots";
import { Step, Steps } from "./report-step";
import type { ReportStore } from "./report-store";

const areaOptions = areas.map(({ id, label, icon: Icon }) => ({
  value: id,
  label,
  icon: <Icon aria-hidden className="hidden @min-[540px]:block" />,
}));

export function ReportPage({ store }: { store: ReportStore }) {
  const snapshot = useStore(store);
  const shots = useShots();
  const descriptionId = useId();
  const [area, setArea] = useState<Area>("menu-bar");
  const [pending, setPending] = useState<"copy" | "open" | null>(null);
  const [sent, setSent] = useState(false);
  useEffect(() => store.opened(), [store]);

  const named = snapshot.title.trim().length > 0;
  const blocked = snapshot.busy || snapshot.preparing || !snapshot.preview || snapshot.stale;
  const areaLabel = areas.find((option) => option.id === area)?.label ?? "";
  const run = (action: "copy" | "open") => {
    setPending(action);
    void store[action]().then((done) => {
      setPending(null);
      if (done && action === "open") setSent(true);
    });
  };

  if (sent) {
    const count = shots.shots.length;
    const toAttach = count === 1 ? "1 screenshot to attach" : `${count} screenshots to attach`;
    return (
      <>
        <PageHeader title="Report a problem" />
        <ReportSent
          title={snapshot.title}
          included={[areaLabel, "Diagnostics", ...(count ? [toAttach] : [])]}
          notice={snapshot.notice}
          onBack={() => setSent(false)}
          onAnother={() => {
            store.clear();
            shots.clear();
            setSent(false);
          }}
        />
      </>
    );
  }

  return (
    <>
      <PageHeader title="Report a problem" />
      <div className="flex flex-col gap-4">
        {snapshot.error ? (
          <Notice.Root variant="error">
            <Notice.Title>
              {snapshot.stale ? "Could not prepare the report" : "That did not go through"}
            </Notice.Title>
            <Notice.Description>{snapshot.error}</Notice.Description>
            {snapshot.stale ? (
              <Notice.Actions>
                <Button disabled={snapshot.preparing} onClick={() => void store.load()}>
                  Try again
                </Button>
              </Notice.Actions>
            ) : null}
          </Notice.Root>
        ) : null}
        <Card className="px-6 py-5">
          <Steps>
            <Step
              number={1}
              title="What is it about?"
              hint="Points you to known issues first. Not part of the report."
              done
            >
              <div className="@container flex flex-col gap-3">
                <SegmentedControl
                  label="Area"
                  value={area}
                  options={areaOptions}
                  onValueChange={setArea}
                  fill
                />
                <KnownIssues
                  area={area}
                  busy={snapshot.busy}
                  onOpenIssues={() => void store.openIssues()}
                />
              </div>
            </Step>
            <Step number={2} title="Describe it" done={named}>
              <div className="flex flex-col gap-4">
                <Field.Root>
                  <div className="flex items-baseline justify-between gap-3">
                    <Field.Label>Summary</Field.Label>
                    <span
                      aria-hidden
                      className={cn(
                        "text-meta tabular-nums",
                        snapshot.title.length >= summaryMax - 10
                          ? "text-fg-secondary"
                          : "text-fg-tertiary",
                      )}
                    >
                      {snapshot.title.length}/{summaryMax}
                    </span>
                  </div>
                  <Input
                    value={snapshot.title}
                    maxLength={summaryMax}
                    placeholder="Menu bar disappears after sleep"
                    onValueChange={(value) => store.setTitle(value)}
                  />
                </Field.Root>
                <div className="flex flex-col gap-1.5">
                  <div className="flex items-center justify-between gap-3">
                    <label htmlFor={descriptionId} className="text-small font-medium text-fg">
                      What happened, and what you expected
                    </label>
                    <Button
                      variant="ghost"
                      size="xs"
                      onClick={() => store.setDescription(withSteps(snapshot.description))}
                    >
                      <ListOrdered aria-hidden />
                      Add steps
                    </Button>
                  </div>
                  <Textarea
                    id={descriptionId}
                    rows={5}
                    placeholder="Steps to reproduce"
                    value={snapshot.description}
                    onChange={(event) => store.setDescription(event.currentTarget.value)}
                  />
                </div>
              </div>
            </Step>
            <Step number={3} title="Screenshots" done={shots.shots.length > 0} optional>
              <ScreenshotsField shots={shots.shots} onAdd={shots.add} onRemove={shots.remove} />
            </Step>
            <Step
              number={4}
              title="Diagnostics"
              hint="Versions and check results, with your home folder hidden."
              done={Boolean(snapshot.preview) && !snapshot.stale}
              last
              action={
                <Tooltip content="Run the checks again, such as after fixing something" describe>
                  <Button
                    variant="ghost"
                    size="xs"
                    aria-label="Refresh diagnostics"
                    disabled={snapshot.preparing || snapshot.busy}
                    onClick={() => void store.load()}
                  >
                    <RotateCw aria-hidden />
                    Refresh
                  </Button>
                </Tooltip>
              }
            >
              <div className="flex flex-col gap-2.5">
                {snapshot.preparing ? (
                  <p role="status" className="flex items-center gap-2 text-meta text-fg-secondary">
                    <Spinner size="sm" />
                    Preparing…
                  </p>
                ) : null}
                {snapshot.preview ? (
                  <CodeBlock code={snapshot.preview.body} label="Report to be sent" />
                ) : null}
                <div className="rounded-tile border border-hairline">
                  <Row
                    title="Attach config files"
                    description="Not available yet. Reports carry versions and check results only."
                    control={<Switch checked={false} disabled aria-label="Attach config files" />}
                    className="px-3.5 py-3"
                  />
                </div>
                <p className="flex items-center gap-1.5 text-small text-fg-tertiary">
                  <ShieldCheck aria-hidden className="size-3 shrink-0" />
                  Never includes logs, personal files or window titles.
                </p>
              </div>
            </Step>
          </Steps>
        </Card>
        <div className="flex flex-wrap items-center justify-end gap-2.5">
          <div className="mr-auto min-w-0">
            {snapshot.notice ? (
              <p role="status" className="text-detail text-fg">
                {snapshot.notice}
              </p>
            ) : named ? null : (
              <p className="flex items-center gap-1.5 text-small text-fg-tertiary">
                <Info aria-hidden className="size-3 shrink-0" />
                Summary required
              </p>
            )}
          </div>
          <Button
            variant="ghost"
            disabled={blocked}
            busy={pending === "copy"}
            onClick={() => run("copy")}
          >
            {pending === "copy" ? null : <Copy aria-hidden />}
            Copy report
          </Button>
          <Tooltip content="Opens a new public issue in your browser for you to submit">
            <Button
              variant="primary"
              disabled={blocked || !named}
              busy={pending === "open"}
              onClick={() => run("open")}
            >
              {pending === "open" ? null : <Send aria-hidden />}
              Open on GitHub
            </Button>
          </Tooltip>
        </div>
      </div>
    </>
  );
}

function KnownIssues({
  area,
  busy,
  onOpenIssues,
}: {
  area: Area;
  busy: boolean;
  onOpenIssues(): void;
}) {
  const issues = issuesFor(area);
  return (
    <div className="overflow-hidden rounded-tile border border-hairline">
      {issues.length ? (
        <ul className="divide-y divide-hairline">
          {issues.map((issue) => (
            <li key={issue.title} className="px-3.5 py-3">
              <p className="text-body font-medium text-fg">{issue.title}</p>
              <p className="mt-0.5 text-small text-fg-secondary">{issue.detail}</p>
            </li>
          ))}
        </ul>
      ) : (
        <p className="px-3.5 py-3 text-small text-fg-secondary">No known issues in this area.</p>
      )}
      <Row
        title="Something else?"
        description="See open issues before writing a new one."
        control={
          <Button size="sm" disabled={busy} onClick={onOpenIssues}>
            Open issues
          </Button>
        }
        className="border-t border-hairline bg-side px-3.5 py-3"
      />
    </div>
  );
}
