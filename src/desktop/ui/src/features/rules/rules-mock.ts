/**
 * Workspace assignments from the Studio design. Macarchy cannot send an app
 * to a desktop when it opens yet, so these stand in until it can, and edits
 * stay on the page. Each use is marked `Mock:`.
 */

export interface Assignment {
  id: number;
  app: string;
  /** The desktop's number, "1" to "9". */
  workspace: string;
  enabled: boolean;
}

/** Names for desktops 1 to 9; yabai only numbers them. */
export const workspaceNames: Readonly<Record<string, string>> = {
  "1": "Terminal",
  "2": "Browser",
  "3": "Chat",
  "4": "Code",
  "5": "Design",
  "6": "Notes",
  "7": "Mail",
  "8": "Calls",
  "9": "Music",
};

export const workspaces: readonly string[] = Object.keys(workspaceNames);

export const workspaceName = (workspace: string) =>
  workspaceNames[workspace] ?? `Workspace ${workspace}`;

export const initialAssignments: readonly Assignment[] = [
  { id: 1, app: "Ghostty", workspace: "1", enabled: true },
  { id: 2, app: "Slack", workspace: "3", enabled: true },
  { id: 3, app: "Spotify", workspace: "9", enabled: false },
];
