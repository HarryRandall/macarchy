import { describe, expect, it } from "vitest";

import { readHexDraft, sameHex } from "./hex";

describe("readHexDraft", () => {
  it("reads six digits with or without the hash", () => {
    expect(readHexDraft("#7C6CF2")).toBe("#7c6cf2");
    expect(readHexDraft(" 7c6cf2 ")).toBe("#7c6cf2");
  });

  it("expands the three-digit shorthand", () => {
    expect(readHexDraft("#fA0")).toBe("#ffaa00");
  });

  it("rejects partial and malformed input", () => {
    expect(readHexDraft("")).toBeNull();
    expect(readHexDraft("#7c6c")).toBeNull();
    expect(readHexDraft("#7c6cf2ff")).toBeNull();
    expect(readHexDraft("#gggggg")).toBeNull();
  });
});

describe("sameHex", () => {
  it("ignores case, the hash and shorthand", () => {
    expect(sameHex("#FFAA00", "fa0")).toBe(true);
    expect(sameHex("#ffaa00", "#ffaa01")).toBe(false);
  });

  it("never matches unreadable values", () => {
    expect(sameHex("nope", "nope")).toBe(false);
  });
});
