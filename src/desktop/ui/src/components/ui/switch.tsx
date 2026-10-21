import { Switch as SwitchPrimitive } from "@base-ui/react/switch";

import { cn } from "~/lib/cn";

function Switch({
  className,
  size = "default",
  ...props
}: SwitchPrimitive.Root.Props & { size?: "default" | "sm" }) {
  return (
    <SwitchPrimitive.Root
      data-slot="switch"
      className={cn(
        "inline-flex shrink-0 items-center rounded-full p-0.5 transition-colors duration-200",
        "bg-well data-checked:bg-accent data-disabled:opacity-45",
        // Matches the accent unless it is too close to the surface, when it
        // outlines the track so the on state still reads.
        "data-checked:shadow-[inset_0_0_0_1px_var(--accent-stroke)]",
        size === "sm" ? "h-4 w-[26px] [--thumb:12px]" : "h-[18px] w-8 [--thumb:14px]",
        className,
      )}
      {...props}
    >
      <SwitchPrimitive.Thumb
        className={cn(
          "pointer-events-none block size-(--thumb) rounded-full bg-white shadow-[0_0_0_0.5px_rgb(0_0_0/0.35),0_1px_2px_rgb(0_0_0/0.3)]",
          "transition-transform duration-snappy",
          size === "sm" ? "data-checked:translate-x-2.5" : "data-checked:translate-x-3.5",
        )}
      />
    </SwitchPrimitive.Root>
  );
}

export { Switch };
