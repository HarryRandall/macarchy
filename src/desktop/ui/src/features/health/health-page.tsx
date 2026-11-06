import { ChevronRight, FileText, FolderOpen } from "lucide-react";
import type { ReactNode } from "react";
import { useState } from "react";

import { PageHeader } from "~/components/layout/page-header";
import { Button } from "~/components/ui/button";
import { Card, CardHeader, CardRows, Row } from "~/components/ui/card";
import { CopyButton } from "~/components/ui/copy-button";
import { Spinner } from "~/components/ui/spinner";
import { TruncatedText } from "~/components/ui/truncated-text";
import { ReadNotice } from "~/features/overview/read-notice";
import { cn } from "~/lib/cn";
import { useStore } from "~/lib/store";
import type { PageContext } from "~/shell/page";

import { type Check, listNames, othersTitle, partitionChecks } from "./check-list";
import { CheckDetail, CheckRow } from "./check-rows";
import { historyLabels } from "./health-mock";
import { HealthSummaryCard } from "./health-summary-card";
import type { HealthStore } from "./health-store";
import { StatusIcon } from "./status-icon";

/**
 * A problem's row actions: Copy for a real command and Open for a file to
 * correct by hand. Advice in words is shown in the detail, never copied.
 */
function fixActions(check: Check, store: HealthStore): ReactNode {
  if (!check.command && !check.file) return null;
  return (
    <div className="flex items-center gap-2">
      {check.file ? (
        <Button size="sm" onClick={() => void store.openFile(check.id)}>
          <FileText aria-hidden />
          Open {check.file.split("/").at(-1)}
        </Button>
      ) : null}
      {check.command ? (
        <CopyButton
          size="sm"
          text={check.command}
          label="Copy command"
          tooltip={check.command}
          write={async () => {
            if (!(await store.copyCommand(check.id)))
              throw new Error("The command could not be copied.");
          }}
        />
      ) : null}
    </div>
  );
}

const time = (seconds: number) =>
  new Date(seconds * 1000).toLocaleTimeString("en-GB", { hour: "2-digit", minute: "2-digit" });

export function HealthPage({ store, context }: { store: HealthStore; context: PageContext }) {
  const snapshot = useStore(store);
  const state = snapshot.state;
  /** `undefined` until a row is toggled: the worst problem starts open. */
  const [open, setOpen] = useState<string | null>();
  const [showOthers, setShowOthers] = useState(false);
  const refreshing = snapshot.refreshing;
  const run = () => void store.load();

  const header = (
    <PageHeader
      title="Setup health"
      actions={
        <Button size="sm" onClick={() => context.navigate("report")}>
          Report a problem
        </Button>
      }
    />
  );
  const notice = <ReadNotice error={snapshot.error} retry={run} busy={refreshing} />;

  if (!state)
    return (
      <>
        {header}
        {notice}
        {snapshot.status === "loading" ? <Spinner label="Running checks" /> : null}
      </>
    );

  const { problems, others } = partitionChecks(state.checks);
  const unchecked = others.some((check) => check.status === "unknown");
  const openId = open === undefined ? (problems[0]?.id ?? null) : open;
  const toggle = (id: string) => setOpen(openId === id ? null : id);
  const checkedAt = time(state.checkedAt);
  // Mock: the history's days end on the real last run.
  const days = historyLabels(state.checkedAt);
  const detail = (check: Check) => (
    <CheckDetail check={check} days={days} checkedAt={checkedAt} busy={refreshing} onRun={run} />
  );

  return (
    <div className="@container flex flex-col gap-4">
      {header}
      {notice}
      <HealthSummaryCard
        checks={state.checks}
        problems={problems.length}
        checkedAt={checkedAt}
        days={days}
        refreshing={refreshing}
        onRun={run}
      />

      {problems.length ? (
        <Card aria-labelledby="health-problems" className="overflow-hidden">
          <CardHeader
            id="health-problems"
            title="Needs attention"
            action={
              <span className="text-meta text-fg-tertiary tabular-nums">
                {problems.length} of {state.checks.length}
              </span>
            }
          />
          <CardRows>
            {problems.map((check) => (
              <CheckRow
                key={check.id}
                check={check}
                state={refreshing ? "checking" : check.status}
                expanded={openId === check.id}
                onToggle={() => toggle(check.id)}
                action={fixActions(check, store)}
              >
                {detail(check)}
              </CheckRow>
            ))}
          </CardRows>
        </Card>
      ) : null}

      {others.length ? (
        <Card aria-label="Checks without problems" className="overflow-hidden">
          <button
            type="button"
            aria-expanded={showOthers}
            onClick={() => setShowOthers((shown) => !shown)}
            className="flex w-full min-w-0 items-center gap-4 rounded-[inherit] px-5 py-3 text-left transition-colors duration-150 outline-none hover:bg-hover focus-visible:ring-2 focus-visible:ring-accent focus-visible:ring-inset"
          >
            <StatusIcon state={refreshing ? "checking" : unchecked ? "unknown" : "passed"} />
            <span className="min-w-0 flex-1">
              <span className="block text-body font-medium text-fg">{othersTitle(others)}</span>
              <span className="block truncate text-small text-fg-secondary">
                {listNames(others.map((check) => check.title))}
              </span>
            </span>
            <span className="shrink-0 text-meta text-fg-tertiary">
              {showOthers ? "Hide" : "Show all"}
            </span>
            <ChevronRight
              aria-hidden
              size={14}
              className={cn(
                "shrink-0 text-fg-tertiary transition-transform duration-150 motion-reduce:transition-none",
                showOthers && "rotate-90",
              )}
            />
          </button>
          {showOthers ? (
            <CardRows>
              {others.map((check) => (
                <CheckRow
                  key={check.id}
                  compact
                  check={check}
                  state={refreshing ? "checking" : check.status}
                  expanded={openId === check.id}
                  onToggle={() => toggle(check.id)}
                  trailing={refreshing ? "Checking" : checkedAt}
                >
                  {detail(check)}
                </CheckRow>
              ))}
            </CardRows>
          ) : null}
        </Card>
      ) : null}

      <Card aria-labelledby="health-mac">
        <CardHeader
          id="health-mac"
          title="This Mac"
          help="Included in problem reports, without your name or paths."
        />
        <CardRows>
          <Row
            title="Mac"
            description={`${state.environment.model} · ${state.environment.architecture}`}
          />
          <Row title="macOS" description={state.environment.macOS} />
          <Row title="Macarchy" description={state.environment.app} />
          <Row
            title="Settings folder"
            description={
              <TruncatedText
                text={state.environment.settingsFolder}
                className="font-mono text-caption"
              />
            }
            control={
              <Button size="sm" onClick={() => void store.reveal()}>
                <FolderOpen aria-hidden />
                Reveal
              </Button>
            }
          />
        </CardRows>
      </Card>
    </div>
  );
}
