import { Search, X } from "lucide-react";
import { type ComponentProps, type ReactNode, useRef } from "react";

import { cn } from "~/lib/cn";

import { Tooltip } from "./tooltip";

type SearchFieldProps = Omit<ComponentProps<"input">, "value" | "onChange" | "type" | "size"> & {
  value: string;
  onValueChange: (value: string) => void;
  /** The accessible name, such as "Find a shortcut". The placeholder defaults to it. */
  label: string;
  /** Help on hover, such as what the search looks through. */
  help?: string;
  /** Trailing content while empty, such as the ⌘K hint. */
  hint?: ReactNode;
};

/**
 * The one search field: a magnifier, the query and a clear button. Escape
 * clears it first and only then reaches a dialog behind it. Size it with a
 * width class; it fills its container by default.
 */
function SearchField({
  value,
  onValueChange,
  label,
  help,
  hint,
  placeholder,
  className,
  onKeyDown,
  ...props
}: SearchFieldProps) {
  const inputRef = useRef<HTMLInputElement>(null);
  return (
    <div
      data-slot="search-field"
      className={cn(
        "flex h-8 w-full min-w-0 items-center gap-2 rounded-control border border-hairline bg-side px-2.5",
        "transition-[border-color,box-shadow] hover:border-line-strong focus-within:border-accent focus-within:ring-[3px] focus-within:ring-accent-soft",
        "has-disabled:opacity-50",
        className,
      )}
    >
      <Search aria-hidden className="size-3.5 shrink-0 text-fg-tertiary" strokeWidth={2} />
      <Tooltip content={help ?? ""} disabled={!help}>
        <input
          ref={inputRef}
          type="search"
          aria-label={label}
          placeholder={placeholder ?? label}
          value={value}
          onChange={(event) => onValueChange(event.currentTarget.value)}
          onKeyDown={(event) => {
            if (event.key === "Escape" && value !== "") {
              event.preventDefault();
              event.stopPropagation();
              onValueChange("");
            }
            onKeyDown?.(event);
          }}
          spellCheck={false}
          autoCapitalize="off"
          autoCorrect="off"
          className="h-full min-w-0 flex-1 bg-transparent text-body text-fg outline-none placeholder:text-fg-tertiary focus-visible:outline-none [&::-webkit-search-cancel-button]:appearance-none"
          {...props}
        />
      </Tooltip>
      {value ? (
        <button
          type="button"
          aria-label="Clear search"
          onClick={() => {
            onValueChange("");
            inputRef.current?.focus();
          }}
          className="-mr-1 grid size-5 shrink-0 place-items-center rounded-small text-fg-tertiary transition-colors outline-none hover:bg-hover hover:text-fg focus-visible:ring-2 focus-visible:ring-accent"
        >
          <X aria-hidden className="size-3" strokeWidth={2.25} />
        </button>
      ) : (
        hint
      )}
    </div>
  );
}

export { SearchField };
