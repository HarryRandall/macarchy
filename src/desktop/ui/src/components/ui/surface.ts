/** The floating panel shared by menus, selects and popovers. */
export const popupSurface =
  "rounded-card border border-hairline bg-popover p-1 text-body text-fg shadow-pop outline-none";

/**
 * Base UI's open and close states: a small drop from the trigger, faded.
 * The global Reduce Motion rule removes the movement.
 */
export const popupMotion =
  "origin-(--transform-origin) transition-[opacity,transform] duration-[120ms] ease-out data-ending-style:opacity-0 data-starting-style:-translate-y-0.5 data-starting-style:scale-[0.98] data-starting-style:opacity-0";

/** A row in a menu or list popup. */
export const popupItem =
  "flex h-8 cursor-default items-center gap-2.5 rounded-small px-2 text-body text-fg outline-none select-none data-disabled:opacity-50 data-highlighted:bg-muted [&_svg]:size-3.5 [&_svg]:shrink-0 [&_svg]:text-fg-secondary";
