import {
  Activity,
  AppWindow,
  BatteryMedium,
  Clock,
  Cpu,
  Hash,
  type LucideIcon,
  MemoryStick,
  MoveHorizontal,
  PanelTop,
  Puzzle,
  Terminal,
  Type,
  Volume2,
  Wifi,
} from "lucide-react";
import { createElement, type CSSProperties } from "react";

import type { BarItem } from "./menu-bar-items";

/** The bar's own items by SketchyBar name; anything else is a panel. */
const builtIn: Record<string, LucideIcon> = {
  workspaces: Hash,
  calendar: Clock,
  battery: BatteryMedium,
  cpu: Cpu,
  memory: MemoryStick,
  ram: MemoryStick,
  front_app: AppWindow,
  network: Activity,
  wifi: Wifi,
  volume: Volume2,
};

const made: Record<Exclude<NonNullable<BarItem["kind"]>, "widget">, LucideIcon> = {
  text: Type,
  spacer: MoveHorizontal,
  command: Terminal,
};

/** Built-in widgets by id; the person's own are a puzzle piece. */
const widgets: Record<string, LucideIcon> = { clock: Clock, cpu: Cpu, battery: BatteryMedium };

type IconItem = Pick<BarItem, "id" | "kind"> & { widget?: string | null };

export function iconFor(item: IconItem): LucideIcon {
  if (item.kind === "widget") return widgets[item.widget ?? ""] ?? Puzzle;
  return item.kind ? made[item.kind] : (builtIn[item.id] ?? PanelTop);
}

/** A bar item's glyph; decorative, since the item's name is always beside it. */
export function ItemIcon({
  item,
  size,
  className,
  style,
}: {
  item: IconItem;
  size: number;
  className?: string;
  style?: CSSProperties;
}) {
  return createElement(iconFor(item), {
    "aria-hidden": true,
    size,
    strokeWidth: 1.75,
    className,
    style,
  });
}
