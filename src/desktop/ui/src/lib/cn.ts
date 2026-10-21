import { type ClassValue, clsx } from "clsx";
import { extendTailwindMerge } from "tailwind-merge";

// The type roles in index.css. Unregistered, tailwind-merge reads `text-meta`
// as a colour and drops it beside `text-fg-secondary`.
const twMerge = extendTailwindMerge({
  extend: {
    theme: {
      text: [
        "page-title",
        "hero-title",
        "section-title",
        "card-title",
        "row-title",
        "row-detail",
        "meta",
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
