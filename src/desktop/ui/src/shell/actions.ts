import {
  Download,
  FolderOpen,
  Info,
  Keyboard,
  type LucideIcon,
  Power,
  RotateCw,
  ScrollText,
  Sparkles,
} from "lucide-react";

/** What the brand menu and the command palette can both do. */
export type ShellAction =
  "updates" | "folder" | "reload" | "logs" | "changelog" | "shortcuts" | "about" | "quit";

export const shellActions: Record<ShellAction, { label: string; icon: LucideIcon; keys?: string }> =
  {
    updates: { label: "Check for updates", icon: Download },
    folder: { label: "Open config folder", icon: FolderOpen, keys: "⇧⌘O" },
    reload: { label: "Reload everything", icon: RotateCw, keys: "⇧⌘R" },
    logs: { label: "Show logs", icon: ScrollText, keys: "⇧⌘L" },
    changelog: { label: "What's new", icon: Sparkles },
    shortcuts: { label: "Keyboard shortcuts", icon: Keyboard, keys: "⌘/" },
    about: { label: "About Macarchy", icon: Info },
    quit: { label: "Quit Macarchy", icon: Power, keys: "⌘Q" },
  };
