import { RotateCcw, SquareTerminal, Wand } from "lucide-react";

import type { AdvancedState, SetupReport } from "~/bridge/protocol";
import { Badge } from "~/components/ui/badge";
import { Button } from "~/components/ui/button";
import { Card, CardHeader, CardRows, Row, SectionLabel } from "~/components/ui/card";
import { ConfirmDialog } from "~/components/ui/confirm-dialog";
import { CopyButton } from "~/components/ui/copy-button";
import { IconTile } from "~/components/ui/icon-tile";
import { Notice } from "~/components/ui/notice";
import { PreviewTag } from "~/components/ui/preview-tag";
import { Switch } from "~/components/ui/switch";

import { commandPath } from "./advanced-mock";

const addition = {
  active: { label: "Active", tone: "ok" },
  repair: { label: "Needs repair", tone: "warn" },
  unavailable: { label: "Unavailable", tone: "neutral" },
  missing: { label: "Not installed", tone: "neutral" },
} as const;

/** The optional yabai pieces: the scripting addition and the window signals. */
export function ExtrasCard({
  state,
  busy,
  repairing,
  onRepair,
}: {
  state: AdvancedState;
  busy: boolean;
  repairing: boolean;
  onRepair: () => void;
}) {
  const shown = addition[state.addition];
  return (
    <Card>
      <CardHeader
        title="yabai extras"
        help="Optional. Macarchy works without these, with System Integrity Protection on."
      />
      <CardRows>
        <Row
          title="Scripting addition"
          description={state.additionExplanation}
          control={
            <>
              <Badge tone={shown.tone} dot>
                {shown.label}
              </Badge>
              {state.addition === "repair" ? (
                <Button size="sm" busy={repairing} disabled={busy} onClick={onRepair}>
                  Repair
                </Button>
              ) : null}
            </>
          }
        />
        <Row
          title="Window signals"
          help="Let floating rules reach new windows and keep focus when a window closes."
          control={
            <Badge tone={state.wakeHelpers ? "ok" : "warn"} dot>
              {state.wakeHelpers ? "Active" : "Not registered"}
            </Badge>
          }
        />
      </CardRows>
    </Card>
  );
}

/** The `macarchy` command. Nothing installs it from here yet. */
export function CommandLineCard() {
  return (
    <Card className="flex flex-wrap items-center gap-x-3.5 gap-y-3 px-5 py-4">
      <IconTile variant="outline" size="lg">
        <SquareTerminal strokeWidth={1.75} />
      </IconTile>
      <div className="min-w-0 flex-1 basis-40">
        <div className="flex items-center gap-2 text-body font-medium text-fg">
          Command line
          <PreviewTag />
        </div>
        <div className="mt-0.5 text-small text-fg-secondary">
          Installing the command from here is not available yet.
        </div>
      </div>
      <span className="inline-flex h-7 max-w-full min-w-0 items-center gap-1.5 rounded-control border border-hairline bg-side pr-0.5 pl-2.5 font-mono text-mono-value text-fg">
        {/* Mock: the install location is the design's until the app installs the command. */}
        <span className="min-w-0 truncate">{commandPath}</span>
        <CopyButton iconOnly size="sm" text={commandPath} label="Copy path" />
      </span>
      <Switch checked={false} disabled aria-label="Install the macarchy command" />
    </Card>
  );
}

/** Opens setup again, which repairs startup files without touching your edits. */
export function SetupCard({ busy, onOpenSetup }: { busy: boolean; onOpenSetup: () => void }) {
  return (
    <Card>
      <Row
        title="Run setup again"
        description="Repairs startup files and the app link. Your edits are kept."
        leading={
          <IconTile variant="outline">
            <Wand strokeWidth={1.75} />
          </IconTile>
        }
        control={
          <Button disabled={busy} onClick={onOpenSetup}>
            Open setup
          </Button>
        }
      />
    </Card>
  );
}

/** Putting back the files from before Macarchy, behind a confirmation, and what it did. */
export function DangerZone({
  directory,
  busy,
  report,
  onRestore,
  onDismissReport,
}: {
  directory: string;
  busy: boolean;
  report: SetupReport | null;
  onRestore: () => Promise<void>;
  onDismissReport: () => void;
}) {
  const description = `Puts back the configs you had before Macarchy, from ${directory}. Setup backed up every file it replaced.`;
  return (
    <section aria-labelledby="advanced-danger">
      <SectionLabel id="advanced-danger">Danger zone</SectionLabel>
      <div className="flex flex-col gap-3">
        <div className="overflow-hidden rounded-card border border-danger/30 bg-danger/[2.5%]">
          <Row
            className="py-4"
            title="Restore original files"
            description={description}
            leading={
              <IconTile tint="danger" size="lg" className="border border-danger/25">
                <RotateCcw strokeWidth={1.75} />
              </IconTile>
            }
            control={
              <ConfirmDialog
                title="Really restore?"
                description={description}
                confirmLabel="Restore"
                busyLabel="Restoring…"
                tone="danger"
                onConfirm={onRestore}
                trigger={
                  <Button
                    disabled={busy}
                    className="border-danger/40 text-danger hover:bg-danger-soft"
                  >
                    Restore originals
                  </Button>
                }
              />
            }
          />
        </div>
        {report ? (
          <Notice.Root variant={report.failures.length || report.failure ? "warning" : "info"}>
            <Notice.Header onDismiss={onDismissReport}>
              <Notice.Title>
                {report.failure ? "Original files partly restored" : "Original files restored"}
              </Notice.Title>
              {report.failure ? <Notice.Description>{report.failure}</Notice.Description> : null}
              {report.lines.length || report.failures.length ? (
                <Notice.Description className="whitespace-pre-line">
                  {[...report.lines, ...report.failures].join("\n")}
                </Notice.Description>
              ) : null}
            </Notice.Header>
          </Notice.Root>
        ) : null}
      </div>
    </section>
  );
}
