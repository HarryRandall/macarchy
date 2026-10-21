import { cva, type VariantProps } from "class-variance-authority";
import type { ComponentProps } from "react";

import { cn } from "~/lib/cn";

const kbdVariants = cva("inline-flex items-center justify-center font-sans", {
  variants: {
    variant: {
      /** Plain text in a pill, as the search pill shows ⌘K. */
      inline: "text-meta text-fg-secondary",
      /** The switcher's key caps. */
      cap: "h-5 min-w-[22px] rounded-[5px] bg-white/10 px-1 text-[12px] font-medium text-fg",
      /** A shortcut's keys on a settings page, drawn as raised keys. */
      key: "h-[22px] min-w-[22px] rounded-small border border-hairline bg-well px-[5px] text-[12px] font-medium text-fg",
    },
  },
  defaultVariants: { variant: "inline" },
});

function Kbd({
  className,
  variant,
  ...props
}: ComponentProps<"kbd"> & VariantProps<typeof kbdVariants>) {
  return <kbd data-slot="kbd" className={cn(kbdVariants({ variant }), className)} {...props} />;
}

/** A shortcut drawn as one cap per key, e.g. ["⌘", "K"]. */
function KbdGroup({
  keys,
  label,
  variant = "cap",
  className,
}: {
  keys: string[];
  label?: string;
  variant?: "cap" | "key";
  className?: string;
}) {
  return (
    <span
      className={cn("inline-flex", variant === "key" ? "gap-1" : "gap-[3px]", className)}
      aria-label={label}
      role={label ? "img" : undefined}
    >
      {keys.map((key, index) => (
        // A chord can repeat a glyph, so position is part of the key.
        <Kbd key={`${index}-${key}`} variant={variant} aria-hidden={label ? true : undefined}>
          {key}
        </Kbd>
      ))}
    </span>
  );
}

export { Kbd, KbdGroup };
