import { CircleAlert, CircleCheck, Info, TriangleAlert } from "lucide-react";
import type { ComponentProps } from "react";

import { cn } from "~/lib/cn";

const icons = { neutral: Info, success: CircleCheck, warning: TriangleAlert, danger: CircleAlert };
const iconColours = {
  neutral: "text-fg-secondary",
  success: "text-success",
  warning: "text-warning",
  danger: "text-danger",
};

/**
 * One line of status beside the thing it is about: "Copied", "Already used
 * by Spaces", a failed save under a form. Use `Notice` for status that needs
 * a title or actions. Danger announces itself; the rest are polite.
 */
function InlineStatus({
  tone = "neutral",
  icon = true,
  className,
  children,
  ...props
}: ComponentProps<"p"> & {
  tone?: keyof typeof icons;
  /** Off for a status that is only words, such as "Checked 10:42". */
  icon?: boolean;
}) {
  const Icon = icons[tone];
  return (
    <p
      role={tone === "danger" ? "alert" : "status"}
      data-slot="inline-status"
      data-tone={tone}
      className={cn(
        "flex items-start gap-1.5 text-meta select-text",
        tone === "neutral" ? "text-fg-secondary" : "text-fg",
        className,
      )}
      {...props}
    >
      {icon ? (
        <Icon aria-hidden className={cn("mt-px size-3 shrink-0", iconColours[tone])} />
      ) : null}
      <span className="min-w-0">{children}</span>
    </p>
  );
}

export { InlineStatus };
