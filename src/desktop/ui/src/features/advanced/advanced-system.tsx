import { Hand, Power, RotateCcw, SquareTerminal, Wand } from "lucide-react";
import { useState } from "react";

import type { AdvancedState, SetupReport } from "~/bridge/protocol";
import { Badge } from "~/components/ui/badge";
import { Button } from "~/components/ui/button";
import { Card, CardHeader, CardRows, Row, SectionLabel } from "~/components/ui/card";
import { Checkbox } from "~/components/ui/checkbox";
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

const loginDescription = {
  on: null,
  off: null,
  approval: "Allow Macarchy in System Settings, under General → Login Items.",
  unavailable: "Development copies never open at login.",
} as const;

/** Opening Macarchy at login, which keeps the bar's widgets updating. */
export function LoginCard({
  state,
  busy,
  onChange,
  onOpenSettings,
}: {
  state: AdvancedState["loginItem"];
  busy: boolean;
  onChange: (enabled: boolean) => void;
  onOpenSettings: () => void;
}) {
  return (
    <Card>
      <Row
        title="Open at login"
        help="The bar's widgets update while Macarchy runs. Without it, they keep their last values until Macarchy opens."
        description={loginDescription[state]}
        leading={
          <IconTile variant="outline">
            <Power strokeWidth={1.75} />
          </IconTile>
        }
        control={
          <>
            {state === "approval" ? (
              <Button size="sm" disabled={busy} onClick={onOpenSettings}>
                Open Login Items
              </Button>
            ) : null}
            <Switch
              aria-label="Open Macarchy at login"
              checked={state === "on" || state === "approval"}
              disabled={busy || state === "unavailable"}
              onCheckedChange={onChange}
            />
          </>
        }
      />
    </Card>
  );
}

/** Instant trackpad swipes between desktops, which are off unless turned on. */
export function TrackpadSwipesCard({
  enabled,
  busy,
  onChange,
}: {
  enabled: boolean;
  busy: boolean;
  onChange: (enabled: boolean) => void;
}) {
  return (
    <Card>
      <Row
        title="Instant trackpad swipes"
        help="Swiping between desktops with three fingers switches at once instead of sliding. Swipes in Mission Control slide as usual. Needs Macarchy allowed under Accessibility, and only works while Macarchy is open."
        leading={
          <IconTile variant="outline">
            <Hand strokeWidth={1.75} />
          </IconTile>
        }
        control={
          <Switch
            aria-label="Switch desktops at once when swiping"
            checked={enabled}
            disabled={busy}
            onCheckedChange={onChange}
          />
        }
      />
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
  removableTools,
  busy,
  report,
  onRestore,
  onDismissReport,
}: {
  directory: string;
  /** Tools Macarchy installed, offered for removal, unticked to begin with. */
  removableTools: AdvancedState["removableTools"];
  busy: boolean;
  report: SetupReport | null;
  onRestore: (removeTools: string[]) => Promise<void>;
  onDismissReport: () => void;
}) {
  const [removing, setRemoving] = useState<string[]>([]);
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
                onConfirm={() => onRestore(removing)}
                onOpenChange={(open) => {
                  if (open) setRemoving([]);
                }}
                trigger={
                  <Button
                    disabled={busy}
                    className="border-danger/40 text-danger hover:bg-danger-soft"
                  >
                    Restore originals
                  </Button>
                }
              >
                {removableTools.length ? (
                  <fieldset className="flex flex-col gap-2">
                    <legend className="mb-2 text-detail text-fg-secondary">
                      Macarchy installed these with Homebrew. Also remove:
                    </legend>
                    {removableTools.map((tool) => (
                      <label key={tool.id} className="flex items-center gap-2 text-body text-fg">
                        <Checkbox
                          checked={removing.includes(tool.id)}
                          onCheckedChange={(checked) =>
                            setRemoving((current) =>
                              checked
                                ? [...current, tool.id]
                                : current.filter((id) => id !== tool.id),
                            )
                          }
                        />
                        {tool.name}
                      </label>
                    ))}
                  </fieldset>
                ) : null}
              </ConfirmDialog>
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
