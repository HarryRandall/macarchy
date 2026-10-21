import { AppWindow, CircleQuestionMark, Keyboard, Palette, PanelTop } from "lucide-react";

export const summaryMax = 80;
export const shotsMax = 6;

export const areas = [
  { id: "menu-bar", label: "Menu bar", icon: PanelTop },
  { id: "windows", label: "Windows", icon: AppWindow },
  { id: "shortcuts", label: "Shortcuts", icon: Keyboard },
  { id: "themes", label: "Themes", icon: Palette },
  { id: "other", label: "Other", icon: CircleQuestionMark },
] as const;
export type Area = (typeof areas)[number]["id"];

export interface KnownIssue {
  area: Area;
  title: string;
  detail: string;
}

export const knownIssues: readonly KnownIssue[] = [
  {
    area: "shortcuts",
    title: "Shortcuts stop working",
    detail: "Secure Keyboard Entry in another app blocks skhd. Setup health names the app.",
  },
  {
    area: "windows",
    title: "Desktop switching does nothing",
    detail: "Needs yabai 7.1.25 or newer. Check Setup health for the installed version.",
  },
];

/** Known issues for an area; Other lists them all, as the person has not narrowed it down. */
export function issuesFor(area: Area) {
  return area === "other" ? knownIssues : knownIssues.filter((issue) => issue.area === area);
}

const stepsTemplate = "Steps to reproduce:\n1. \n2. \n3. \n\nExpected:\n";

/** Appends a steps outline to a description, once. */
export function withSteps(text: string) {
  if (text.includes("Steps to reproduce:")) return text;
  const kept = text.trimEnd();
  return kept ? `${kept}\n\n${stepsTemplate}` : stepsTemplate;
}

export function formatBytes(bytes: number) {
  const kb = bytes / 1024;
  return kb < 1000 ? `${Math.max(1, Math.round(kb))} KB` : `${(kb / 1024).toFixed(1)} MB`;
}
