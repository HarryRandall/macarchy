import { RotateCw } from "lucide-react";
import { useState } from "react";

import { PageHeader } from "~/components/layout/page-header";
import { Button } from "~/components/ui/button";
import { IconButton } from "~/components/ui/icon-button";
import { Notice } from "~/components/ui/notice";
import { useStore } from "~/lib/store";

import { BackupsCard } from "./advanced-backups";
import { AdvancedCharts } from "./advanced-charts";
import { ConfigFilesCard, generatedFiles } from "./advanced-files";
import { dayStarts } from "./advanced-format";
import { ServicesCard } from "./advanced-services";
import type { AdvancedStore } from "./advanced-store";
import { AdvancedSummary } from "./advanced-summary";
import { CommandLineCard, DangerZone, ExtrasCard, SetupCard } from "./advanced-system";

export function AdvancedPage({ store, openSetup }: { store: AdvancedStore; openSetup(): void }) {
  const snapshot = useStore(store);
  const [openedAt] = useState(() => Date.now());
  // Which action's control shows a spinner: "restart:yabai", "rebuild:all", "repair".
  const [pending, setPending] = useState<string | null>(null);
  const { state, busy } = snapshot;

  // Failures reach the page through the store's error; the spinner only needs to stop.
  const track = (key: string, work: Promise<unknown>) => {
    setPending(key);
    void work
      .catch(() => {})
      .finally(() => setPending((current) => (current === key ? null : current)));
  };
  const pendingId = (kind: string) =>
    pending?.startsWith(`${kind}:`) ? pending.slice(kind.length + 1) : null;

  // A backup taken since the page opened is the latest moment the page knows of.
  const now = Math.max(openedAt, ...(state?.snapshots.map((backup) => backup.created) ?? []));

  return (
    <>
      <PageHeader
        title="Advanced"
        actions={
          <IconButton
            label="Check service status again"
            busy={snapshot.refreshing}
            disabled={busy}
            onClick={() => void store.load()}
          >
            <RotateCw aria-hidden />
          </IconButton>
        }
      />
      <div className="@container flex flex-col gap-5">
        {snapshot.error ? (
          <Notice.Root variant="error">
            <Notice.Title>
              {state ? "Could not complete that action" : "Could not read Advanced settings"}
            </Notice.Title>
            <Notice.Description>{snapshot.error}</Notice.Description>
            {!state ? (
              <Notice.Actions>
                <Button disabled={snapshot.refreshing} onClick={() => void store.load()}>
                  Try again
                </Button>
              </Notice.Actions>
            ) : null}
          </Notice.Root>
        ) : null}
        <p role="status" className="sr-only">
          {busy ? "Working…" : ""}
        </p>
        {state ? (
          <>
            <AdvancedSummary state={state} now={now} />
            <ServicesCard
              services={state.services}
              busy={busy}
              pending={pendingId("restart")}
              onRestart={(id) => track(`restart:${id}`, store.restart(id))}
              onStop={(id) => store.stop(id)}
            />
            <ConfigFilesCard
              outcomes={snapshot.outcomes}
              busy={busy}
              pending={pendingId("rebuild")}
              onRebuild={(id) => track(`rebuild:${id}`, store.rebuild(id))}
              onRebuildAll={() =>
                track("rebuild:all", store.rebuildAll(generatedFiles.map((file) => file.id)))
              }
              onReveal={() => void store.reveal()}
            />
            <AdvancedCharts starts={dayStarts(now)} />
            <BackupsCard
              snapshots={state.snapshots}
              now={now}
              busy={busy}
              onRestore={(id) => store.restoreSnapshot(id)}
            />
            <ExtrasCard
              state={state}
              busy={busy}
              repairing={pending === "repair"}
              onRepair={() => track("repair", store.repair())}
            />
            <CommandLineCard />
            <SetupCard busy={busy} onOpenSetup={openSetup} />
            <DangerZone
              directory={state.backupsDirectory}
              busy={busy}
              report={snapshot.report}
              onRestore={() => store.restoreOriginals()}
              onDismissReport={() => store.dismissReport()}
            />
          </>
        ) : null}
      </div>
    </>
  );
}
