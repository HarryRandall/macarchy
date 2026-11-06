import { cva, type VariantProps } from "class-variance-authority";
import { type ComponentProps, type ReactNode, useId } from "react";

import { cn } from "~/lib/cn";

const heroVariants = cva(
  "relative flex flex-col overflow-hidden rounded-panel border border-hairline bg-card shadow-card",
  {
    variants: {
      layout: {
        /** Artwork above a caption bar, as Themes shows the current theme. */
        caption: "",
        /** Words over the foot of the artwork, as Home's desktop banner. */
        overlay: "justify-end",
      },
    },
    defaultVariants: { layout: "caption" },
  },
);

type HeroCardProps = Omit<ComponentProps<"section">, "title"> &
  VariantProps<typeof heroVariants> & {
    /** Fills the artwork area: an image, a desktop preview. Decorative. */
    artwork: ReactNode;
    /** Height of the artwork in the caption layout, or the whole card in the overlay one. */
    artworkHeight?: number;
    /** A short upper-case line above the title, such as "Current theme". */
    eyebrow?: string;
    title: string;
    subtitle?: ReactNode;
    /** Chips under the title: services, counts. */
    meta?: ReactNode;
    /** Buttons at the trailing edge of the caption. */
    actions?: ReactNode;
    /** Pinned to the top-right corner of the artwork, such as an "Applied" chip. */
    badge?: ReactNode;
  };

/**
 * A full-bleed picture with its title. One component so the banner keeps its
 * shape from page to page. The overlay layout draws its text and controls in
 * the dark appearance whatever the window's, since they sit on a darkened
 * picture.
 */
function HeroCard({
  layout = "caption",
  artwork,
  artworkHeight = layout === "overlay" ? 210 : 240,
  eyebrow,
  title,
  subtitle,
  meta,
  actions,
  badge,
  className,
  ...props
}: HeroCardProps) {
  const overlay = layout === "overlay";
  const titleId = useId();
  const text = (
    <div className="flex min-w-0 flex-col gap-1">
      {eyebrow ? (
        <p className={cn("text-label uppercase", overlay ? "text-white/75" : "text-fg-tertiary")}>
          {eyebrow}
        </p>
      ) : null}
      <h2
        id={titleId}
        className={cn("truncate", overlay ? "text-hero-title text-white" : "text-title text-fg")}
      >
        {title}
      </h2>
      {subtitle ? (
        <p className={cn("text-detail", overlay ? "text-white/75" : "text-fg-secondary")}>
          {subtitle}
        </p>
      ) : null}
      {meta ? <div className="mt-1 flex flex-wrap items-center gap-2">{meta}</div> : null}
    </div>
  );

  return (
    <section
      data-slot="hero-card"
      data-layout={layout}
      aria-labelledby={titleId}
      className={cn(heroVariants({ layout }), className)}
      style={overlay ? { height: artworkHeight } : undefined}
      {...props}
    >
      <div
        aria-hidden
        className={cn("overflow-hidden", overlay ? "absolute inset-0" : "relative shrink-0")}
        style={overlay ? undefined : { height: artworkHeight }}
      >
        {artwork}
      </div>
      {overlay ? (
        <div
          aria-hidden
          className="absolute inset-0 bg-[linear-gradient(to_bottom,transparent_45%,rgb(0_0_0/0.5)_72%,rgb(0_0_0/0.88))]"
        />
      ) : null}
      <div
        data-appearance={overlay ? "dark" : undefined}
        className={cn(
          "relative flex items-end justify-between gap-4 p-5",
          overlay && "bg-transparent",
        )}
      >
        {text}
        {actions ? <div className="flex shrink-0 items-center gap-2">{actions}</div> : null}
      </div>
      {badge ? (
        <div
          data-appearance="dark"
          className="absolute top-3 right-3 flex gap-2 rounded-small bg-black/40 ring-1 ring-white/15 backdrop-blur-md"
        >
          {badge}
        </div>
      ) : null}
    </section>
  );
}

export { HeroCard };
