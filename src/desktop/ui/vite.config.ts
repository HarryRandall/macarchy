import { resolve } from "node:path";

import tailwindcss from "@tailwindcss/vite";
import react from "@vitejs/plugin-react";
import { defineConfig } from "vitest/config";

export default defineConfig({
  // The host serves dist/ from a custom scheme, so asset URLs must be relative.
  base: "./",
  plugins: [react(), tailwindcss()],
  resolve: {
    alias: { "~": resolve(import.meta.dirname, "src") },
  },
  server: {
    port: 5173,
    strictPort: true,
  },
  build: {
    outDir: "dist",
    emptyOutDir: true,
    // WKWebView on macOS 26 is Safari 26; nothing older loads these pages.
    target: "safari18",
    // Vite 8 bundles with Rolldown; `rollupOptions` is its deprecated alias.
    rolldownOptions: {
      input: {
        settings: resolve(import.meta.dirname, "settings.html"),
        switcher: resolve(import.meta.dirname, "switcher.html"),
      },
      // One named chunk for what both pages use (React, the bridge, styles),
      // so nothing settings-only rides along with the switcher.
      output: { codeSplitting: { groups: [{ name: "shared", minShareCount: 2 }] } },
    },
  },
  test: {
    include: ["src/**/*.test.ts", "lint/**/*.test.ts"],
    environment: "node",
  },
});
