import { RefreshCw } from "lucide-react";
import { useEffect } from "react";

import { PageHeader } from "~/components/layout/page-header";
import { SettingRow } from "~/components/layout/setting-row";
import { CardContent, SectionAction, SettingsSection } from "~/components/layout/settings-section";
import { ActionBar } from "~/components/ui/action-bar";
import { Button } from "~/components/ui/button";
import { CodeBlock } from "~/components/ui/code-block";
import { InlineStatus } from "~/components/ui/inline-status";
import { Spinner } from "~/components/ui/spinner";
import { TextareaField, TextField } from "~/components/ui/text-field";
import { Tooltip } from "~/components/ui/tooltip";
import { ReadNotice } from "~/features/overview/read-notice";
import { useStore } from "~/lib/store";
import type { ReportStore } from "./report-store";

export function ReportPage({ store }: { store: ReportStore }) {
  const snapshot = useStore(store);
  const disabled = snapshot.busy || snapshot.preparing || !snapshot.preview || !!snapshot.error;
  useEffect(() => store.opened(), [store]);
  return (
    <>
      <PageHeader
        title="Report a problem"
        subtitle="Tell us what went wrong. You see everything first."
      />
      <ReadNotice
        error={snapshot.error}
        retry={() => void store.load()}
        busy={snapshot.preparing}
      />
      <SettingsSection title="Known issues" help="Problems with a known cause and a workaround.">
        <SettingRow
          title="Shortcuts stop working"
          detail="Secure Keyboard Entry in another app blocks skhd. Setup health names the app."
        />
        <SettingRow
          title="Desktop switching does nothing"
          detail="Needs yabai 7.1.25 or newer. Check Setup health for the installed version."
        />
        <SettingRow title="Something else?" detail="See open issues before filing a new one.">
          <Button disabled={snapshot.busy} onClick={() => void store.openIssues()}>
            Open issues
          </Button>
        </SettingRow>
      </SettingsSection>
      <SettingsSection title="Your report">
        <CardContent>
          <TextField
            label="Short summary"
            placeholder="Short summary, such as “Bar disappears after sleep”"
            value={snapshot.title}
            onValueChange={(value) => store.setTitle(value)}
          />
          <TextareaField
            label="What happened, and what you expected"
            value={snapshot.description}
            onChange={(event) => store.setDescription(event.currentTarget.value)}
          />
        </CardContent>
      </SettingsSection>
      <SettingsSection
        title="What will be sent"
        help="Versions and check results only. No logs, files or window titles."
        action={
          <SectionAction
            icon={<RefreshCw aria-hidden />}
            aria-label="Refresh diagnostics"
            tooltip="Run the checks again, such as after fixing something"
            disabled={snapshot.preparing || snapshot.busy}
            onClick={() => void store.load()}
          >
            Refresh
          </SectionAction>
        }
      >
        <CardContent>
          {snapshot.preparing ? (
            <div role="status" className="flex items-center gap-2 text-meta">
              <Spinner size="sm" />
              Preparing…
            </div>
          ) : null}
          <CodeBlock code={snapshot.preview?.body ?? "Preparing…"} label="Report to be sent" />
        </CardContent>
      </SettingsSection>
      <ActionBar
        status={
          snapshot.notice ? <InlineStatus role="status">{snapshot.notice}</InlineStatus> : undefined
        }
      >
        {snapshot.busy ? <Spinner label="Working" size="sm" /> : null}
        <Button disabled={disabled} onClick={() => void store.copy()}>
          Copy report
        </Button>
        <Tooltip content="Opens a new public issue in your browser for you to submit">
          <Button
            variant="primary"
            disabled={disabled || !snapshot.title.trim()}
            onClick={() => void store.open()}
          >
            Open on GitHub
          </Button>
        </Tooltip>
      </ActionBar>
    </>
  );
}
