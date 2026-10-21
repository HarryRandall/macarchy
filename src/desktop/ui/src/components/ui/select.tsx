import { Select as SelectPrimitive } from "@base-ui/react/select";
import { cva, type VariantProps } from "class-variance-authority";
import { Check, ChevronsUpDown } from "lucide-react";

import { cn } from "~/lib/cn";

const selectTriggerVariants = cva(
  "inline-flex items-center justify-between gap-2 text-left text-row-title text-fg outline-none transition-[background-color,opacity] select-none data-disabled:opacity-45",
  {
    variants: {
      variant: {
        /** The glass dropdown the SwiftUI settings rows use. */
        glass:
          "rounded-control border border-hairline bg-well shadow-[inset_0_1px_0_rgb(255_255_255/0.06),0_1px_2px_rgb(0_0_0/0.12)] hover:bg-hover data-popup-open:bg-hover",
      },
      size: {
        default: "h-7 w-44 px-2",
      },
    },
    defaultVariants: { variant: "glass", size: "default" },
  },
);

interface SelectOption<V extends string> {
  value: V;
  label: string;
}

type SelectProps<V extends string> = VariantProps<typeof selectTriggerVariants> & {
  /** The accessible name; rows also show it as their title. */
  label: string;
  value: V;
  options: readonly SelectOption<V>[];
  onValueChange: (value: V) => void;
  disabled?: boolean;
  className?: string;
};

/**
 * A macOS pop-up button: the menu opens over the trigger with the chosen
 * item aligned to it, rather than dropping below like a web select.
 */
function Select<V extends string>({
  label,
  value,
  options,
  onValueChange,
  disabled,
  variant,
  size,
  className,
}: SelectProps<V>) {
  return (
    <SelectPrimitive.Root
      items={options}
      value={value}
      disabled={disabled}
      onValueChange={(next) => {
        if (next !== null) onValueChange(next as V);
      }}
    >
      <SelectPrimitive.Trigger
        aria-label={label}
        data-slot="select-trigger"
        className={cn(selectTriggerVariants({ variant, size }), className)}
      >
        <SelectPrimitive.Value className="min-w-0 flex-1 truncate" />
        <SelectPrimitive.Icon className="flex text-fg-secondary">
          <ChevronsUpDown aria-hidden className="size-2.5" strokeWidth={2.5} />
        </SelectPrimitive.Icon>
      </SelectPrimitive.Trigger>
      <SelectPrimitive.Portal>
        <SelectPrimitive.Positioner
          alignItemWithTrigger
          sideOffset={4}
          className="z-50 outline-none"
        >
          <SelectPrimitive.Popup
            data-slot="select-popup"
            className={cn(
              "min-w-(--anchor-width) rounded-control border border-hairline bg-popover/95 p-[5px] text-row-title text-fg shadow-[0_8px_24px_rgb(0_0_0/0.28)] backdrop-blur-xl outline-none",
              "origin-(--transform-origin) transition-opacity duration-140 data-ending-style:opacity-0 data-starting-style:opacity-0",
            )}
          >
            <SelectPrimitive.List>
              {options.map((option) => (
                <SelectPrimitive.Item
                  key={option.value}
                  value={option.value}
                  className="grid h-[22px] grid-cols-[16px_1fr] items-center gap-1 rounded-[5px] pr-3 pl-1 outline-none select-none data-highlighted:bg-accent data-highlighted:text-accent-fg"
                >
                  <SelectPrimitive.ItemIndicator className="col-start-1 flex">
                    <Check aria-hidden className="size-3" strokeWidth={3} />
                  </SelectPrimitive.ItemIndicator>
                  <SelectPrimitive.ItemText className="col-start-2 whitespace-nowrap">
                    {option.label}
                  </SelectPrimitive.ItemText>
                </SelectPrimitive.Item>
              ))}
            </SelectPrimitive.List>
          </SelectPrimitive.Popup>
        </SelectPrimitive.Positioner>
      </SelectPrimitive.Portal>
    </SelectPrimitive.Root>
  );
}

export { Select, selectTriggerVariants, type SelectOption };
