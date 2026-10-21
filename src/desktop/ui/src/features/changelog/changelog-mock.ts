/**
 * Placeholder release notes from the Studio design. There is no release feed
 * yet; swap this module for one when there is. Each use is marked `Mock:`.
 */

export type ChangeKind = "new" | "improved" | "fixed";

export interface Release {
  version: string;
  /** ISO date. */
  date: string;
  title: string;
  summary: string;
  /** A theme's colours illustrating a big release. */
  art?: { from: string; to: string; caption: string };
  entries: { kind: ChangeKind; text: string }[];
}

export const latestRelease: Release = {
  version: "0.9.2",
  date: "2026-10-14",
  title: "Themes everywhere",
  summary:
    "Ghostty and Neovim now follow your theme, and every theme remembers its own wallpaper, so one click restyles the whole desktop.",
  art: { from: "#16242d", to: "#f2fcff", caption: "Lumon theme" },
  entries: [
    {
      kind: "new",
      text: "Ghostty follows the active theme. Open windows pick up the new palette without a restart.",
    },
    {
      kind: "new",
      text: "Neovim switches colourscheme when the theme changes, through a small bundled plugin.",
    },
    {
      kind: "new",
      text: "Each theme keeps its own wallpaper. Choose one per theme from the Themes page.",
    },
    {
      kind: "improved",
      text: "Switching themes is roughly twice as fast because services now reload in parallel.",
    },
    { kind: "improved", text: "Theme cards show the chosen wallpaper and the terminal palette." },
    {
      kind: "fixed",
      text: "SketchyBar no longer flashes its default colours during a theme change.",
    },
    { kind: "fixed", text: "Borders keep the theme colour after the Mac wakes from sleep." },
  ],
};

export const releases: readonly Release[] = [
  latestRelease,
  {
    version: "0.9.1",
    date: "2026-09-30",
    title: "Polish for the new window",
    summary:
      "Small fixes and refinements following the 0.9.0 redesign, thanks to everyone who sent reports.",
    entries: [
      {
        kind: "improved",
        text: "The sidebar collapses to an icon rail with ⌘\\ and remembers its state.",
      },
      { kind: "improved", text: "Search now matches settings inside pages, not just page names." },
      { kind: "fixed", text: "The settings window reopens at its last size and position." },
      {
        kind: "fixed",
        text: "Login items failed to register when the home folder had a space in it.",
      },
      { kind: "fixed", text: "Back and forward no longer skip a page after using search." },
    ],
  },
  {
    version: "0.9.0",
    date: "2026-09-16",
    title: "A new settings window",
    summary:
      "The settings window has been rebuilt from scratch, with search, a live log and changes that apply as you make them.",
    art: { from: "#000000", to: "#66ccff", caption: "Midnight theme" },
    entries: [
      { kind: "new", text: "A redesigned settings window with a Home overview of your desktop." },
      { kind: "new", text: "Search settings and run commands from anywhere with ⌘K." },
      {
        kind: "new",
        text: "A Logs panel shows every command Macarchy runs and what each service says back.",
      },
      {
        kind: "improved",
        text: "Every change applies immediately. There is no Save button any more.",
      },
      {
        kind: "improved",
        text: "Light and dark appearance follow the system, or can be set by hand.",
      },
      { kind: "fixed", text: "Restarting yabai no longer moves windows between displays." },
    ],
  },
  {
    version: "0.8.4",
    date: "2026-08-26",
    title: "Setup health checks",
    summary:
      "Macarchy now checks that yabai, SketchyBar, borders and skhd are installed, running and starting at login.",
    entries: [
      {
        kind: "new",
        text: "Setup health lists each check with a one-click fix, such as starting skhd or adding a login item.",
      },
      { kind: "new", text: "Health problems show as a badge in the sidebar until they are fixed." },
      {
        kind: "improved",
        text: "Report a problem attaches the health results and recent log lines.",
      },
      {
        kind: "fixed",
        text: "The accessibility permission check gave a false warning on macOS 26.",
      },
    ],
  },
  {
    version: "0.8.2",
    date: "2026-08-05",
    title: "Menu Bar editor",
    summary:
      "Arrange SketchyBar visually: drag items between sides, hide the ones you do not use and preview the result.",
    entries: [
      {
        kind: "new",
        text: "Drag menu bar items to reorder them or move them between the left and right.",
      },
      {
        kind: "new",
        text: "Show or hide items such as Network, Memory and GPU with a single toggle.",
      },
      {
        kind: "improved",
        text: "Item scripts that time out keep their last value instead of going blank.",
      },
      { kind: "fixed", text: "The battery item showed the wrong icon while charging." },
    ],
  },
  {
    version: "0.8.0",
    date: "2026-07-15",
    title: "Window borders",
    summary:
      "Window borders join the theme. Macarchy installs and configures borders, and colours it from the active theme.",
    art: { from: "#161616", to: "#78a9ff", caption: "Carbonfox theme" },
    entries: [
      { kind: "new", text: "A Borders page for width, style and active and inactive colours." },
      { kind: "new", text: "Border colours come from the theme unless you set your own." },
      {
        kind: "new",
        text: "Exclude apps that draw their own frames, such as Zoom or screen recorders.",
      },
      {
        kind: "improved",
        text: "Theme changes now reload yabai, SketchyBar and borders together.",
      },
      { kind: "fixed", text: "Borders were drawn behind full-screen video in some browsers." },
    ],
  },
  {
    version: "0.7.3",
    date: "2026-06-24",
    title: "Rules for floating apps",
    summary:
      "Decide which apps float above the tiling layout and which desktop they open on, without editing yabairc.",
    entries: [
      {
        kind: "new",
        text: "Rules lets you float apps such as System Settings, TablePlus and Calculator.",
      },
      { kind: "new", text: "Send an app to a desktop when it opens." },
      {
        kind: "improved",
        text: "Pick apps from a list of what is installed instead of typing bundle IDs.",
      },
      { kind: "fixed", text: "Rules with a dot in the app name were ignored." },
    ],
  },
  {
    version: "0.7.0",
    date: "2026-06-03",
    title: "Workshop preview",
    summary:
      "An early look at Workshop: browse Omarchy community themes and install them into Macarchy in one step.",
    entries: [
      { kind: "new", text: "Workshop lists community themes with their wallpapers and palettes." },
      { kind: "new", text: "Install a community theme and switch to it straight away." },
      {
        kind: "improved",
        text: "Themes now install into ~/.config/macarchy/themes so they survive updates.",
      },
      { kind: "fixed", text: "Installing a theme with an uppercase name failed silently." },
    ],
  },
];
