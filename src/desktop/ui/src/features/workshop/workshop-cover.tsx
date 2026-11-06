import { ImageOff } from "lucide-react";
import { type CSSProperties, type ReactNode, useState } from "react";

import { cn } from "~/lib/cn";

import { gradient } from "./workshop-items";
import type { WorkshopItem } from "./workshop-mock";

/**
 * An image over its palette, which shimmers while the file loads and stays,
 * labelled, when the file is not on this Mac or fails to load.
 */
export function Shot({
  src,
  colours,
  alt,
  className,
  eager,
  labelMissing = true,
}: {
  src: string | undefined;
  colours: readonly string[];
  alt: string;
  className?: string;
  eager?: boolean;
  /** Off where the label would crowd a thumbnail or sit under other controls. */
  labelMissing?: boolean;
}) {
  const [loaded, setLoaded] = useState<string | null>(null);
  const [failed, setFailed] = useState<string | null>(null);
  const missing = !src || failed === src;
  const ready = !missing && loaded === src;
  return (
    <div
      className={cn("relative overflow-hidden bg-muted", className)}
      style={{ background: gradient(colours) }}
    >
      {!missing && !ready ? (
        <div
          aria-hidden
          className="absolute inset-0 animate-pulse bg-[linear-gradient(110deg,transparent_30%,rgba(255,255,255,0.08)_50%,transparent_70%)] motion-reduce:animate-none"
        />
      ) : null}
      {missing ? null : (
        <img
          src={src}
          alt={alt}
          loading={eager ? "eager" : "lazy"}
          decoding="async"
          draggable={false}
          onLoad={() => setLoaded(src)}
          onError={() => setFailed(src)}
          className={cn(
            "absolute inset-0 size-full object-cover transition-opacity duration-300 motion-reduce:transition-none",
            ready ? "opacity-100" : "opacity-0",
          )}
        />
      )}
      {missing && labelMissing ? (
        <div className="absolute right-2 bottom-2 flex items-center gap-1 rounded-[5px] bg-black/35 px-1.5 py-0.5 text-axis text-white/80 backdrop-blur-sm">
          <ImageOff aria-hidden size={10} /> Preview only
        </div>
      ) : null}
    </div>
  );
}

function LayoutSchematic({ item, large }: { item: WorkshopItem; large?: boolean }) {
  const [background = "#18181b", foreground = "#e4e4e7", accent = "#818cf8"] = item.colours;
  const rects = item.layout ?? [];
  return (
    <div className="relative size-full p-[6%]" style={{ background: gradient(item.colours) }}>
      <div className="absolute inset-x-0 top-0 h-[7%]" style={{ background: `${background}cc` }} />
      <div className="relative size-full" style={{ marginTop: large ? 6 : 3 }}>
        {rects.map(([x, y, w, h], index) => {
          const focused = item.id === "layout:accordion" ? index === rects.length - 1 : index === 0;
          return (
            <div
              key={`${x}-${y}-${w}-${h}`}
              className="absolute"
              style={{
                left: `${x}%`,
                top: `${y}%`,
                width: `${w}%`,
                height: `${h}%`,
                padding: large ? 4 : 2,
              }}
            >
              <div
                className="flex size-full flex-col overflow-hidden rounded-[4px] shadow-[0_4px_12px_-4px_rgba(0,0,0,0.5)]"
                style={{
                  background,
                  border: `${large ? 2 : 1.5}px solid ${focused ? accent : `${foreground}33`}`,
                }}
              >
                <div className="flex gap-[3px] px-[5%] pt-[6%]">
                  {[0.7, 0.4, 0.55].map((opacity, line) => (
                    <span
                      key={opacity}
                      className="h-[3px] rounded-full"
                      style={{
                        width: `${18 + line * 9}%`,
                        background: foreground,
                        opacity: opacity * 0.5,
                      }}
                    />
                  ))}
                </div>
                <div className="mt-[6%] space-y-[3px] px-[5%]">
                  {[62, 44, 70].map((width) => (
                    <div
                      key={width}
                      className="h-[2px] rounded-full"
                      style={{ width: `${width}%`, background: foreground, opacity: 0.18 }}
                    />
                  ))}
                </div>
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
}

function BarSchematic({ item, large }: { item: WorkshopItem; large?: boolean }) {
  const [background = "#18181b", foreground = "#e4e4e7", accent = "#818cf8"] = item.colours;
  const spec = item.bar ?? { position: "top", shape: "full" };
  const height = large ? 20 : 11;
  const dot = (key: string, on?: boolean) => (
    <span
      key={key}
      className="rounded-[2px]"
      style={{
        width: height * 0.42,
        height: height * 0.42,
        background: on ? accent : foreground,
        opacity: on ? 1 : 0.4,
      }}
    />
  );
  const line = (key: string, width: number) => (
    <span
      key={key}
      className="rounded-full"
      style={{
        width: width * (large ? 2 : 1),
        height: Math.max(2, height * 0.16),
        background: foreground,
        opacity: 0.55,
      }}
    />
  );
  const spaces = (
    <div className="flex items-center gap-[3px]">
      {[0, 1, 2, 3].map((space) => dot(`space-${space}`, space === 0))}
    </div>
  );
  const status = (
    <div className="flex items-center gap-[5px]">
      {line("a", 10)}
      {line("b", 8)}
      {line("c", 16)}
    </div>
  );
  const chrome: CSSProperties = {
    background: spec.glass ? `${foreground}22` : background,
    backdropFilter: spec.glass ? "blur(6px)" : undefined,
    border: `1px solid ${foreground}1f`,
    height,
  };
  const edge = spec.position === "top" ? "top-0" : "bottom-0";
  const offset = large ? 8 : 4;

  let bar: ReactNode;
  if (spec.shape === "full" || spec.shape === "notch") {
    bar = (
      <div
        className={cn("absolute inset-x-0 flex items-center justify-between px-[4%]", edge)}
        style={{ ...chrome, borderRadius: 0 }}
      >
        {spaces}
        {spec.shape === "notch" ? (
          <span className="h-full rounded-b-[6px] bg-black" style={{ width: "18%" }} />
        ) : (
          line("clock", 14)
        )}
        {status}
      </div>
    );
  } else if (spec.shape === "pill") {
    bar = (
      <div className="absolute inset-x-0 flex justify-center" style={{ top: offset }}>
        <div className="flex items-center gap-[10px] rounded-full px-[3%]" style={chrome}>
          {spaces}
          {line("clock", 14)}
          {status}
        </div>
      </div>
    );
  } else if (spec.shape === "islands") {
    bar = (
      <div
        className="absolute flex items-center justify-between"
        style={{ top: offset, left: offset, right: offset }}
      >
        <div className="flex items-center rounded-[6px] px-[6px]" style={chrome}>
          {spaces}
        </div>
        <div className="flex items-center gap-[4px] rounded-[6px] px-[6px]" style={chrome}>
          {dot("media", true)}
          {line("title", 18)}
        </div>
        <div className="flex items-center rounded-[6px] px-[6px]" style={chrome}>
          {status}
        </div>
      </div>
    );
  } else {
    bar = (
      <div
        className="absolute flex items-center justify-between rounded-[7px] px-[3%]"
        style={{ ...chrome, top: offset, left: offset, right: offset }}
      >
        {spaces}
        {line("clock", 14)}
        {status}
      </div>
    );
  }

  const docked = spec.shape === "full" || spec.shape === "notch";
  const windowsTop = spec.position === "top" ? height + offset * (docked ? 1 : 2) : offset;
  const windowsBottom = spec.position === "bottom" ? height + offset : offset;
  return (
    <div
      className="relative size-full overflow-hidden"
      style={{ background: gradient(item.colours) }}
    >
      <div
        className="absolute flex gap-[5px]"
        style={{ top: windowsTop, bottom: windowsBottom, left: offset, right: offset }}
      >
        <div
          className="flex-[3] rounded-[4px]"
          style={{ background: `${background}e6`, border: `1.5px solid ${accent}` }}
        />
        <div
          className="flex-[2] rounded-[4px]"
          style={{ background: `${background}cc`, border: `1px solid ${foreground}26` }}
        />
      </div>
      {bar}
    </div>
  );
}

/** What an item looks like: its picture, or a drawing of the layout or bar. */
export function Cover({
  item,
  index = 0,
  large,
  eager,
  labelMissing,
}: {
  item: WorkshopItem;
  index?: number;
  large?: boolean;
  eager?: boolean;
  labelMissing?: boolean;
}) {
  if (item.kind === "layout") return <LayoutSchematic item={item} large={large} />;
  if (item.kind === "bar") return <BarSchematic item={item} large={large} />;
  return (
    <Shot
      src={item.images[index]}
      colours={item.colours}
      alt={item.name}
      className="size-full"
      eager={eager}
      labelMissing={labelMissing}
    />
  );
}
