import { afterEach, describe, expect, it, vi } from "vitest";

import { copyText } from "./clipboard";

afterEach(() => vi.unstubAllGlobals());

describe("copyText", () => {
  it("uses the Clipboard API when it is there", async () => {
    const writeText = vi.fn<(text: string) => Promise<void>>(() => Promise.resolve());
    vi.stubGlobal("navigator", { clipboard: { writeText } });
    await copyText("brew install yabai");
    expect(writeText).toHaveBeenCalledWith("brew install yabai");
  });

  it("rejects when nothing can write the clipboard", async () => {
    vi.stubGlobal("navigator", {
      clipboard: { writeText: () => Promise.reject(new Error("not allowed")) },
    });
    await expect(copyText("x")).rejects.toThrow("could not be written");
  });
});
