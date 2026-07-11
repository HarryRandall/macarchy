export type NamedTheme = {
  name: string;
};

const LEGACY_THEME_ALIASES: Record<string, string> = {
  lumon: "cool-blue",
  turbonite: "amber-metal",
};

export function normaliseLegacyThemeName(name: string, themes: NamedTheme[]): string {
  const current = name.trim();

  // Original theme packs are still valid. Only use the newer name when the
  // recorded pack is no longer installed.
  if (themes.some((theme) => theme.name === current)) return current;

  const replacement = LEGACY_THEME_ALIASES[current];
  if (replacement && themes.some((theme) => theme.name === replacement)) return replacement;
  return current;
}
