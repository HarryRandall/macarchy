import { CornerDownLeft, Images, RotateCw, Settings } from "lucide-react";

import { KbdGroup } from "~/components/ui/kbd";
import { cn } from "~/lib/cn";

import { keepSearchFocus, selectedEdge } from "./switcher-chrome";
import type { ActionItem, Command } from "./switcher-model";

const icons: Record<Command, typeof CornerDownLeft> = {
  primary: CornerDownLeft,
  switchBackground: Images,
  refresh: RotateCw,
  openSettings: Settings,
};

export const actionId = (index: number) => `switcher-action-${index}`;

/**
 * The ⌘K menu. The search field keeps focus throughout, so this is a listbox
 * driven by the field's active descendant rather than a focus-taking menu.
 */
export function SwitcherActions({
  id,
  items,
  highlighted,
  onHighlight,
  onRun,
}: {
  id: string;
  items: ActionItem[];
  highlighted: number;
  onHighlight: (index: number) => void;
  onRun: (command: Command) => void;
}) {
  return (
    <div
      id={id}
      role="listbox"
      aria-label="Actions"
      className={cn(
        "absolute right-2.5 bottom-[46px] z-10 flex w-[280px] flex-col gap-0.5 rounded-[10px] bg-black/55 p-1.5 backdrop-blur-2xl",
        "shadow-[0_6px_16px_rgb(0_0_0/0.4)] after:pointer-events-none after:absolute after:inset-0 after:rounded-[10px] after:border after:border-white/12",
        "origin-bottom-right transition-[opacity,scale] duration-120 ease-out starting:scale-97 starting:opacity-0",
      )}
    >
      {items.map((item, index) => {
        const Icon = icons[item.command];
        return (
          // oxlint-disable-next-line jsx-a11y/click-events-have-key-events, jsx-a11y/interactive-supports-focus -- reached through the search field's aria-activedescendant; the field keeps focus and handles the keys.
          <div
            key={item.command}
            id={actionId(index)}
            role="option"
            aria-selected={index === highlighted}
            onMouseEnter={() => onHighlight(index)}
            onClick={() => onRun(item.command)}
            {...keepSearchFocus}
            className={cn(
              "flex h-[30px] items-center gap-2.5 rounded-small px-2 text-[13px] text-fg",
              index === highlighted && selectedEdge,
            )}
          >
            <Icon aria-hidden className="w-[18px] shrink-0" size={14} strokeWidth={2} />
            <span className="min-w-0 flex-1 truncate">{item.title}</span>
            <KbdGroup keys={item.keys} />
          </div>
        );
      })}
    </div>
  );
}
