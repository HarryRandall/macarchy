import { cva, type VariantProps } from "class-variance-authority";
import type { ComponentProps } from "react";

import { cn } from "~/lib/cn";

const buttonVariants = cva(
  "relative inline-flex shrink-0 items-center justify-center gap-1.5 whitespace-nowrap select-none transition-[background-color,color,opacity] disabled:pointer-events-none disabled:opacity-45 [&_svg]:pointer-events-none [&_svg]:shrink-0",
  {
    variants: {
      variant: {
        /** A filled push button on a card or page. */
        default: "rounded-control bg-well text-fg hover:bg-hover active:opacity-75",
        /** The one action a notice or empty state is asking for. */
        primary: "rounded-control bg-accent text-accent-fg hover:brightness-110 active:opacity-80",
        /** Confirms something that cannot be undone: restoring, deleting, resetting. */
        danger: "rounded-control bg-danger text-white hover:brightness-110 active:opacity-80",
        /** A wash under the pointer and nothing else, as macOS rows do. */
        ghost: "rounded-control text-fg hover:bg-hover active:opacity-75",
        /** A bare glyph in the window bar: it brightens rather than filling. */
        bar: "rounded-small text-fg-secondary hover:text-fg active:opacity-70",
      },
      size: {
        default: "h-7 px-3 text-row-title",
        /** The one large action that finishes a flow, as setup's. */
        lg: "h-8 px-4 text-row-title font-medium",
        sm: "h-6 px-2 text-meta",
        icon: "size-7 [&_svg]:size-4",
        "icon-sm": "size-[22px] [&_svg]:size-3.5",
        /** The 28 x 26 hit area of the bar's glyph buttons. */
        "icon-bar": "h-[26px] w-7 [&_svg]:size-4",
      },
    },
    defaultVariants: { variant: "default", size: "default" },
  },
);

type ButtonProps = ComponentProps<"button"> & VariantProps<typeof buttonVariants>;

function Button({ className, variant, size, type = "button", ...props }: ButtonProps) {
  return (
    <button
      type={type}
      data-slot="button"
      className={cn(buttonVariants({ variant, size }), className)}
      {...props}
    />
  );
}

export { Button, buttonVariants };
