import { ArrowLeft } from "lucide-react";
import type { ComponentProps, ReactNode, Ref } from "react";

import { Button } from "~/components/ui/button";
import { KbdGroup } from "~/components/ui/kbd";
import { cn } from "~/lib/cn";

import type { Mode } from "./switcher-model";

/** Buttons in the panel must not take focus from the search field. */
export const keepSearchFocus = {
  onMouseDown: (event: { preventDefault(): void }) => event.preventDefault(),
};

export function Divider({ vertical = false }: { vertical?: boolean }) {
  return (
    <div
      aria-hidden
      className={cn("shrink-0 bg-white/10 opacity-60", vertical ? "w-px" : "h-px")}
    />
  );
}

export function SearchBar({
  inputRef,
  onBack,
  ...input
}: ComponentProps<"input"> & { inputRef: Ref<HTMLInputElement>; onBack: () => void }) {
  return (
    <div className="flex h-[54px] shrink-0 items-center gap-3 px-4">
      <Button
        variant="translucent"
        size="icon-md"
        tabIndex={-1}
        aria-label="Back"
        onClick={onBack}
        {...keepSearchFocus}
      >
        <ArrowLeft aria-hidden strokeWidth={2.5} />
      </Button>
      <input
        ref={inputRef}
        type="text"
        autoComplete="off"
        autoCorrect="off"
        autoCapitalize="off"
        spellCheck={false}
        className="min-w-0 flex-1 bg-transparent text-[19px] text-fg outline-none placeholder:text-fg-secondary focus-visible:outline-none"
        {...input}
      />
    </div>
  );
}

export function Footer({
  primary,
  mode,
  actionsOpen,
  onActions,
}: {
  primary: string;
  /** What the panel is choosing, which the footer names. */
  mode: Mode["kind"];
  actionsOpen: boolean;
  onActions: () => void;
}) {
  return (
    <div className="flex h-10 shrink-0 items-center gap-2.5 px-3 text-[13px]">
      <img src="./app-icon.png" alt="" draggable={false} className="size-5" />
      <span className="text-fg-secondary">
        {mode === "backgrounds" ? "Switch Background" : "Switch Theme"}
      </span>
      <span className="ml-auto font-semibold text-fg">{primary}</span>
      <KbdGroup keys={["↵"]} label="Return" />
      <span aria-hidden className="h-3.5 w-px bg-white/15" />
      <Button
        variant="bar"
        size="inline"
        tabIndex={-1}
        aria-expanded={actionsOpen}
        aria-keyshortcuts="Meta+K"
        onClick={onActions}
        {...keepSearchFocus}
        className="gap-2"
      >
        Actions
        <KbdGroup keys={["⌘", "K"]} label="Command K" />
      </Button>
    </div>
  );
}

/**
 * The selected row's wash. A tenth of white is its only sign, which Increase
 * Contrast asks to be stronger and drawn as an edge too.
 */
export const selectedEdge =
  "bg-white/10 contrast-more:bg-white/20 contrast-more:outline contrast-more:-outline-offset-1 contrast-more:outline-white/70";

/** One list row: icon, title, and right-aligned accessories. */
export function SwitcherRow({
  selected,
  icon,
  title,
  accessories,
  ...props
}: Omit<ComponentProps<"div">, "title"> & {
  selected: boolean;
  icon: ReactNode;
  title: ReactNode;
  accessories: ReactNode;
}) {
  return (
    // oxlint-disable-next-line jsx-a11y/click-events-have-key-events, jsx-a11y/interactive-supports-focus -- reached through the search field's aria-activedescendant; the field keeps focus and handles the keys.
    <div
      role="option"
      aria-selected={selected}
      {...keepSearchFocus}
      className={cn(
        "flex h-[38px] shrink-0 items-center gap-2.5 rounded-control px-2 text-[14px] font-medium text-fg",
        // Selection moves at once, as the keyboard expects; only the pointer's
        // lighter wash eases, drawn beneath the row's content.
        "relative isolate before:absolute before:inset-0 before:-z-10 before:rounded-control before:bg-white/5 before:opacity-0 before:transition-opacity before:ease-hover hover:not-aria-selected:before:opacity-100",
        selected && selectedEdge,
      )}
      {...props}
    >
      <span className="flex w-[22px] shrink-0 items-center justify-center">{icon}</span>
      <span className="min-w-0 flex-1 truncate">{title}</span>
      <span className="flex shrink-0 items-center gap-3 pl-1.5 whitespace-nowrap">
        {accessories}
      </span>
    </div>
  );
}
