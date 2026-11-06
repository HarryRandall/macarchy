/**
 * Real content for the mockups: the themes, palettes and wallpapers installed
 * in ~/.config/macarchy, a snapshot of its settings, and Omarchy's community
 * themes on GitHub for Workshop. Generated once; wallpaper thumbnails live in
 * assets/backgrounds (ignored by git) and resolve to nothing elsewhere.
 */

const files = import.meta.glob<string>("./assets/backgrounds/*/*.jpg", {
  eager: true,
  query: "?url",
  import: "default",
});

/** The thumbnail URL for a theme's wallpaper, or undefined when it is not on this machine. */
export function wallpaperUrl(theme: string, name: string): string | undefined {
  return files[`./assets/backgrounds/${theme}/${name}.jpg`];
}

export interface RealTheme {
  id: string;
  name: string;
  dark: boolean;
  /** The active border colour, which Macarchy uses as the theme's accent. */
  accent: string;
  background: string;
  foreground: string;
  /** Terminal colours 0 to 7 from the theme's Ghostty config. */
  palette: string[];
  nvim: string;
  wallpapers: string[];
  /** The wallpaper chosen for this theme in settings. */
  wallpaper: string;
}

export const realThemes: RealTheme[] = [
  {
    id: "awakening",
    name: "Awakening",
    dark: true,
    accent: "#ffff00",
    background: "#141010",
    foreground: "#dacbe6",
    palette: [
      "#141010",
      "#f56728",
      "#ffff00",
      "#c92b50",
      "#2976d1",
      "#976add",
      "#449392",
      "#dacbe6",
    ],
    nvim: "gruvbox",
    wallpapers: ["0-awakening", "2-gasmask-runner", "4-street-signal"],
    wallpaper: "0-awakening",
  },
  {
    id: "blackgold",
    name: "Black Gold",
    dark: true,
    accent: "#bfa75d",
    background: "#0d0d0d",
    foreground: "#ebdbb2",
    palette: [
      "#0d0d0d",
      "#d35f5f",
      "#a3850e",
      "#4d574e",
      "#6e6a58",
      "#bfa75d",
      "#7a6a2c",
      "#f6f1dd",
    ],
    nvim: "blackgold",
    wallpapers: ["bg2", "bg3"],
    wallpaper: "bg3",
  },
  {
    id: "carbonfox",
    name: "Carbonfox",
    dark: true,
    accent: "#78a9ff",
    background: "#161616",
    foreground: "#f2f4f8",
    palette: [
      "#161616",
      "#ee5396",
      "#33b1ff",
      "#08bdba",
      "#78a9ff",
      "#be95ff",
      "#25be6a",
      "#f2f4f8",
    ],
    nvim: "tokyonight-night",
    wallpapers: ["4", "5"],
    wallpaper: "4",
  },
  {
    id: "city-783",
    name: "City 783",
    dark: true,
    accent: "#eceff2",
    background: "#181a1f",
    foreground: "#b9bec6",
    palette: [
      "#181a1f",
      "#b31414",
      "#d12b2b",
      "#9e1a1a",
      "#ad2222",
      "#c3c8d0",
      "#8f949c",
      "#b9bec6",
    ],
    nvim: "rose-pine-moon",
    wallpapers: [
      "0-gasmask-triad",
      "1-city-783",
      "2-crimson-diver",
      "3-crimson-corridor",
      "4-red-monolith",
    ],
    wallpaper: "3-crimson-corridor",
  },
  {
    id: "lumon",
    name: "Lumon",
    dark: true,
    accent: "#f2fcff",
    background: "#16242d",
    foreground: "#d6e2ee",
    palette: [
      "#1b2d40",
      "#4d86b0",
      "#5e95bc",
      "#6fa4c9",
      "#6fb8e3",
      "#8bc9eb",
      "#b4e4f6",
      "#d6e2ee",
    ],
    nvim: "lumon",
    wallpapers: ["01-united-in-severance", "02-opinions-equally", "wall"],
    wallpaper: "wall",
  },
  {
    id: "matte-black",
    name: "Matte Black",
    dark: true,
    accent: "#e68e0d",
    background: "#121212",
    foreground: "#bebebe",
    palette: [
      "#333333",
      "#d35f5f",
      "#ffc107",
      "#b91c1c",
      "#e68e0d",
      "#d35f5f",
      "#bebebe",
      "#bebebe",
    ],
    nvim: "gruvbox",
    wallpapers: ["0-ship-at-sea", "1-dark-waters", "2-dot-hands", "wall"],
    wallpaper: "0-ship-at-sea",
  },
  {
    id: "midnight",
    name: "Midnight",
    dark: true,
    accent: "#66ccff",
    background: "#000000",
    foreground: "#f0f6ff",
    palette: [
      "#050505",
      "#ff3366",
      "#33ffdd",
      "#3399ff",
      "#1e90ff",
      "#00cfff",
      "#66ccff",
      "#f0f6ff",
    ],
    nvim: "tokyonight-night",
    wallpapers: ["2-hand-of-adam", "3-omarchy-window"],
    wallpaper: "2-hand-of-adam",
  },
  {
    id: "turbonite",
    name: "Turbonite",
    dark: true,
    accent: "#ed9a1d",
    background: "#0b0c0c",
    foreground: "#eae9e3",
    palette: [
      "#0b0c0c",
      "#f24331",
      "#6e6a64",
      "#ed9a1d",
      "#666a6d",
      "#aaa8a4",
      "#ebd698",
      "#cac8c4",
    ],
    nvim: "gruvbox",
    wallpapers: ["bg02", "bg05", "bg09"],
    wallpaper: "bg02",
  },
];

export const currentThemeId = "matte-black";

/** A snapshot of ~/.config/macarchy/settings.json, trimmed to what the pages show. */
export const snapshot = {
  borders: {
    border_radius: 0.3,
    border_style: "square",
    border_width: 7,
    borders_blacklist: "iPhone Mirroring",
    borders_visible: true,
  },
  layout: {
    auto_balance: false,
    bottom_padding: 8,
    layout: "bsp",
    left_padding: 8,
    mouse_drop_action: "stack",
    mouse_follows_focus: false,
    mouse_modifier: "ctrl",
    right_padding: 8,
    split_type: "auto",
    top_padding: 8,
    window_gap: 8,
    window_placement: "second_child",
  },
  menuBar: {
    blur_radius: 0,
    corner_radius: 0,
    height: 35,
    padding_left: 10,
    padding_right: 10,
    position: "top",
    sticky: true,
    y_offset: 0,
  },
  barItems: [
    { id: "workspaces", title: "Workspaces", side: "left", visible: true },
    { id: "network", title: "Network", side: "right", visible: true },
    { id: "ram", title: "Memory", side: "right", visible: true },
    { id: "gpu", title: "GPU", side: "right", visible: true },
    { id: "cpu", title: "CPU", side: "right", visible: true },
    { id: "battery", title: "Battery", side: "right", visible: true },
    { id: "calendar", title: "Clock", side: "right", visible: true },
    { id: "macarchy", title: "Spacer", side: "right", visible: true },
    { id: "theme_listener", title: "Theme Listener", side: "left", visible: false },
  ],
  floatingApps: ["FaceTime", "Macarchy", "TablePlus", "iPhone Mirroring"],
  bundledBar: false,
};

/** Omarchy's community themes and their published backgrounds (hotlinked from GitHub). */
export const communityThemes: { id: string; backgrounds: string[] }[] = [
  {
    id: "catppuccin",
    backgrounds: [
      "https://raw.githubusercontent.com/omacom/omarchy/quattro/themes/catppuccin/backgrounds/1-totoro.webp",
      "https://raw.githubusercontent.com/omacom/omarchy/quattro/themes/catppuccin/backgrounds/2-waves.webp",
      "https://raw.githubusercontent.com/omacom/omarchy/quattro/themes/catppuccin/backgrounds/3-blue-eye.webp",
    ],
  },
  {
    id: "catppuccin-latte",
    backgrounds: [
      "https://raw.githubusercontent.com/omacom/omarchy/quattro/themes/catppuccin-latte/backgrounds/1-color-fade.webp",
    ],
  },
  {
    id: "ethereal",
    backgrounds: [
      "https://raw.githubusercontent.com/omacom/omarchy/quattro/themes/ethereal/backgrounds/1-cosmic.webp",
      "https://raw.githubusercontent.com/omacom/omarchy/quattro/themes/ethereal/backgrounds/2-meadow.webp",
    ],
  },
  {
    id: "everforest",
    backgrounds: [
      "https://raw.githubusercontent.com/omacom/omarchy/quattro/themes/everforest/backgrounds/1-tree-tops.webp",
    ],
  },
  {
    id: "flexoki-light",
    backgrounds: [
      "https://raw.githubusercontent.com/omacom/omarchy/quattro/themes/flexoki-light/backgrounds/1-orb.webp",
    ],
  },
  {
    id: "gruvbox",
    backgrounds: [
      "https://raw.githubusercontent.com/omacom/omarchy/quattro/themes/gruvbox/backgrounds/1-the-backwater.jpg",
      "https://raw.githubusercontent.com/omacom/omarchy/quattro/themes/gruvbox/backgrounds/2-flower-basket.webp",
      "https://raw.githubusercontent.com/omacom/omarchy/quattro/themes/gruvbox/backgrounds/3-village-square.jpg",
    ],
  },
  {
    id: "hackerman",
    backgrounds: [
      "https://raw.githubusercontent.com/omacom/omarchy/quattro/themes/hackerman/backgrounds/1-synth-scape.jpg",
      "https://raw.githubusercontent.com/omacom/omarchy/quattro/themes/hackerman/backgrounds/2-geometric.webp",
    ],
  },
  {
    id: "kanagawa",
    backgrounds: [
      "https://raw.githubusercontent.com/omacom/omarchy/quattro/themes/kanagawa/backgrounds/1-kanagawa.jpg",
    ],
  },
  {
    id: "last-horizon",
    backgrounds: [
      "https://raw.githubusercontent.com/omacom/omarchy/quattro/themes/last-horizon/backgrounds/1-eyes-wide.webp",
      "https://raw.githubusercontent.com/omacom/omarchy/quattro/themes/last-horizon/backgrounds/2-blink.webp",
      "https://raw.githubusercontent.com/omacom/omarchy/quattro/themes/last-horizon/backgrounds/3-bokeh.webp",
    ],
  },
  {
    id: "lupine",
    backgrounds: [
      "https://raw.githubusercontent.com/omacom/omarchy/quattro/themes/lupine/backgrounds/01-cherry-blossom-bokeh.webp",
      "https://raw.githubusercontent.com/omacom/omarchy/quattro/themes/lupine/backgrounds/02-cherry-blossom-white.webp",
      "https://raw.githubusercontent.com/omacom/omarchy/quattro/themes/lupine/backgrounds/03-pastel-clouds.webp",
    ],
  },
  {
    id: "miasma",
    backgrounds: [
      "https://raw.githubusercontent.com/omacom/omarchy/quattro/themes/miasma/backgrounds/01-nature-of-fear.webp",
      "https://raw.githubusercontent.com/omacom/omarchy/quattro/themes/miasma/backgrounds/02-crowned.webp",
    ],
  },
  {
    id: "nord",
    backgrounds: [
      "https://raw.githubusercontent.com/omacom/omarchy/quattro/themes/nord/backgrounds/0-black-moon.jpg",
      "https://raw.githubusercontent.com/omacom/omarchy/quattro/themes/nord/backgrounds/1-city-view.webp",
      "https://raw.githubusercontent.com/omacom/omarchy/quattro/themes/nord/backgrounds/2-night-hawks.webp",
    ],
  },
  {
    id: "osaka-jade",
    backgrounds: [
      "https://raw.githubusercontent.com/omacom/omarchy/quattro/themes/osaka-jade/backgrounds/1-glowing-city.webp",
      "https://raw.githubusercontent.com/omacom/omarchy/quattro/themes/osaka-jade/backgrounds/2-shaded-entrance.webp",
      "https://raw.githubusercontent.com/omacom/omarchy/quattro/themes/osaka-jade/backgrounds/3-mountain-moon.webp",
    ],
  },
  {
    id: "retro-82",
    backgrounds: [
      "https://raw.githubusercontent.com/omacom/omarchy/quattro/themes/retro-82/backgrounds/1-in-the-groove.webp",
      "https://raw.githubusercontent.com/omacom/omarchy/quattro/themes/retro-82/backgrounds/2-dusk-guardian.webp",
      "https://raw.githubusercontent.com/omacom/omarchy/quattro/themes/retro-82/backgrounds/3-glassy-lines.webp",
    ],
  },
  {
    id: "ristretto",
    backgrounds: [
      "https://raw.githubusercontent.com/omacom/omarchy/quattro/themes/ristretto/backgrounds/0-launch.webp",
      "https://raw.githubusercontent.com/omacom/omarchy/quattro/themes/ristretto/backgrounds/1-color-curves.webp",
      "https://raw.githubusercontent.com/omacom/omarchy/quattro/themes/ristretto/backgrounds/2-coffee-beans.jpg",
    ],
  },
  {
    id: "rose-pine",
    backgrounds: [
      "https://raw.githubusercontent.com/omacom/omarchy/quattro/themes/rose-pine/backgrounds/1-funky-shapes.webp",
      "https://raw.githubusercontent.com/omacom/omarchy/quattro/themes/rose-pine/backgrounds/2-dot-map.webp",
      "https://raw.githubusercontent.com/omacom/omarchy/quattro/themes/rose-pine/backgrounds/3-omarchy-plants.webp",
    ],
  },
  {
    id: "solitude",
    backgrounds: [
      "https://raw.githubusercontent.com/omacom/omarchy/quattro/themes/solitude/backgrounds/1-on-pole.webp",
      "https://raw.githubusercontent.com/omacom/omarchy/quattro/themes/solitude/backgrounds/2-wreakage.webp",
      "https://raw.githubusercontent.com/omacom/omarchy/quattro/themes/solitude/backgrounds/3-climb.jpg",
    ],
  },
  {
    id: "starship",
    backgrounds: [
      "https://raw.githubusercontent.com/omacom/omarchy/quattro/themes/starship/backgrounds/1-starbase.webp",
      "https://raw.githubusercontent.com/omacom/omarchy/quattro/themes/starship/backgrounds/2-flight14-dawn.webp",
      "https://raw.githubusercontent.com/omacom/omarchy/quattro/themes/starship/backgrounds/3-engine-cluster.webp",
    ],
  },
  {
    id: "tokyo-night",
    backgrounds: [
      "https://raw.githubusercontent.com/omacom/omarchy/quattro/themes/tokyo-night/backgrounds/0-liftoff.webp",
      "https://raw.githubusercontent.com/omacom/omarchy/quattro/themes/tokyo-night/backgrounds/1-winding-road.webp",
      "https://raw.githubusercontent.com/omacom/omarchy/quattro/themes/tokyo-night/backgrounds/2-quattro.webp",
    ],
  },
  {
    id: "vantablack",
    backgrounds: [
      "https://raw.githubusercontent.com/omacom/omarchy/quattro/themes/vantablack/backgrounds/0-dot-hands.webp",
      "https://raw.githubusercontent.com/omacom/omarchy/quattro/themes/vantablack/backgrounds/1-twisted-stairs.webp",
      "https://raw.githubusercontent.com/omacom/omarchy/quattro/themes/vantablack/backgrounds/2-layers-deep.webp",
    ],
  },
  {
    id: "white",
    backgrounds: [
      "https://raw.githubusercontent.com/omacom/omarchy/quattro/themes/white/backgrounds/1-white.webp",
      "https://raw.githubusercontent.com/omacom/omarchy/quattro/themes/white/backgrounds/2-white.webp",
      "https://raw.githubusercontent.com/omacom/omarchy/quattro/themes/white/backgrounds/3-white.webp",
    ],
  },
];

const icons = import.meta.glob<string>("./assets/app-icons/*.png", {
  eager: true,
  query: "?url",
  import: "default",
});

/**
 * A real app icon extracted from this Mac's /Applications, keyed by a slug of
 * the app name ("facetime", "iphone-mirroring", "ghostty", "spotify",
 * "tableplus", "safari", "finder", "system-settings", "music", "calendar",
 * "notes", "mail", "messages", "google-chrome", "visual-studio-code",
 * "cursor", "macarchy"). Undefined when the app is not installed, so callers
 * fall back to a letter tile.
 */
export function appIconUrl(app: string): string | undefined {
  const slug = app.toLowerCase().replace(/\s+/g, "-");
  return icons[`./assets/app-icons/${slug}.png`];
}
