import { Check } from "lucide-react";
import { Badge } from "~/components/ui/badge";
import { Button } from "~/components/ui/button";
import { Tooltip } from "~/components/ui/tooltip";
import { PaletteDots, ThemeWallpaper } from "./theme-art";
import type { ThemeLook } from "./theme-look";

/** A large wallpaper card in the theme gallery. The whole image opens the theme. */
export function ThemeCard({
  look,
  preview,
  applied,
  busy,
  onOpen,
  onApply,
}: {
  look: ThemeLook;
  preview: string | null;
  applied: boolean;
  busy: boolean;
  onOpen: () => void;
  onApply: () => void;
}) {
  const count = look.wallpapers.length;
  return (
    <div className="group min-w-0" data-theme={look.name} data-current={applied || undefined}>
      <div
        className={
          applied
            ? "relative aspect-[16/10] overflow-hidden rounded-card shadow-[0_0_0_2px_var(--color-page),0_0_0_4px_var(--color-accent)] transition-[transform,box-shadow] duration-200 ease-out group-hover:-translate-y-0.5 motion-reduce:transition-none motion-reduce:group-hover:translate-y-0"
            : "relative aspect-[16/10] overflow-hidden rounded-card shadow-card ring-1 ring-hairline transition-[transform,box-shadow] duration-200 ease-out group-hover:-translate-y-0.5 group-hover:shadow-[0_18px_36px_-18px_rgba(0,0,0,0.5)] motion-reduce:transition-none motion-reduce:group-hover:translate-y-0"
        }
      >
        <ThemeWallpaper
          look={look}
          preview={preview}
          className="transition-transform duration-500 ease-out group-hover:scale-[1.04] motion-reduce:transition-none motion-reduce:group-hover:scale-100"
        />
        <div className="pointer-events-none absolute inset-0 bg-gradient-to-t from-black/55 via-black/0 to-black/0 opacity-0 transition-opacity duration-200 group-focus-within:opacity-100 group-hover:opacity-100" />
        <button
          type="button"
          onClick={onOpen}
          aria-label={`View ${look.title}`}
          className="absolute inset-0 rounded-card outline-none focus-visible:ring-2 focus-visible:ring-accent focus-visible:ring-inset"
        />
        {applied ? (
          <span className="pointer-events-none absolute top-2.5 left-2.5 inline-flex h-[22px] items-center gap-1 rounded-small bg-black/55 px-2 text-caption font-medium text-white ring-1 ring-white/15 backdrop-blur-md">
            <Check aria-hidden className="size-[11px]" /> Current
          </span>
        ) : null}
        <div className="pointer-events-none absolute inset-x-2.5 bottom-2.5 flex translate-y-1 items-center justify-between gap-2 opacity-0 transition-[opacity,transform] duration-200 group-focus-within:translate-y-0 group-focus-within:opacity-100 group-hover:translate-y-0 group-hover:opacity-100 motion-reduce:translate-y-0">
          <span className="truncate text-meta font-medium text-white/85">View details</span>
          {applied ? null : (
            <Button
              size="sm"
              disabled={busy}
              aria-label={`Apply ${look.title}`}
              onClick={onApply}
              className="pointer-events-auto bg-white text-zinc-900 shadow-[0_1px_2px_rgba(0,0,0,0.3)] hover:bg-white hover:opacity-90"
            >
              Apply
            </Button>
          )}
        </div>
      </div>
      <div className="mt-3 flex items-center justify-between gap-3 px-0.5">
        <span className="flex min-w-0 items-center gap-2">
          <Tooltip content={look.title} describe={false}>
            <span className="min-w-0 truncate text-emphasis font-medium text-fg">{look.title}</span>
          </Tooltip>
          {look.modified ? <Badge>Edited</Badge> : null}
        </span>
        <PaletteDots look={look} />
      </div>
      <div className="mt-0.5 truncate px-0.5 text-small text-fg-tertiary">
        Neovim {look.nvim}, {count === 0 ? "no" : count} wallpaper{count === 1 ? "" : "s"}
      </div>
    </div>
  );
}
