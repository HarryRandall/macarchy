import { Select as SelectPrimitive } from "@base-ui/react/select";
import { cva, type VariantProps } from "class-variance-authority";
import { Check, ChevronsUpDown } from "lucide-react";

import { cn } from "~/lib/cn";

import { focusRing } from "./focus-ring";
import { popupItem, popupMotion, popupSurface } from "./surface";

const selectTriggerVariants = cva(
  [
    "inline-flex items-center justify-between gap-2 rounded-control border border-hairline bg-card text-left text-fg shadow-card select-none",
    "transition-[background-color,border-color,opacity] hover:bg-hover data-popup-open:bg-hover data-disabled:opacity-50",
    focusRing,
  ],
  {
    variants: {
      variant: {
        /** The outlined pop-up button every settings row uses. */
        default: "",
        /** Earlier name for `default`. */
        glass: "",
      },
      size: {
        sm: "h-7 w-40 pr-2 pl-2.5 text-small",
        default: "h-8 w-48 pr-2 pl-3 text-body",
      },
    },
    defaultVariants: { variant: "default", size: "default" },
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
        <SelectPrimitive.Icon className="flex text-fg-tertiary">
          <ChevronsUpDown aria-hidden className="size-3.5" strokeWidth={2} />
        </SelectPrimitive.Icon>
      </SelectPrimitive.Trigger>
      <SelectPrimitive.Portal>
        <SelectPrimitive.Positioner
          alignItemWithTrigger
          sideOffset={6}
          collisionPadding={8}
          className="z-50 outline-none"
        >
          <SelectPrimitive.Popup
            data-slot="select-popup"
            className={cn("min-w-(--anchor-width)", popupSurface, popupMotion)}
          >
            <SelectPrimitive.List>
              {options.map((option) => (
                <SelectPrimitive.Item
                  key={option.value}
                  value={option.value}
                  className={cn(popupItem, "grid grid-cols-[14px_1fr] gap-2 pr-3 [&_svg]:text-fg")}
                >
                  <SelectPrimitive.ItemIndicator className="col-start-1 flex">
                    <Check aria-hidden strokeWidth={2.5} />
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
