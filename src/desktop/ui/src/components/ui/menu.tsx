import { Menu as MenuPrimitive } from "@base-ui/react/menu";
import { Check } from "lucide-react";
import type { ReactNode } from "react";

import { cn } from "~/lib/cn";

const Menu = MenuPrimitive.Root;
const MenuTrigger = MenuPrimitive.Trigger;

function MenuPopup({
  className,
  children,
  side = "bottom",
  align = "start",
  ...props
}: MenuPrimitive.Popup.Props & {
  side?: MenuPrimitive.Positioner.Props["side"];
  align?: MenuPrimitive.Positioner.Props["align"];
}) {
  return (
    <MenuPrimitive.Portal>
      <MenuPrimitive.Positioner
        side={side}
        align={align}
        sideOffset={4}
        className="z-50 outline-none"
      >
        <MenuPrimitive.Popup
          data-slot="menu-popup"
          className={cn(
            "min-w-44 rounded-control border border-hairline bg-popover/95 p-[5px] text-row-title text-fg shadow-[0_8px_24px_rgb(0_0_0/0.28)] backdrop-blur-xl outline-none",
            "origin-(--transform-origin) transition-[opacity,scale] duration-140 data-ending-style:opacity-0 data-starting-style:scale-97 data-starting-style:opacity-0",
            className,
          )}
          {...props}
        >
          {children}
        </MenuPrimitive.Popup>
      </MenuPrimitive.Positioner>
    </MenuPrimitive.Portal>
  );
}

function MenuItem({
  className,
  icon,
  shortcut,
  children,
  ...props
}: MenuPrimitive.Item.Props & { icon?: ReactNode; shortcut?: ReactNode }) {
  return (
    <MenuPrimitive.Item
      data-slot="menu-item"
      className={cn(
        "flex h-[22px] items-center gap-2 rounded-[5px] px-2 outline-none select-none data-disabled:opacity-45 data-highlighted:bg-accent data-highlighted:text-accent-fg [&_svg]:size-3.5",
        className,
      )}
      {...props}
    >
      {icon}
      <span className="flex-1">{children}</span>
      {shortcut ? (
        <span className="ml-4 text-fg-secondary in-data-highlighted:text-accent-fg/80">
          {shortcut}
        </span>
      ) : null}
    </MenuPrimitive.Item>
  );
}

const MenuGroup = MenuPrimitive.Group;

/** A section heading inside a menu, such as "Scope" or "Modifiers". */
function MenuGroupLabel({ className, ...props }: MenuPrimitive.GroupLabel.Props) {
  return (
    <MenuPrimitive.GroupLabel
      data-slot="menu-group-label"
      className={cn("px-2 pt-1 pb-0.5 text-meta font-medium text-fg-secondary", className)}
      {...props}
    />
  );
}

const choiceItem =
  "grid h-[22px] grid-cols-[16px_1fr] items-center gap-1 rounded-[5px] pr-3 pl-1 outline-none select-none data-disabled:opacity-45 data-highlighted:bg-accent data-highlighted:text-accent-fg";

/** An item that toggles on and off and stays open, such as a modifier filter. */
function MenuCheckboxItem({ className, children, ...props }: MenuPrimitive.CheckboxItem.Props) {
  return (
    <MenuPrimitive.CheckboxItem
      data-slot="menu-checkbox-item"
      className={cn(choiceItem, className)}
      {...props}
    >
      <MenuPrimitive.CheckboxItemIndicator className="col-start-1 flex">
        <Check aria-hidden className="size-3" strokeWidth={3} />
      </MenuPrimitive.CheckboxItemIndicator>
      <span className="col-start-2 whitespace-nowrap">{children}</span>
    </MenuPrimitive.CheckboxItem>
  );
}

/** Holds `MenuRadioItem`s that choose one value, such as a scope. */
const MenuRadioGroup = MenuPrimitive.RadioGroup;

function MenuRadioItem({ className, children, ...props }: MenuPrimitive.RadioItem.Props) {
  return (
    <MenuPrimitive.RadioItem
      data-slot="menu-radio-item"
      className={cn(choiceItem, className)}
      {...props}
    >
      <MenuPrimitive.RadioItemIndicator className="col-start-1 flex">
        <Check aria-hidden className="size-3" strokeWidth={3} />
      </MenuPrimitive.RadioItemIndicator>
      <span className="col-start-2 whitespace-nowrap">{children}</span>
    </MenuPrimitive.RadioItem>
  );
}

function MenuSeparator({ className, ...props }: MenuPrimitive.Separator.Props) {
  return (
    <MenuPrimitive.Separator
      className={cn("mx-2 my-[5px] h-px bg-hairline", className)}
      {...props}
    />
  );
}

export {
  Menu,
  MenuCheckboxItem,
  MenuGroup,
  MenuGroupLabel,
  MenuItem,
  MenuPopup,
  MenuRadioGroup,
  MenuRadioItem,
  MenuSeparator,
  MenuTrigger,
};
