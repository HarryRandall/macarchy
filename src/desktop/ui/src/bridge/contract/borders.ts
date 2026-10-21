export interface BorderAppearance {
  width: number;
  visible: boolean;
  excludedApps: string[];
  radius: number | null;
  activeColour: string | null;
  inactiveColour: string | null;
}

export interface BordersState {
  appearance: BorderAppearance;
  applicationIcons: Record<string, string>;
  theme: string | null;
  defaults: BorderAppearance | null;
  unavailableReason: string | null;
  wallpaper: string | null;
}

export interface BordersMethods {
  "borders.getState": { params: Record<string, never>; result: BordersState };
  "borders.apply": { params: { appearance: BorderAppearance; theme: string }; result: null };
  "borders.pickApplication": {
    params: Record<string, never>;
    result: { name: string; icon: string | null } | null;
  };
}

export type BordersEvent = { type: "borders.changed"; state: BordersState };
