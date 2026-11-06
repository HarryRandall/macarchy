import { type ClassValue, clsx } from "clsx";
import { extendTailwindMerge } from "tailwind-merge";

// The type roles in index.css. Unregistered, tailwind-merge reads `text-meta`
// as a colour and drops it beside `text-fg-secondary`.
const twMerge = extendTailwindMerge({
  extend: {
    theme: {
      text: [
        "hero-title",
        "stat",
        "title",
        "card-title",
        "emphasis",
        "body",
        "detail",
        "small",
        "meta",
        "caption",
        "axis",
        "tag",
        "label",
        "mono",
        "mono-value",
        "page-title",
        "section-title",
        "row-title",
        "row-detail",
        "eyebrow",
        "badge",
        "mono-detail",
      ],
    },
  },
});

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}
