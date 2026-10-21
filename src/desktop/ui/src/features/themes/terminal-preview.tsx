import { Image } from "lucide-react";
import type { ThemeDetail, ThemeTerminal } from "~/bridge/protocol";
import { cssColour, parseColour } from "~/lib/colour";

const entries = [
  ["drwxr-xr-x", "   -", "20 Sep 00:24", ".build", 4],
  [".rw-r--r--", " 247", "19 Sep 22:26", ".editorconfig", 5],
  ["drwxr-xr-x", "   -", "20 Sep 00:09", ".git", 4],
  [".rw-r--r--", "1.1k", "19 Sep 20:05", ".swift-format", 5],
  [".rw-r--r--", "2.5k", "19 Sep 22:26", "CONTRIBUTING.md", 3],
] as const;

export function TerminalPreview({
  palette,
  name,
  accent,
}: {
  palette: ThemeTerminal;
  name: string;
  accent: string | null;
}) {
  const border = parseColour(accent);
  const colour = (slot: number) => palette.ansi[slot] ?? palette.foreground;
  return (
    <div
      role="img"
      aria-label={`Terminal preview for ${name}`}
      className="overflow-hidden rounded-card border font-mono text-[10px] shadow-lg"
      style={{
        background: palette.background,
        color: palette.foreground,
        borderColor: border ? cssColour(border) : colour(4),
      }}
    >
      <div aria-hidden className="flex items-center gap-1.5 bg-black/35 px-3 py-2">
        <span className="size-2 rounded-full bg-[#ff5f56]" />
        <span className="size-2 rounded-full bg-[#ffbd2e]" />
        <span className="size-2 rounded-full bg-[#27c93f]" />
        <span className="ml-auto text-white/45">{name} · zsh</span>
      </div>
      <div aria-hidden className="overflow-hidden px-3 py-2 leading-4 whitespace-pre">
        <div>
          <span style={{ color: colour(3) }}>{name}</span>
          <span style={{ color: colour(5) }}> ❯ </span>ls -la
        </div>
        {entries.map(([mode, size, date, file, slot]) => (
          <div key={file}>
            {[...mode].map((bit, index) => (
              <span
                key={index}
                style={{
                  color: colour(
                    ({ d: 4, l: 6, r: 3, w: 1, x: 2 } as Record<string, number>)[bit] ?? 8,
                  ),
                }}
              >
                {bit}
              </span>
            ))}
            <span style={{ color: colour(2) }}> {size} </span>
            <span style={{ color: colour(3) }}>you </span>
            <span style={{ color: colour(8) }}>{date} </span>
            <span style={{ color: colour(slot) }}>{file}</span>
          </div>
        ))}
        <div>
          <span style={{ color: colour(3) }}>{name}</span>
          <span style={{ color: colour(5) }}> ❯ </span>
          <span style={{ background: palette.cursor }}> </span>
        </div>
      </div>
    </div>
  );
}

export function ThemeArtwork({ theme }: { theme: ThemeDetail }) {
  const accent = parseColour(theme.values.borderActive);
  return (
    <div
      role="img"
      aria-label="Wallpaper preview"
      className="relative grid size-full place-items-center overflow-hidden bg-well"
      style={{
        background: `linear-gradient(135deg, ${theme.terminal?.background ?? "#141414"}, ${accent ? cssColour({ ...accent, a: 89 }) : "#0a84ff59"})`,
      }}
    >
      {theme.summary.preview ? (
        <img alt="" src={theme.summary.preview} className="absolute size-full object-cover" />
      ) : (
        <Image aria-hidden className="size-6 text-fg-secondary" />
      )}
    </div>
  );
}
