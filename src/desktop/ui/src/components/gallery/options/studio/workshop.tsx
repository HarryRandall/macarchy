import {
  Check,
  ChevronLeft,
  ChevronRight,
  Download,
  ImageOff,
  Images,
  LayoutGrid,
  PanelTop,
  Palette,
  Search,
  Sparkles,
  X,
} from "lucide-react";
import { type ReactNode, useEffect, useMemo, useRef, useState } from "react";

import { communityThemes, currentThemeId, realThemes, wallpaperUrl } from "../real";
import {
  Badge,
  Button,
  Card,
  EmptyState,
  PageHeader,
  SectionLabel,
  Tabs,
  cx,
  focusRing,
  usePageSearch,
} from "./ui";

/* ------------------------------------------------------------------ */
/* Data                                                                */
/* ------------------------------------------------------------------ */

type Kind = "theme" | "wallpaper" | "layout" | "bar";
type Tab = "all" | Kind;

type Rect = readonly [x: number, y: number, w: number, h: number];

interface BarSpec {
  position: "top" | "bottom";
  shape: "full" | "floating" | "pill" | "islands" | "notch";
  glass?: boolean;
}

interface Item {
  id: string;
  kind: Kind;
  name: string;
  author: string;
  subtitle: string;
  downloads: number;
  /** Image URLs; an undefined entry means the file is not on this machine. */
  images: (string | undefined)[];
  /** Background, foreground, accent, then two highlights. */
  colours: string[];
  dark: boolean;
  tags: string[];
  seededInstalled?: boolean;
  /** The theme a wallpaper belongs to, so the dialog can page through its siblings. */
  group?: string;
  layout?: Rect[];
  bar?: BarSpec;
}

const KIND_LABEL: Record<Kind, string> = {
  theme: "Theme",
  wallpaper: "Wallpaper",
  layout: "Layout",
  bar: "Bar",
};

function hash(s: string) {
  let h = 2166136261;
  for (let i = 0; i < s.length; i++) h = Math.imul(h ^ s.charCodeAt(i), 16777619);
  return Math.abs(h);
}

function seededDownloads(id: string, base: number, spread: number) {
  return base + (hash(id) % spread);
}

function formatCount(n: number) {
  if (n >= 1000) return `${(n / 1000).toFixed(n >= 10000 ? 0 : 1)}k`;
  return String(n);
}

const NAME_OVERRIDES: Record<string, string> = {
  "rose-pine": "Rosé Pine",
  "retro-82": "Retro 82",
  "catppuccin-latte": "Catppuccin Latte",
  "flexoki-light": "Flexoki Light",
};

function titleCase(s: string) {
  return s
    .split(/[-_\s]+/)
    .filter(Boolean)
    .map((w) => w.charAt(0).toUpperCase() + w.slice(1))
    .join(" ");
}

function prettyTheme(id: string) {
  return NAME_OVERRIDES[id] ?? titleCase(id);
}

/** "1-the-backwater.jpg" becomes "The backwater"; bare numbers keep the theme name. */
function prettyWallpaper(file: string, themeName: string) {
  const base = file.replace(/\.[a-z0-9]+$/i, "").replace(/^\d+-/, "");
  const numeric = /^(bg)?(\d+)$/i.exec(base);
  if (numeric) return `${themeName} No. ${Number(numeric[2])}`;
  if (base === "wall") return `${themeName} classic`;
  const words = titleCase(base);
  return words.charAt(0) + words.slice(1).toLowerCase();
}

/** Plausible palettes for the community themes: background, foreground, accent, two highlights. */
const COMMUNITY_META: Record<
  string,
  { colours: string[]; dark: boolean; blurb: string; tags: string[] }
> = {
  catppuccin: {
    colours: ["#1e1e2e", "#cdd6f4", "#cba6f7", "#f38ba8", "#a6e3a1"],
    dark: true,
    blurb: "Soothing pastels on a deep mocha base.",
    tags: ["pastel", "cosy"],
  },
  "catppuccin-latte": {
    colours: ["#eff1f5", "#4c4f69", "#8839ef", "#d20f39", "#40a02b"],
    dark: false,
    blurb: "The light flavour of Catppuccin, warm and milky.",
    tags: ["light", "pastel"],
  },
  ethereal: {
    colours: ["#060b1e", "#ffcead", "#7d82d9", "#c89dc1", "#92a593"],
    dark: true,
    blurb: "Cosmic violets with a soft peach foreground.",
    tags: ["space", "dreamy"],
  },
  everforest: {
    colours: ["#2d353b", "#d3c6aa", "#a7c080", "#e69875", "#7fbbb3"],
    dark: true,
    blurb: "Green, comfortable and easy on the eyes all day.",
    tags: ["nature", "calm"],
  },
  "flexoki-light": {
    colours: ["#fffcf0", "#100f0f", "#205ea6", "#af3029", "#66800b"],
    dark: false,
    blurb: "Inky colours on paper, designed for reading.",
    tags: ["light", "paper"],
  },
  gruvbox: {
    colours: ["#282828", "#ebdbb2", "#d79921", "#cc241d", "#98971a"],
    dark: true,
    blurb: "Retro groove with warm, earthy contrast.",
    tags: ["retro", "warm"],
  },
  hackerman: {
    colours: ["#0b0c16", "#ddf7ff", "#82fb9c", "#50f872", "#7cf8f7"],
    dark: true,
    blurb: "Phosphor greens for people who type fast.",
    tags: ["neon", "terminal"],
  },
  kanagawa: {
    colours: ["#1f1f28", "#dcd7ba", "#7e9cd8", "#c34043", "#98bb6c"],
    dark: true,
    blurb: "Inspired by the colours of a famous woodblock wave.",
    tags: ["japanese", "ink"],
  },
  "last-horizon": {
    colours: ["#0f0f14", "#e6e1dc", "#d4a373", "#8a6f9e", "#5f7a8a"],
    dark: true,
    blurb: "Muted dusk tones and soft bokeh.",
    tags: ["moody", "film"],
  },
  lupine: {
    colours: ["#1b1726", "#e8dff5", "#b39ddb", "#f48fb1", "#9fa8da"],
    dark: true,
    blurb: "Cherry blossom pinks against a violet night.",
    tags: ["floral", "pastel"],
  },
  miasma: {
    colours: ["#222222", "#c2c2b0", "#bb7744", "#685742", "#5f875f"],
    dark: true,
    blurb: "Foggy forest browns with a rusty accent.",
    tags: ["earthy", "dark"],
  },
  nord: {
    colours: ["#2e3440", "#d8dee9", "#88c0d0", "#bf616a", "#a3be8c"],
    dark: true,
    blurb: "An arctic, north-bluish palette.",
    tags: ["cool", "classic"],
  },
  "osaka-jade": {
    colours: ["#111c18", "#c1c497", "#2dd5b7", "#ff5345", "#549e6a"],
    dark: true,
    blurb: "Jade greens and neon signs after rain.",
    tags: ["city", "neon"],
  },
  "retro-82": {
    colours: ["#0d0221", "#f7f1ff", "#ff2a6d", "#05d9e8", "#d1f7ff"],
    dark: true,
    blurb: "Synthwave magenta and cyan, straight from 1982.",
    tags: ["synthwave", "neon"],
  },
  ristretto: {
    colours: ["#2c2525", "#e6d9db", "#f38d70", "#fd6883", "#adda78"],
    dark: true,
    blurb: "Rich espresso browns with a fruity finish.",
    tags: ["warm", "coffee"],
  },
  "rose-pine": {
    colours: ["#faf4ed", "#575279", "#d7827e", "#b4637a", "#286983"],
    dark: false,
    blurb: "All natural pine, faux fur and a bit of soho vibes.",
    tags: ["light", "soft"],
  },
  solitude: {
    colours: ["#14161b", "#d0d4da", "#8fa1b3", "#c0a36e", "#6b7a8f"],
    dark: true,
    blurb: "Quiet greys and lonely landscapes.",
    tags: ["minimal", "moody"],
  },
  starship: {
    colours: ["#0a0e14", "#e6e6e6", "#ff7a18", "#4fa3ff", "#9aa5b1"],
    dark: true,
    blurb: "Launch pads at dawn, steel and rocket flame.",
    tags: ["space", "industrial"],
  },
  "tokyo-night": {
    colours: ["#1a1b26", "#a9b1d6", "#7aa2f7", "#f7768e", "#9ece6a"],
    dark: true,
    blurb: "Celebrates the lights of downtown Tokyo at night.",
    tags: ["city", "classic"],
  },
  vantablack: {
    colours: ["#000000", "#f0f0f0", "#8a8a8a", "#ffffff", "#3a3a3a"],
    dark: true,
    blurb: "As close to pure black as a screen allows.",
    tags: ["mono", "minimal"],
  },
  white: {
    colours: ["#ffffff", "#1a1a1a", "#6e6e6e", "#000000", "#d0d0d0"],
    dark: false,
    blurb: "Pure white, sharp black type, nothing else.",
    tags: ["light", "mono"],
  },
};

const FALLBACK_META = {
  colours: ["#18181b", "#e4e4e7", "#818cf8", "#f472b6", "#4ade80"],
  dark: true,
  blurb: "A community theme for Omarchy.",
  tags: [] as string[],
};

const installedThemes: Item[] = realThemes.map((t) => ({
  id: `theme:${t.id}`,
  kind: "theme",
  name: t.name,
  author: "On this Mac",
  subtitle: `${t.wallpapers.length} wallpapers, pairs with ${t.nvim} in Neovim.`,
  downloads: seededDownloads(t.id, 900, 14000),
  images: [t.wallpaper, ...t.wallpapers.filter((w) => w !== t.wallpaper)].map((w) =>
    wallpaperUrl(t.id, w),
  ),
  colours: [
    t.background,
    t.foreground,
    t.accent,
    t.palette[1] ?? t.accent,
    t.palette[4] ?? t.accent,
  ],
  dark: t.dark,
  tags: ["installed", t.dark ? "dark" : "light"],
  seededInstalled: true,
}));

const community: Item[] = communityThemes.map((t) => {
  const meta = COMMUNITY_META[t.id] ?? FALLBACK_META;
  return {
    id: `theme:${t.id}`,
    kind: "theme",
    name: prettyTheme(t.id),
    author: "Omarchy community",
    subtitle: meta.blurb,
    downloads: seededDownloads(t.id, 2400, 38000),
    images: t.backgrounds,
    colours: meta.colours,
    dark: meta.dark,
    tags: [...meta.tags, meta.dark ? "dark" : "light"],
  };
});

const themeItems: Item[] = [...community, ...installedThemes].filter(
  (item, i, all) => all.findIndex((o) => o.id === item.id) === i,
);

const wallpaperItems: Item[] = [
  ...realThemes.flatMap((t) =>
    t.wallpapers.map<Item>((w) => ({
      id: `wallpaper:${t.id}/${w}`,
      kind: "wallpaper",
      name: prettyWallpaper(w, t.name),
      author: "On this Mac",
      subtitle: `From ${t.name}.`,
      downloads: seededDownloads(`${t.id}${w}`, 300, 6000),
      images: [wallpaperUrl(t.id, w)],
      colours: [
        t.background,
        t.foreground,
        t.accent,
        t.palette[1] ?? t.accent,
        t.palette[4] ?? t.accent,
      ],
      dark: t.dark,
      tags: [t.name.toLowerCase(), "installed"],
      seededInstalled: true,
      group: `theme:${t.id}`,
    })),
  ),
  ...communityThemes.flatMap((t) => {
    const meta = COMMUNITY_META[t.id] ?? FALLBACK_META;
    const themeName = prettyTheme(t.id);
    return t.backgrounds.map<Item>((url) => {
      const file = url.split("/").pop() ?? url;
      return {
        id: `wallpaper:${t.id}/${file}`,
        kind: "wallpaper",
        name: prettyWallpaper(file, themeName),
        author: "Omarchy community",
        subtitle: `From ${themeName}.`,
        downloads: seededDownloads(url, 400, 9000),
        images: [url],
        colours: meta.colours,
        dark: meta.dark,
        tags: [themeName.toLowerCase(), ...meta.tags],
        group: `theme:${t.id}`,
      };
    });
  }),
];

const ZINC = ["#18181b", "#e4e4e7", "#818cf8", "#f472b6", "#34d399"];

const layoutItems: Item[] = (
  [
    {
      id: "golden",
      name: "Golden split",
      author: "@tilde",
      subtitle: "One large tile and a stacked pair, the BSP classic.",
      layout: [
        [0, 0, 62, 100],
        [62, 0, 38, 58],
        [62, 58, 38, 42],
      ],
      tags: ["bsp", "coding"],
    },
    {
      id: "centred",
      name: "Centred master",
      author: "@nadia.codes",
      subtitle: "Main window in the middle, helpers on either side.",
      layout: [
        [0, 0, 22, 100],
        [22, 0, 56, 100],
        [78, 0, 22, 50],
        [78, 50, 22, 50],
      ],
      tags: ["ultrawide", "focus"],
    },
    {
      id: "columns",
      name: "Three columns",
      author: "@kestrel",
      subtitle: "Equal columns for browser, editor and terminal.",
      layout: [
        [0, 0, 33.33, 100],
        [33.33, 0, 33.34, 100],
        [66.67, 0, 33.33, 100],
      ],
      tags: ["ultrawide", "tiles"],
    },
    {
      id: "accordion",
      name: "Accordion deck",
      author: "@ollie_w",
      subtitle: "Windows fan out like cards, the focused one in front.",
      layout: [
        [0, 0, 80, 100],
        [10, 0, 80, 100],
        [20, 0, 80, 100],
      ],
      tags: ["stack", "laptop"],
    },
    {
      id: "monocle",
      name: "Monocle and float",
      author: "Macarchy",
      subtitle: "Full screen focus with a floating scratchpad.",
      layout: [
        [0, 0, 100, 100],
        [58, 52, 36, 40],
      ],
      tags: ["focus", "laptop"],
    },
    {
      id: "quad",
      name: "Quad grid",
      author: "@grid.guy",
      subtitle: "Four equal quarters for dashboards and logs.",
      layout: [
        [0, 0, 50, 50],
        [50, 0, 50, 50],
        [0, 50, 50, 50],
        [50, 50, 50, 50],
      ],
      tags: ["monitoring", "tiles"],
    },
    {
      id: "writer",
      name: "Writer's column",
      author: "@marginalia",
      subtitle: "A single narrow column with generous margins.",
      layout: [[24, 0, 52, 100]],
      tags: ["writing", "focus"],
    },
    {
      id: "triad",
      name: "Dev triad",
      author: "@hjr",
      subtitle: "Editor on the left, preview above two terminals.",
      layout: [
        [0, 0, 55, 100],
        [55, 0, 45, 55],
        [55, 55, 22.5, 45],
        [77.5, 55, 22.5, 45],
      ],
      tags: ["coding", "bsp"],
    },
  ] satisfies {
    id: string;
    name: string;
    author: string;
    subtitle: string;
    layout: Rect[];
    tags: string[];
  }[]
).map((l, i) => ({
  ...l,
  id: `layout:${l.id}`,
  kind: "layout" as const,
  downloads: seededDownloads(l.id, 600, 12000),
  images: [],
  colours: themeItems[i % themeItems.length]?.colours ?? ZINC,
  dark: true,
}));

const barItems: Item[] = (
  [
    {
      id: "hairline",
      name: "Hairline",
      author: "Macarchy",
      subtitle: "A thin full-width bar with workspaces and a clock.",
      bar: { position: "top", shape: "full" },
      tags: ["minimal", "top"],
    },
    {
      id: "pill",
      name: "Floating pill",
      author: "@pebble",
      subtitle: "One rounded capsule centred under the notch.",
      bar: { position: "top", shape: "pill" },
      tags: ["floating", "notch"],
    },
    {
      id: "islands",
      name: "Islands",
      author: "@archipelago",
      subtitle: "Three detached groups for spaces, media and status.",
      bar: { position: "top", shape: "islands" },
      tags: ["floating", "busy"],
    },
    {
      id: "dock",
      name: "Bottom deck",
      author: "@lowrider",
      subtitle: "Status along the bottom edge, like a taskbar.",
      bar: { position: "bottom", shape: "full" },
      tags: ["bottom", "classic"],
    },
    {
      id: "notch",
      name: "Notch split",
      author: "@mbp14",
      subtitle: "Items hug either side of the camera housing.",
      bar: { position: "top", shape: "notch" },
      tags: ["notch", "laptop"],
    },
    {
      id: "glass",
      name: "Frosted glass",
      author: "@vitreous",
      subtitle: "A floating, blurred bar that lets the wallpaper through.",
      bar: { position: "top", shape: "floating", glass: true },
      tags: ["floating", "blur"],
    },
  ] satisfies {
    id: string;
    name: string;
    author: string;
    subtitle: string;
    bar: BarSpec;
    tags: string[];
  }[]
).map((b, i) => ({
  ...b,
  id: `bar:${b.id}`,
  kind: "bar" as const,
  downloads: seededDownloads(b.id, 500, 9000),
  images: [],
  colours: themeItems[(i * 3 + 2) % themeItems.length]?.colours ?? ZINC,
  dark: true,
}));

const ALL: Item[] = [...themeItems, ...wallpaperItems, ...layoutItems, ...barItems];
const featured: Item = themeItems.find((t) => t.id === "theme:tokyo-night") ?? themeItems[0]!;
const FEATURED_INDEX = 1;

const TABS: { id: Tab; label: string; icon: ReactNode }[] = [
  { id: "all", label: "All", icon: <Sparkles size={13} /> },
  { id: "theme", label: "Themes", icon: <Palette size={13} /> },
  { id: "wallpaper", label: "Wallpapers", icon: <Images size={13} /> },
  { id: "layout", label: "Layouts", icon: <LayoutGrid size={13} /> },
  { id: "bar", label: "Bars", icon: <PanelTop size={13} /> },
];

function gradient(colours: string[]) {
  const [bg = "#18181b", , accent = "#818cf8", a = accent, b = accent] = colours;
  return `radial-gradient(120% 90% at 85% 10%, ${a}55, transparent 55%), radial-gradient(90% 80% at 10% 100%, ${b}44, transparent 60%), linear-gradient(135deg, ${bg}, ${accent}33)`;
}

/* ------------------------------------------------------------------ */
/* Local persistence                                                   */
/* ------------------------------------------------------------------ */

const STORE_KEY = "macarchy.studio.workshop";

interface Stored {
  installed: string[];
  applied: Partial<Record<Kind, string>>;
}

function load(): Stored {
  try {
    const raw = localStorage.getItem(STORE_KEY);
    if (raw) {
      const parsed = JSON.parse(raw) as Partial<Stored>;
      return { installed: parsed.installed ?? [], applied: parsed.applied ?? {} };
    }
  } catch {
    /* storage unavailable: fall back to defaults */
  }
  return { installed: [], applied: { theme: `theme:${currentThemeId}` } };
}

function save(state: Stored) {
  try {
    localStorage.setItem(STORE_KEY, JSON.stringify(state));
  } catch {
    /* ignore */
  }
}

/* ------------------------------------------------------------------ */
/* Pieces                                                              */
/* ------------------------------------------------------------------ */

/** An image with a palette placeholder while it loads and a calm fallback if it fails. */
function Shot({
  src,
  colours,
  alt,
  className,
  eager,
}: {
  src: string | undefined;
  colours: string[];
  alt: string;
  className?: string;
  eager?: boolean;
}) {
  const [state, setState] = useState<"loading" | "ready" | "error">(src ? "loading" : "error");
  return (
    <div
      className={cx("relative overflow-hidden bg-[var(--st-muted)]", className)}
      style={{ background: gradient(colours) }}
    >
      {state === "loading" ? (
        <div className="absolute inset-0 animate-pulse bg-[linear-gradient(110deg,transparent_30%,rgba(255,255,255,0.08)_50%,transparent_70%)]" />
      ) : null}
      {src && state !== "error" ? (
        <img
          src={src}
          alt={alt}
          loading={eager ? "eager" : "lazy"}
          decoding="async"
          draggable={false}
          onLoad={() => setState("ready")}
          onError={() => setState("error")}
          className={cx(
            "absolute inset-0 size-full object-cover transition-opacity duration-300",
            state === "ready" ? "opacity-100" : "opacity-0",
          )}
        />
      ) : null}
      {state === "error" ? (
        <div className="absolute right-2 bottom-2 flex items-center gap-1 rounded-[5px] bg-black/35 px-1.5 py-0.5 text-[10.5px] text-white/80 backdrop-blur-sm">
          <ImageOff size={10} /> Preview only
        </div>
      ) : null}
    </div>
  );
}

function Swatches({ colours, size = 12 }: { colours: string[]; size?: number }) {
  return (
    <div className="flex items-center -space-x-1">
      {colours.map((c, i) => (
        <span
          key={`${c}${i}`}
          className="rounded-full ring-2 ring-[var(--st-bg)]"
          style={{ background: c, width: size, height: size }}
        />
      ))}
    </div>
  );
}

function LayoutSchematic({ item, large }: { item: Item; large?: boolean }) {
  const [bg = "#18181b", fg = "#e4e4e7", accent = "#818cf8"] = item.colours;
  const rects = item.layout ?? [];
  return (
    <div className="relative size-full p-[6%]" style={{ background: gradient(item.colours) }}>
      <div className="absolute inset-x-0 top-0 h-[7%]" style={{ background: `${bg}cc` }} />
      <div className="relative size-full" style={{ marginTop: large ? 6 : 3 }}>
        {rects.map(([x, y, w, h], i) => {
          const focused = item.id === "layout:accordion" ? i === rects.length - 1 : i === 0;
          return (
            <div
              key={i}
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
                  background: bg,
                  border: `${large ? 2 : 1.5}px solid ${focused ? accent : `${fg}33`}`,
                }}
              >
                <div className="flex gap-[3px] px-[5%] pt-[6%]">
                  {[0.7, 0.4, 0.55].map((o, j) => (
                    <span
                      key={j}
                      className="h-[3px] rounded-full"
                      style={{ width: `${18 + j * 9}%`, background: fg, opacity: o * 0.5 }}
                    />
                  ))}
                </div>
                <div className="mt-[6%] space-y-[3px] px-[5%]">
                  {[62, 44, 70].map((wd, j) => (
                    <div
                      key={j}
                      className="h-[2px] rounded-full"
                      style={{ width: `${wd}%`, background: fg, opacity: 0.18 }}
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

function BarSchematic({ item, large }: { item: Item; large?: boolean }) {
  const [bg = "#18181b", fg = "#e4e4e7", accent = "#818cf8"] = item.colours;
  const spec = item.bar ?? { position: "top", shape: "full" };
  const h = large ? 20 : 11;
  const dot = (key: string, on?: boolean) => (
    <span
      key={key}
      className="rounded-[2px]"
      style={{
        width: h * 0.42,
        height: h * 0.42,
        background: on ? accent : fg,
        opacity: on ? 1 : 0.4,
      }}
    />
  );
  const line = (key: string, w: number) => (
    <span
      key={key}
      className="rounded-full"
      style={{
        width: w * (large ? 2 : 1),
        height: Math.max(2, h * 0.16),
        background: fg,
        opacity: 0.55,
      }}
    />
  );
  const spaces = (
    <div className="flex items-center gap-[3px]">
      {[0, 1, 2, 3].map((i) => dot(`s${i}`, i === 0))}
    </div>
  );
  const status = (
    <div className="flex items-center gap-[5px]">
      {line("a", 10)}
      {line("b", 8)}
      {line("c", 16)}
    </div>
  );
  const surface = spec.glass ? `${fg}22` : bg;
  const chrome = {
    background: surface,
    backdropFilter: spec.glass ? "blur(6px)" : undefined,
    border: `1px solid ${fg}1f`,
    height: h,
  };
  const edge = spec.position === "top" ? "top-0" : "bottom-0";
  const offset = large ? 8 : 4;

  let bar: ReactNode;
  if (spec.shape === "full" || spec.shape === "notch") {
    bar = (
      <div
        className={cx("absolute inset-x-0 flex items-center justify-between px-[4%]", edge)}
        style={{ ...chrome, borderRadius: 0 }}
      >
        {spaces}
        {spec.shape === "notch" ? (
          <span className="h-full rounded-b-[6px]" style={{ width: "18%", background: "#000" }} />
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
          {dot("m", true)}
          {line("t", 18)}
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

  const winTop =
    spec.position === "top"
      ? spec.shape === "full" || spec.shape === "notch"
        ? h + offset
        : h + offset * 2
      : offset;
  const winBottom = spec.position === "bottom" ? h + offset : offset;
  return (
    <div
      className="relative size-full overflow-hidden"
      style={{ background: gradient(item.colours) }}
    >
      <div
        className="absolute flex gap-[5px]"
        style={{ top: winTop, bottom: winBottom, left: offset, right: offset }}
      >
        <div
          className="flex-[3] rounded-[4px]"
          style={{ background: `${bg}e6`, border: `1.5px solid ${accent}` }}
        />
        <div
          className="flex-[2] rounded-[4px]"
          style={{ background: `${bg}cc`, border: `1px solid ${fg}26` }}
        />
      </div>
      {bar}
    </div>
  );
}

function Cover({
  item,
  index = 0,
  large,
  eager,
}: {
  item: Item;
  index?: number;
  large?: boolean;
  eager?: boolean;
}) {
  if (item.kind === "layout") return <LayoutSchematic item={item} large={large} />;
  if (item.kind === "bar") return <BarSchematic item={item} large={large} />;
  const src = item.images[index];
  return (
    <Shot
      key={src ?? `${item.id}-${index}`}
      src={src}
      colours={item.colours}
      alt={item.name}
      className="size-full"
      eager={eager}
    />
  );
}

function ItemCard({
  item,
  installed,
  inUse,
  trying,
  onOpen,
  onTry,
}: {
  item: Item;
  installed: boolean;
  inUse: boolean;
  trying: boolean;
  onOpen: () => void;
  onTry: () => void;
}) {
  const imageCount = item.images.length;
  return (
    <Card className="group overflow-hidden p-1.5 transition-[border-color,box-shadow] hover:border-[var(--st-border-strong)]">
      <button
        type="button"
        onClick={onOpen}
        aria-label={`Open ${item.name}`}
        className={cx(
          "relative block aspect-[16/10] w-full overflow-hidden rounded-[7px] border border-[var(--st-border)]",
          focusRing,
        )}
      >
        <div className="size-full transition-transform duration-500 ease-out group-hover:scale-[1.03]">
          <Cover item={item} />
        </div>
        <div className="absolute top-1.5 left-1.5 flex gap-1">
          {inUse ? (
            <span className="inline-flex items-center gap-1 rounded-[5px] bg-[var(--st-accent)] px-1.5 py-0.5 text-[10.5px] font-semibold text-[var(--st-accent-fg)]">
              <Check size={10} strokeWidth={3} /> In use
            </span>
          ) : installed ? (
            <span className="inline-flex items-center gap-1 rounded-[5px] bg-black/55 px-1.5 py-0.5 text-[10.5px] font-medium text-white backdrop-blur-sm">
              <Check size={10} strokeWidth={3} /> Installed
            </span>
          ) : null}
        </div>
        {imageCount > 1 ? (
          <span className="absolute top-1.5 right-1.5 inline-flex items-center gap-1 rounded-[5px] bg-black/45 px-1.5 py-0.5 text-[10.5px] text-white opacity-0 backdrop-blur-sm transition-opacity group-hover:opacity-100">
            <Images size={10} /> {imageCount}
          </span>
        ) : null}
      </button>
      <div className="px-1 pt-2 pb-0.5">
        <div className="flex items-center gap-2">
          <div className="min-w-0 flex-1 truncate text-[13px] font-semibold tracking-[-0.01em] text-[var(--st-fg)]">
            {item.name}
          </div>
          <span className="flex shrink-0 items-center gap-1 text-[11px] tabular-nums text-[var(--st-fg3)]">
            <Download size={10.5} /> {formatCount(item.downloads)}
          </span>
        </div>
        <div className="mt-0.5 flex items-center gap-2">
          <div className="min-w-0 flex-1 truncate text-[11.5px] text-[var(--st-fg2)]">
            {item.author}
          </div>
          <Swatches colours={item.colours} size={10} />
        </div>
        <Button
          size="sm"
          className="mt-2 w-full"
          variant={trying ? "accent" : "outline"}
          onClick={onTry}
          disabled={inUse}
        >
          {inUse ? "In use" : trying ? "Trying now" : "Try it on"}
        </Button>
      </div>
    </Card>
  );
}

function WallpaperTile({
  item,
  installed,
  inUse,
  onOpen,
}: {
  item: Item;
  installed: boolean;
  inUse: boolean;
  onOpen: () => void;
}) {
  return (
    <button
      type="button"
      onClick={onOpen}
      className={cx(
        "group relative block aspect-[16/10] w-full overflow-hidden rounded-[8px] border border-[var(--st-border)] bg-[var(--st-muted)] text-left",
        focusRing,
      )}
      aria-label={`Open ${item.name}`}
    >
      <div className="size-full transition-transform duration-500 ease-out group-hover:scale-[1.04]">
        <Cover item={item} />
      </div>
      <div className="pointer-events-none absolute inset-x-0 bottom-0 bg-gradient-to-t from-black/70 to-transparent px-2 pt-6 pb-1.5 opacity-0 transition-opacity group-hover:opacity-100 group-focus-visible:opacity-100">
        <div className="truncate text-[11.5px] font-medium text-white">{item.name}</div>
        <div className="truncate text-[10.5px] text-white/70">
          {item.subtitle.replace(/\.$/, "")}
        </div>
      </div>
      {inUse || installed ? (
        <span
          className={cx(
            "absolute top-1.5 left-1.5 grid size-[18px] place-items-center rounded-full",
            inUse
              ? "bg-[var(--st-accent)] text-[var(--st-accent-fg)]"
              : "bg-black/55 text-white backdrop-blur-sm",
          )}
          title={inUse ? "In use" : "Installed"}
        >
          <Check size={10} strokeWidth={3} />
        </span>
      ) : null}
    </button>
  );
}

/* ------------------------------------------------------------------ */
/* Detail dialog                                                       */
/* ------------------------------------------------------------------ */

function DetailDialog({
  base,
  siblings,
  startIndex,
  isInstalled,
  isInUse,
  onClose,
  onInstall,
  onTry,
}: {
  base: Item;
  /** For wallpapers: every background from the same theme, paged as one carousel. */
  siblings?: Item[];
  startIndex: number;
  isInstalled: (item: Item) => boolean;
  isInUse: (item: Item) => boolean;
  onClose: () => void;
  onInstall: (item: Item) => void;
  onTry: (item: Item) => void;
}) {
  const ref = useRef<HTMLDialogElement>(null);
  const [index, setIndex] = useState(startIndex);
  const paged = siblings && siblings.length > 1 ? siblings : undefined;
  const item = paged ? (paged[index] ?? base) : base;
  const images = paged ? paged.map((s) => s.images[0]) : item.images;
  const slides = paged
    ? paged.length
    : item.kind === "layout" || item.kind === "bar"
      ? 1
      : Math.max(1, images.length);
  const installed = isInstalled(item);
  const inUse = isInUse(item);

  useEffect(() => {
    const d = ref.current;
    if (d && !d.open) d.showModal();
  }, []);

  const step = (delta: number) => setIndex((i) => (i + delta + slides) % slides);
  const installLabel = item.kind === "wallpaper" ? "Add to library" : "Install";

  return (
    <dialog
      ref={ref}
      onClose={onClose}
      onClick={(e) => {
        if (e.target === e.currentTarget) onClose();
      }}
      onKeyDown={(e) => {
        if (slides < 2) return;
        if (e.key === "ArrowRight") step(1);
        if (e.key === "ArrowLeft") step(-1);
      }}
      aria-label={item.name}
      className="m-auto w-[min(820px,calc(100vw-48px))] overflow-hidden rounded-[14px] border border-[var(--st-border)] bg-[var(--st-bg)] p-0 text-[var(--st-fg)] shadow-[0_40px_100px_-20px_rgba(0,0,0,0.6)] backdrop:bg-black/50 backdrop:backdrop-blur-[2px]"
    >
      <div className="relative aspect-[16/9] w-full bg-[var(--st-muted)]">
        <Cover item={item} index={paged ? 0 : index} large eager />
        {slides > 1 ? (
          <>
            <button
              type="button"
              aria-label="Previous background"
              onClick={() => step(-1)}
              className={cx(
                "absolute top-1/2 left-3 grid size-8 -translate-y-1/2 place-items-center rounded-full bg-black/45 text-white backdrop-blur-sm transition-colors hover:bg-black/65",
                focusRing,
              )}
            >
              <ChevronLeft size={16} />
            </button>
            <button
              type="button"
              aria-label="Next background"
              onClick={() => step(1)}
              className={cx(
                "absolute top-1/2 right-3 grid size-8 -translate-y-1/2 place-items-center rounded-full bg-black/45 text-white backdrop-blur-sm transition-colors hover:bg-black/65",
                focusRing,
              )}
            >
              <ChevronRight size={16} />
            </button>
            <span className="absolute bottom-3 left-3 rounded-[6px] bg-black/50 px-2 py-0.5 text-[11px] tabular-nums text-white backdrop-blur-sm">
              {index + 1} of {slides}
            </span>
          </>
        ) : null}
        <button
          type="button"
          aria-label="Close"
          onClick={onClose}
          className={cx(
            "absolute top-3 right-3 grid size-7 place-items-center rounded-full bg-black/45 text-white backdrop-blur-sm hover:bg-black/65",
            focusRing,
          )}
        >
          <X size={14} />
        </button>
      </div>

      {slides > 1 ? (
        <div className="flex gap-2 overflow-x-auto border-b border-[var(--st-border)] px-5 py-3">
          {images.map((src, i) => (
            <button
              key={`${src ?? "missing"}${i}`}
              type="button"
              aria-label={`Show background ${i + 1}`}
              onClick={() => setIndex(i)}
              className={cx(
                "h-12 w-20 shrink-0 overflow-hidden rounded-[6px] border transition-[opacity,box-shadow]",
                focusRing,
                i === index
                  ? "border-[var(--st-accent)] ring-2 ring-[var(--st-accent-soft)]"
                  : "border-[var(--st-border)] opacity-60 hover:opacity-100",
              )}
            >
              <Shot src={src} colours={item.colours} alt="" className="size-full" />
            </button>
          ))}
        </div>
      ) : null}

      <div className="flex items-start gap-6 px-5 py-4">
        <div className="min-w-0 flex-1">
          <div className="mb-1 flex items-center gap-1.5">
            <Badge>{KIND_LABEL[item.kind]}</Badge>
            {inUse ? (
              <Badge tone="accent" dot>
                In use
              </Badge>
            ) : installed ? (
              <Badge tone="ok" dot>
                Installed
              </Badge>
            ) : null}
          </div>
          <h2 className="text-[18px] font-semibold tracking-[-0.02em]">{item.name}</h2>
          <p className="mt-0.5 text-[13px] text-[var(--st-fg2)]">
            {item.subtitle} By {item.author}.
          </p>
          <div className="mt-3 flex flex-wrap items-center gap-3 text-[12px] text-[var(--st-fg3)]">
            <Swatches colours={item.colours} size={16} />
            <span className="flex items-center gap-1 tabular-nums">
              <Download size={12} /> {item.downloads.toLocaleString("en-GB")} downloads
            </span>
            {item.tags.map((t) => (
              <span
                key={t}
                className="rounded-[5px] bg-[var(--st-muted)] px-1.5 py-0.5 text-[11px] text-[var(--st-fg2)]"
              >
                {t}
              </span>
            ))}
          </div>
        </div>
        <div className="flex shrink-0 flex-col gap-2 pt-1">
          <Button variant="primary" onClick={() => onTry(item)} disabled={inUse}>
            {inUse ? "In use" : "Try it on"}
          </Button>
          <Button onClick={() => onInstall(item)} disabled={installed}>
            {installed ? (
              <>
                <Check size={13} /> {item.kind === "wallpaper" ? "In library" : "Installed"}
              </>
            ) : (
              <>
                <Download size={13} /> {installLabel}
              </>
            )}
          </Button>
        </div>
      </div>
    </dialog>
  );
}

/* ------------------------------------------------------------------ */
/* Page                                                                */
/* ------------------------------------------------------------------ */

export function WorkshopPage() {
  const [tab, setTab] = useState<Tab>("all");
  const [query, setQuery] = usePageSearch("Search the Workshop");
  const [stored, setStored] = useState<Stored>(load);
  const [trying, setTrying] = useState<string | null>(null);
  const [open, setOpen] = useState<{ id: string; index: number } | null>(null);

  useEffect(() => save(stored), [stored]);

  const installedSet = useMemo(
    () => new Set([...ALL.filter((i) => i.seededInstalled).map((i) => i.id), ...stored.installed]),
    [stored.installed],
  );
  const isInUse = (item: Item) => stored.applied[item.kind] === item.id && trying !== item.id;

  const q = query.trim().toLowerCase();
  const matches = useMemo(
    () =>
      q
        ? ALL.filter((i) =>
            [i.name, i.author, i.subtitle, KIND_LABEL[i.kind], ...i.tags]
              .join(" ")
              .toLowerCase()
              .includes(q),
          )
        : ALL,
    [q],
  );
  const byKind = (k: Kind) => matches.filter((i) => i.kind === k);

  const tryingItem = ALL.find((i) => i.id === trying);
  const openItem = open ? ALL.find((i) => i.id === open.id) : undefined;
  const openSiblings =
    openItem?.kind === "wallpaper"
      ? wallpaperItems.filter((w) => w.group === openItem.group)
      : undefined;

  const install = (id: string) =>
    setStored((s) => (s.installed.includes(id) ? s : { ...s, installed: [...s.installed, id] }));
  const keep = (item: Item) => {
    setStored((s) => ({
      installed: s.installed.includes(item.id) ? s.installed : [...s.installed, item.id],
      applied: { ...s.applied, [item.kind]: item.id },
    }));
    setTrying(null);
  };

  /** Wallpapers open on their theme's carousel so you can page through siblings. */
  const openDetail = (item: Item, index = 0) => setOpen({ id: item.id, index });

  const card = (item: Item) => (
    <ItemCard
      key={item.id}
      item={item}
      installed={installedSet.has(item.id)}
      inUse={isInUse(item)}
      trying={trying === item.id}
      onOpen={() => openDetail(item)}
      onTry={() => setTrying(item.id)}
    />
  );
  const tile = (item: Item) => (
    <WallpaperTile
      key={item.id}
      item={item}
      installed={installedSet.has(item.id)}
      inUse={isInUse(item)}
      onOpen={() => openDetail(item)}
    />
  );

  const counts: Record<Tab, number> = {
    all: matches.length,
    theme: byKind("theme").length,
    wallpaper: byKind("wallpaper").length,
    layout: byKind("layout").length,
    bar: byKind("bar").length,
  };

  const section = (k: Kind, limit?: number) => {
    const list = byKind(k);
    if (list.length === 0) return null;
    const shown = limit ? list.slice(0, limit) : list;
    const label = TABS.find((t) => t.id === k)?.label ?? k;
    return (
      <section key={k} className="mb-7">
        <SectionLabel
          action={
            limit && list.length > limit ? (
              <button
                type="button"
                onClick={() => setTab(k)}
                className={cx(
                  "flex items-center gap-0.5 rounded-[4px] text-[12px] font-medium text-[var(--st-accent-text)] hover:underline",
                  focusRing,
                )}
              >
                See all {list.length} <ChevronRight size={12} />
              </button>
            ) : (
              <span className="text-[11.5px] tabular-nums text-[var(--st-fg3)]">{list.length}</span>
            )
          }
        >
          {label}
        </SectionLabel>
        {k === "wallpaper" ? (
          <div className="grid grid-cols-4 gap-2.5">{shown.map(tile)}</div>
        ) : (
          <div className="grid grid-cols-3 gap-3">{shown.map(card)}</div>
        )}
      </section>
    );
  };

  return (
    <>
      <PageHeader title="Workshop" />

      {tryingItem ? (
        <div className="sticky top-2 z-10 mb-4 flex items-center gap-3 rounded-[10px] border border-[var(--st-accent)] bg-[var(--st-bg)] px-3 py-2 shadow-[0_8px_24px_-12px_rgba(0,0,0,0.35)]">
          <div className="h-8 w-12 shrink-0 overflow-hidden rounded-[5px] border border-[var(--st-border)]">
            <Cover item={tryingItem} />
          </div>
          <span className="size-2 shrink-0 animate-pulse rounded-full bg-[var(--st-accent)]" />
          <div className="min-w-0 flex-1 text-[13px] text-[var(--st-fg)]">
            Trying <span className="font-semibold">{tryingItem.name}</span>
          </div>
          <Button size="sm" variant="ghost" onClick={() => setTrying(null)}>
            Revert
          </Button>
          <Button size="sm" variant="primary" onClick={() => keep(tryingItem)}>
            Keep it
          </Button>
        </div>
      ) : null}

      {!q ? (
        <div className="relative mb-6 h-[280px] overflow-hidden rounded-[12px] border border-[var(--st-border)] shadow-[var(--st-shadow)]">
          <div className="absolute inset-0">
            <Shot
              src={featured.images[FEATURED_INDEX] ?? featured.images[0]}
              colours={featured.colours}
              alt={featured.name}
              className="size-full"
              eager
            />
          </div>
          <div className="absolute inset-0 bg-[linear-gradient(90deg,rgba(0,0,0,0.78)_0%,rgba(0,0,0,0.45)_45%,transparent_75%)]" />
          <div className="absolute inset-y-0 left-0 flex w-[56%] flex-col justify-end p-6 text-white">
            <span className="mb-2 inline-flex w-fit items-center gap-1.5 rounded-[6px] bg-white/15 px-2 py-0.5 text-[11.5px] font-medium backdrop-blur-sm">
              <Sparkles size={11} /> Featured this week
            </span>
            <h2 className="text-[26px] leading-tight font-semibold tracking-[-0.025em]">
              {featured.name}
            </h2>
            <p className="mt-1 text-[13px] text-white/75">
              {featured.subtitle} By {featured.author}.
            </p>
            <div className="mt-2.5 flex items-center gap-3 text-[11.5px] text-white/70">
              <div className="flex items-center -space-x-1">
                {featured.colours.map((c, i) => (
                  <span
                    key={`${c}${i}`}
                    className="size-3 rounded-full ring-2 ring-black/40"
                    style={{ background: c }}
                  />
                ))}
              </div>
              <span className="flex items-center gap-1 tabular-nums">
                <Download size={11} /> {formatCount(featured.downloads)}
              </span>
            </div>
            <div className="mt-4 flex items-center gap-2">
              <Button
                variant="accent"
                onClick={() => setTrying(featured.id)}
                disabled={isInUse(featured)}
              >
                {isInUse(featured) ? "In use" : trying === featured.id ? "Trying now" : "Try it on"}
              </Button>
              <button
                type="button"
                onClick={() => openDetail(featured, FEATURED_INDEX)}
                className={cx(
                  "h-8 rounded-[7px] px-3 text-[13px] font-medium text-white/90 transition-colors hover:bg-white/15",
                  focusRing,
                )}
              >
                View details
              </button>
            </div>
          </div>
          <div className="absolute right-4 bottom-4 flex gap-1.5">
            {featured.images.map((src, i) => (
              <button
                key={`${src ?? "x"}${i}`}
                type="button"
                aria-label={`Preview background ${i + 1}`}
                onClick={() => openDetail(featured, i)}
                className={cx(
                  "h-11 w-[70px] overflow-hidden rounded-[6px] border border-white/30 shadow-lg transition-transform hover:-translate-y-0.5",
                  focusRing,
                )}
              >
                <Shot src={src} colours={featured.colours} alt="" className="size-full" />
              </button>
            ))}
          </div>
        </div>
      ) : null}

      <Tabs
        tabs={TABS.map((t) => ({ id: t.id, label: t.label, count: counts[t.id] }))}
        value={tab}
        onChange={setTab}
      />

      {matches.length === 0 || (tab !== "all" && counts[tab] === 0) ? (
        <EmptyState
          icon={<Search size={16} />}
          title="Nothing matches"
          action={
            <Button size="sm" onClick={() => setQuery("")}>
              Clear search
            </Button>
          }
        />
      ) : tab === "all" ? (
        <>
          {section("theme", q ? undefined : 9)}
          {section("wallpaper", q ? undefined : 12)}
          {section("layout", q ? undefined : 6)}
          {section("bar", q ? undefined : 6)}
        </>
      ) : tab === "wallpaper" ? (
        <>
          <div className="mb-3 flex items-center justify-between text-[12px] text-[var(--st-fg3)]">
            <span>
              {counts.wallpaper} backgrounds from{" "}
              {new Set(byKind("wallpaper").map((w) => w.group)).size} themes
            </span>
          </div>
          <div className="grid grid-cols-4 gap-2.5">{byKind("wallpaper").map(tile)}</div>
        </>
      ) : (
        <div className="grid grid-cols-3 gap-3">{byKind(tab).map(card)}</div>
      )}

      {openItem && open ? (
        <DetailDialog
          key={`${openItem.id}-${open.index}`}
          base={openItem}
          siblings={openSiblings}
          startIndex={
            openSiblings
              ? Math.max(
                  0,
                  openSiblings.findIndex((s) => s.id === openItem.id),
                )
              : Math.min(open.index, Math.max(0, openItem.images.length - 1))
          }
          isInstalled={(i) => installedSet.has(i.id)}
          isInUse={isInUse}
          onClose={() => setOpen(null)}
          onInstall={(i) => install(i.id)}
          onTry={(i) => {
            setTrying(i.id);
            setOpen(null);
          }}
        />
      ) : null}
    </>
  );
}
