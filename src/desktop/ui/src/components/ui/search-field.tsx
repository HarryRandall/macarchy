import { CircleX, Search } from "lucide-react";
import { type ComponentProps, useRef } from "react";

import { cn } from "~/lib/cn";

import { Tooltip } from "./tooltip";

type SearchFieldProps = Omit<ComponentProps<"input">, "value" | "onChange" | "type" | "size"> & {
  value: string;
  onValueChange: (value: string) => void;
  /** The accessible name, such as "Find a shortcut". The placeholder defaults to it. */
  label: string;
  /** Help on hover, such as what the search looks through. */
  help?: string;
};

/**
 * The one search field: a capsule with a magnifier and a clear button.
 * Escape clears it first and only then reaches a dialog behind it. Size it
 * with a width class; it fills its container by default.
 */
function SearchField({
  value,
  onValueChange,
  label,
  help,
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
        "flex h-7 w-full min-w-0 items-center gap-2 rounded-full border border-hairline bg-well px-3",
        "transition-[border-color,box-shadow] focus-within:border-accent-stroke focus-within:shadow-[0_0_0_1px_var(--accent-stroke)]",
        "has-disabled:opacity-45",
        className,
      )}
    >
      <Search aria-hidden className="size-3 shrink-0 text-fg-secondary" strokeWidth={2.25} />
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
          className="h-full min-w-0 flex-1 bg-transparent text-row-title text-fg outline-none placeholder:text-fg-secondary focus-visible:outline-none [&::-webkit-search-cancel-button]:appearance-none"
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
          className="-mr-1.5 flex size-5 shrink-0 items-center justify-center rounded-full text-fg-secondary transition-colors hover:text-fg"
        >
          <CircleX aria-hidden className="size-3.5" />
        </button>
      ) : null}
    </div>
  );
}

export { SearchField };
