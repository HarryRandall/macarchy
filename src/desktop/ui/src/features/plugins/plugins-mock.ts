import {
  Beer,
  BellOff,
  CalendarClock,
  CloudSun,
  GitPullRequest,
  Keyboard,
  Layers,
  ListTodo,
  type LucideIcon,
  MessageSquare,
  Music,
  SquareTerminal,
  Timer,
} from "lucide-react";

/**
 * Placeholder plugins from the Studio design. Nothing can be installed yet;
 * swap this module for a real catalogue when there is one. Each use is
 * marked `Mock:`.
 */

export const pluginCategories = ["Menu bar", "Windows", "Integrations", "Focus"] as const;
export type PluginCategory = (typeof pluginCategories)[number];

/** The author of the plugins Macarchy makes itself, shown with the brand mark. */
export const officialAuthor = "Macarchy";

export interface Plugin {
  id: string;
  name: string;
  icon: LucideIcon;
  category: PluginCategory;
  author: string;
  /** One line, for a small card. */
  detail: string;
  /** A paragraph, for a large card and the dialog. */
  about: string;
  /** What installing it would add, listed in the dialog. */
  brings: readonly string[];
  /** The plugin's own hue, for its tile, preview wash and accents. */
  colour: string;
}

export const plugins: readonly Plugin[] = [
  {
    id: "media",
    name: "Now playing",
    icon: Music,
    category: "Menu bar",
    author: "Macarchy",
    detail: "Track and controls for Music and Spotify in the bar.",
    about:
      "Shows the current track from Music or Spotify. Click to play, pause or skip, and hover for the artwork.",
    brings: ["Menu bar item", "Play, pause and skip shortcuts", "Artwork popup"],
    colour: "#ec4899",
  },
  {
    id: "weather",
    name: "Weather",
    icon: CloudSun,
    category: "Menu bar",
    author: "Macarchy",
    detail: "Current conditions and a three-hour outlook.",
    about:
      "Temperature and conditions where you are, refreshed every 15 minutes. Click it for the next three hours.",
    brings: ["Menu bar item", "Hourly outlook popup", "Location permission"],
    colour: "#0ea5e9",
  },
  {
    id: "brew",
    name: "Homebrew updates",
    icon: Beer,
    category: "Menu bar",
    author: "@oskar",
    detail: "Counts outdated formulae and upgrades them in one click.",
    about:
      "Checks Homebrew once an hour and shows how many formulae and casks are out of date. Upgrade everything, or pick what to skip.",
    brings: ["Menu bar item", "Hourly background check", "Upgrade from the popup"],
    colour: "#f59e0b",
  },
  {
    id: "stack",
    name: "Window stacks",
    icon: Layers,
    category: "Windows",
    author: "@mira",
    detail: "Group windows into tabs inside one tile.",
    about:
      "Stack several windows in a single tile and switch between them like browser tabs. Works with every yabai layout.",
    brings: ["Layout mode", "Tab strip on stacked tiles", "Next and previous tab shortcuts"],
    colour: "#6366f1",
  },
  {
    id: "keys",
    name: "Key overlay",
    icon: Keyboard,
    category: "Windows",
    author: "@tobyk",
    detail: "Shows the shortcuts for the focused app while you hold Option.",
    about:
      "Hold Option for a moment to see a cheat sheet for the app in front, including your own Macarchy shortcuts.",
    brings: ["Overlay", "Cheat sheets for 40 popular apps", "Accessibility permission"],
    colour: "#64748b",
  },
  {
    id: "scratch",
    name: "Scratchpad",
    icon: SquareTerminal,
    category: "Windows",
    author: "Macarchy",
    detail: "A floating terminal that drops down with one shortcut.",
    about:
      "Keeps a terminal floating above your tiles on every desktop. Press the shortcut to show or hide it without losing your place.",
    brings: ["Floating window rule", "Show and hide shortcut", "Remembers size and position"],
    colour: "#10b981",
  },
  {
    id: "pr",
    name: "Pull requests",
    icon: GitPullRequest,
    category: "Integrations",
    author: "@mira",
    detail: "Review requests waiting for you, counted in the bar.",
    about:
      "Counts the GitHub pull requests that are waiting on your review. Click one to open it in your browser.",
    brings: ["Menu bar item", "Sign-in with a GitHub token", "Open a review in one click"],
    colour: "#8b5cf6",
  },
  {
    id: "linear",
    name: "Linear issues",
    icon: ListTodo,
    category: "Integrations",
    author: "@tobyk",
    detail: "Your assigned issues, with the active one in the bar.",
    about:
      "Shows the issue you are working on and lets you switch to another from the command palette.",
    brings: ["Menu bar item", "Issue picker in the command palette", "Linear API key"],
    colour: "#3b82f6",
  },
  {
    id: "meetings",
    name: "Meeting join",
    icon: CalendarClock,
    category: "Integrations",
    author: "Macarchy",
    detail: "Your next meeting, with a join button when it starts.",
    about:
      "Reads your calendar and shows the next meeting. A join button appears a minute before it starts.",
    brings: ["Menu bar item", "Join links for Zoom, Meet and Teams", "Calendar permission"],
    colour: "#14b8a6",
  },
  {
    id: "slack",
    name: "Slack status",
    icon: MessageSquare,
    category: "Integrations",
    author: "@oskar",
    detail: "Sets your Slack status from the desktop you are on.",
    about:
      "Pick a status for each desktop, such as Focusing on your editor's desktop, and it updates as you move around.",
    brings: ["Rule set", "Status per desktop", "Slack sign-in"],
    colour: "#a8458f",
  },
  {
    id: "pomodoro",
    name: "Focus timer",
    icon: Timer,
    category: "Focus",
    author: "Macarchy",
    detail: "25 minute sessions that hide noisy desktops.",
    about:
      "Starts a 25 minute session and hides the desktops you mark as noisy until it ends. Breaks are announced in the bar.",
    brings: ["Menu bar item", "Rule set", "Start and stop shortcut"],
    colour: "#f97316",
  },
  {
    id: "quiet",
    name: "Quiet hours",
    icon: BellOff,
    category: "Focus",
    author: "Macarchy",
    detail: "Mutes notifications while a fullscreen window has focus.",
    about: "Turns on Do Not Disturb when a window goes fullscreen, and on a schedule you choose.",
    brings: ["Rule set", "Schedule by time of day"],
    colour: "#f43f5e",
  },
];

/** Shown large above the categories while nothing is filtered. */
export const featuredPlugins: readonly string[] = ["media", "stack"];
