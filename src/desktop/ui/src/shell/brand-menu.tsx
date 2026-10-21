import { Menu as MenuPrimitive } from "@base-ui/react/menu";
import { ChevronDown, type LucideIcon, Monitor, Moon, Sun } from "lucide-react";

import type { AppearanceMode } from "~/bridge/protocol";
import {
  Menu,
  MenuGroup,
  MenuGroupLabel,
  MenuItem,
  MenuPopup,
  MenuRadioGroup,
  MenuSeparator,
  MenuTrigger,
} from "~/components/ui/menu";
import { Tooltip } from "~/components/ui/tooltip";
import { cn } from "~/lib/cn";

import { type ShellAction, shellActions } from "./actions";
import { AppTile } from "./app-tile";

const modes: { id: AppearanceMode; label: string; icon: LucideIcon }[] = [
  { id: "system", label: "System", icon: Monitor },
  { id: "light", label: "Light", icon: Sun },
  { id: "dark", label: "Dark", icon: Moon },
];

const sections: ShellAction[][] = [
  ["updates", "folder", "reload", "logs"],
  ["changelog", "shortcuts", "about"],
  ["quit"],
];

function isMode(value: unknown): value is AppearanceMode {
  return modes.some((mode) => mode.id === value);
}

/** Three equal columns whose raised pill slides to the chosen one. Choosing keeps the menu open. */
function AppearanceChoice({
  mode,
  onMode,
}: {
  mode: AppearanceMode;
  onMode: (mode: AppearanceMode) => void;
}) {
  const index = Math.max(
    0,
    modes.findIndex((candidate) => candidate.id === mode),
  );
  return (
    <MenuRadioGroup
      value={mode}
      onValueChange={(value: unknown) => {
        if (isMode(value)) onMode(value);
      }}
      className="relative grid grid-cols-3 rounded-[8px] bg-seg-track p-[3px] ring-1 ring-seg-ring ring-inset"
    >
      <span
        aria-hidden
        className="pointer-events-none absolute inset-y-[3px] left-[3px] rounded-[5px] bg-seg-pill shadow-seg-pill transition-transform duration-200 ease-[cubic-bezier(0.32,0.72,0,1)]"
        style={{
          width: `calc((100% - 6px) / ${modes.length})`,
          transform: `translateX(${index * 100}%)`,
        }}
      />
      {modes.map(({ id, label, icon: Icon }) => (
        <MenuPrimitive.RadioItem
          key={id}
          value={id}
          closeOnClick={false}
          className={cn(
            "group relative flex h-[30px] min-w-0 items-center justify-center gap-1.5 rounded-[5px] px-2.5 text-[12px] leading-none font-medium whitespace-nowrap outline-none select-none transition-[color,background-color] duration-150 focus-visible:ring-2 focus-visible:ring-accent focus-visible:ring-inset",
            "text-fg-secondary data-checked:text-fg data-highlighted:text-fg [&:not([data-checked])]:hover:bg-seg-hover",
          )}
        >
          <Icon
            aria-hidden
            size={13}
            strokeWidth={id === mode ? 2 : 1.75}
            className="shrink-0 text-fg-tertiary transition-colors duration-150 group-hover:text-fg-secondary group-data-checked:text-fg"
          />
          {label}
        </MenuPrimitive.RadioItem>
      ))}
    </MenuRadioGroup>
  );
}

/**
 * The app's own menu at the top of the sidebar: appearance and the window's
 * actions. Collapsed, only the tile shows and its name is in a tooltip.
 */
export function BrandMenu({
  collapsed,
  subtitle,
  fresh,
  mode,
  open,
  onOpenChange,
  onMode,
  onAction,
}: {
  collapsed: boolean;
  /** The Mac's model, once Setup health has read it. */
  subtitle: string | null;
  /** A release the person has not read yet, marked on What's new. */
  fresh: boolean;
  mode: AppearanceMode;
  open: boolean;
  onOpenChange: (open: boolean) => void;
  onMode: (mode: AppearanceMode) => void;
  onAction: (action: ShellAction) => void;
}) {
  return (
    <Menu open={open} onOpenChange={(next) => onOpenChange(next)}>
      <Tooltip content="Macarchy" side="right" disabled={!collapsed || open} describe={false}>
        <MenuTrigger
          aria-label={collapsed ? "Macarchy menu" : undefined}
          className={cn(
            "group flex h-10 items-center gap-2.5 overflow-hidden rounded-[8px] px-1.5 text-left whitespace-nowrap transition-[width,background-color] duration-200 ease-out focus-visible:ring-2 focus-visible:ring-accent focus-visible:outline-none",
            collapsed ? "w-10" : "w-full",
            open ? "bg-hover" : "hover:bg-hover",
          )}
        >
          <AppTile />
          <span
            aria-hidden={collapsed}
            className={cn(
              "flex min-w-0 flex-1 items-center gap-2.5 transition-opacity duration-150",
              collapsed ? "opacity-0" : "opacity-100",
            )}
          >
            <span className="min-w-0 flex-1">
              <span className="block text-[13px] leading-[18px] font-semibold tracking-[-0.01em] text-fg">
                Macarchy
              </span>
              {subtitle ? (
                <span className="block truncate text-[11.5px] leading-4 text-fg-tertiary">
                  {subtitle}
                </span>
              ) : null}
            </span>
            <ChevronDown
              aria-hidden
              size={14}
              strokeWidth={1.75}
              className={cn(
                "shrink-0 text-fg-tertiary transition-[transform,opacity] duration-150",
                open ? "rotate-180 opacity-100" : "opacity-60 group-hover:opacity-100",
              )}
            />
          </span>
        </MenuTrigger>
      </Tooltip>
      <MenuPopup align="start" aria-label="Macarchy" className="w-64 p-1">
        <MenuGroup className="px-1 pt-1.5 pb-2">
          <MenuGroupLabel className="px-0.5 pt-0 pb-[7px] text-[11px] leading-[14px] font-medium text-fg-tertiary">
            Appearance
          </MenuGroupLabel>
          <AppearanceChoice mode={mode} onMode={onMode} />
        </MenuGroup>
        {sections.map((section) => (
          <MenuGroup key={section[0]}>
            <MenuSeparator className="-mx-1 my-1" />
            {section.map((action) => {
              const { label, icon: Icon, keys } = shellActions[action];
              return (
                <MenuItem
                  key={action}
                  icon={<Icon aria-hidden strokeWidth={1.75} className="text-fg-secondary" />}
                  shortcut={keys}
                  onClick={() => onAction(action)}
                >
                  <span className="flex items-center gap-2">
                    {label}
                    {action === "changelog" && fresh ? (
                      <span className="size-1.5 rounded-full bg-accent">
                        <span className="sr-only">, unread</span>
                      </span>
                    ) : null}
                  </span>
                </MenuItem>
              );
            })}
          </MenuGroup>
        ))}
      </MenuPopup>
    </Menu>
  );
}
