import "~/styles/index.css";

import { Moon, Sun } from "lucide-react";
import { type ComponentType, StrictMode, Suspense, lazy, useEffect, useState } from "react";
import { createRoot } from "react-dom/client";

import type { Appearance, OptionProps } from "./data";

/** Each direction lives in its own folder and draws the whole window itself. */
const directions: {
  id: string;
  name: string;
  blurb: string;
  load: () => Promise<{ default: ComponentType<OptionProps> }>;
}[] = [
  {
    id: "studio",
    name: "Studio",
    blurb: "The main direction: a modern web app",
    load: () => import("./studio/studio"),
  },
  {
    id: "tiling",
    name: "Tiling (feature)",
    blurb: "Kept as a feature: an optional keyboard-first, terminal-style mode",
    load: () => import("./tiling/tiling"),
  },
];

const loaded = Object.fromEntries(directions.map((d) => [d.id, lazy(d.load)]));

function readHash() {
  const id = location.hash.slice(1);
  return directions.some((d) => d.id === id) ? id : directions[0]!.id;
}

function Options() {
  const [current, setCurrent] = useState(readHash);
  const [appearance, setAppearance] = useState<Appearance>(
    matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light",
  );
  useEffect(() => {
    location.hash = current;
  }, [current]);
  const Direction = loaded[current]!;
  const dark = appearance === "dark";

  return (
    <div
      className={
        dark ? "min-h-screen bg-[#0e0e10] text-white" : "min-h-screen bg-[#e7e7ea] text-black"
      }
    >
      <header className="sticky top-0 z-50 flex flex-wrap items-center gap-2 border-b border-current/10 px-4 py-2.5 backdrop-blur-xl">
        <a href="../" className="mr-2 text-[13px] font-semibold opacity-60 hover:opacity-100">
          ← Components
        </a>
        <div className="flex flex-wrap gap-1 rounded-full bg-current/[0.06] p-1">
          {directions.map((d) => (
            <button
              key={d.id}
              type="button"
              title={d.blurb}
              onClick={() => setCurrent(d.id)}
              className={
                "rounded-full px-3 py-1 text-[13px] font-medium transition " +
                (d.id === current
                  ? dark
                    ? "bg-white text-black"
                    : "bg-black text-white"
                  : "opacity-70 hover:opacity-100")
              }
            >
              {d.name}
            </button>
          ))}
        </div>
        <span className="text-[12px] opacity-50">
          {directions.find((d) => d.id === current)!.blurb}
        </span>
        <button
          type="button"
          onClick={() => setAppearance(dark ? "light" : "dark")}
          className="ml-auto flex items-center gap-1.5 rounded-full bg-current/[0.06] px-3 py-1 text-[13px]"
        >
          {dark ? <Sun size={14} /> : <Moon size={14} />}
          {dark ? "Light" : "Dark"}
        </button>
      </header>
      <main className="flex justify-center p-6">
        <Suspense fallback={<p className="opacity-50">Loading…</p>}>
          <Direction key={current} appearance={appearance} onAppearanceChange={setAppearance} />
        </Suspense>
      </main>
    </div>
  );
}

createRoot(document.getElementById("root")!).render(
  <StrictMode>
    <Options />
  </StrictMode>,
);
