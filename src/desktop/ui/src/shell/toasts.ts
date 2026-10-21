import { createListeners } from "~/lib/store";

type ToastTone = "success" | "danger";

interface Toast {
  id: number;
  message: string;
  tone: ToastTone;
}

/** Failures stay long enough to read twice; the log keeps them after that. */
const duration: Record<ToastTone, number> = { success: 2600, danger: 6000 };
const visible = 3;

/** Short results of actions, such as "yabai restarted". The newest is last. */
export function createToasts() {
  const listeners = createListeners();
  const timers = new Map<number, ReturnType<typeof setTimeout>>();
  let toasts: readonly Toast[] = [];
  let next = 1;

  function forget(id: number) {
    clearTimeout(timers.get(id));
    timers.delete(id);
  }

  function dismiss(id: number) {
    forget(id);
    toasts = toasts.filter((toast) => toast.id !== id);
    listeners.notify();
  }

  return {
    subscribe: listeners.subscribe,
    getSnapshot: () => toasts,
    push(message: string, tone: ToastTone = "success") {
      const id = next++;
      const kept = toasts.slice(-(visible - 1));
      for (const dropped of toasts.slice(0, toasts.length - kept.length)) forget(dropped.id);
      toasts = [...kept, { id, message, tone }];
      timers.set(
        id,
        setTimeout(() => dismiss(id), duration[tone]),
      );
      listeners.notify();
    },
    dismiss,
  };
}

export type Toasts = ReturnType<typeof createToasts>;
