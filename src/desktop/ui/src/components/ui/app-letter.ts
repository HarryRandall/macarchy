/** A stable hue for an app's name, so its lettered tile keeps one colour everywhere. */
export function letterHue(name: string): number {
  return [...name].reduce((hue, char) => (hue * 31 + (char.codePointAt(0) ?? 0)) % 360, 7);
}

/** The letter drawn on an app's tile: its first character, capitalised. */
export function appLetter(name: string): string {
  const [first] = [...name.trim()];
  return first ? first.toLocaleUpperCase() : "?";
}
