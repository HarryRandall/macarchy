import { Check, Search } from "lucide-react";
import { type KeyboardEvent, useId, useState } from "react";

import { AppIcon } from "~/components/ui/app-icon";
import { cn } from "~/lib/cn";

import { matchApps } from "./rule-apps";

/**
 * A search field over a list of apps, for choosing one. The arrow keys move
 * through the matches from the field and Return picks, as a combobox does.
 * Options are buttons only for the pointer; they stay out of the Tab order.
 */
export function AppPicker({
  apps,
  icons,
  value,
  onPick,
  onCancel,
}: {
  apps: readonly string[];
  icons: Readonly<Record<string, string>>;
  value: string;
  onPick: (app: string) => void;
  /** Escape in the field, when an app is already chosen. */
  onCancel?: () => void;
}) {
  const [query, setQuery] = useState("");
  const [cursor, setCursor] = useState(0);
  const id = useId();
  const matches = matchApps(apps, query);
  const active = Math.min(cursor, Math.max(0, matches.length - 1));
  const optionId = (index: number) => `${id}-option-${index}`;

  const onKeyDown = (event: KeyboardEvent<HTMLInputElement>) => {
    if (event.key === "ArrowDown" || event.key === "ArrowUp") {
      event.preventDefault();
      const step = event.key === "ArrowDown" ? 1 : -1;
      setCursor(Math.min(Math.max(active + step, 0), Math.max(0, matches.length - 1)));
    } else if (event.key === "Enter") {
      event.preventDefault();
      const app = matches[active];
      if (app) onPick(app);
    } else if (event.key === "Escape" && (query || onCancel)) {
      // Clears the search, then closes the list, before Escape reaches the dialog.
      event.stopPropagation();
      event.preventDefault();
      if (query) setQuery("");
      else onCancel?.();
    }
  };

  return (
    <div className="overflow-hidden rounded-tile border border-hairline bg-card">
      <label className="flex h-[34px] items-center gap-2 border-b border-hairline px-2.5">
        <Search aria-hidden className="size-3.5 shrink-0 text-fg-tertiary" />
        <input
          role="combobox"
          aria-label="Search apps"
          aria-expanded
          aria-controls={`${id}-list`}
          aria-autocomplete="list"
          aria-activedescendant={matches.length ? optionId(active) : undefined}
          value={query}
          placeholder="Search apps"
          spellCheck={false}
          autoCapitalize="off"
          autoCorrect="off"
          onChange={(event) => {
            setQuery(event.target.value);
            setCursor(0);
          }}
          onKeyDown={onKeyDown}
          className="w-full min-w-0 bg-transparent text-body text-fg outline-none placeholder:text-fg-tertiary"
        />
      </label>
      <div
        id={`${id}-list`}
        role="listbox"
        aria-label="Apps"
        className="max-h-[188px] overflow-y-auto p-1"
      >
        {matches.map((app, index) => (
          <button
            key={app}
            id={optionId(index)}
            type="button"
            role="option"
            tabIndex={-1}
            aria-selected={app === value}
            onMouseDown={(event) => event.preventDefault()}
            onMouseEnter={() => setCursor(index)}
            onClick={() => onPick(app)}
            className={cn(
              "flex h-9 w-full items-center gap-2.5 rounded-small px-2 text-left",
              index === active ? "bg-hover" : "hover:bg-hover",
            )}
          >
            <AppIcon src={icons[app]} name={app} size={24} />
            <span className="min-w-0 flex-1 truncate text-detail font-medium text-fg">{app}</span>
            <span className="grid w-3 shrink-0 place-items-center">
              {app === value ? (
                <Check aria-hidden className="size-3 text-accent-text" strokeWidth={2.5} />
              ) : null}
            </span>
          </button>
        ))}
        {matches.length === 0 ? (
          <p className="px-2 py-3 text-small text-fg-secondary">
            {query ? `No app matches "${query.trim()}"` : "No apps to choose from"}
          </p>
        ) : null}
      </div>
    </div>
  );
}
