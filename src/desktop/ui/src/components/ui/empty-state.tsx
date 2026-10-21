import { cva, type VariantProps } from "class-variance-authority";
import type { ComponentProps, ReactNode } from "react";

import { cn } from "~/lib/cn";

const emptyStateVariants = cva("flex flex-col items-center justify-center gap-3 px-6 text-center", {
  variants: {
    variant: {
      /** In place of a whole list or grid. */
      card: "rounded-card border border-hairline bg-card py-10",
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
    /** A lucide glyph; drawn large and quiet. */
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
          className="flex size-10 items-center justify-center rounded-full bg-well text-fg-secondary [&_svg]:size-5"
        >
          {icon}
        </span>
      ) : null}
      <div className="flex max-w-80 flex-col gap-1">
        <p className="text-section-title text-fg">{title}</p>
        {description ? <p className="text-row-title text-fg-secondary">{description}</p> : null}
      </div>
      {action ? <div className="flex items-center gap-2 pt-1">{action}</div> : null}
    </div>
  );
}

export { EmptyState };
