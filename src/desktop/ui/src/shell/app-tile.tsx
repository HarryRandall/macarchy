import { BrandMark } from "./brand-mark";

/** The Macarchy logo on its app-icon tile, which stays dark in both appearances. */
export function AppTile({ size = 28 }: { size?: number }) {
  return (
    <span
      aria-hidden
      className="grid shrink-0 place-items-center rounded-[7px] text-white shadow-[0_1px_2px_rgb(0_0_0/0.25),inset_0_0_0_1px_rgb(255_255_255/0.1)]"
      style={{
        width: size,
        height: size,
        background: "linear-gradient(180deg, #3f3f46 0%, #18181b 100%)",
      }}
    >
      <BrandMark width={size * 0.62} height={size * 0.62} />
    </span>
  );
}
