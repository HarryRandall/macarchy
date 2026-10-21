import { ArrowLeft } from "lucide-react";
import type { ComponentProps, ReactNode, Ref } from "react";

import { KbdGroup } from "~/components/ui/kbd";
import { cn } from "~/lib/cn";

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
      <button
        type="button"
        tabIndex={-1}
        aria-label="Back"
        onClick={onBack}
        {...keepSearchFocus}
        className="flex size-[26px] shrink-0 items-center justify-center rounded-small bg-white/10 text-fg transition-colors hover:bg-white/15"
      >
        <ArrowLeft aria-hidden className="size-[15px]" strokeWidth={2.5} />
      </button>
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
  actionsOpen,
  onActions,
}: {
  primary: string;
  actionsOpen: boolean;
  onActions: () => void;
}) {
  return (
    <div className="flex h-10 shrink-0 items-center gap-2.5 px-3 text-[13px]">
      <img src="./app-icon.png" alt="" draggable={false} className="size-5" />
      <span className="text-fg-secondary">Switch Theme</span>
      <span className="ml-auto font-semibold text-fg">{primary}</span>
      <KbdGroup keys={["↵"]} label="Return" />
      <span aria-hidden className="h-3.5 w-px bg-white/15" />
      <button
        type="button"
        tabIndex={-1}
        aria-expanded={actionsOpen}
        aria-keyshortcuts="Meta+K"
        onClick={onActions}
        {...keepSearchFocus}
        className="flex items-center gap-2 rounded-small text-fg-secondary transition-colors hover:text-fg"
      >
        Actions
        <KbdGroup keys={["⌘", "K"]} label="Command K" />
      </button>
    </div>
  );
}

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
        selected && "bg-white/10",
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
