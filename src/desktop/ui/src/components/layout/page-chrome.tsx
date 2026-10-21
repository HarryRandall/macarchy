import {
  createContext,
  type Context,
  type ReactNode,
  useContext,
  useEffect,
  useState,
} from "react";
import { createPortal } from "react-dom";

/** A page's live filter, drawn as the top bar's search field while the page is open. */
export interface PageSearch {
  placeholder: string;
  value: string;
  onChange(value: string): void;
}

/**
 * How a page reaches the window's top bar: the element its actions are
 * portalled into, and a setter that turns the top bar's search field into
 * the page's own filter. The shell provides it around the page.
 */
export interface PageChrome {
  actionsSlot: HTMLElement | null;
  setSearch(search: PageSearch | null): void;
}

/** The value with no shell around the page, told apart by identity. */
const detached: PageChrome = { actionsSlot: null, setSearch: () => {} };

export const PageChromeContext: Context<PageChrome> = createContext<PageChrome>(detached);

/**
 * A query for the current page, typed into the top bar's search field
 * rather than a field of the page's own. The field goes back to searching
 * all settings when the page closes.
 */
export function usePageSearch(placeholder: string): [string, (value: string) => void] {
  const [value, setValue] = useState("");
  const { setSearch } = useContext(PageChromeContext);
  useEffect(() => {
    setSearch({ placeholder, value, onChange: setValue });
  }, [placeholder, value, setSearch]);
  useEffect(() => () => setSearch(null), [setSearch]);
  return [value, setValue];
}

/**
 * Renders a page's actions in the top bar, before Logs, instead of a row on
 * the page. Inside the shell nothing is drawn until it has mounted the slot;
 * with no shell at all, the actions stay on the page so they are never lost.
 */
export function TopBarActions({ children }: { children: ReactNode }): ReactNode {
  const chrome = useContext(PageChromeContext);
  const actions = (
    <div data-slot="top-bar-actions" className="flex items-center justify-end gap-1.5">
      {children}
    </div>
  );
  if (chrome === detached) return actions;
  return chrome.actionsSlot ? createPortal(actions, chrome.actionsSlot) : null;
}
