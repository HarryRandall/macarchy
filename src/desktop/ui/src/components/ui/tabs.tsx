import { type ComponentProps, type KeyboardEvent, useRef } from "react";

import { cn } from "~/lib/cn";

import { focusRing } from "./focus-ring";
import { rovingIndex } from "./roving";

interface TabItem<T extends string> {
  id: T;
  label: string;
  /** A count after the label, such as the items in that view. */
  count?: number;
  disabled?: boolean;
}

const tabId = (group: string, id: string) => `${group}-tab-${id}`;
const panelId = (group: string, id: string) => `${group}-panel-${id}`;

/**
 * Views of one page, underlined: Installed, Discover. One tab stop for the
 * row; the arrow keys move between tabs and choose as they go, Home and End
 * jump. With `id`, each tab controls the `TabPanel` that shares it.
 */
function Tabs<T extends string>({
  tabs,
  value,
  onChange,
  label,
  id,
  className,
}: {
  tabs: readonly TabItem<T>[];
  value: T;
  onChange: (value: T) => void;
  /** Names the row for VoiceOver: "Plugin views". */
  label?: string;
  /** Ties each tab to its panel; pass the same to `TabPanel`. */
  id?: string;
  className?: string;
}) {
  const refs = useRef<(HTMLButtonElement | null)[]>([]);
  const selected = Math.max(
    0,
    tabs.findIndex((tab) => tab.id === value),
  );

  const onKeyDown = (event: KeyboardEvent<HTMLButtonElement>, index: number) => {
    const next = rovingIndex(
      index,
      event.key,
      tabs.map((tab) => !tab.disabled),
    );
    const tab = next === undefined ? undefined : tabs[next];
    if (next === undefined || !tab) return;
    event.preventDefault();
    refs.current[next]?.focus();
    onChange(tab.id);
  };

  return (
    <div
      role="tablist"
      aria-label={label}
      data-slot="tabs"
      className={cn("flex gap-5 border-b border-hairline", className)}
    >
      {tabs.map((tab, index) => {
        const on = index === selected;
        return (
          <button
            key={tab.id}
            ref={(element) => {
              refs.current[index] = element;
            }}
            type="button"
            role="tab"
            id={id ? tabId(id, tab.id) : undefined}
            aria-controls={id ? panelId(id, tab.id) : undefined}
            aria-selected={on}
            tabIndex={on ? 0 : -1}
            disabled={tab.disabled}
            onClick={() => onChange(tab.id)}
            onKeyDown={(event) => onKeyDown(event, index)}
            className={cn(
              "relative -mb-px flex items-center gap-1.5 rounded-t-[4px] border-b-2 pb-2.5 text-body font-medium whitespace-nowrap transition-colors duration-150",
              "disabled:pointer-events-none disabled:opacity-50",
              focusRing,
              on ? "border-fg text-fg" : "border-transparent text-fg-secondary hover:text-fg",
            )}
          >
            {tab.label}
            {tab.count === undefined ? null : (
              <span className="rounded-key bg-muted px-1.5 text-caption text-fg-secondary tabular-nums">
                {tab.count}
              </span>
            )}
          </button>
        );
      })}
    </div>
  );
}

/** The content a tab shows. Render only the chosen one; `tabs` is the `Tabs` id. */
function TabPanel({
  tabs,
  value,
  className,
  ...props
}: ComponentProps<"div"> & { tabs: string; value: string }) {
  return (
    <div
      role="tabpanel"
      id={panelId(tabs, value)}
      aria-labelledby={tabId(tabs, value)}
      // A stop after the tab row, so Tab reaches the panel even when it holds no control.
      tabIndex={0}
      data-slot="tab-panel"
      className={cn("rounded-small", focusRing, className)}
      {...props}
    />
  );
}

export { type TabItem, TabPanel, Tabs };
