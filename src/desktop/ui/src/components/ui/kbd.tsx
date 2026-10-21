import { cva, type VariantProps } from "class-variance-authority";
import type { ComponentProps } from "react";

import { cn } from "~/lib/cn";

const kbdVariants = cva("inline-flex shrink-0 items-center justify-center font-sans", {
  variants: {
    variant: {
      /** Plain text, as a menu item's shortcut. */
      inline: "text-meta tracking-[0.04em] text-fg-tertiary",
      /** A small boxed hint, as the top bar's search shows ⌘K. */
      hint: "h-[18px] rounded-[4px] border border-hairline bg-card px-1.5 text-caption font-medium text-fg-secondary",
      /** The switcher's key caps on its dark backdrop. */
      cap: "h-5 min-w-[22px] rounded-key bg-white/10 px-1 text-small font-medium text-white",
      /** A shortcut's keys on a settings page, drawn as raised keys. */
      key: "h-[22px] min-w-[22px] rounded-key border border-hairline border-b-line-strong bg-side px-1.5 text-meta font-medium text-fg-secondary shadow-[0_1px_0_var(--line-hairline)]",
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
  /** Read by VoiceOver in place of the glyphs: "Command K". */
  label?: string;
  variant?: "cap" | "key" | "hint";
  className?: string;
}) {
  return (
    <span
      className={cn(
        "inline-flex items-center",
        variant === "cap" ? "gap-[3px]" : "gap-1",
        className,
      )}
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
