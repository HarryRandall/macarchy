import { cva, type VariantProps } from "class-variance-authority";
import type { ComponentProps } from "react";

import { cn } from "~/lib/cn";

import { buttonVariants } from "./button";
import { Spinner } from "./spinner";
import { Tooltip } from "./tooltip";

const iconButtonVariants = cva("px-0", {
  variants: {
    tone: {
      /** Quiet until pointed at, so a row of them never reads as a wall of buttons. */
      default: "text-fg-secondary hover:text-fg",
      /** Removes or stops something. Red only under the pointer. */
      danger: "text-fg-secondary hover:text-danger",
    },
    size: {
      /** The 26 x 24 hit area rows and clusters use. */
      default: "h-6 w-[26px] [&_svg]:size-3.5",
      sm: "size-[22px] [&_svg]:size-3",
    },
  },
  defaultVariants: { tone: "default", size: "default" },
});

type IconButtonProps = ComponentProps<"button"> &
  VariantProps<typeof iconButtonVariants> & {
    /** The accessible name, also shown as the tooltip: say the action, "Restart yabai". */
    label: string;
    /** Longer help shown instead of the label, as its description. */
    tooltip?: string;
    /** Shows a spinner in place of the glyph and refuses clicks until done. */
    busy?: boolean;
  };

/**
 * A square glyph button with its name in a tooltip. The glyph is the child;
 * mark it `aria-hidden`, since the label names the button.
 */
function IconButton({
  label,
  tooltip,
  busy = false,
  tone,
  size,
  disabled,
  className,
  children,
  type = "button",
  ...props
}: IconButtonProps) {
  return (
    <Tooltip content={tooltip ?? label} describe={tooltip !== undefined}>
      <button
        type={type}
        data-slot="icon-button"
        aria-label={label}
        aria-busy={busy || undefined}
        disabled={disabled || busy}
        className={cn(
          buttonVariants({ variant: "ghost" }),
          iconButtonVariants({ tone, size }),
          "rounded-small",
          className,
        )}
        {...props}
      >
        {busy ? <Spinner size="sm" /> : children}
      </button>
    </Tooltip>
  );
}

/**
 * Icon buttons that act on the same thing, sharing one well, so a row's
 * actions read as one control rather than several competing pills.
 */
function ActionCluster({ className, ...props }: ComponentProps<"div">) {
  return (
    <div
      role="group"
      data-slot="action-cluster"
      className={cn(
        "inline-flex items-center gap-px rounded-full border border-hairline bg-well p-0.5 [&_[data-slot=icon-button]]:rounded-full",
        className,
      )}
      {...props}
    />
  );
}

export { ActionCluster, IconButton, iconButtonVariants };
