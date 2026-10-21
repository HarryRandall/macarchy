import { SquareDashed } from "lucide-react";
import { useState } from "react";

import { cn } from "~/lib/cn";

/**
 * An application's icon, or a neutral placeholder when there is none or it
 * fails to load. Decorative: the row beside it names the app. The host
 * resolves icons by name, so pages pass the URL it gives them.
 */
function AppIcon({
  src,
  size = 18,
  className,
}: {
  src?: string | null;
  /** Points square. */
  size?: number;
  className?: string;
}) {
  const [failed, setFailed] = useState<string | null>(null);
  const showImage = src && failed !== src;
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
          className="size-full object-contain"
        />
      ) : (
        <SquareDashed className="size-[85%] text-fg-secondary" strokeWidth={1.75} />
      )}
    </span>
  );
}

export { AppIcon };
