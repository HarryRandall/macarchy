import { PageHeader } from "~/components/layout/page-header";
import { SettingRow } from "~/components/layout/setting-row";
import { SettingsSection } from "~/components/layout/settings-section";
import { Button } from "~/components/ui/button";
import { CopyButton } from "~/components/ui/copy-button";
import { Spinner } from "~/components/ui/spinner";
import { StatusChip, type StatusTone } from "~/components/ui/status-chip";
import { ReadNotice } from "~/features/overview/read-notice";
import { useStore } from "~/lib/store";
import type { PageContext } from "~/shell/page";
import type { HealthStore } from "./health-store";

const groups = {
  Dependencies: "The programs Macarchy configures. Install any that are missing.",
  Services: "Whether each program is set to start at login and is running.",
  Configuration: "Macarchy's settings and the startup files it writes.",
  Optional: "Extras that are not needed for Macarchy to work.",
};
const tones: Record<string, StatusTone> = {
  passed: "success",
  warning: "warning",
  failed: "danger",
  unknown: "neutral",
};

export function HealthPage({ store, context }: { store: HealthStore; context: PageContext }) {
  const snapshot = useStore(store);
  const state = snapshot.state;
  const failed = state?.checks.filter((check) => check.status === "failed").length ?? 0;
  const warnings = state?.checks.filter((check) => check.status === "warning").length ?? 0;
  return (
    <>
      <PageHeader
        title="Setup health"
        subtitle="What is installed, and what needs attention."
        actions={
          <>
            <Button disabled={snapshot.refreshing} onClick={() => void store.load()}>
              {snapshot.refreshing ? "Checking…" : "Check again"}
            </Button>
            <Button onClick={() => context.navigate("report")}>Report a problem</Button>
          </>
        }
      />
      <ReadNotice
        error={snapshot.error}
        retry={() => void store.load()}
        busy={snapshot.refreshing}
      />
      {snapshot.refreshing ? (
        <div role="status" className="flex items-center gap-2 text-meta text-fg-secondary">
          <Spinner size="sm" />
          Checking…
        </div>
      ) : null}
      {state ? (
        <>
          <div role="status" className="flex flex-wrap items-center gap-2">
            <StatusChip
              tone={failed ? "danger" : "success"}
              label={failed ? `${failed} to fix` : "Everything Macarchy needs is working"}
            />
            {warnings ? <StatusChip tone="warning" label={`${warnings} to review`} /> : null}
            <span className="ml-auto text-meta text-fg-meta">
              Checked{" "}
              {new Date(state.checkedAt * 1000).toLocaleTimeString("en-GB", {
                hour: "2-digit",
                minute: "2-digit",
              })}
            </span>
          </div>
          {Object.entries(groups).map(([group, help]) => {
            const checks = state.checks.filter((check) => check.group === group);
            return checks.length ? (
              <SettingsSection key={group} title={group} help={help}>
                {checks.map((check) => (
                  <SettingRow
                    key={check.id}
                    title={check.title}
                    detail={check.detail}
                    leading={<StatusChip tone={tones[check.status]} label={check.status} />}
                  >
                    {check.fix && check.status !== "passed" ? (
                      <CopyButton
                        text={check.fix}
                        label="Copy fix"
                        tooltip={check.fix}
                        write={async () => {
                          if (!(await store.copyFix(check.id)))
                            throw new Error("The fix could not be copied.");
                        }}
                      />
                    ) : null}
                  </SettingRow>
                ))}
              </SettingsSection>
            ) : null;
          })}
          <SettingsSection
            title="This Mac"
            help="Included in problem reports, without your name or paths."
          >
            <SettingRow
              title="Mac"
              detail={`${state.environment.model} · ${state.environment.architecture}`}
            />
            <SettingRow title="macOS" detail={state.environment.macOS} />
            <SettingRow title="Macarchy" detail={state.environment.app} />
            <SettingRow title="Settings folder" detail={state.environment.settingsFolder}>
              <Button onClick={() => void store.reveal()}>Reveal</Button>
            </SettingRow>
          </SettingsSection>
        </>
      ) : null}
    </>
  );
}
