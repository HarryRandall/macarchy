import type { CustomWindowRule } from "~/bridge/protocol";

/** Custom-scheme WebKit pages can use random bytes without requiring randomUUID. */
export function createRuleDraft(app = "", title = ""): CustomWindowRule {
  const bytes = crypto.getRandomValues(new Uint8Array(16));
  const hex = Array.from(bytes, (byte, index) => {
    const value = index === 6 ? (byte & 15) | 64 : index === 8 ? (byte & 63) | 128 : byte;
    return value.toString(16).padStart(2, "0");
  }).join("");
  const id = [
    hex.slice(0, 8),
    hex.slice(8, 12),
    hex.slice(12, 16),
    hex.slice(16, 20),
    hex.slice(20),
  ].join("-");
  return { id, app, title };
}
