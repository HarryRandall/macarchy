import { PageHeader } from "~/components/layout/page-header";
import { CardContent, SettingsSection } from "~/components/layout/settings-section";
import { SettingRow } from "~/components/layout/setting-row";
import { Button } from "~/components/ui/button";
import { CopyButton } from "~/components/ui/copy-button";
import { Notice } from "~/components/ui/notice";
import { RadioGroup } from "~/components/ui/radio-group";
import { Tooltip } from "~/components/ui/tooltip";
import { useStore } from "~/lib/store";
import type { SetupStore } from "./setup-store";

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
      <PageHeader
        title="Set up Macarchy"
        subtitle="A themed, tiling desktop in a few steps."
        actions={state?.canClose && !busy ? <Button onClick={close}>Close</Button> : null}
      />
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
      {state && !report ? (
        <>
          <SettingsSection
            title="1. Install the tools"
            help="Macarchy configures these. It does not replace them."
          >
            {state.tools.map((tool) => (
              <SettingRow
                key={tool.id}
                title={tool.name}
                detail={tool.installed ? "Installed" : tool.role}
              >
                {!tool.installed ? (
                  <CopyButton
                    text={tool.installCommand}
                    label="Copy command"
                    tooltip={tool.installCommand}
                  />
                ) : null}
              </SettingRow>
            ))}
            {missing.length ? (
              <SettingRow
                title="Install everything"
                detail="Paste into Terminal. Needs Homebrew from brew.sh."
              >
                <CopyButton text={command} label="Copy command" tooltip={command} />
              </SettingRow>
            ) : null}
          </SettingsSection>
          {state.hasExisting ? (
            <SettingsSection
              title="2. Your existing setup"
              help="Either way, every original is backed up before anything changes."
            >
              <CardContent>
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
              </CardContent>
            </SettingsSection>
          ) : null}
          <SettingsSection title={`${state.hasExisting ? 3 : 2}. What will change`}>
            {state.changes.map((change) => (
              <SettingRow key={change.path} title={change.path} detail={change.detail} />
            ))}
          </SettingsSection>
          <div className="flex justify-end">
            <Tooltip
              content={
                missing.length
                  ? "You can set up now and install the missing tools later"
                  : "Write the files above and start the services"
              }
            >
              <Button
                variant="primary"
                disabled={busy || snapshot.planning}
                aria-busy={busy}
                onClick={() => void store.run()}
              >
                {busy ? "Setting up…" : "Set up Macarchy"}
              </Button>
            </Tooltip>
          </div>
        </>
      ) : null}
      {report ? (
        <>
          {report.failures.length ? (
            <Notice.Root variant="warning">
              <Notice.Title>Setup needs attention</Notice.Title>
              <Notice.Description>{report.failures.join("\n")}</Notice.Description>
            </Notice.Root>
          ) : null}
          <SettingsSection title="Almost there">
            <SettingRow
              title="Allow yabai and skhd"
              detail="macOS asks for Accessibility access the first time each runs. Turn both on, then restart them from Advanced."
            >
              <Button onClick={() => void store.openAccessibility()}>Open Accessibility</Button>
            </SettingRow>
            <SettingRow
              title="Separate Spaces"
              detail={"Keep “Displays have separate Spaces” on in Desktop & Dock."}
            />
          </SettingsSection>
          <SettingsSection title="What setup did">
            {report.lines.map((line, index) => (
              <SettingRow key={index} title={line} />
            ))}
          </SettingsSection>
          <div className="flex justify-end gap-2">
            <Button onClick={health}>Check setup health</Button>
            <Button variant="primary" onClick={close}>
              Done
            </Button>
          </div>
        </>
      ) : null}
    </>
  );
}
