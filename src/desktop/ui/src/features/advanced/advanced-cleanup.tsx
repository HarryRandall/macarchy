import { Archive } from "lucide-react";

import type { CleanupPlan, CleanupReport } from "~/bridge/protocol";
import { Button } from "~/components/ui/button";
import { Card, Row } from "~/components/ui/card";
import { ConfirmDialog } from "~/components/ui/confirm-dialog";
import { IconTile } from "~/components/ui/icon-tile";
import { Notice } from "~/components/ui/notice";

/** The plan's headings and paths, as the command prints them. */
function PlanSections({ plan }: { plan: CleanupPlan }) {
  return (
    <div className="mt-2 flex max-h-80 flex-col gap-3 overflow-y-auto rounded-control border border-hairline bg-side px-3 py-2.5">
      {plan.sections.map((section) => (
        <section key={section.title} aria-label={section.title}>
          <h3 className="text-detail font-medium text-fg">{section.title}</h3>
          <ul className="mt-1 flex flex-col gap-1">
            {section.lines.map((line) => (
              <li key={line.path} className="min-w-0 text-detail">
                <span className="block font-mono break-all text-fg select-text">{line.path}</span>
                {line.detail ? (
                  <span className="block text-fg-secondary select-text">{line.detail}</span>
                ) : null}
              </li>
            ))}
          </ul>
        </section>
      ))}
    </div>
  );
}

/**
 * Cleaning up what earlier versions left in `~/.config`: review the plan,
 * confirm it, then read what was done.
 */
export function CleanupCard({
  busy,
  reviewing,
  plan,
  report,
  onReview,
  onClose,
  onCleanUp,
  onDismissReport,
}: {
  busy: boolean;
  reviewing: boolean;
  plan: CleanupPlan | null;
  report: CleanupReport | null;
  onReview: () => void;
  onClose: () => void;
  onCleanUp: () => Promise<void>;
  onDismissReport: () => void;
}) {
  return (
    <div className="flex flex-col gap-3">
      <Card>
        <Row
          title="Clean up old configuration"
          description="Moves scripts your shortcuts run out of ~/.config and deletes old files Macarchy no longer reads. Everything is archived first."
          leading={
            <IconTile variant="outline">
              <Archive strokeWidth={1.75} />
            </IconTile>
          }
          control={
            <Button busy={reviewing} disabled={busy} onClick={onReview}>
              Review
            </Button>
          }
        />
      </Card>
      <ConfirmDialog
        open={plan?.hasChanges === true}
        onOpenChange={(open) => {
          if (!open) onClose();
        }}
        size="lg"
        title="Clean up old configuration?"
        description="Everything it deletes or changes goes into one archive in Macarchy's backups first. macarchy cleanup --restore puts it back."
        confirmLabel="Clean up"
        busyLabel="Cleaning up…"
        onConfirm={onCleanUp}
      >
        {plan ? <PlanSections plan={plan} /> : null}
      </ConfirmDialog>
      {plan && !plan.hasChanges ? (
        <Notice.Root variant="info">
          <Notice.Header onDismiss={onClose}>
            <Notice.Title>{plan.refusal ? "Not yet" : "Nothing to clean up"}</Notice.Title>
            {plan.refusal ? <Notice.Description>{plan.refusal}</Notice.Description> : null}
          </Notice.Header>
          {plan.sections.length ? <PlanSections plan={plan} /> : null}
        </Notice.Root>
      ) : null}
      {report ? (
        <Notice.Root variant={report.failures.length || report.failure ? "warning" : "info"}>
          <Notice.Header onDismiss={onDismissReport}>
            <Notice.Title>
              {report.failure
                ? "Old configuration partly cleaned up"
                : "Old configuration cleaned up"}
            </Notice.Title>
            {report.failure ? <Notice.Description>{report.failure}</Notice.Description> : null}
            <Notice.Description className="whitespace-pre-line">
              {[...report.lines, ...report.failures].join("\n")}
            </Notice.Description>
          </Notice.Header>
        </Notice.Root>
      ) : null}
    </div>
  );
}
