import { cva, type VariantProps } from "class-variance-authority";
import type { ComponentProps } from "react";

import { cn } from "~/lib/cn";

/**
 * Subject colours, set as `--tint` so a component can paint its glyph, its
 * wash and its hover border from the one value.
 */
const tintVariants = cva("", {
  variants: {
    tint: {
      accent: "[--tint:var(--accent-stroke)]",
      blue: "[--tint:var(--hue-blue)]",
      purple: "[--tint:var(--hue-purple)]",
      pink: "[--tint:var(--hue-pink)]",
      teal: "[--tint:var(--hue-teal)]",
      orange: "[--tint:var(--hue-orange)]",
      green: "[--tint:var(--hue-green)]",
      red: "[--tint:var(--hue-red)]",
      neutral: "[--tint:var(--ink-secondary)]",
    },
  },
  defaultVariants: { tint: "accent" },
});

type Tint = NonNullable<VariantProps<typeof tintVariants>["tint"]>;

const iconTileVariants = cva(
  "inline-flex shrink-0 items-center justify-center bg-(--tint)/16 text-(--tint) [&_svg]:shrink-0",
  {
    variants: {
      size: {
        /** Beside a stat tile's caption. */
        sm: "size-[18px] rounded-[5px] [&_svg]:size-[11px]",
        /** Leading a list row. */
        default: "size-6 rounded-small [&_svg]:size-3.5",
        /** Leading a card, as Home's quick actions do. */
        lg: "size-[34px] rounded-control [&_svg]:size-4",
      },
    },
    defaultVariants: { size: "default" },
  },
);

/** A glyph on a soft wash of its subject's colour. Decorative: the text beside it names it. */
function IconTile({
  tint,
  size,
  className,
  ...props
}: ComponentProps<"span"> & VariantProps<typeof iconTileVariants> & { tint?: Tint }) {
  return (
    <span
      aria-hidden
      data-slot="icon-tile"
      className={cn(tintVariants({ tint }), iconTileVariants({ size }), className)}
      {...props}
    />
  );
}

export { IconTile, type Tint, tintVariants };
