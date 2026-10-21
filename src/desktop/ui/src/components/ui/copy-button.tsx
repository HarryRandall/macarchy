import type { VariantProps } from "class-variance-authority";
import { Check, Copy } from "lucide-react";
import { type ComponentProps, useEffect, useRef, useState } from "react";

import { copyText } from "~/lib/clipboard";
import { cn } from "~/lib/cn";

import { Button, type buttonVariants } from "./button";
import { IconButton } from "./icon-button";
import { Tooltip } from "./tooltip";

type CopyState = "idle" | "copied" | "failed";

/** How long "Copied" stays before the button goes back to its label. */
const SETTLE_MS = 1600;

/** Copies on demand and reports how it went, resetting after a moment. */
function useCopy(text: string, write: (text: string) => Promise<void> = copyText) {
  const [state, setState] = useState<CopyState>("idle");
  const timer = useRef<ReturnType<typeof setTimeout>>(undefined);
  useEffect(() => () => clearTimeout(timer.current), []);

  async function copy() {
    clearTimeout(timer.current);
    try {
      await write(text);
      setState("copied");
    } catch {
      setState("failed");
    }
    timer.current = setTimeout(() => setState("idle"), SETTLE_MS);
  }

  return { state, copy };
}

type CopyButtonProps = Omit<ComponentProps<"button">, "onClick" | "children"> &
  VariantProps<typeof buttonVariants> & {
    /** What goes on the clipboard. */
    text: string;
    /** Say what is copied: "Copy command", "Copy fix", "Copy report". */
    label?: string;
    /** A glyph-only button, named by `label`, for a corner of a code block. */
    iconOnly?: boolean;
    /** Help on hover, such as the command itself, so it can be read before copying. */
    tooltip?: string;
    /** Replaces the clipboard write, for a host bridge method. */
    write?: (text: string) => Promise<void>;
  };

/**
 * Copies text and says so in place: the label turns to "Copied" for a
 * moment, keeping the button's width, and the change is announced. The
 * SwiftUI app's only transient confirmation, so there is no toast.
 */
function CopyButton({
  text,
  label = "Copy",
  iconOnly = false,
  tooltip,
  write,
  variant,
  size,
  className,
  ...props
}: CopyButtonProps) {
  const { state, copy } = useCopy(text, write);
  const result = state === "copied" ? "Copied" : state === "failed" ? "Could not copy" : "";
  const Glyph = state === "copied" ? Check : Copy;

  const announcement = (
    <span role="status" className="sr-only">
      {result}
    </span>
  );

  if (iconOnly) {
    return (
      <>
        <IconButton
          label={label}
          tooltip={tooltip}
          className={className}
          onClick={() => void copy()}
          {...props}
        >
          <Glyph aria-hidden className={cn(state === "copied" && "text-success")} />
        </IconButton>
        {announcement}
      </>
    );
  }

  const button = (
    <Button
      variant={variant}
      size={size}
      data-slot="copy-button"
      data-state={state}
      className={className}
      onClick={() => void copy()}
      {...props}
    >
      <Glyph aria-hidden className={cn("size-3.5", state === "copied" && "text-success")} />
      {/* Both labels share one cell, so the button keeps the wider one's width. */}
      <span className="grid">
        <span className={cn("col-start-1 row-start-1", state !== "idle" && "invisible")}>
          {label}
        </span>
        <span
          aria-hidden
          className={cn("col-start-1 row-start-1", state === "idle" && "invisible")}
        >
          {result || "Copied"}
        </span>
      </span>
    </Button>
  );

  return (
    <>
      {tooltip ? <Tooltip content={tooltip}>{button}</Tooltip> : button}
      {announcement}
    </>
  );
}

export { CopyButton, useCopy };
