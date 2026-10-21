/**
 * A typed hex as `#rrggbb` in lower case, or null while it is incomplete or
 * wrong. Accepts a missing `#` and the three-digit shorthand.
 */
export function readHexDraft(text: string): string | null {
  const bare = text.trim().replace(/^#/, "");
  if (/^[0-9a-f]{6}$/i.test(bare)) return `#${bare.toLowerCase()}`;
  if (/^[0-9a-f]{3}$/i.test(bare)) {
    return `#${[...bare.toLowerCase()].map((digit) => digit + digit).join("")}`;
  }
  return null;
}

/** Whether two colours written as hex name the same colour. */
export function sameHex(a: string, b: string) {
  return readHexDraft(a) !== null && readHexDraft(a) === readHexDraft(b);
}
