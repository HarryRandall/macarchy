import { Check, Download, Images } from "lucide-react";

import { Button } from "~/components/ui/button";
import { cardSurface } from "~/components/ui/card";
import { focusRing } from "~/components/ui/focus-ring";
import { Swatches } from "~/components/ui/swatches";
import { TruncatedText } from "~/components/ui/truncated-text";
import { cn } from "~/lib/cn";

import { Cover } from "./workshop-cover";
import { formatCount } from "./workshop-items";
import type { WorkshopItem } from "./workshop-mock";

/** What the page knows about one item beyond the catalogue. */
export interface ItemStatus {
  installed: boolean;
  inUse: boolean;
  trying: boolean;
}

function StatusChip({ inUse, installed }: { inUse: boolean; installed: boolean }) {
  if (inUse) {
    return (
      <span className="inline-flex items-center gap-1 rounded-[5px] bg-accent px-1.5 py-0.5 text-axis font-semibold text-accent-fg">
        <Check aria-hidden size={10} strokeWidth={3} /> In use
      </span>
    );
  }
  if (installed) {
    return (
      <span className="inline-flex items-center gap-1 rounded-[5px] bg-black/55 px-1.5 py-0.5 text-axis font-medium text-white backdrop-blur-sm">
        <Check aria-hidden size={10} strokeWidth={3} /> Installed
      </span>
    );
  }
  return null;
}

/**
 * The try-on button's words, and its name with the item after them, so the
 * name still starts with what the button shows.
 */
export function tryOn(item: WorkshopItem, status: ItemStatus): { text: string; label: string } {
  const text = status.inUse ? "In use" : status.trying ? "Trying now" : "Try it on";
  return { text, label: `${text}, ${item.name}` };
}

function statusWords({ inUse, installed }: Pick<ItemStatus, "inUse" | "installed">): string {
  if (inUse) return ", in use";
  if (installed) return ", installed";
  return "";
}

/** A theme, layout or bar: its cover opens the details, and the button tries it on. */
export function ItemCard({
  item,
  status,
  onOpen,
  onTry,
}: {
  item: WorkshopItem;
  status: ItemStatus;
  onOpen: () => void;
  onTry: () => void;
}) {
  const imageCount = item.images.length;
  const action = tryOn(item, status);
  return (
    <li
      className={cn(
        cardSurface,
        "group p-1.5 transition-[border-color,box-shadow] hover:border-line-strong",
      )}
    >
      <button
        type="button"
        onClick={onOpen}
        aria-label={`Open ${item.name}${statusWords(status)}`}
        className={cn(
          "relative block aspect-[16/10] w-full overflow-hidden rounded-[7px] border border-hairline",
          focusRing,
        )}
      >
        <div className="size-full transition-transform duration-500 ease-out group-hover:scale-[1.03] motion-reduce:transition-none motion-reduce:group-hover:scale-100">
          <Cover item={item} />
        </div>
        <div className="absolute top-1.5 left-1.5 flex gap-1">
          <StatusChip inUse={status.inUse} installed={status.installed} />
        </div>
        {imageCount > 1 ? (
          <span className="absolute top-1.5 right-1.5 inline-flex items-center gap-1 rounded-[5px] bg-black/45 px-1.5 py-0.5 text-axis text-white opacity-0 backdrop-blur-sm transition-opacity group-focus-within:opacity-100 group-hover:opacity-100">
            <Images aria-hidden size={10} /> {imageCount}
          </span>
        ) : null}
      </button>
      <div className="px-1 pt-2 pb-0.5">
        <div className="flex items-center gap-2">
          <TruncatedText
            text={item.name}
            className="flex-1 text-body font-semibold tracking-[-0.01em] text-fg"
          />
          <span className="flex shrink-0 items-center gap-1 text-caption text-fg-tertiary tabular-nums">
            <Download aria-hidden size={10.5} /> {formatCount(item.downloads)}
            <span className="sr-only"> downloads</span>
          </span>
        </div>
        <div className="mt-0.5 flex items-center gap-2">
          <div className="min-w-0 flex-1 truncate text-meta text-fg-secondary">{item.author}</div>
          <Swatches colours={item.colours} size={10} className="gap-0.5" />
        </div>
        <Button
          size="sm"
          className="mt-2 w-full"
          variant={status.trying ? "accent" : "secondary"}
          aria-label={action.label}
          disabled={status.inUse}
          onClick={onTry}
        >
          {action.text}
        </Button>
      </div>
    </li>
  );
}

/** A wallpaper, all picture: the name shows on hover or focus, and it opens the details. */
export function WallpaperTile({
  item,
  status,
  onOpen,
}: {
  item: WorkshopItem;
  status: Pick<ItemStatus, "inUse" | "installed">;
  onOpen: () => void;
}) {
  return (
    <li className="min-w-0">
      <button
        type="button"
        onClick={onOpen}
        aria-label={`Open ${item.name}${statusWords(status)}`}
        className={cn(
          "group relative block aspect-[16/10] w-full overflow-hidden rounded-tile border border-hairline bg-muted text-left",
          focusRing,
        )}
      >
        <div className="size-full transition-transform duration-500 ease-out group-hover:scale-[1.04] motion-reduce:transition-none motion-reduce:group-hover:scale-100">
          <Cover item={item} />
        </div>
        <div className="pointer-events-none absolute inset-x-0 bottom-0 bg-gradient-to-t from-black/70 to-transparent px-2 pt-6 pb-1.5 opacity-0 transition-opacity group-hover:opacity-100 group-focus-visible:opacity-100">
          <div className="truncate text-meta font-medium text-white">{item.name}</div>
          <div className="truncate text-axis text-white/70">{item.subtitle.replace(/\.$/, "")}</div>
        </div>
        {status.inUse || status.installed ? (
          <span
            aria-hidden
            className={cn(
              "absolute top-1.5 left-1.5 grid size-[18px] place-items-center rounded-full",
              status.inUse ? "bg-accent text-accent-fg" : "bg-black/55 text-white backdrop-blur-sm",
            )}
          >
            <Check size={10} strokeWidth={3} />
          </span>
        ) : null}
      </button>
    </li>
  );
}
