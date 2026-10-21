import type { BorderAppearance } from "~/bridge/contract/borders";
import { cssColour, parseColour } from "~/lib/colour";

function WindowPreview({
  appearance,
  caption,
}: {
  appearance: BorderAppearance;
  caption?: string;
}) {
  const scale = 232 / 720;
  const width = appearance.visible ? appearance.width * scale : 0;
  const radius = appearance.radius ?? 12;
  const colour = parseColour(appearance.activeColour ?? "0xff45e8ff");
  return (
    <div
      className="flex flex-col items-center gap-2.5"
      role="img"
      aria-label={
        (caption ?? "Border preview") + ", " + (radius < 1 ? "square" : "rounded") + " corners"
      }
    >
      <div
        className="h-[146px] w-[232px] bg-card/90 text-fg shadow-lg"
        style={{
          borderRadius: radius < 1 ? 0 : radius * scale,
          outline: width + "px solid " + (colour ? cssColour(colour) : "transparent"),
        }}
      >
        <div className="flex h-[22px] items-center gap-1 border-b border-hairline px-2" aria-hidden>
          <span className="size-[7px] rounded-full bg-red-400" />
          <span className="size-[7px] rounded-full bg-yellow-400" />
          <span className="size-[7px] rounded-full bg-green-400" />
        </div>
        <div className="p-2.5 font-mono text-[11px]">~ $ _</div>
      </div>
      {caption ? <span className="text-[11px] text-white/85">{caption}</span> : null}
    </div>
  );
}
export function BorderPreview({
  draft,
  before,
  wallpaper,
}: {
  draft: BorderAppearance;
  before: BorderAppearance | null;
  wallpaper: string | null;
}) {
  return (
    <div className="pointer-events-none relative flex min-h-[232px] flex-wrap items-center justify-center gap-8 overflow-hidden rounded-card bg-well p-[18px]">
      {wallpaper ? (
        <img src={wallpaper} alt="" className="absolute inset-0 size-full object-cover" />
      ) : null}
      <div className="absolute inset-0 bg-black/40" />
      <div className="relative flex flex-wrap justify-center gap-8 p-2">
        {before ? <WindowPreview appearance={before} caption="Before" /> : null}
        <WindowPreview appearance={draft} caption={before ? "After" : undefined} />
      </div>
    </div>
  );
}
