import { Switch as SwitchPrimitive } from "@base-ui/react/switch";

import { cn } from "~/lib/cn";

import { focusRing } from "./focus-ring";

/**
 * An on/off setting that applies at once. Accent and thumb position indicate
 * the state; the thumb keeps a two-pixel inset at either end.
 */
function Switch({
  className,
  size = "default",
  ...props
}: SwitchPrimitive.Root.Props & { size?: "default" | "sm" }) {
  return (
    <SwitchPrimitive.Root
      data-slot="switch"
      className={cn(
        "group/switch relative inline-flex shrink-0 cursor-default items-center rounded-full bg-line-strong transition-colors duration-200",
        "data-checked:bg-accent data-disabled:opacity-50",
        focusRing,
        size === "sm" ? "h-4 w-7 [--thumb:calc(1rem-4px)]" : "h-[16px] w-[28px] [--thumb:12px]",
        className,
      )}
      {...props}
    >
      <SwitchPrimitive.Thumb
        className={cn(
          "pointer-events-none block size-(--thumb) translate-x-[2px] rounded-full bg-white shadow-[0_1px_2px_rgb(0_0_0/0.2)]",
          "transition-transform duration-200 ease-glide",
          size === "sm"
            ? "data-checked:translate-x-[calc(1.75rem-var(--thumb)-2px)]"
            : "data-checked:translate-x-[14px]",
        )}
      />
    </SwitchPrimitive.Root>
  );
}

export { Switch };
