import { cva, type VariantProps } from "class-variance-authority";
import { CircleAlert, Info, TriangleAlert, X } from "lucide-react";
import type { ComponentProps } from "react";

import { cn } from "~/lib/cn";

import { IconButton } from "./icon-button";

const rootVariants = cva("flex items-start gap-3 rounded-card border px-4 py-3 text-body text-fg", {
  variants: {
    variant: {
      info: "border-hairline bg-side",
      warning: "border-warning/30 bg-warning-soft",
      error: "border-danger/30 bg-danger-soft",
    },
  },
  defaultVariants: { variant: "info" },
});

const icons = { info: Info, warning: TriangleAlert, error: CircleAlert };
const iconColours = { info: "text-fg-secondary", warning: "text-warning", error: "text-danger" };

type Variant = NonNullable<VariantProps<typeof rootVariants>["variant"]>;

/**
 * Status that must stay on screen: a failed apply, a read-only page, a step
 * still to do. Errors announce themselves; the rest are polite.
 */
function Root({
  className,
  variant = "info",
  children,
  ...props
}: ComponentProps<"div"> & { variant?: Variant }) {
  const Icon = icons[variant];
  return (
    <div
      role={variant === "error" ? "alert" : "status"}
      data-slot="notice"
      data-variant={variant}
      className={cn(rootVariants({ variant }), className)}
      {...props}
    >
      <Icon aria-hidden className={cn("mt-px size-4 shrink-0", iconColours[variant])} />
      <div className="flex min-w-0 flex-1 flex-col gap-0.5">{children}</div>
    </div>
  );
}

function Title({ className, ...props }: ComponentProps<"p">) {
  return <p className={cn("font-medium", className)} {...props} />;
}

function Description({ className, ...props }: ComponentProps<"p">) {
  return <p className={cn("text-detail text-fg-secondary select-text", className)} {...props} />;
}

function Actions({ className, ...props }: ComponentProps<"div">) {
  return <div className={cn("mt-2.5 flex flex-wrap gap-2", className)} {...props} />;
}

function Dismiss({
  label = "Dismiss",
  className,
  ...props
}: Omit<ComponentProps<"button">, "children"> & { label?: string }) {
  return (
    <IconButton label={label} size="sm" className={cn("-my-0.5 -mr-1.5", className)} {...props}>
      <X aria-hidden />
    </IconButton>
  );
}

/** A title and description with a dismiss button at their trailing edge. */
function Header({
  onDismiss,
  dismissLabel,
  className,
  children,
  ...props
}: ComponentProps<"div"> & { onDismiss: () => void; dismissLabel?: string }) {
  return (
    <div data-slot="notice-header" className={cn("flex items-start gap-2", className)} {...props}>
      <div className="flex min-w-0 flex-1 flex-col gap-0.5">{children}</div>
      <Dismiss label={dismissLabel} onClick={onDismiss} />
    </div>
  );
}

const Notice = { Root, Header, Title, Description, Actions, Dismiss };

export { Notice };
