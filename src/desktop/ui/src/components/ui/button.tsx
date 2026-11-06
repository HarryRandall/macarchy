import { cva, type VariantProps } from "class-variance-authority";
import type { ComponentProps } from "react";

import { cn } from "~/lib/cn";

import { focusRing } from "./focus-ring";
import { Spinner } from "./spinner";

const buttonVariants = cva(
  [
    "relative inline-flex shrink-0 items-center justify-center gap-1.5 font-medium tracking-[-0.01em] whitespace-nowrap select-none",
    "transition-[background-color,border-color,color,opacity,box-shadow,transform] duration-150",
    "active:translate-y-px disabled:pointer-events-none disabled:opacity-50 aria-busy:pointer-events-none",
    "[&_svg]:pointer-events-none [&_svg]:shrink-0",
    focusRing,
  ],
  {
    variants: {
      variant: {
        /** The page's main action: Save, Apply, Set up. Dark on light, light on dark. */
        primary: "rounded-control bg-strong text-strong-fg shadow-card hover:opacity-90",
        /** An outlined button for every other action on a card or page. */
        secondary:
          "rounded-control border border-hairline bg-card text-fg shadow-card hover:bg-hover",
        /** The interface accent, for an action that should stand out from the primary. */
        accent: "rounded-control bg-accent text-accent-fg shadow-card hover:opacity-90",
        /** Confirms something that cannot be undone: restoring, deleting, resetting. */
        danger: "rounded-control bg-danger text-white shadow-card hover:opacity-90",
        /** Secondary ink with a wash under the pointer. */
        ghost: "rounded-control text-fg-secondary hover:bg-hover hover:text-fg",
        /** Earlier name for `secondary`. */
        default:
          "rounded-control border border-hairline bg-card text-fg shadow-card hover:bg-hover",
        /** Earlier name for `ghost` beside a heading. */
        quiet: "rounded-control text-fg-secondary hover:bg-hover hover:text-fg",
        /** Bare ink that brightens rather than filling: the bar's glyphs, an inline action. */
        bar: "rounded-control text-fg-secondary hover:bg-hover hover:text-fg",
        /** Drawn as the field it opens, such as the top bar's search launcher. */
        field:
          "justify-start rounded-control border border-hairline bg-side font-normal text-fg-tertiary hover:border-line-strong hover:text-fg-secondary",
        /** A state summary that opens its details, such as the services count. */
        pill: "rounded-control text-fg-secondary hover:bg-hover hover:text-fg data-popup-open:bg-muted data-popup-open:text-fg data-popup-open:ring-1 data-popup-open:ring-hairline",
        /** A translucent fill that reads on artwork or the switcher's dark backdrop. */
        translucent:
          "rounded-control bg-white/10 text-white ring-1 ring-white/20 backdrop-blur-md hover:bg-white/20",
      },
      size: {
        /** The standard height, matching fields and selects. */
        md: "h-8 px-3 text-body",
        sm: "h-7 px-2.5 text-small [&_svg]:size-3",
        /** On a section's title line, level with its label. */
        xs: "h-6 px-2 text-meta [&_svg]:size-3",
        /** The one large action that finishes a flow, as setup's. */
        lg: "h-9 px-4 text-body",
        /** No box of its own, for an action set in a line of text. */
        inline: "text-body",
        icon: "size-7 [&_svg]:size-3.5",
        "icon-sm": "size-6 [&_svg]:size-3",
        /** The 26px square of the switcher's Back. */
        "icon-md": "size-[26px] [&_svg]:size-[15px]",
        "icon-bar": "size-8 [&_svg]:size-4",
        /** Earlier name for `md`. */
        default: "h-8 px-3 text-body",
      },
    },
    compoundVariants: [{ size: "inline", className: "h-auto px-0 active:translate-y-0" }],
    defaultVariants: { variant: "secondary", size: "md" },
  },
);

type ButtonProps = ComponentProps<"button"> &
  VariantProps<typeof buttonVariants> & {
    /** Shows a spinner before the label and refuses clicks until the work is done. */
    busy?: boolean;
  };

function Button({
  className,
  variant,
  size,
  busy = false,
  type = "button",
  onClick,
  children,
  ...props
}: ButtonProps) {
  return (
    <button
      type={type}
      data-slot="button"
      aria-busy={busy || undefined}
      // Not disabled while busy, so keyboard focus stays on the button that started the work.
      onClick={busy ? undefined : onClick}
      className={cn(buttonVariants({ variant, size }), className)}
      {...props}
    >
      {busy ? <Spinner size="sm" /> : null}
      {children}
    </button>
  );
}

export { Button, buttonVariants };
