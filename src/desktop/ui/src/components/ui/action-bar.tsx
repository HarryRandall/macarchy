import type { ComponentProps, ReactNode } from "react";

import { cn } from "~/lib/cn";

/**
 * A row of actions with an optional status at its leading edge: a page
 * header's buttons, or the foot of a form page such as Report's "Copy
 * report" and "Open on GitHub". Buttons go in macOS order, the default
 * action last. It wraps rather than clipping when the window is narrow.
 */
function ActionBar({
  status,
  className,
  children,
  ...props
}: ComponentProps<"div"> & {
  /** An `InlineStatus` or a short note, such as "Checked 10:42". */
  status?: ReactNode;
}) {
  return (
    <div
      data-slot="action-bar"
      className={cn("flex flex-wrap items-center gap-2", className)}
      {...props}
    >
      {status ? <div className="mr-auto min-w-0">{status}</div> : null}
      <div className={cn("flex flex-wrap items-center gap-2", !status && "ml-auto")}>
        {children}
      </div>
    </div>
  );
}

export { ActionBar };
