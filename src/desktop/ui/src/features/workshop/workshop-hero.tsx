import { Download, Sparkles } from "lucide-react";
import { useId } from "react";

import { Button } from "~/components/ui/button";
import { focusRing } from "~/components/ui/focus-ring";
import { cn } from "~/lib/cn";

import { type ItemStatus, tryOn } from "./workshop-cards";
import { Shot } from "./workshop-cover";
import { formatCount } from "./workshop-items";
import type { WorkshopItem } from "./workshop-mock";

/**
 * The week's featured theme over its own wallpaper. The words sit on a
 * darkened picture, so they are drawn in the dark appearance whatever the
 * window's.
 */
export function WorkshopHero({
  item,
  image,
  status,
  onTry,
  onOpen,
}: {
  item: WorkshopItem;
  image: number;
  status: ItemStatus;
  onTry: () => void;
  onOpen: (index: number) => void;
}) {
  const titleId = useId();
  const action = tryOn(item, status);
  return (
    <section
      aria-labelledby={titleId}
      className="@container relative mb-6 h-[280px] overflow-hidden rounded-panel border border-hairline shadow-card"
    >
      <div aria-hidden className="absolute inset-0">
        <Shot
          src={item.images[image] ?? item.images[0]}
          colours={item.colours}
          alt=""
          className="size-full"
          eager
          labelMissing={false}
        />
      </div>
      <div
        aria-hidden
        className="absolute inset-0 bg-[linear-gradient(90deg,rgba(0,0,0,0.78)_0%,rgba(0,0,0,0.45)_45%,transparent_75%)]"
      />
      <div
        data-appearance="dark"
        className="absolute inset-y-0 left-0 flex w-full flex-col justify-end bg-transparent p-6 text-white @[640px]:w-[56%]"
      >
        <span className="mb-2 inline-flex w-fit items-center gap-1.5 rounded-small bg-white/15 px-2 py-0.5 text-meta font-medium backdrop-blur-sm">
          <Sparkles aria-hidden size={11} /> Featured this week
        </span>
        <h2 id={titleId} className="truncate text-hero-title">
          {item.name}
        </h2>
        <p className="mt-1 line-clamp-2 text-body text-white/75">
          {item.subtitle} By {item.author}.
        </p>
        <div className="mt-2.5 flex items-center gap-3 text-meta text-white/70">
          <div aria-hidden className="flex items-center -space-x-1">
            {item.colours.map((colour, index) => (
              <span
                // A palette can repeat a colour, so position is part of the key.
                key={`${index}-${colour}`}
                className="size-3 rounded-full ring-2 ring-black/40"
                style={{ background: colour }}
              />
            ))}
          </div>
          <span className="flex items-center gap-1 tabular-nums">
            <Download aria-hidden size={11} /> {formatCount(item.downloads)}
            <span className="sr-only"> downloads</span>
          </span>
        </div>
        <div className="mt-4 flex items-center gap-2">
          <Button
            variant="accent"
            disabled={status.inUse}
            aria-label={action.label}
            onClick={onTry}
          >
            {action.text}
          </Button>
          <Button
            variant="ghost"
            className="text-white/90 hover:bg-white/15 hover:text-white"
            onClick={() => onOpen(image)}
          >
            View details
          </Button>
        </div>
      </div>
      <ul
        aria-label={`${item.name} backgrounds`}
        className="absolute right-4 bottom-4 hidden gap-1.5 @[640px]:flex"
      >
        {item.images.map((src, index) => (
          <li key={src ?? `missing-${index}`}>
            <button
              type="button"
              aria-label={`Preview background ${index + 1}`}
              onClick={() => onOpen(index)}
              className={cn(
                "block h-11 w-[70px] overflow-hidden rounded-small border border-white/30 shadow-lg transition-transform hover:-translate-y-0.5 motion-reduce:transition-none",
                focusRing,
              )}
            >
              <Shot
                src={src}
                colours={item.colours}
                alt=""
                className="size-full"
                labelMissing={false}
              />
            </button>
          </li>
        ))}
      </ul>
    </section>
  );
}
