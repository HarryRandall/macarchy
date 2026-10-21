import { AlertDialog } from "@base-ui/react/alert-dialog";
import { type ReactElement, type ReactNode, useRef, useState } from "react";

import { Button } from "./button";
import { dialogBackdropClass, dialogVariants } from "./dialog";
import { InlineStatus } from "./inline-status";

type ConfirmDialogProps = {
  title: string;
  /** What will happen and how to undo it, such as where the backup goes. */
  description: ReactNode;
  /** Say the action: "Restore", "Delete theme", "Reset shortcuts". Never "OK". */
  confirmLabel: string;
  /** Shown on the confirm button while `onConfirm` runs, such as "Restoring…". */
  busyLabel?: string;
  cancelLabel?: string;
  /** `danger` paints the confirm button red and focuses Cancel first. */
  tone?: "default" | "danger";
  /**
   * Runs the action. A returned promise keeps the dialog open and busy until
   * it settles: it closes on success, and on failure stays open with the
   * error's message so the person can retry or cancel.
   */
  onConfirm: () => void | Promise<void>;
  /** The control that opens it. Omit it and pass `open` to control it yourself. */
  trigger?: ReactElement;
  open?: boolean;
  onOpenChange?: (open: boolean) => void;
};

function message(error: unknown) {
  return error instanceof Error ? error.message : String(error);
}

/**
 * Asks before something hard to undo: restoring original files, deleting a
 * theme, resetting to defaults. Only the buttons answer it; a click outside
 * does nothing, and Escape cancels unless the action is already running.
 */
function ConfirmDialog({
  title,
  description,
  confirmLabel,
  busyLabel,
  cancelLabel = "Cancel",
  tone = "default",
  onConfirm,
  trigger,
  open: controlledOpen,
  onOpenChange,
}: ConfirmDialogProps) {
  const [uncontrolledOpen, setUncontrolledOpen] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const cancelRef = useRef<HTMLButtonElement>(null);
  const open = controlledOpen ?? uncontrolledOpen;

  function setOpen(next: boolean) {
    if (controlledOpen === undefined) setUncontrolledOpen(next);
    onOpenChange?.(next);
  }

  async function confirm() {
    setError(null);
    setBusy(true);
    try {
      await onConfirm();
      setOpen(false);
    } catch (failure) {
      setError(message(failure));
    } finally {
      setBusy(false);
    }
  }

  return (
    <AlertDialog.Root
      open={open}
      onOpenChange={(next, details) => {
        if (!next && busy) {
          details.cancel();
          return;
        }
        setOpen(next);
      }}
      onOpenChangeComplete={(next) => {
        if (!next) setError(null);
      }}
    >
      {trigger ? <AlertDialog.Trigger render={trigger} /> : null}
      <AlertDialog.Portal>
        <AlertDialog.Backdrop className={dialogBackdropClass} />
        <AlertDialog.Viewport className="fixed inset-0 z-50 flex items-center justify-center p-6">
          <AlertDialog.Popup
            data-slot="confirm-dialog"
            initialFocus={tone === "danger" ? cancelRef : true}
            className={dialogVariants({ size: "sm" })}
          >
            <div className="flex flex-col gap-1.5 px-5 pt-5 pb-4">
              <AlertDialog.Title className="text-card-title text-fg">{title}</AlertDialog.Title>
              <AlertDialog.Description className="text-detail text-fg-secondary select-text">
                {description}
              </AlertDialog.Description>
              {error ? (
                <InlineStatus tone="danger" className="pt-1">
                  {error}
                </InlineStatus>
              ) : null}
            </div>
            <div className="flex items-center justify-end gap-2 border-t border-hairline bg-side px-5 py-3">
              <AlertDialog.Close ref={cancelRef} disabled={busy} render={<Button />}>
                {cancelLabel}
              </AlertDialog.Close>
              <Button
                variant={tone === "danger" ? "danger" : "primary"}
                busy={busy}
                onClick={() => void confirm()}
              >
                {busy ? (busyLabel ?? confirmLabel) : confirmLabel}
              </Button>
            </div>
          </AlertDialog.Popup>
        </AlertDialog.Viewport>
      </AlertDialog.Portal>
    </AlertDialog.Root>
  );
}

export { ConfirmDialog };
