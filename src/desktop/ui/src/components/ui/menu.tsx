import { Menu as MenuPrimitive } from "@base-ui/react/menu";
import { Check } from "lucide-react";
import type { ReactNode } from "react";

import { cn } from "~/lib/cn";

import { popupItem, popupMotion, popupSurface } from "./surface";

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
        sideOffset={6}
        collisionPadding={8}
        className="z-50 outline-none"
      >
        <MenuPrimitive.Popup
          data-slot="menu-popup"
          className={cn("min-w-48", popupSurface, popupMotion, className)}
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
}: MenuPrimitive.Item.Props & {
  /** A 14px glyph before the label; mark it `aria-hidden`. */
  icon?: ReactNode;
  /** Keys or a hint after the label, such as "⌘L". */
  shortcut?: ReactNode;
}) {
  return (
    <MenuPrimitive.Item data-slot="menu-item" className={cn(popupItem, className)} {...props}>
      {icon}
      <span className="min-w-0 flex-1 truncate">{children}</span>
      {shortcut ? (
        <span className="ml-4 shrink-0 text-meta tracking-[0.04em] text-fg-tertiary">
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
      className={cn("px-2 pt-1.5 pb-1 text-caption font-medium text-fg-tertiary", className)}
      {...props}
    />
  );
}

const choiceItem = cn(popupItem, "grid grid-cols-[14px_1fr] gap-2 pr-3 [&_svg]:text-fg");

/** An item that toggles on and off and stays open, such as a modifier filter. */
function MenuCheckboxItem({ className, children, ...props }: MenuPrimitive.CheckboxItem.Props) {
  return (
    <MenuPrimitive.CheckboxItem
      data-slot="menu-checkbox-item"
      className={cn(choiceItem, className)}
      {...props}
    >
      <MenuPrimitive.CheckboxItemIndicator className="col-start-1 flex">
        <Check aria-hidden strokeWidth={2.5} />
      </MenuPrimitive.CheckboxItemIndicator>
      <span className="col-start-2 truncate">{children}</span>
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
        <Check aria-hidden strokeWidth={2.5} />
      </MenuPrimitive.RadioItemIndicator>
      <span className="col-start-2 truncate">{children}</span>
    </MenuPrimitive.RadioItem>
  );
}

function MenuSeparator({ className, ...props }: MenuPrimitive.Separator.Props) {
  return (
    <MenuPrimitive.Separator className={cn("-mx-1 my-1 h-px bg-hairline", className)} {...props} />
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
