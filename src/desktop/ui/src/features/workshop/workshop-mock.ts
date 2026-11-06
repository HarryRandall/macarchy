/**
 * Placeholder Workshop catalogue from the Studio design. There is nothing to
 * download yet: Omarchy's community themes, the layouts and the bars below
 * stand in for a catalogue that does not exist. Installed themes and their
 * wallpapers are real and come from the themes bridge. Each use is marked
 * `Mock:`.
 */

export type Kind = "theme" | "wallpaper" | "layout" | "bar";

/** A window as percentages of the screen: x, y, width, height. */
export type Rect = readonly [x: number, y: number, w: number, h: number];

export interface BarSpec {
  position: "top" | "bottom";
  shape: "full" | "floating" | "pill" | "islands" | "notch";
  glass?: boolean;
}

export interface WorkshopItem {
  id: string;
  kind: Kind;
  name: string;
  author: string;
  subtitle: string;
  downloads: number;
  /** Image URLs; an undefined entry is an image that is not on this Mac. */
  images: (string | undefined)[];
  /** Background, foreground, accent, then two highlights. */
  colours: string[];
  dark: boolean;
  tags: string[];
  /** Already on this Mac, so it cannot be installed again. */
  local?: boolean;
  /** The theme a wallpaper belongs to, so the dialog can page through its siblings. */
  group?: string;
  layout?: Rect[];
  bar?: BarSpec;
}

export interface CommunityTheme {
  id: string;
  /** Background file names as Omarchy publishes them. */
  backgrounds: string[];
  colours: string[];
  dark: boolean;
  blurb: string;
  tags: string[];
}

/** Omarchy's community themes, with palettes close to their own. */
export const communityThemes: CommunityTheme[] = [
  {
    id: "catppuccin",
    backgrounds: ["1-totoro.webp", "2-waves.webp", "3-blue-eye.webp"],
    colours: ["#1e1e2e", "#cdd6f4", "#cba6f7", "#f38ba8", "#a6e3a1"],
    dark: true,
    blurb: "Soothing pastels on a deep mocha base.",
    tags: ["pastel", "cosy"],
  },
  {
    id: "catppuccin-latte",
    backgrounds: ["1-color-fade.webp"],
    colours: ["#eff1f5", "#4c4f69", "#8839ef", "#d20f39", "#40a02b"],
    dark: false,
    blurb: "The light flavour of Catppuccin, warm and milky.",
    tags: ["light", "pastel"],
  },
  {
    id: "ethereal",
    backgrounds: ["1-cosmic.webp", "2-meadow.webp"],
    colours: ["#060b1e", "#ffcead", "#7d82d9", "#c89dc1", "#92a593"],
    dark: true,
    blurb: "Cosmic violets with a soft peach foreground.",
    tags: ["space", "dreamy"],
  },
  {
    id: "everforest",
    backgrounds: ["1-tree-tops.webp"],
    colours: ["#2d353b", "#d3c6aa", "#a7c080", "#e69875", "#7fbbb3"],
    dark: true,
    blurb: "Green, comfortable and easy on the eyes all day.",
    tags: ["nature", "calm"],
  },
  {
    id: "flexoki-light",
    backgrounds: ["1-orb.webp"],
    colours: ["#fffcf0", "#100f0f", "#205ea6", "#af3029", "#66800b"],
    dark: false,
    blurb: "Inky colours on paper, designed for reading.",
    tags: ["light", "paper"],
  },
  {
    id: "gruvbox",
    backgrounds: ["1-the-backwater.jpg", "2-flower-basket.webp", "3-village-square.jpg"],
    colours: ["#282828", "#ebdbb2", "#d79921", "#cc241d", "#98971a"],
    dark: true,
    blurb: "Retro groove with warm, earthy contrast.",
    tags: ["retro", "warm"],
  },
  {
    id: "hackerman",
    backgrounds: ["1-synth-scape.jpg", "2-geometric.webp"],
    colours: ["#0b0c16", "#ddf7ff", "#82fb9c", "#50f872", "#7cf8f7"],
    dark: true,
    blurb: "Phosphor greens for people who type fast.",
    tags: ["neon", "terminal"],
  },
  {
    id: "kanagawa",
    backgrounds: ["1-kanagawa.jpg"],
    colours: ["#1f1f28", "#dcd7ba", "#7e9cd8", "#c34043", "#98bb6c"],
    dark: true,
    blurb: "Inspired by the colours of a famous woodblock wave.",
    tags: ["japanese", "ink"],
  },
  {
    id: "last-horizon",
    backgrounds: ["1-eyes-wide.webp", "2-blink.webp", "3-bokeh.webp"],
    colours: ["#0f0f14", "#e6e1dc", "#d4a373", "#8a6f9e", "#5f7a8a"],
    dark: true,
    blurb: "Muted dusk tones and soft bokeh.",
    tags: ["moody", "film"],
  },
  {
    id: "lupine",
    backgrounds: [
      "01-cherry-blossom-bokeh.webp",
      "02-cherry-blossom-white.webp",
      "03-pastel-clouds.webp",
    ],
    colours: ["#1b1726", "#e8dff5", "#b39ddb", "#f48fb1", "#9fa8da"],
    dark: true,
    blurb: "Cherry blossom pinks against a violet night.",
    tags: ["floral", "pastel"],
  },
  {
    id: "miasma",
    backgrounds: ["01-nature-of-fear.webp", "02-crowned.webp"],
    colours: ["#222222", "#c2c2b0", "#bb7744", "#685742", "#5f875f"],
    dark: true,
    blurb: "Foggy forest browns with a rusty accent.",
    tags: ["earthy", "dark"],
  },
  {
    id: "nord",
    backgrounds: ["0-black-moon.jpg", "1-city-view.webp", "2-night-hawks.webp"],
    colours: ["#2e3440", "#d8dee9", "#88c0d0", "#bf616a", "#a3be8c"],
    dark: true,
    blurb: "An arctic, north-bluish palette.",
    tags: ["cool", "classic"],
  },
  {
    id: "osaka-jade",
    backgrounds: ["1-glowing-city.webp", "2-shaded-entrance.webp", "3-mountain-moon.webp"],
    colours: ["#111c18", "#c1c497", "#2dd5b7", "#ff5345", "#549e6a"],
    dark: true,
    blurb: "Jade greens and neon signs after rain.",
    tags: ["city", "neon"],
  },
  {
    id: "retro-82",
    backgrounds: ["1-in-the-groove.webp", "2-dusk-guardian.webp", "3-glassy-lines.webp"],
    colours: ["#0d0221", "#f7f1ff", "#ff2a6d", "#05d9e8", "#d1f7ff"],
    dark: true,
    blurb: "Synthwave magenta and cyan, straight from 1982.",
    tags: ["synthwave", "neon"],
  },
  {
    id: "ristretto",
    backgrounds: ["0-launch.webp", "1-color-curves.webp", "2-coffee-beans.jpg"],
    colours: ["#2c2525", "#e6d9db", "#f38d70", "#fd6883", "#adda78"],
    dark: true,
    blurb: "Rich espresso browns with a fruity finish.",
    tags: ["warm", "coffee"],
  },
  {
    id: "rose-pine",
    backgrounds: ["1-funky-shapes.webp", "2-dot-map.webp", "3-omarchy-plants.webp"],
    colours: ["#faf4ed", "#575279", "#d7827e", "#b4637a", "#286983"],
    dark: false,
    blurb: "All natural pine, faux fur and a bit of soho vibes.",
    tags: ["light", "soft"],
  },
  {
    id: "solitude",
    backgrounds: ["1-on-pole.webp", "2-wreakage.webp", "3-climb.jpg"],
    colours: ["#14161b", "#d0d4da", "#8fa1b3", "#c0a36e", "#6b7a8f"],
    dark: true,
    blurb: "Quiet greys and lonely landscapes.",
    tags: ["minimal", "moody"],
  },
  {
    id: "starship",
    backgrounds: ["1-starbase.webp", "2-flight14-dawn.webp", "3-engine-cluster.webp"],
    colours: ["#0a0e14", "#e6e6e6", "#ff7a18", "#4fa3ff", "#9aa5b1"],
    dark: true,
    blurb: "Launch pads at dawn, steel and rocket flame.",
    tags: ["space", "industrial"],
  },
  {
    id: "tokyo-night",
    backgrounds: ["0-liftoff.webp", "1-winding-road.webp", "2-quattro.webp"],
    colours: ["#1a1b26", "#a9b1d6", "#7aa2f7", "#f7768e", "#9ece6a"],
    dark: true,
    blurb: "Celebrates the lights of downtown Tokyo at night.",
    tags: ["city", "classic"],
  },
  {
    id: "vantablack",
    backgrounds: ["0-dot-hands.webp", "1-twisted-stairs.webp", "2-layers-deep.webp"],
    colours: ["#000000", "#f0f0f0", "#8a8a8a", "#ffffff", "#3a3a3a"],
    dark: true,
    blurb: "As close to pure black as a screen allows.",
    tags: ["mono", "minimal"],
  },
  {
    id: "white",
    backgrounds: ["1-white.webp", "2-white.webp", "3-white.webp"],
    colours: ["#ffffff", "#1a1a1a", "#6e6e6e", "#000000", "#d0d0d0"],
    dark: false,
    blurb: "Pure white, sharp black type, nothing else.",
    tags: ["light", "mono"],
  },
];

/** The theme the page features, and which of its images leads. */
export const featured = { theme: "tokyo-night", image: 1 };

export interface LayoutDesign {
  id: string;
  name: string;
  author: string;
  subtitle: string;
  layout: Rect[];
  tags: string[];
}

export const layoutDesigns: LayoutDesign[] = [
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
];

export interface BarDesign {
  id: string;
  name: string;
  author: string;
  subtitle: string;
  bar: BarSpec;
  tags: string[];
}

export const barDesigns: BarDesign[] = [
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
];

/** Zinc and indigo, for a design without a theme of its own. */
export const neutralColours = ["#18181b", "#e4e4e7", "#818cf8", "#f472b6", "#34d399"];
