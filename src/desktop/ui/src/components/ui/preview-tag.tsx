import { cn } from "~/lib/cn";

/**
 * Marks a page or feature still in preview. Teal, so it reads apart from
 * the accent and from warnings.
 */
function PreviewTag({ size = "sm", className }: { size?: "sm" | "md"; className?: string }) {
  return (
    <span
      data-slot="preview-tag"
      className={cn(
        "inline-flex shrink-0 items-center rounded-key bg-preview-soft leading-none font-medium text-preview shadow-[inset_0_0_0_1px_var(--preview-ring)]",
        size === "sm" ? "h-4 px-[5px] text-tag" : "h-5 px-[7px] text-caption tracking-[0.01em]",
        className,
      )}
    >
      Preview
    </span>
  );
}

export { PreviewTag };
