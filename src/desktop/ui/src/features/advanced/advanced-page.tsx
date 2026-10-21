import { Clock, Hammer, Palette, RotateCw, ShieldCheck, Square, StopCircle } from "lucide-react";
import { useState } from "react";
import type { GeneratedFileId, ServiceId } from "~/bridge/protocol";
import { PageHeader } from "~/components/layout/page-header";
import { SettingsSection } from "~/components/layout/settings-section";
import { SettingRow } from "~/components/layout/setting-row";
import { Button } from "~/components/ui/button";
import { ConfirmDialog } from "~/components/ui/confirm-dialog";
import { ActionCluster, IconButton } from "~/components/ui/icon-button";
import { Notice } from "~/components/ui/notice";
import { StatTile } from "~/components/ui/stat-tile";
import { StatusChip } from "~/components/ui/status-chip";
import { Tooltip } from "~/components/ui/tooltip";
import { useStore } from "~/lib/store";
import type { AdvancedStore } from "./advanced-store";
import { BackupTrend } from "./backup-trend";

const services: Record<ServiceId, { title: string; detail: string; stops: string }> = {
  yabai: {
    title: "Window arrangement",
    detail: "Keeps your windows arranged across the desktop.",
    stops: "automatic window arrangement and your window rules",
  },
  borders: {
    title: "Window outlines",
    detail: "Highlights the window you are working in.",
    stops: "the outline around the active window",
  },
  sketchybar: {
    title: "Menu bar",
    detail: "Shows your custom menu bar and its widgets.",
    stops: "your custom menu bar and its widgets",
  },
  skhd: {
    title: "Keyboard shortcuts",
    detail: "Responds to the keyboard shortcuts in your setup.",
    stops: "your keyboard shortcuts",
  },
};
const files: { id: GeneratedFileId; title: string }[] = [
  { id: "bordersrc", title: "Window borders" },
  { id: "yabairc", title: "Window layout" },
  { id: "sketchybarrc", title: "Menu bar" },
];
function date(created: number) {
  return new Date(created).toLocaleString("en-GB", { dateStyle: "medium", timeStyle: "short" });
}
function relative(created: number) {
  const minutes = Math.round((created - Date.now()) / 60000);
  const formatter = new Intl.RelativeTimeFormat("en-GB", { style: "narrow" });
  if (Math.abs(minutes) < 60) return formatter.format(minutes, "minute");
  if (Math.abs(minutes) < 1440) return formatter.format(Math.round(minutes / 60), "hour");
  return formatter.format(Math.round(minutes / 1440), "day");
}

// Button actions report through the store; dialogs receive the rejection too.
function action(promise: Promise<unknown>) {
  void promise.catch(() => {});
}

export function AdvancedPage({ store, openSetup }: { store: AdvancedStore; openSetup(): void }) {
  const snapshot = useStore(store);
  const [showAll, setShowAll] = useState(false);
  // The target outlives the open flag so the dialog keeps its wording while it closes.
  const [stopTarget, setStopTarget] = useState<ServiceId>("yabai");
  const [stopOpen, setStopOpen] = useState(false);
  const { state, busy } = snapshot;

  return (
    <>
      <PageHeader
        title="Advanced"
        subtitle="Keep your desktop running smoothly."
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
      {busy ? (
        <p role="status" className="text-meta text-fg-secondary">
          Working…
        </p>
      ) : null}
      {state ? (
        <>
          <div className="grid grid-cols-2 gap-3 xl:grid-cols-4">
            <StatTile
              icon={<ShieldCheck aria-hidden />}
              caption="Services"
              value={`${state.services.filter((service) => service.state === "running").length}/${state.services.length}`}
              emphasis
              tint={
                state.services.every((service) => service.state === "running") ? "green" : "orange"
              }
              detail={
                <div className="flex gap-2">
                  {state.services.map((service) => (
                    <Tooltip
                      key={service.id}
                      content={`${services[service.id].title}: ${service.state}`}
                    >
                      <span
                        className={
                          service.state === "running" ? "text-success" : "text-fg-secondary"
                        }
                      >
                        <Square aria-hidden className="size-3" />
                        <span className="sr-only">
                          {services[service.id].title}: {service.state}
                        </span>
                      </span>
                    </Tooltip>
                  ))}
                </div>
              }
            />
            <StatTile
              icon={<Clock aria-hidden />}
              caption="Backups"
              value={String(state.snapshots.length)}
              emphasis
              detail={<BackupTrend snapshots={state.snapshots} />}
            />
            <Tooltip content="Backups are kept for the last 20 changes">
              <StatTile
                icon={<RotateCw aria-hidden />}
                caption="Last backup"
                value={state.snapshots[0] ? relative(state.snapshots[0].created) : "None"}
                tint="teal"
              />
            </Tooltip>
            <StatTile
              icon={<Palette aria-hidden />}
              caption="Active theme"
              value={state.theme}
              tint="purple"
              detail={
                <span className="text-meta text-fg-secondary">
                  {state.installedThemes} installed
                </span>
              }
            />
          </div>
          <SettingsSection
            title="Desktop services"
            help="Restart a service if its feature stops responding. Stop turns that feature off."
          >
            {state.services.map((service) => (
              <SettingRow
                key={service.id}
                title={services[service.id].title}
                help={services[service.id].detail}
              >
                <div className="flex items-center gap-2">
                  <StatusChip
                    tone={service.state === "running" ? "success" : "neutral"}
                    live={service.state === "running"}
                    label={
                      service.state === "running"
                        ? "Running"
                        : service.state === "stopped"
                          ? "Stopped"
                          : "Unavailable"
                    }
                  />
                  <ActionCluster>
                    <IconButton
                      label={`Restart ${services[service.id].title.toLowerCase()}`}
                      disabled={busy}
                      onClick={() => action(store.restart(service.id))}
                    >
                      <RotateCw aria-hidden />
                    </IconButton>
                    <IconButton
                      label={`Stop ${services[service.id].title.toLowerCase()}`}
                      disabled={busy || service.state !== "running"}
                      onClick={() => {
                        setStopTarget(service.id);
                        setStopOpen(true);
                      }}
                    >
                      <StopCircle aria-hidden />
                    </IconButton>
                  </ActionCluster>
                </div>
              </SettingRow>
            ))}
          </SettingsSection>
          <ConfirmDialog
            open={stopOpen}
            onOpenChange={setStopOpen}
            title={`Stop ${services[stopTarget].title.toLowerCase()}?`}
            description={`Stopping ${stopTarget} turns off ${services[stopTarget].stops} until you restart it here.`}
            confirmLabel={`Stop ${stopTarget}`}
            busyLabel="Stopping…"
            tone="danger"
            onConfirm={() => store.stop(stopTarget)}
          />
          <SettingsSection
            title="Saved setup"
            help="Rebuild files from saved preferences. Custom edits are backed up before replacement."
          >
            {files.map((file) => (
              <SettingRow key={file.id} title={file.title}>
                <div className="flex items-center gap-2">
                  <StatusChip label={snapshot.outcomes[file.id] ?? "Not checked"} />
                  <IconButton
                    label={`Rebuild ${file.title.toLowerCase()} from preferences`}
                    disabled={busy}
                    onClick={() => action(store.rebuild(file.id))}
                  >
                    <Hammer aria-hidden />
                  </IconButton>
                </div>
              </SettingRow>
            ))}
          </SettingsSection>
          <SettingsSection
            title="Restore a previous setup"
            help="Restore replaces current settings after backing them up. Changes create backups automatically."
          >
            {!state.snapshots.length ? (
              <SettingRow
                title="No backups yet"
                detail="Your saved setups will appear here when settings change."
              />
            ) : null}
            {(showAll ? state.snapshots : state.snapshots.slice(0, 4)).map((backup) => (
              <SettingRow
                key={backup.id}
                title={date(backup.created)}
                detail={`${backup.files} saved ${backup.files === 1 ? "file" : "files"}`}
                help={backup.reason || undefined}
              >
                <ConfirmDialog
                  title="Restore a previous setup?"
                  description="Restore replaces current settings after backing them up. Changes create backups automatically."
                  confirmLabel="Restore"
                  busyLabel="Restoring…"
                  tone="danger"
                  onConfirm={() => store.restoreSnapshot(backup.id)}
                  trigger={
                    <Button
                      disabled={busy}
                      aria-label={`Restore backup from ${date(backup.created)}`}
                    >
                      Restore
                    </Button>
                  }
                />
              </SettingRow>
            ))}
            {state.snapshots.length > 4 ? (
              <div className="flex justify-center p-2">
                <Button variant="ghost" onClick={() => setShowAll(!showAll)}>
                  {showAll ? "Show fewer" : `Show all ${state.snapshots.length} backups`}
                </Button>
              </div>
            ) : null}
          </SettingsSection>
          <SettingsSection
            title="yabai extras"
            help="Optional. Macarchy works without these, with System Integrity Protection on."
          >
            <SettingRow title="Scripting addition" detail={state.additionExplanation}>
              <div className="flex items-center gap-2">
                <StatusChip
                  tone={
                    state.addition === "active"
                      ? "success"
                      : state.addition === "repair"
                        ? "warning"
                        : "neutral"
                  }
                  label={
                    state.addition === "active"
                      ? "Active"
                      : state.addition === "repair"
                        ? "Needs repair"
                        : "Not installed"
                  }
                />
                {state.addition === "repair" ? (
                  <Button disabled={busy} onClick={() => action(store.repair())}>
                    {busy ? "Repairing…" : "Repair"}
                  </Button>
                ) : null}
              </div>
            </SettingRow>
            <SettingRow
              title="Window signals"
              help="Let floating rules reach new windows and keep focus when a window closes."
            >
              <StatusChip
                tone={state.wakeHelpers ? "success" : "warning"}
                label={state.wakeHelpers ? "Active" : "Not registered"}
              />
            </SettingRow>
          </SettingsSection>
          <SettingsSection
            title="Setup"
            help="Setup backed up every file it replaced. Restoring puts them all back."
          >
            <SettingRow
              title="Run setup again"
              detail="Repairs startup files and the app link. Your edits are kept."
            >
              <Button disabled={busy} onClick={openSetup}>
                Open setup
              </Button>
            </SettingRow>
            <SettingRow
              title="Restore original files"
              detail={`Puts back the configs you had before Macarchy, in ${state.backupsDirectory}`}
            >
              <ConfirmDialog
                title="Really restore?"
                description={`Puts back the configs you had before Macarchy, in ${state.backupsDirectory}`}
                confirmLabel="Restore"
                busyLabel="Restoring…"
                tone="danger"
                onConfirm={() => store.restoreOriginals()}
                trigger={
                  <Button variant="danger" disabled={busy}>
                    Restore
                  </Button>
                }
              />
            </SettingRow>
          </SettingsSection>
          {snapshot.report ? (
            <Notice.Root variant={snapshot.report.failures.length ? "warning" : "info"}>
              <Notice.Title>Original files restored</Notice.Title>
              <Notice.Description>{snapshot.report.lines.join("\n")}</Notice.Description>
            </Notice.Root>
          ) : null}
        </>
      ) : null}
    </>
  );
}
