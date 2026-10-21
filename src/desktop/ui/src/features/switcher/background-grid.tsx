import { useState } from "react";

import type { Background, ThemeSummary } from "~/bridge/protocol";
import { cn } from "~/lib/cn";

import { keepSearchFocus } from "./switcher-chrome";

export const tileId = (index: number) => `switcher-tile-${index}`;

/** Two columns of 16:9 wallpapers, the one in force first and ticked. */
export function BackgroundGrid({
  id,
  theme,
  tiles,
  selected,
  onSelect,
  onUse,
}: {
  id: string;
  theme: ThemeSummary;
  tiles: Background[];
  selected: string | null;
  onSelect: (path: string) => void;
  onUse: (path: string) => void;
}) {
  if (tiles.length === 0) {
    return (
      <div className="flex flex-1 items-center justify-center text-[13px] text-fg-secondary">
        No wallpapers in {theme.title}
      </div>
    );
  }
  return (
    <div
      id={id}
      role="listbox"
      aria-label={`Backgrounds in ${theme.title}`}
      data-scroll-reset
      className="grid flex-1 auto-rows-min grid-cols-2 gap-x-3 gap-y-3.5 overflow-y-auto p-3.5"
    >
      {tiles.map((background, index) => (
        <Tile
          key={background.path}
          id={tileId(index)}
          background={background}
          current={background.path === theme.currentBackground}
          selected={background.path === selected}
          onSelect={() => onSelect(background.path)}
          onUse={() => onUse(background.path)}
        />
      ))}
    </div>
  );
}

function Tile({
  id,
  background,
  current,
  selected,
  onSelect,
  onUse,
}: {
  id: string;
  background: Background;
  current: boolean;
  selected: boolean;
  onSelect: () => void;
  onUse: () => void;
}) {
  const [failed, setFailed] = useState(false);
  return (
    // oxlint-disable-next-line jsx-a11y/click-events-have-key-events, jsx-a11y/interactive-supports-focus -- reached through the search field's aria-activedescendant; the field keeps focus and handles the keys.
    <div
      id={id}
      role="option"
      aria-selected={selected}
      aria-label={current ? `${background.name}, current` : background.name}
      onClick={onSelect}
      onDoubleClick={onUse}
      {...keepSearchFocus}
      className="flex min-w-0 flex-col gap-1.5"
    >
      <div className="relative aspect-video overflow-hidden rounded-control bg-white/5">
        {failed ? null : (
          <img
            src={background.thumbnail}
            alt=""
            draggable={false}
            loading="lazy"
            decoding="async"
            onError={() => setFailed(true)}
            className="absolute inset-0 size-full object-cover"
          />
        )}
        <div
          aria-hidden
          className={cn(
            "absolute inset-0 rounded-control border-2 transition-colors duration-140",
            selected ? "border-white/80" : "border-transparent",
          )}
        />
      </div>
      <div className="flex items-center gap-1.5">
        <span className="min-w-0 flex-1 truncate text-[12px] font-medium text-fg">
          {background.name}
        </span>
        {current ? <CurrentMark /> : null}
      </div>
    </div>
  );
}

/** SF Symbols' checkmark.circle.fill, which Lucide has no filled form of. */
function CurrentMark() {
  return (
    <svg viewBox="0 0 16 16" aria-hidden className="size-[15px] shrink-0">
      <circle cx="8" cy="8" r="7.5" fill="var(--status-success)" />
      <path
        d="M4.8 8.2 7 10.4l4.2-4.6"
        fill="none"
        stroke="#000"
        strokeOpacity="0.85"
        strokeWidth="1.7"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
    </svg>
  );
}
