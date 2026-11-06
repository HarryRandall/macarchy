import { cva, type VariantProps } from "class-variance-authority";
import type { ComponentProps, ReactNode } from "react";

import { cn } from "~/lib/cn";

const emptyStateVariants = cva("flex flex-col items-center justify-center px-6 text-center", {
  variants: {
    variant: {
      /** In place of a whole list or grid: a dashed outline where the content would be. */
      card: "rounded-card border border-dashed border-line-strong py-10",
      /** Inside a card or a dialog that is already drawn. */
      plain: "py-8",
    },
  },
  defaultVariants: { variant: "card" },
});

/**
 * What an empty list is for and how to fill it: "No shortcuts found",
 * "Your collection starts here". Offer the action that fills it, if there is
 * one.
 */
function EmptyState({
  icon,
  title,
  description,
  action,
  variant,
  className,
  ...props
}: Omit<ComponentProps<"div">, "title" | "children"> &
  VariantProps<typeof emptyStateVariants> & {
    /** A lucide glyph, drawn in a small outlined tile. */
    icon?: ReactNode;
    title: string;
    description?: ReactNode;
    action?: ReactNode;
  }) {
  return (
    <div
      data-slot="empty-state"
      className={cn(emptyStateVariants({ variant }), className)}
      {...props}
    >
      {icon ? (
        <span
          aria-hidden
          className="mb-3 grid size-9 place-items-center rounded-tile border border-hairline bg-side text-fg-secondary [&_svg]:size-4"
        >
          {icon}
        </span>
      ) : null}
      <p className="text-emphasis font-medium text-fg">{title}</p>
      {description ? (
        <p className="mt-1 max-w-80 text-detail text-fg-secondary">{description}</p>
      ) : null}
      {action ? <div className="mt-4 flex items-center gap-2">{action}</div> : null}
    </div>
  );
}

export { EmptyState };
