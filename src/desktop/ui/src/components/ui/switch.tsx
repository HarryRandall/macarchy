import { Switch as SwitchPrimitive } from "@base-ui/react/switch";

import { cn } from "~/lib/cn";

import { focusRing } from "./focus-ring";

/**
 * An on/off setting that applies at once. The track fills with the strong
 * ink when on, so the state reads without colour.
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
        "data-checked:bg-strong data-disabled:opacity-50",
        focusRing,
        size === "sm" ? "h-4 w-7 [--thumb:12px]" : "h-5 w-[34px] [--thumb:16px]",
        className,
      )}
      {...props}
    >
      <SwitchPrimitive.Thumb
        className={cn(
          "pointer-events-none block size-(--thumb) translate-x-0.5 rounded-full bg-white shadow-[0_1px_2px_rgb(0_0_0/0.2)]",
          "transition-transform duration-200 ease-glide data-checked:bg-strong-fg",
          size === "sm" ? "data-checked:translate-x-3.5" : "data-checked:translate-x-4",
        )}
      />
    </SwitchPrimitive.Root>
  );
}

export { Switch };
