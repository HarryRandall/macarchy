import {
  Activity,
  AppWindow,
  BatteryMedium,
  Bluetooth,
  CalendarDays,
  Clock,
  CloudSun,
  Coffee,
  Cpu,
  Globe,
  Gpu,
  HardDrive,
  Hash,
  type LucideIcon,
  Mail,
  MemoryStick,
  Music,
  Palette,
  PanelTop,
  Rocket,
  Terminal,
  Volume2,
  Wifi,
  Zap,
} from "lucide-react";
import type { CSSProperties } from "react";

import { BrandMark } from "~/shell/brand-mark";

import type { BarIconName } from "./menu-bar-mock";

const icons: Record<Exclude<BarIconName, "macarchy">, LucideIcon> = {
  Activity,
  AppWindow,
  BatteryMedium,
  Bluetooth,
  CalendarDays,
  Clock,
  CloudSun,
  Coffee,
  Cpu,
  Globe,
  Gpu,
  HardDrive,
  Hash,
  Mail,
  MemoryStick,
  Music,
  Palette,
  PanelTop,
  Rocket,
  Terminal,
  Volume2,
  Wifi,
  Zap,
};

/** A bar item's glyph; decorative, since the item's name is always beside it. */
export function ItemIcon({
  icon,
  size,
  className,
  style,
}: {
  icon: BarIconName;
  size: number;
  className?: string;
  style?: CSSProperties;
}) {
  if (icon === "macarchy") {
    return <BrandMark width={size + 2} height={size + 2} className={className} style={style} />;
  }
  const Icon = icons[icon];
  return <Icon aria-hidden size={size} strokeWidth={1.75} className={className} style={style} />;
}
