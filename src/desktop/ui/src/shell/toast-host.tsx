import { CircleAlert, CircleCheck, X } from "lucide-react";

import { cn } from "~/lib/cn";
import { useStore } from "~/lib/store";

import type { Toasts } from "./toasts";

/**
 * Where action results appear, above the logs panel when it is open. The
 * live region is always mounted so screen readers hear the first toast too.
 */
export function ToastHost({ toasts, offset }: { toasts: Toasts; offset: number }) {
  const list = useStore(toasts);
  return (
    <div
      role="status"
      aria-live="polite"
      className="pointer-events-none fixed right-4 z-40 flex w-[320px] max-w-[calc(100vw-32px)] flex-col items-end gap-2 transition-[bottom] duration-200 ease-out"
      style={{ bottom: offset + 16 }}
    >
      {list.map((toast) => {
        const Icon = toast.tone === "danger" ? CircleAlert : CircleCheck;
        return (
          <div
            key={toast.id}
            className="pointer-events-auto flex max-w-full items-start transition-[opacity,translate] duration-200 ease-out starting:translate-y-1.5 starting:opacity-0 gap-2 rounded-[10px] border border-hairline bg-popover py-2 pr-1.5 pl-3 text-[12.5px] text-fg shadow-pop"
          >
            <Icon
              aria-hidden
              size={14}
              strokeWidth={2}
              className={cn(
                "mt-[2px] shrink-0",
                toast.tone === "danger" ? "text-danger" : "text-success",
              )}
            />
            <span className="min-w-0 flex-1 py-px break-words">{toast.message}</span>
            <button
              type="button"
              aria-label="Dismiss"
              onClick={() => toasts.dismiss(toast.id)}
              className="grid size-5 shrink-0 place-items-center rounded-[5px] text-fg-tertiary hover:bg-hover hover:text-fg focus-visible:ring-2 focus-visible:ring-accent focus-visible:outline-none"
            >
              <X aria-hidden size={12} strokeWidth={2} />
            </button>
          </div>
        );
      })}
    </div>
  );
}
