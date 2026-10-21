import { cva, type VariantProps } from "class-variance-authority";
import type { ComponentProps } from "react";

import { cn } from "~/lib/cn";

import { CopyButton } from "./copy-button";

const codeBlockVariants = cva(
  "relative min-w-0 rounded-tile border border-hairline font-mono text-mono text-fg",
  {
    variants: {
      variant: {
        /** Recessed, inside a card or a dialog. */
        well: "bg-side",
        /** Raised, standing alone on the page. */
        card: "bg-card shadow-card",
      },
    },
    defaultVariants: { variant: "well" },
  },
);

type CodeBlockProps = Omit<ComponentProps<"div">, "children"> &
  VariantProps<typeof codeBlockVariants> & {
    /** The text, shown exactly and selectable: a command, a report, a config line. */
    code: string;
    /** Names the block for assistive technology, such as "Report to be sent". */
    label: string;
    /** Adds a copy glyph in the corner. Its name, such as "Copy report". */
    copyLabel?: string;
    /** Taller blocks scroll; the default suits a report. */
    maxHeight?: number;
    /** Wraps long lines rather than scrolling sideways. Off for configuration. */
    wrap?: boolean;
    /** Replaces the clipboard write, for a host bridge method. */
    write?: (text: string) => Promise<void>;
  };

/**
 * Monospaced text to read or copy: Report's preview, a setup command, a
 * shortcut's command. It scrolls with the keyboard as well as the pointer.
 */
function CodeBlock({
  code,
  label,
  copyLabel,
  maxHeight = 260,
  wrap = true,
  write,
  variant,
  className,
  ...props
}: CodeBlockProps) {
  return (
    <div
      data-slot="code-block"
      className={cn(codeBlockVariants({ variant }), className)}
      {...props}
    >
      <pre
        role="region"
        // A scrolling block must take focus, or the keyboard cannot scroll it.
        // oxlint-disable-next-line jsx-a11y/no-noninteractive-tabindex
        tabIndex={0}
        aria-label={label}
        className={cn(
          "overflow-auto rounded-[inherit] px-3 py-2.5 outline-none select-text focus-visible:ring-2 focus-visible:ring-accent focus-visible:ring-inset",
          wrap ? "break-words whitespace-pre-wrap" : "whitespace-pre",
          copyLabel && "pr-10",
        )}
        style={{ maxHeight }}
      >
        <code>{code}</code>
      </pre>
      {copyLabel ? (
        <div className="absolute top-1.5 right-1.5">
          <CopyButton iconOnly size="sm" text={code} label={copyLabel} write={write} />
        </div>
      ) : null}
    </div>
  );
}

export { CodeBlock };
