import { cn } from "~/lib/cn";

import type { Release } from "./changelog-mock";

/** A glow of the theme's accent over its background, standing in for the theme's wallpaper. */
export function ReleaseArt({
  art,
  className,
}: {
  art: NonNullable<Release["art"]>;
  className?: string;
}) {
  return (
    <div
      aria-hidden
      className={cn("absolute inset-0", className)}
      style={{
        background: `radial-gradient(120% 120% at 20% 0%, color-mix(in srgb, ${art.to} 55%, ${art.from}) 0%, ${art.from} 70%)`,
      }}
    />
  );
}
