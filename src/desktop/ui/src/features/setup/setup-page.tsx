import { CircleCheck } from "lucide-react";

import { TopBarActions } from "~/components/layout/page-chrome";
import { Badge } from "~/components/ui/badge";
import { Button } from "~/components/ui/button";
import { Card, CardHeader, CardRows, Row } from "~/components/ui/card";
import { CopyButton } from "~/components/ui/copy-button";
import { Notice } from "~/components/ui/notice";
import { RadioGroup } from "~/components/ui/radio-group";
import { Spinner } from "~/components/ui/spinner";
import { Step, Steps } from "~/features/report/report-step";
import { useStore } from "~/lib/store";
import { BrandMark } from "~/shell/brand-mark";

import type { SetupStore } from "./setup-store";

const accessibilityNote =
  "macOS asks for Accessibility access the first time each runs. Turn both on, then restart them from Advanced.";

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
  const missing = state?.tools.filter((tool) => !tool.installed) ?? [];
  const command =
    "brew install " +
    missing.map((tool) => tool.installCommand.replace("brew install ", "")).join(" ") +
    " jq";
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
      {state && !report ? (
        <>
          <Card className="px-6 py-5">
            <Steps>
              <Step
                number={1}
                title="Install the tools"
                hint="Macarchy configures these. It does not replace them."
                done={missing.length === 0}
              >
                <div className="overflow-hidden rounded-tile border border-hairline">
                  {state.tools.map((tool) => (
                    <Row
                      key={tool.id}
                      title={tool.name}
                      description={tool.role}
                      className="px-3.5 py-3"
                      control={
                        tool.installed ? (
                          <Badge tone="ok">Installed</Badge>
                        ) : (
                          <CopyButton
                            size="sm"
                            text={tool.installCommand}
                            label="Copy command"
                            tooltip={tool.installCommand}
                          />
                        )
                      }
                    />
                  ))}
                  {missing.length ? (
                    <Row
                      title="Install everything"
                      description="Paste into Terminal. Needs Homebrew from brew.sh."
                      className="bg-side px-3.5 py-3"
                      control={
                        <CopyButton
                          size="sm"
                          text={command}
                          label="Copy command"
                          tooltip={command}
                        />
                      }
                    />
                  ) : null}
                </div>
              </Step>
              {state.hasExisting ? (
                <Step
                  number={2}
                  title="Your existing setup"
                  hint="Either way, every original is backed up before anything changes."
                  done
                >
                  <RadioGroup
                    label="Existing configuration"
                    value={snapshot.existing}
                    disabled={busy || snapshot.planning}
                    options={[
                      { value: "keep", label: "Keep mine and add Macarchy" },
                      { value: "replace", label: "Start fresh with Macarchy's defaults" },
                    ]}
                    onValueChange={(value) => store.choose(value)}
                  />
                </Step>
              ) : null}
              <Step number={state.hasExisting ? 3 : 2} title="What will change" last>
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
            <p className="mr-auto min-w-0 text-small text-fg-tertiary">
              {missing.length
                ? "You can set up now and install the missing tools later."
                : "Writes the files above and starts the services."}
            </p>
            <p role="status" className="sr-only">
              {busy ? "Setting up…" : ""}
            </p>
            <Button
              variant="primary"
              size="lg"
              busy={busy}
              disabled={snapshot.planning}
              onClick={() => void store.run()}
            >
              Set up Macarchy
            </Button>
          </div>
        </>
      ) : null}
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
