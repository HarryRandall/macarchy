import { cva, type VariantProps } from "class-variance-authority";
import type { ComponentProps } from "react";

import { cn } from "~/lib/cn";

import { focusRing } from "./focus-ring";
import { Spinner } from "./spinner";
import { Tooltip } from "./tooltip";

const iconButtonVariants = cva(
  [
    "inline-grid shrink-0 place-items-center rounded-control transition-[background-color,color,opacity] duration-150 select-none",
    "hover:bg-hover active:translate-y-px disabled:pointer-events-none disabled:text-fg-tertiary disabled:opacity-50",
    "aria-pressed:bg-muted aria-pressed:text-fg [&_svg]:pointer-events-none [&_svg]:shrink-0",
    focusRing,
  ],
  {
    variants: {
      tone: {
        /** Quiet until pointed at, so a row of them never reads as a wall of buttons. */
        default: "text-fg-secondary hover:text-fg",
        /** Removes or stops something. Red only under the pointer. */
        danger: "text-fg-secondary hover:text-danger",
        /** On artwork or the switcher's dark backdrop. */
        translucent:
          "bg-black/40 text-white/85 ring-1 ring-white/15 backdrop-blur-md hover:bg-black/60 hover:text-white",
      },
      size: {
        /** Rows, card headers and the logs panel. */
        sm: "size-6 rounded-small [&_svg]:size-[13px]",
        /** The top bar and dialog headers. */
        default: "size-7 [&_svg]:size-[15px]",
        md: "size-8 [&_svg]:size-4",
      },
    },
    defaultVariants: { tone: "default", size: "default" },
  },
);

type IconButtonProps = ComponentProps<"button"> &
  VariantProps<typeof iconButtonVariants> & {
    /** The accessible name, also shown as the tooltip: say the action, "Restart yabai". */
    label: string;
    /** A shortcut shown in the tooltip, such as "⌘[". */
    keys?: string;
    /** Longer help shown instead of the label, as its description. */
    tooltip?: string;
    /** Shows a spinner in place of the glyph and refuses clicks until done. */
    busy?: boolean;
    /** A toggle's state, such as the sidebar being shown. */
    pressed?: boolean;
  };

/**
 * A square glyph button with its name in a tooltip. The glyph is the child;
 * mark it `aria-hidden`, since the label names the button.
 */
function IconButton({
  label,
  keys,
  tooltip,
  busy = false,
  pressed,
  tone,
  size,
  disabled,
  className,
  children,
  type = "button",
  ...props
}: IconButtonProps) {
  return (
    <Tooltip content={tooltip ?? label} keys={keys} describe={tooltip !== undefined}>
      <button
        type={type}
        data-slot="icon-button"
        aria-label={label}
        aria-busy={busy || undefined}
        aria-pressed={pressed}
        disabled={disabled || busy}
        className={cn(iconButtonVariants({ tone, size }), className)}
        {...props}
      >
        {busy ? <Spinner size="sm" /> : children}
      </button>
    </Tooltip>
  );
}

/**
 * Icon buttons that act on the same thing, sharing one outlined well, so a
 * row's actions read as one control rather than several competing pills.
 */
function ActionCluster({ className, ...props }: ComponentProps<"div">) {
  return (
    <div
      role="group"
      data-slot="action-cluster"
      className={cn(
        "inline-flex items-center gap-px rounded-control border border-hairline bg-card p-0.5 shadow-card [&_[data-slot=icon-button]]:rounded-small",
        className,
      )}
      {...props}
    />
  );
}

export { ActionCluster, IconButton, iconButtonVariants };
