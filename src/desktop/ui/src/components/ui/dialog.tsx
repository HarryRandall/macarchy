import { Dialog as DialogPrimitive } from "@base-ui/react/dialog";
import { cva, type VariantProps } from "class-variance-authority";
import { X } from "lucide-react";
import { type ComponentProps, type ReactNode, useRef } from "react";

import { cn } from "~/lib/cn";

import { HelpTooltip } from "./help-tooltip";
import { IconButton } from "./icon-button";

type RootProps = DialogPrimitive.Root.Props & {
  /** Escape closes the dialog. Turn off while a save is running. */
  dismissOnEscape?: boolean;
  /** A click on the dimmed window closes the dialog. Off for forms with unsaved input. */
  dismissOnOutsidePress?: boolean;
};

/**
 * An in-window modal: the page behind goes inert and dims, focus moves in
 * and is trapped, and it returns to the control that opened it on close.
 * Control it with `open` and `onOpenChange`, or give it a `Dialog.Trigger`.
 */
function Root({
  dismissOnEscape = true,
  dismissOnOutsidePress = true,
  onOpenChange,
  ...props
}: RootProps) {
  return (
    <DialogPrimitive.Root
      disablePointerDismissal={!dismissOnOutsidePress}
      onOpenChange={(open, details) => {
        if (!open && !dismissOnEscape && details.reason === "escape-key") {
          details.cancel();
          return;
        }
        onOpenChange?.(open, details);
      }}
      {...props}
    />
  );
}

const popupVariants = cva(
  [
    "flex max-h-[calc(100dvh-48px)] max-w-[calc(100vw-48px)] flex-col overflow-hidden rounded-card border border-hairline bg-page text-fg outline-none",
    "shadow-[0_12px_40px_rgb(0_0_0/0.35)]",
    // Fades and rises in over 280 ms and out over 220 ms, as ModalRouter did.
    "transition-[opacity,scale,translate] duration-[280ms] ease-out data-ending-style:duration-[220ms] data-ending-style:ease-in-out",
    "data-starting-style:translate-y-2 data-starting-style:scale-[0.985] data-starting-style:opacity-0 data-ending-style:opacity-0",
  ],
  {
    variants: {
      size: {
        /** A question with two buttons. */
        sm: "w-[420px]",
        /** A form: a rule, a shortcut. */
        default: "w-[540px]",
        /** A workspace with tabs and previews: a theme. */
        lg: "w-[640px]",
      },
    },
    defaultVariants: { size: "default" },
  },
);

const firstField =
  "[data-slot=dialog-body] :is(input, textarea, select):not(:disabled, [type=hidden])";

/**
 * The backdrop, the centring viewport and the panel, portalled over the page.
 * Opening focuses the first field in the body, or else the panel itself, so
 * the close glyph's tooltip does not greet every opening; pass
 * `initialFocus` to choose another element.
 */
function Popup({
  size,
  className,
  children,
  initialFocus,
  ...props
}: Omit<DialogPrimitive.Popup.Props, "ref"> & VariantProps<typeof popupVariants>) {
  const popupRef = useRef<HTMLDivElement>(null);
  return (
    <DialogPrimitive.Portal>
      <DialogPrimitive.Backdrop className="fixed inset-0 z-50 bg-black/32 transition-opacity duration-[280ms] ease-out data-ending-style:duration-[220ms] data-ending-style:opacity-0 data-starting-style:opacity-0" />
      <DialogPrimitive.Viewport className="fixed inset-0 z-50 flex items-center justify-center p-6">
        <DialogPrimitive.Popup
          ref={popupRef}
          data-slot="dialog"
          initialFocus={
            initialFocus ??
            (() => popupRef.current?.querySelector<HTMLElement>(firstField) ?? popupRef.current)
          }
          className={cn(popupVariants({ size }), className)}
          {...props}
        >
          {children}
        </DialogPrimitive.Popup>
      </DialogPrimitive.Viewport>
    </DialogPrimitive.Portal>
  );
}

/**
 * The title block, trailing controls and the close glyph. A glyph rather than
 * "Done": nothing is being confirmed, and a text button beside a real action
 * reads as a second action of equal weight.
 */
function Header({
  className,
  children,
  actions,
  closable = true,
  closeLabel = "Close",
  ...props
}: ComponentProps<"div"> & {
  /** Beside the close button: a menu of more actions, the chord being edited. */
  actions?: ReactNode;
  /** Off for a dialog that must be answered with its footer buttons. */
  closable?: boolean;
  closeLabel?: string;
}) {
  return (
    <div
      data-slot="dialog-header"
      className={cn(
        "flex shrink-0 items-start gap-3 border-b border-hairline px-5 py-4",
        className,
      )}
      {...props}
    >
      <div className="flex min-w-0 flex-1 flex-col gap-0.5">{children}</div>
      {actions ? <div className="flex shrink-0 items-center gap-1">{actions}</div> : null}
      {closable ? (
        <DialogPrimitive.Close render={<IconButton label={closeLabel} className="-mr-1.5" />}>
          <X aria-hidden strokeWidth={2.25} />
        </DialogPrimitive.Close>
      ) : null}
    </div>
  );
}

/** Names the dialog. Optional help sits beside it as a tooltip. */
function Title({
  className,
  help,
  children,
  ...props
}: DialogPrimitive.Title.Props & { help?: string }) {
  const title = (
    <DialogPrimitive.Title
      data-slot="dialog-title"
      className={cn("truncate text-section-title text-fg", className)}
      {...props}
    >
      {children}
    </DialogPrimitive.Title>
  );
  if (!help) return title;
  return (
    <div className="flex min-w-0 items-center gap-[3px]">
      {title}
      <HelpTooltip text={help} />
    </div>
  );
}

function Description({ className, ...props }: DialogPrimitive.Description.Props) {
  return (
    <DialogPrimitive.Description
      data-slot="dialog-description"
      className={cn("text-meta text-fg-secondary", className)}
      {...props}
    />
  );
}

/** The scrolling middle. Cards and sections stack with the page's gap. */
function Body({ className, ...props }: ComponentProps<"div">) {
  return (
    <div
      data-slot="dialog-body"
      className={cn("flex min-h-0 flex-1 flex-col gap-4 overflow-y-auto px-5 py-4", className)}
      {...props}
    />
  );
}

/**
 * Actions along the foot. Children sit at the trailing edge in macOS order,
 * Cancel then the default action last; `leading` holds a destructive action
 * kept apart from them, such as Disable.
 */
function Footer({
  className,
  leading,
  children,
  ...props
}: ComponentProps<"div"> & { leading?: ReactNode }) {
  return (
    <div
      data-slot="dialog-footer"
      className={cn(
        "flex shrink-0 items-center gap-2 border-t border-hairline px-5 py-4",
        className,
      )}
      {...props}
    >
      {leading ? <div className="flex min-w-0 items-center gap-2">{leading}</div> : null}
      <div className="ml-auto flex items-center gap-2">{children}</div>
    </div>
  );
}

/** Opens the dialog. Use `render` to make a `Button` the trigger. */
const Trigger = DialogPrimitive.Trigger;
/** Closes the dialog. Use `render={<Button />}` for a Cancel button. */
const Close = DialogPrimitive.Close;

const Dialog = { Root, Trigger, Popup, Header, Title, Description, Body, Footer, Close };

export { Dialog, popupVariants as dialogVariants };
