/**
 * How much of the top bar fits beside the sidebar. The window can be 720 px
 * wide, which leaves the bar about 450 px, so it gives things up in steps
 * rather than clipping: first the breadcrumb's group, then the search field
 * and the Logs label, which become icon buttons.
 */
export interface TopBarFit {
  /** "Appearance › Themes" rather than "Themes". */
  group: boolean;
  /** The search field itself rather than an icon that opens it. */
  searchField: boolean;
  /** "Logs" beside its icon. */
  logsLabel: boolean;
  /** The bar's side padding in pixels. */
  padding: number;
}

/** Room left once the page's actions are placed, for everything else at full size. */
const full = 560;
/** The same, with the breadcrumb reduced to the page's name. */
const named = 420;

/**
 * `width` is the bar's own width; `actions` is how wide the page's top bar
 * actions are, since a page with several buttons needs the room sooner.
 */
export function topBarFit(width: number, actions: number): TopBarFit {
  const room = width - actions;
  if (room >= full) return { group: true, searchField: true, logsLabel: true, padding: 32 };
  if (room >= named) return { group: false, searchField: true, logsLabel: true, padding: 24 };
  return { group: false, searchField: false, logsLabel: false, padding: 16 };
}
