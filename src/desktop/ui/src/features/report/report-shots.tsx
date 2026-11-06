import { ImagePlus, Lock, X } from "lucide-react";
import { type DragEvent, useEffect, useRef, useState } from "react";

import { focusRing } from "~/components/ui/focus-ring";
import { IconButton } from "~/components/ui/icon-button";
import { IconTile } from "~/components/ui/icon-tile";
import { cn } from "~/lib/cn";

import { formatBytes, shotsMax } from "./report-content";

const privacyNote =
  "Screenshots stay on this Mac and are not sent. Drag them into the issue once it opens.";

export interface Shot {
  id: number;
  url: string;
  name: string;
  size: number;
}

/**
 * Screenshots the person picked, held as object URLs on this Mac. The bridge
 * has no way to send them, so they are only a reminder of what to attach on
 * GitHub; every URL is released on removal and when the page goes away.
 */
export function useShots() {
  const [shots, setShots] = useState<readonly Shot[]>([]);
  const [urls] = useState(() => new Set<string>());
  const nextId = useRef(1);
  useEffect(
    () => () => {
      for (const url of urls) URL.revokeObjectURL(url);
      urls.clear();
    },
    [urls],
  );
  const release = (shot: Shot) => {
    URL.revokeObjectURL(shot.url);
    urls.delete(shot.url);
  };
  return {
    shots,
    add(files: FileList | null) {
      const images = Array.from(files ?? []).filter((file) => file.type.startsWith("image/"));
      const added = images.slice(0, shotsMax - shots.length).map((file) => {
        const url = URL.createObjectURL(file);
        urls.add(url);
        return { id: nextId.current++, url, name: file.name, size: file.size };
      });
      if (added.length) setShots([...shots, ...added]);
    },
    remove(id: number) {
      const gone = shots.find((shot) => shot.id === id);
      if (gone) release(gone);
      setShots(shots.filter((shot) => shot.id !== id));
    },
    clear() {
      shots.forEach(release);
      setShots([]);
    },
  };
}

export function ScreenshotsField({
  shots,
  onAdd,
  onRemove,
}: {
  shots: readonly Shot[];
  onAdd(files: FileList | null): void;
  onRemove(id: number): void;
}) {
  const input = useRef<HTMLInputElement>(null);
  const [dragging, setDragging] = useState(false);
  const full = shots.length >= shotsMax;
  const drop = (event: DragEvent<HTMLButtonElement>) => {
    event.preventDefault();
    setDragging(false);
    onAdd(event.dataTransfer.files);
  };
  return (
    <div className="@container flex flex-col gap-2.5">
      <button
        type="button"
        disabled={full}
        onClick={() => input.current?.click()}
        onDragOver={(event) => {
          event.preventDefault();
          setDragging(true);
        }}
        onDragLeave={() => setDragging(false)}
        onDrop={drop}
        className={cn(
          "flex w-full items-center gap-3 rounded-tile border border-dashed px-4 py-3.5 text-left transition-colors disabled:opacity-50",
          focusRing,
          dragging
            ? "border-accent bg-accent-soft"
            : "border-line-strong bg-side hover:border-fg-tertiary",
        )}
      >
        <IconTile tint={dragging ? "accent" : "neutral"} size="lg">
          <ImagePlus />
        </IconTile>
        <span className="min-w-0 flex-1">
          <span className="block text-body font-medium text-fg">
            {dragging ? "Drop to add" : "Drop screenshots here, or browse"}
          </span>
          <span className="block text-small text-fg-tertiary">
            {full ? `${shotsMax} of ${shotsMax} added` : `PNG or JPG, up to ${shotsMax} images`}
          </span>
        </span>
      </button>
      <input
        ref={input}
        type="file"
        accept="image/*"
        multiple
        hidden
        aria-label="Choose screenshots"
        onChange={(event) => {
          onAdd(event.currentTarget.files);
          event.currentTarget.value = "";
        }}
      />
      {shots.length ? (
        <ul className="grid grid-cols-2 gap-2.5 @min-[480px]:grid-cols-3">
          {shots.map((shot) => (
            <li
              key={shot.id}
              className="group relative overflow-hidden rounded-tile border border-hairline bg-card shadow-card"
            >
              <img src={shot.url} alt="" className="aspect-[16/10] w-full bg-muted object-cover" />
              <div className="flex items-center gap-1.5 px-2 py-1.5 text-meta">
                <span className="min-w-0 flex-1 truncate text-fg">{shot.name}</span>
                <span className="shrink-0 text-fg-tertiary tabular-nums">
                  {formatBytes(shot.size)}
                </span>
              </div>
              <IconButton
                label={`Remove ${shot.name}`}
                size="sm"
                onClick={() => onRemove(shot.id)}
                className="absolute top-1.5 right-1.5 border border-hairline bg-card opacity-0 shadow-card group-hover:opacity-100 focus-visible:opacity-100"
              >
                <X aria-hidden />
              </IconButton>
            </li>
          ))}
        </ul>
      ) : null}
      <p className="flex items-center gap-1.5 text-small text-fg-tertiary">
        <Lock aria-hidden className="size-3 shrink-0" />
        {privacyNote}
      </p>
    </div>
  );
}
