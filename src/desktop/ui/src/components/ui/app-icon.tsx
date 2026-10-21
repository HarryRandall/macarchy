import { SquareDashed } from "lucide-react";
import { useState } from "react";

import { cn } from "~/lib/cn";

import { appLetter, letterHue } from "./app-letter";

/**
 * An application's icon, or a placeholder when there is none or it fails to
 * load: a lettered tile in a colour of its own when the app's `name` is
 * known, else a dashed square. Decorative: the row beside it names the app.
 * The host resolves icons by name, so pages pass the URL it gives them.
 */
function AppIcon({
  src,
  name,
  size = 18,
  className,
}: {
  src?: string | null;
  /** The app's name, for the lettered tile drawn when there is no icon. */
  name?: string;
  /** Points square. */
  size?: number;
  className?: string;
}) {
  const [failed, setFailed] = useState<string | null>(null);
  const showImage = src && failed !== src;
  // macOS icons leave a transparent margin, so the tile is inset to match.
  const inner = Math.round(size * 0.8);
  const hue = name ? letterHue(name) : 0;
  return (
    <span
      aria-hidden
      data-slot="app-icon"
      className={cn("inline-flex shrink-0 items-center justify-center", className)}
      style={{ width: size, height: size }}
    >
      {showImage ? (
        <img
          src={src}
          alt=""
          draggable={false}
          onError={() => setFailed(src)}
          className="size-full object-contain drop-shadow-[0_1px_1.5px_rgb(0_0_0/0.16)]"
        />
      ) : name ? (
        <span
          className="grid place-items-center leading-none font-semibold text-white shadow-[inset_0_0_0_0.5px_rgb(255_255_255/0.28),0_1px_2px_rgb(0_0_0/0.22)]"
          style={{
            width: inner,
            height: inner,
            borderRadius: inner * 0.24,
            fontSize: inner * 0.46,
            background: `linear-gradient(160deg, hsl(${hue} 58% 58%), hsl(${(hue + 18) % 360} 52% 38%))`,
          }}
        >
          {appLetter(name)}
        </span>
      ) : (
        <SquareDashed className="size-[85%] text-fg-tertiary" strokeWidth={1.75} />
      )}
    </span>
  );
}

export { AppIcon };
