/**
 * The keyboard focus ring every interactive primitive draws. The offset is
 * painted in the page colour so the ring reads on a filled control.
 */
export const focusRing =
  "outline-none focus-visible:ring-2 focus-visible:ring-accent focus-visible:ring-offset-2 focus-visible:ring-offset-page";

/**
 * The ring drawn inside the box, for rows and items in a clipped or
 * scrolling container whose edge would cut an outer ring off.
 */
export const focusRingInset =
  "outline-none focus-visible:ring-2 focus-visible:ring-accent focus-visible:ring-inset";
