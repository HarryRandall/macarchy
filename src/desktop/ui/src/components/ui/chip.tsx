import type { ComponentProps, ReactNode } from "react";

import { cn } from "~/lib/cn";

/**
 * A compact pill naming one thing in a run of them: a menu bar item, an
 * excluded app, a plugin's tag. Not a control; use `Button` for that.
 */
function Chip({
  colour,
  icon,
  className,
  children,
  ...props
}: ComponentProps<"span"> & {
  /** A dot in the thing's own colour, such as a workspace's. */
  colour?: string;
  /** A glyph before the text; mark it `aria-hidden`. */
  icon?: ReactNode;
}) {
  return (
    <span
      data-slot="chip"
      className={cn(
        "inline-flex h-[22px] max-w-full min-w-0 items-center gap-1.5 rounded-small border border-hairline bg-side px-2 text-meta font-medium whitespace-nowrap text-fg-secondary [&_svg]:size-3 [&_svg]:shrink-0",
        className,
      )}
      {...props}
    >
      {colour ? (
        <span aria-hidden className="size-2 shrink-0 rounded-full" style={{ background: colour }} />
      ) : null}
      {icon}
      <span className="min-w-0 truncate">{children}</span>
    </span>
  );
}

export { Chip };
