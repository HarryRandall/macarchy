import { useState } from "react";

import type { ShortcutBinding } from "~/bridge/protocol";
import { CardContent, SettingsSection } from "~/components/layout/settings-section";
import { SettingRow } from "~/components/layout/setting-row";
import { Button } from "~/components/ui/button";
import { Dialog } from "~/components/ui/dialog";
import { KbdGroup } from "~/components/ui/kbd";
import { Notice } from "~/components/ui/notice";
import { Tooltip } from "~/components/ui/tooltip";
import { useStore } from "~/lib/store";

import { recordedChord, shortcutLabel } from "./shortcut-presentation";
import type { ShortcutsStore } from "./shortcuts-store";

export function ShortcutDetails({ binding }: { binding: ShortcutBinding }) {
  return (
    <>
      {binding.command ? (
        <p className="font-mono text-mono-detail break-all select-text">{binding.command}</p>
      ) : null}
      {binding.appOverrides.map((entry, index) => (
        <div key={index}>
          <p className="text-meta">{entry.app === "*" ? "Other apps" : entry.app}</p>
          <p className="font-mono text-mono-detail break-all select-text">{entry.command}</p>
        </div>
      ))}
      {binding.passthrough ? (
        <p className="text-meta text-fg-secondary">Also sent to the focused app</p>
      ) : null}
    </>
  );
}

export function ShortcutEditor({ store }: { store: ShortcutsStore }) {
  const snapshot = useStore(store);
  const [recording, setRecording] = useState(false);
  const [confirmingDisable, setConfirmingDisable] = useState(false);
  const draft = snapshot.draft;
  if (!draft) return null;
  const binding = draft.binding;
  const changed =
    draft.chord.key !== binding.key ||
    draft.chord.modifiers.toSorted().join() !== binding.modifiers.toSorted().join();
  const caps = draft.validation?.caps ?? binding.caps;
  const conflicts = draft.validation?.conflicts ?? [];
  const conflict = snapshot.state?.bindings.find((item) => conflicts.includes(item.id));
  const label = shortcutLabel(binding, snapshot.state?.bindings ?? [binding]);
  return (
    <Dialog.Root
      open
      onOpenChange={(open) => {
        if (!open) store.close();
      }}
      dismissOnEscape={!recording && !snapshot.busy}
      dismissOnOutsidePress={false}
    >
      <Dialog.Popup className="h-[560px]">
        <Dialog.Header closable={!snapshot.busy} actions={<KbdGroup variant="key" keys={caps} />}>
          <Dialog.Title>Edit shortcut</Dialog.Title>
          <Dialog.Description>{label}</Dialog.Description>
        </Dialog.Header>
        <Dialog.Body>
          <SettingsSection
            title="Key combination"
            help="Record a new combination, then Save to update the shortcut."
          >
            <CardContent>
              <Button
                aria-label="Record key combination"
                aria-pressed={recording}
                disabled={snapshot.busy || snapshot.external}
                className="h-auto min-h-10 w-full justify-between py-2"
                onClick={() => setRecording(!recording)}
                onBlur={() => setRecording(false)}
                onKeyDown={(event) => {
                  if (!recording) return;
                  event.preventDefault();
                  event.stopPropagation();
                  if (
                    event.key === "Escape" &&
                    !event.metaKey &&
                    !event.altKey &&
                    !event.ctrlKey &&
                    !event.shiftKey
                  ) {
                    setRecording(false);
                    return;
                  }
                  const chord = recordedChord(event.nativeEvent);
                  if (chord) {
                    setRecording(false);
                    void store.record(chord);
                  }
                }}
              >
                {recording ? "Press a key combination…" : <KbdGroup variant="key" keys={caps} />}
                <span className="text-meta text-fg-secondary">
                  {recording ? "Esc to cancel" : "Change"}
                </span>
              </Button>
              {draft.validating ? (
                <p role="status" className="text-meta">
                  Checking combination…
                </p>
              ) : null}
              {changed && draft.validation ? (
                <div className="flex items-center gap-2">
                  <KbdGroup variant="key" keys={binding.caps} />
                  <span aria-label="changes to">→</span>
                  <KbdGroup variant="key" keys={caps} />
                </div>
              ) : null}
              {draft.validation ? (
                <p className="font-mono text-mono-detail text-fg-secondary">
                  {draft.validation.spec}
                </p>
              ) : null}
              {conflict ? (
                <p role="alert" className="text-meta text-warning">
                  Already used by {conflict.section || "another shortcut"}
                </p>
              ) : null}
              {draft.validationError ? (
                <p role="alert" className="text-meta text-danger">
                  {draft.validationError}
                </p>
              ) : null}
              <p className="text-meta text-fg-secondary">
                Some system shortcuts may be intercepted by macOS and never reach this recorder.
              </p>
            </CardContent>
          </SettingsSection>
          <SettingsSection title="What it does">
            {!binding.command ? (
              <SettingRow
                title="Different per app"
                help="Runs a different command in each app below."
              />
            ) : null}
            <CardContent>
              <ShortcutDetails binding={binding} />
            </CardContent>
            {binding.section ? (
              <SettingRow title="Group">
                <span className="text-meta text-fg-secondary">{binding.section}</span>
              </SettingRow>
            ) : null}
          </SettingsSection>
          {snapshot.external ? (
            <Notice.Root variant="warning">
              <Notice.Title>skhdrc changed since it was read</Notice.Title>
              <Notice.Description>
                Your recording has been kept. Cancel and reopen this shortcut to review the current
                file before saving.
              </Notice.Description>
            </Notice.Root>
          ) : null}
          {snapshot.error ? (
            <Notice.Root variant="error">
              <Notice.Description>{snapshot.error}</Notice.Description>
            </Notice.Root>
          ) : null}
        </Dialog.Body>
        <Dialog.Footer
          leading={
            <Tooltip content="Comment this shortcut out, keeping it in the file">
              <Button
                variant="ghost"
                className="text-danger"
                disabled={snapshot.busy || snapshot.external}
                onClick={() => {
                  if (confirmingDisable) void store.disable();
                  else setConfirmingDisable(true);
                }}
              >
                {confirmingDisable ? "Really disable?" : "Disable"}
              </Button>
            </Tooltip>
          }
        >
          <Button disabled={snapshot.busy} onClick={() => store.close()}>
            Cancel
          </Button>
          <Tooltip
            content={
              conflicts.length
                ? "Another shortcut already uses this combination"
                : "Write this combination and restart the service"
            }
          >
            <Button
              variant="primary"
              disabled={
                !changed ||
                !draft.validation ||
                draft.validating ||
                !!conflicts.length ||
                snapshot.busy ||
                snapshot.external
              }
              onClick={() => void store.save()}
            >
              {snapshot.busy ? "Saving…" : "Save"}
            </Button>
          </Tooltip>
        </Dialog.Footer>
      </Dialog.Popup>
    </Dialog.Root>
  );
}
