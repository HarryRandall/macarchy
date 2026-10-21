import { ArrowRight } from "lucide-react";
import { type ReactNode, useState } from "react";

import type { ShortcutBinding } from "~/bridge/protocol";
import { Button } from "~/components/ui/button";
import { Dialog } from "~/components/ui/dialog";
import { focusRing } from "~/components/ui/focus-ring";
import { HelpTooltip } from "~/components/ui/help-tooltip";
import { InlineStatus } from "~/components/ui/inline-status";
import { KbdGroup } from "~/components/ui/kbd";
import { Notice } from "~/components/ui/notice";
import { Tooltip } from "~/components/ui/tooltip";
import { cn } from "~/lib/cn";
import { useStore } from "~/lib/store";

import { recordedChord, shortcutLabel } from "./shortcut-presentation";
import type { ShortcutsStore } from "./shortcuts-store";

export function ShortcutDetails({ binding }: { binding: ShortcutBinding }) {
  return (
    <>
      {binding.command ? (
        <p className="font-mono text-mono-detail break-all text-fg select-text">
          {binding.command}
        </p>
      ) : null}
      {binding.appOverrides.map((entry, index) => (
        <div key={index}>
          <p className="text-meta text-fg-secondary">
            {entry.app === "*" ? "Other apps" : entry.app}
          </p>
          <p className="font-mono text-mono-detail break-all text-fg select-text">
            {entry.command}
          </p>
        </div>
      ))}
      {binding.passthrough ? (
        <p className="text-meta text-fg-secondary">Also sent to the focused app</p>
      ) : null}
    </>
  );
}

function Section({ title, help, children }: { title: string; help?: string; children: ReactNode }) {
  return (
    <section className="flex flex-col gap-2">
      <div className="flex items-center gap-1">
        <h3 className="text-small font-medium text-fg">{title}</h3>
        {help ? <HelpTooltip text={help} /> : null}
      </div>
      {children}
    </section>
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
      <Dialog.Popup>
        <Dialog.Header closable={!snapshot.busy} actions={<KbdGroup variant="key" keys={caps} />}>
          <Dialog.Title>Edit shortcut</Dialog.Title>
          <Dialog.Description>{label}</Dialog.Description>
        </Dialog.Header>
        <Dialog.Body>
          <Section
            title="Key combination"
            help="Record a new combination, then Save to update the shortcut. Some system shortcuts are taken by macOS before they reach the recorder."
          >
            <button
              type="button"
              aria-label="Record key combination"
              aria-pressed={recording}
              disabled={snapshot.busy || snapshot.external}
              className={cn(
                "flex min-h-10 w-full items-center justify-between gap-3 rounded-control border px-3 py-2 text-left transition-colors disabled:pointer-events-none disabled:opacity-50",
                recording
                  ? "border-dashed border-accent bg-accent-soft text-accent-text"
                  : "border-hairline bg-card shadow-card hover:bg-hover",
                focusRing,
              )}
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
              {recording ? (
                <span className="flex items-center gap-2 text-detail">
                  <span
                    aria-hidden
                    className="size-2 rounded-full bg-accent animate-status-pulse"
                  />
                  Press a key combination…
                </span>
              ) : (
                <KbdGroup variant="key" keys={caps} />
              )}
              <span className="text-meta text-fg-tertiary">
                {recording ? "Esc to cancel" : "Change"}
              </span>
            </button>
            {draft.validating ? (
              <InlineStatus icon={false}>Checking combination…</InlineStatus>
            ) : null}
            {changed && draft.validation ? (
              <div className="flex items-center gap-2">
                <KbdGroup variant="key" keys={binding.caps} />
                <ArrowRight aria-hidden className="size-3.5 text-fg-tertiary" />
                <span className="sr-only">changes to</span>
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
              <InlineStatus tone="danger">{draft.validationError}</InlineStatus>
            ) : null}
          </Section>
          <Section
            title={binding.command ? "What it does" : "Different per app"}
            help={binding.command ? undefined : "Runs a different command in each app below."}
          >
            <div className="flex flex-col gap-2 rounded-tile border border-hairline bg-side px-3 py-2.5">
              <ShortcutDetails binding={binding} />
              {binding.section ? (
                <p className="text-meta text-fg-secondary">Group: {binding.section}</p>
              ) : null}
            </div>
          </Section>
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
                size="sm"
                variant="ghost"
                className="text-danger hover:text-danger"
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
          <Button size="sm" disabled={snapshot.busy} onClick={() => store.close()}>
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
              size="sm"
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
