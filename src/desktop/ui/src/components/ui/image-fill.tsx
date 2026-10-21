import { useState } from "react";

import { cn } from "~/lib/cn";

/**
 * An image covering its positioned parent, over a gradient of the theme's
 * own colours that shows while it loads and stays when the file is missing
 * or fails, so a card never shows a broken image.
 */
function ImageFill({
  src,
  from,
  to,
  alt = "",
  className,
}: {
  src?: string | null;
  /** The theme's background, the gradient's base. */
  from: string;
  /** The theme's accent, the gradient's glow. */
  to: string;
  /** Empty for artwork that only decorates; the card names the theme. */
  alt?: string;
  className?: string;
}) {
  const [failed, setFailed] = useState<string | null>(null);
  const show = src && failed !== src;
  return (
    <div
      data-slot="image-fill"
      className={cn("absolute inset-0 overflow-hidden", className)}
      style={{
        background: `radial-gradient(120% 120% at 20% 0%, color-mix(in srgb, ${to} 55%, ${from}) 0%, ${from} 70%)`,
      }}
    >
      {show ? (
        <img
          src={src}
          alt={alt}
          draggable={false}
          loading="lazy"
          onError={() => setFailed(src)}
          className="size-full object-cover"
        />
      ) : null}
    </div>
  );
}

export { ImageFill };
