import { describe, expect, it } from "vitest";

import type { WidgetInfo } from "~/bridge/protocol";

import { type BarItem, newWidgetItem, widgetCounts } from "./menu-bar-items";
import {
  clickFor,
  clickMode,
  clickOf,
  fill,
  humanise,
  lookOf,
  moveRow,
  retype,
  sampleLines,
  sampleText,
  updateText,
  widgetProblem,
  withClick,
  withLook,
  withSetting,
} from "./widget-model";

const clock: WidgetInfo = {
  id: "clock",
  name: "Clock",
  version: "1.0.0",
  origin: "builtIn",
  scripted: false,
  folder: "/widgets/clock",
  files: ["widget.json"],
  manifest: "{}",
  label: "{date}",
  settings: [
    { key: "seconds", type: "toggle", label: "Seconds", default: false },
    { key: "order", type: "choice", label: "Order", options: ["day-month", "month-day"] },
  ],
  style: { box: "none", size: 13 },
  click: { dropdown: [{ type: "divider" }] },
  samples: { widest: "Wed 30 Sep 12:59 PM", unavailable: "--" },
};

const item = (patch: Partial<BarItem> = {}): BarItem => ({
  ...newWidgetItem(clock, "right", []),
  ...patch,
});

describe("widget items", () => {
  it("are numbered when the bar already shows the widget", () => {
    const first = newWidgetItem(clock, "right", []);
    const second = newWidgetItem(clock, "left", [first]);
    expect([first.id, second.id]).toEqual(["macarchy.clock", "macarchy.clock-2"]);
    expect(widgetCounts([first, second]).get("clock")).toBe(2);
  });

  it("keep only settings that differ from the widget's defaults", () => {
    const seconds = clock.settings[0]!;
    const on = withSetting(item(), seconds, true);
    expect(on.settings).toEqual({ seconds: true });
    expect(withSetting(item(on), seconds, false).settings).toEqual({});
  });

  it("keep only look changes that differ from the widget's own", () => {
    const filled = withLook(item(), clock, { box: "fill" });
    expect(filled.style).toEqual({ box: "fill" });
    expect(lookOf(item(filled), clock)).toEqual({ box: "fill", size: 13 });
    expect(withLook(item(filled), clock, { box: "none" }).style).toBeNull();
  });

  it("take the widget's click until they have their own", () => {
    expect(clickMode(clickOf(item(), clock))).toBe("dropdown");
    const opens = withClick(clock, clickFor("app", clickOf(item(), clock)));
    expect(opens.click).toEqual({ open: "" });
    expect(clickMode(clickOf(item(opens), clock))).toBe("app");
    expect(withClick(clock, clickFor("none", null)).click).toEqual({});
    expect(clickMode(clickOf(item({ click: {} }), clock))).toBe("none");
    expect(withClick(clock, { dropdown: [{ type: "divider" }] }).click).toBeNull();
  });

  it("cannot be applied with an empty app, command or dropdown", () => {
    expect(widgetProblem(item({ click: { open: " " } }), clock)).toMatch(/app to open/);
    expect(widgetProblem(item({ click: { run: "" } }), clock)).toMatch(/command/);
    expect(widgetProblem(item({ click: { dropdown: [] } }), clock)).toMatch(/row/);
    expect(widgetProblem(item(), null)).toMatch(/no longer here/);
    expect(widgetProblem(item(), clock)).toBeNull();
  });
});

describe("samples", () => {
  it("show what the bar has, the widest or the unavailable text", () => {
    expect(sampleText(item({ reading: "Fri 23 Oct" }), clock, "live")).toBe("Fri 23 Oct");
    expect(sampleText(item(), clock, "live")).toBe("Fri 23 Oct 3:41 PM");
    expect(sampleText(item(), clock, "widest")).toBe("Wed 30 Sep 12:59 PM");
    expect(sampleText(item(), clock, "unavailable")).toBe("--");
  });

  it("split a two-line widget's text into its lines", () => {
    expect(sampleLines("12.0%\n52.4°", { lines: 2 })).toEqual(["12.0%", "52.4°"]);
    expect(sampleLines("12.0%", {})).toBeNull();
  });

  it("fill readings the preview knows and leave the rest as written", () => {
    expect(fill("{weekday.long} {day} {mystery}")).toBe("Friday 23 {mystery}");
    expect(fill("{time:Europe/London}")).toBe("5:41 AM");
  });
});

describe("words", () => {
  it("say when a widget updates", () => {
    expect(updateText("minute")).toBe("On the minute");
    expect(updateText("2s")).toBe("Every 2 seconds");
    expect(updateText("1m")).toBe("Every minute");
    expect(updateText(undefined)).toBe("Only when clicked");
  });

  it("make ids readable", () => {
    expect(humanise("day-month")).toBe("Day month");
  });
});

describe("dropdown rows", () => {
  it("move within the list, and stop at either end", () => {
    const rows = [{ type: "heading" as const, label: "A" }, { type: "divider" as const }];
    expect(moveRow(rows, 0, 1).map((row) => row.type)).toEqual(["divider", "heading"]);
    expect(moveRow(rows, 0, -1)).toBe(rows);
  });

  it("keep their label when they change type, and pick a setting that fits", () => {
    const toggle = retype({ type: "text", label: "Mine" }, "toggle", clock.settings);
    expect(toggle).toEqual({ type: "toggle", label: "Mine", setting: "seconds" });
    expect(retype(toggle, "divider", clock.settings)).toEqual({ type: "divider" });
  });
});
