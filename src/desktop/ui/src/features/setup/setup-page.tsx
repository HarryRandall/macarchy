import { CircleCheck } from "lucide-react";

import type { SetupState, SetupTool } from "~/bridge/protocol";
import { TopBarActions } from "~/components/layout/page-chrome";
import { Badge } from "~/components/ui/badge";
import { Button } from "~/components/ui/button";
import { Card, CardHeader, CardRows, Row } from "~/components/ui/card";
import { Checkbox } from "~/components/ui/checkbox";
import { CodeBlock } from "~/components/ui/code-block";
import { Notice } from "~/components/ui/notice";
import { RadioGroup } from "~/components/ui/radio-group";
import { Spinner } from "~/components/ui/spinner";
import { Step, Steps } from "~/features/report/report-step";
import { useStore } from "~/lib/store";
import { BrandMark } from "~/shell/brand-mark";

import type { SetupStore, ToolInstall } from "./setup-store";

const accessibilityNote =
  "macOS asks for Accessibility access the first time each runs. Turn both on, then restart them from Advanced.";

function names(tools: SetupTool[]) {
  const list = tools.map((tool) => tool.name);
  return list.length > 1 ? `${list.slice(0, -1).join(", ")} and ${list.at(-1)}` : (list[0] ?? "");
}

export function SetupPage({
  store,
  close,
  health,
}: {
  store: SetupStore;
  close(): void;
  health(): void;
}) {
  const snapshot = useStore(store);
  const { state, report, busy } = snapshot;
  return (
    <>
      {state?.canClose && !busy ? (
        <TopBarActions>
          <Button variant="ghost" size="sm" onClick={close}>
            Close
          </Button>
        </TopBarActions>
      ) : null}
      <header className="flex items-center gap-4 pt-2 pb-1">
        <span className="grid size-12 shrink-0 place-items-center rounded-panel bg-strong text-strong-fg shadow-card">
          <BrandMark className="w-7" />
        </span>
        <div className="min-w-0">
          <h1 className="text-hero-title text-fg">Set up Macarchy</h1>
          <p className="mt-0.5 text-body text-fg-secondary">
            A themed, tiling desktop in a few steps.
          </p>
        </div>
      </header>
      {snapshot.error ? (
        <Notice.Root variant="error">
          <Notice.Title>Setup could not finish</Notice.Title>
          <Notice.Description>{snapshot.error}</Notice.Description>
          {!state ? (
            <Notice.Actions>
              <Button disabled={snapshot.planning} onClick={() => void store.load()}>
                Try again
              </Button>
            </Notice.Actions>
          ) : null}
        </Notice.Root>
      ) : null}
      {!state && snapshot.planning ? (
        <p role="status" className="flex items-center gap-2 text-detail text-fg-secondary">
          <Spinner size="sm" />
          Reading your setup…
        </p>
      ) : null}
      {state && !report && busy ? <Progress store={store} state={state} /> : null}
      {state && !report && !busy ? <Plan store={store} state={state} /> : null}
      {report ? (
        <>
          {report.failures.length ? (
            <Notice.Root variant="warning">
              <Notice.Title>Setup needs attention</Notice.Title>
              <Notice.Description className="whitespace-pre-line">
                {report.failures.join("\n")}
              </Notice.Description>
            </Notice.Root>
          ) : null}
          {!report.failure ? (
            <Card>
              <CardHeader title="Almost there" />
              <CardRows>
                <Row
                  title="Allow yabai and skhd"
                  description={accessibilityNote}
                  control={
                    <Button onClick={() => void store.openAccessibility()}>
                      Open Accessibility
                    </Button>
                  }
                />
                <Row
                  title="Separate Spaces"
                  description="Keep “Displays have separate Spaces” on in Desktop & Dock."
                />
              </CardRows>
            </Card>
          ) : null}
          {report.lines.length || !report.failure ? (
            <Card>
              <CardHeader title="What setup did" />
              <ul className="border-t border-hairline px-5 py-3">
                {report.lines.map((line, index) => (
                  <li key={index} className="flex items-start gap-2.5 py-1 text-body text-fg">
                    <CircleCheck aria-hidden className="mt-0.5 size-3.5 shrink-0 text-success" />
                    <span className="min-w-0 select-text">{line}</span>
                  </li>
                ))}
              </ul>
            </Card>
          ) : null}
          {snapshot.log.length ? <HomebrewLog lines={snapshot.log} /> : null}
          {report.failure && !state?.canClose ? (
            // Without settings the window has nothing to return to, so the
            // only way on is to set up again.
            <div className="flex justify-end gap-2">
              <Button variant="primary" onClick={() => store.reset()}>
                Try again
              </Button>
            </div>
          ) : (
            <div className="flex justify-end gap-2">
              <Button onClick={health}>Check setup health</Button>
              <Button variant="primary" onClick={close}>
                Done
              </Button>
            </div>
          )}
        </>
      ) : null}
    </>
  );
}

/** The tools to tick, how each starts, and the files setup will write. */
function Plan({ store, state }: { store: SetupStore; state: SetupState }) {
  const snapshot = useStore(store);
  const chosen = state.tools.filter((tool) => snapshot.tools.includes(tool.id));
  const missing = chosen.filter((tool) => !tool.installed);
  const installing = state.homebrew ? missing : [];
  const footer = !chosen.length
    ? "Choose at least one tool to set up."
    : installing.length
      ? `Installs ${names(installing)} with Homebrew, then writes the files below and starts the services.`
      : missing.length
        ? `${names(missing)} ${missing.length > 1 ? "are" : "is"} set up once installed.`
        : "Writes the files below and starts the services.";
  return (
    <>
      {state.notices.length ? (
        <Notice.Root>
          <Notice.Title>Your settings moved</Notice.Title>
          <Notice.Description className="whitespace-pre-line select-text">
            {state.notices.join("\n")}
          </Notice.Description>
        </Notice.Root>
      ) : null}
      <Card className="px-6 py-5">
        <Steps>
          <Step
            number={1}
            title="Choose your tools"
            hint="Macarchy configures the ones you tick and leaves the others alone."
            done={chosen.length > 0 && missing.length === 0}
          >
            <div className="overflow-hidden rounded-tile border border-hairline">
              {state.tools.map((tool) => (
                <ToolRow key={tool.id} store={store} tool={tool} homebrew={state.homebrew} />
              ))}
            </div>
            {missing.length && !state.homebrew ? (
              <Notice.Root variant="warning" className="mt-3">
                <Notice.Title>Homebrew installs {names(missing)}</Notice.Title>
                <Notice.Description>
                  Homebrew is not installed yet. Its installer asks for your password, so it opens
                  in Terminal. When it has finished, check again.
                </Notice.Description>
                <Notice.Actions>
                  <Button
                    variant={snapshot.homebrewOpened ? "secondary" : "primary"}
                    onClick={() => void store.installHomebrew()}
                  >
                    Install Homebrew in Terminal
                  </Button>
                  <Button
                    variant={snapshot.homebrewOpened ? "primary" : "secondary"}
                    disabled={snapshot.planning}
                    onClick={() => void store.load()}
                  >
                    Check again
                  </Button>
                </Notice.Actions>
              </Notice.Root>
            ) : null}
          </Step>
          <Step number={2} title="What will change" last>
            <ul className="overflow-hidden rounded-tile border border-hairline">
              {state.changes.map((change) => (
                <li
                  key={change.path}
                  className="flex flex-col gap-0.5 border-hairline px-3.5 py-2.5 not-first:border-t"
                >
                  <span className="truncate font-mono text-mono text-fg">{change.path}</span>
                  <span className="text-small text-fg-secondary">{change.detail}</span>
                </li>
              ))}
            </ul>
          </Step>
        </Steps>
      </Card>
      <div className="flex flex-wrap items-center justify-end gap-x-4 gap-y-2">
        <p className="mr-auto min-w-0 text-small text-fg-tertiary">{footer}</p>
        <Button
          variant="primary"
          size="lg"
          disabled={snapshot.planning || !chosen.length}
          onClick={() => void store.run()}
        >
          {installing.length ? "Install and set up" : "Set up Macarchy"}
        </Button>
      </div>
    </>
  );
}

function ToolRow({
  store,
  tool,
  homebrew,
}: {
  store: SetupStore;
  tool: SetupTool;
  homebrew: boolean;
}) {
  const snapshot = useStore(store);
  const chosen = snapshot.tools.includes(tool.id);
  const disabled = snapshot.busy || snapshot.planning;
  return (
    <Row
      title={tool.name}
      description={tool.description}
      className="px-3.5 py-3 not-first:border-t not-first:border-hairline"
      leading={
        <Checkbox
          aria-label={`Set up ${tool.name}`}
          checked={chosen}
          disabled={disabled}
          onCheckedChange={(checked) => store.toggle(tool.id, checked)}
        />
      }
      control={
        tool.installed ? (
          <Badge tone="ok">Installed</Badge>
        ) : chosen && homebrew ? (
          <Badge tone="accent">Will be installed</Badge>
        ) : (
          <Badge>Not installed</Badge>
        )
      }
    >
      {chosen && tool.ownConfig ? (
        <div className="flex flex-col gap-2 pl-7">
          <p className="text-small text-fg-secondary">
            You have <span className="font-mono text-mono">{tool.ownConfig}</span>. Either way it is
            backed up and left as it is.
          </p>
          <RadioGroup
            label={`How ${tool.name} starts`}
            value={snapshot.existing[tool.id] ?? "keep"}
            disabled={disabled}
            options={[
              { value: "keep", label: "Keep mine and add Macarchy" },
              { value: "replace", label: "Use Macarchy's defaults" },
            ]}
            onValueChange={(value) => store.choose(tool.id, value)}
          />
        </div>
      ) : null}
    </Row>
  );
}

const installLabels: Record<ToolInstall["status"], string> = {
  waiting: "Waiting",
  installing: "Installing…",
  installed: "Installed",
  failed: "Not installed",
};

/** Each tool being installed, Homebrew's output, then writing the files. */
function Progress({ store, state }: { store: SetupStore; state: SetupState }) {
  const snapshot = useStore(store);
  const installs = state.tools.flatMap((tool) => {
    const install = snapshot.installs[tool.id];
    return install ? [{ tool, install }] : [];
  });
  return (
    <>
      {installs.length ? (
        <Card>
          <CardHeader title="Installing tools" />
          <CardRows>
            {installs.map(({ tool, install }) => (
              <Row
                key={tool.id}
                title={tool.name}
                description={install.reason ?? tool.description}
                control={
                  install.status === "installing" ? (
                    <span className="flex items-center gap-2 text-detail text-fg-secondary">
                      <Spinner size="sm" />
                      {installLabels.installing}
                    </span>
                  ) : (
                    <Badge
                      tone={
                        install.status === "installed"
                          ? "ok"
                          : install.status === "failed"
                            ? "danger"
                            : "neutral"
                      }
                    >
                      {installLabels[install.status]}
                    </Badge>
                  )
                }
              />
            ))}
          </CardRows>
        </Card>
      ) : null}
      {snapshot.log.length ? <HomebrewLog lines={snapshot.log} /> : null}
      <p role="status" className="flex items-center gap-2 text-detail text-fg-secondary">
        <Spinner size="sm" />
        {snapshot.phase === "installing"
          ? "Installing with Homebrew…"
          : "Writing files and starting services…"}
      </p>
    </>
  );
}

function HomebrewLog({ lines }: { lines: string[] }) {
  return (
    <CodeBlock
      code={lines.join("\n")}
      label="Homebrew's output"
      copyLabel="Copy output"
      maxHeight={180}
    />
  );
}
