import { Check, ChevronLeft, ChevronRight, Download, X } from "lucide-react";
import { type KeyboardEvent, useState } from "react";

import { Badge } from "~/components/ui/badge";
import { Button } from "~/components/ui/button";
import { Dialog } from "~/components/ui/dialog";
import { focusRing } from "~/components/ui/focus-ring";
import { IconButton } from "~/components/ui/icon-button";
import { Swatches } from "~/components/ui/swatches";
import { cn } from "~/lib/cn";

import { Cover, Shot } from "./workshop-cover";
import { kindLabels, stepIndex } from "./workshop-items";
import type { WorkshopItem } from "./workshop-mock";

/**
 * Which item the dialog shows and which of its pictures to start on. It
 * stays set while the dialog fades out, so the dialog never empties first.
 */
export interface Opened {
  id: string;
  index: number;
  open: boolean;
  /** Counts openings, so each starts afresh on the picture it was opened at. */
  opening: number;
}

interface DetailActions {
  isInstalled: (item: WorkshopItem) => boolean;
  isInUse: (item: WorkshopItem) => boolean;
  onInstall: (item: WorkshopItem) => void;
  onTry: (item: WorkshopItem) => void;
}

/**
 * One item large. A wallpaper pages through every background of its theme
 * as one carousel; a theme pages through its own pictures. Left and Right
 * arrows step through them.
 */
export function DetailDialog({
  opened,
  item,
  siblings,
  onClose,
  ...actions
}: DetailActions & {
  opened: Opened | null;
  item: WorkshopItem | undefined;
  siblings: WorkshopItem[];
  onClose: () => void;
}) {
  return (
    <Dialog.Root
      open={Boolean(opened?.open && item)}
      onOpenChange={(open) => (open ? undefined : onClose())}
    >
      {item && opened ? (
        <DetailContent
          key={opened.opening}
          base={item}
          siblings={siblings}
          start={opened.index}
          {...actions}
        />
      ) : null}
    </Dialog.Root>
  );
}

function DetailContent({
  base,
  siblings,
  start,
  isInstalled,
  isInUse,
  onInstall,
  onTry,
}: DetailActions & {
  base: WorkshopItem;
  siblings: WorkshopItem[];
  start: number;
}) {
  const paged = siblings.length > 1 ? siblings : null;
  const [index, setIndex] = useState(() =>
    paged ? Math.max(0, paged.indexOf(base)) : Math.min(start, Math.max(0, base.images.length - 1)),
  );
  const item = paged ? (paged[index] ?? base) : base;
  const images = paged ? paged.map((entry) => entry.images[0]) : item.images;
  const slides =
    paged?.length ??
    (item.kind === "layout" || item.kind === "bar" ? 1 : Math.max(1, images.length));
  const installed = isInstalled(item);
  const inUse = isInUse(item);
  const wallpaper = item.kind === "wallpaper";
  const picture = wallpaper ? "background" : "picture";
  const step = (delta: number) => setIndex((current) => stepIndex(current, delta, slides));

  const onKeyDown = (event: KeyboardEvent) => {
    if (slides < 2) return;
    if (event.key === "ArrowRight") step(1);
    else if (event.key === "ArrowLeft") step(-1);
    else return;
    event.preventDefault();
  };

  return (
    <Dialog.Popup size="xl" onKeyDown={onKeyDown}>
      <div className="flex min-h-0 flex-col overflow-y-auto">
        <div className="relative aspect-video w-full shrink-0 bg-muted">
          <Cover item={item} index={paged ? 0 : index} large eager />
          {slides > 1 ? (
            <>
              <IconButton
                label={`Previous ${picture}`}
                keys="←"
                tone="translucent"
                size="md"
                className="absolute top-1/2 left-3 -translate-y-1/2 rounded-full"
                onClick={() => step(-1)}
              >
                <ChevronLeft aria-hidden />
              </IconButton>
              <IconButton
                label={`Next ${picture}`}
                keys="→"
                tone="translucent"
                size="md"
                className="absolute top-1/2 right-3 -translate-y-1/2 rounded-full"
                onClick={() => step(1)}
              >
                <ChevronRight aria-hidden />
              </IconButton>
              <span
                aria-live="polite"
                className="absolute bottom-3 left-3 rounded-small bg-black/50 px-2 py-0.5 text-caption text-white tabular-nums backdrop-blur-sm"
              >
                {index + 1} of {slides}
              </span>
            </>
          ) : null}
          <Dialog.Close
            render={
              <IconButton
                label="Close"
                keys="Esc"
                tone="translucent"
                className="absolute top-3 right-3 rounded-full"
              />
            }
          >
            <X aria-hidden />
          </Dialog.Close>
        </div>

        {slides > 1 ? (
          <ul
            aria-label={wallpaper ? "Backgrounds" : "Pictures"}
            className="flex shrink-0 gap-2 overflow-x-auto border-b border-hairline px-5 py-3"
          >
            {images.map((src, position) => (
              <li key={src ?? `missing-${position}`} className="shrink-0">
                <button
                  type="button"
                  aria-label={`Show ${picture} ${position + 1}`}
                  aria-pressed={position === index}
                  onClick={() => setIndex(position)}
                  className={cn(
                    "block h-12 w-20 overflow-hidden rounded-small border transition-[opacity,box-shadow] motion-reduce:transition-none",
                    focusRing,
                    position === index
                      ? "border-accent ring-2 ring-accent-soft"
                      : "border-hairline opacity-60 hover:opacity-100",
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
        ) : null}

        <div className="flex flex-wrap items-start gap-6 px-5 py-4">
          <div className="min-w-0 flex-1 basis-80">
            <div className="mb-1 flex items-center gap-1.5">
              <Badge>{kindLabels[item.kind]}</Badge>
              {inUse ? (
                <Badge tone="accent" dot>
                  In use
                </Badge>
              ) : installed ? (
                <Badge tone="ok" dot>
                  Installed
                </Badge>
              ) : null}
            </div>
            <Dialog.Title className="text-stat">{item.name}</Dialog.Title>
            <Dialog.Description className="mt-0.5 text-body">
              {item.subtitle} By {item.author}.
            </Dialog.Description>
            <div className="mt-3 flex flex-wrap items-center gap-3 text-small text-fg-tertiary">
              <Swatches colours={item.colours} size={16} label={`${item.name} colours`} />
              <span className="flex items-center gap-1 tabular-nums">
                <Download aria-hidden size={12} /> {item.downloads.toLocaleString("en-GB")}{" "}
                downloads
              </span>
              <ul aria-label="Tags" className="flex flex-wrap gap-1.5">
                {item.tags.map((tag) => (
                  <li
                    key={tag}
                    className="rounded-[5px] bg-muted px-1.5 py-0.5 text-caption text-fg-secondary"
                  >
                    {tag}
                  </li>
                ))}
              </ul>
            </div>
          </div>
          <div className="flex shrink-0 flex-col gap-2 pt-1">
            <Button variant="primary" disabled={inUse} onClick={() => onTry(item)}>
              {inUse ? "In use" : "Try it on"}
            </Button>
            <Button disabled={installed} onClick={() => onInstall(item)}>
              {installed ? (
                <>
                  <Check aria-hidden size={13} /> {wallpaper ? "In library" : "Installed"}
                </>
              ) : (
                <>
                  <Download aria-hidden size={13} /> {wallpaper ? "Add to library" : "Install"}
                </>
              )}
            </Button>
            <p className="max-w-40 text-caption text-fg-tertiary">
              A preview: nothing downloads yet.
            </p>
          </div>
        </div>
      </div>
    </Dialog.Popup>
  );
}
