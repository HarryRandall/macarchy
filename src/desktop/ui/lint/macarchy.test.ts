import { spawnSync } from "node:child_process";
import { mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

import { afterAll, beforeAll, describe, expect, it } from "vitest";

const lintFolder = dirname(fileURLToPath(import.meta.url));
const oxlint = join(lintFolder, "..", "node_modules", ".bin", "oxlint");
const plugin = join(lintFolder, "macarchy.js");

interface Case {
  rule: string;
  name: string;
  code: string;
  /** Relative to the case's folder; the extension picks the parser. */
  file?: string;
  errors: number;
  message?: RegExp;
}

interface Diagnostic {
  code?: string;
  message: string;
  filename?: string;
}

const suppression = "require-suppression-reason";
const title = "no-native-title-tooltip";
const gutter = "require-centered-scroll-gutter";
const has = "no-unscoped-has";
const resize = "no-raw-resize-observer";
const comments = "no-low-value-comments";
const timeouts = "no-test-timeout-or-unreasoned-skip";
const clock = "no-wall-clock-in-tests";
const waits = "no-real-time-wait-in-tests";
const polling = "no-polling-loop-in-tests";
const loops = "no-test-in-loop";
const dom = "no-dom-test-environment";
const ruleNames = [
  suppression,
  title,
  gutter,
  has,
  resize,
  comments,
  timeouts,
  clock,
  waits,
  polling,
  loops,
  dom,
];

const pollingHelpers = `declare function done(): boolean;
declare function tick(): Promise<void>;
`;
// Built at runtime so Vitest does not take this file's own environment from it.
const pragma = ["@vitest", "environment"].join("-");

const cases: Case[] = [
  {
    rule: suppression,
    name: "allows a reason after two dashes",
    code: `// oxlint-disable-next-line no-console -- printing is the point\nconsole.log(1);\n`,
    errors: 0,
  },
  {
    rule: suppression,
    name: "allows a reason on the line above",
    code: `// Printing is the point here.\n// oxlint-disable-next-line no-console\nconsole.log(1);\n`,
    errors: 0,
  },
  {
    rule: suppression,
    name: "allows @ts-expect-error with a reason",
    code: `// @ts-expect-error -- the fixture passes a number on purpose\nexport const x: string = 1;\n`,
    errors: 0,
  },
  {
    rule: suppression,
    name: "allows a JSX comment with a reason",
    code: `export const a = (
  <div>
    {/* oxlint-disable-next-line jsx-a11y/no-autofocus -- the dialog's first field */}
    <input autoFocus />
  </div>
);
`,
    errors: 0,
  },
  {
    rule: suppression,
    name: "allows a reason that starts with global or eslint",
    code: `// global state leaks between renders, so log it here.
// oxlint-disable-next-line no-console
console.log(1);
/* eslint warns about this, but the output is the point */
// oxlint-disable-next-line no-console
console.log(2);
`,
    errors: 0,
  },
  {
    rule: suppression,
    name: "does not take a globals directive as the reason",
    code: `/* global reporter: writable */\n// oxlint-disable-next-line no-console\nconsole.log(1);\n`,
    errors: 1,
  },
  {
    rule: suppression,
    name: "does not take a rule configuration as the reason",
    code: `/* eslint no-console: "off" */\n// oxlint-disable-next-line no-alert\nalert(1);\n`,
    errors: 1,
  },
  {
    rule: suppression,
    name: "reports a disable comment without a reason",
    code: `// oxlint-disable-next-line no-console\nconsole.log(1);\n`,
    errors: 1,
  },
  {
    rule: suppression,
    name: "reports a file-wide eslint-disable without a reason",
    code: `/* eslint-disable no-console */\nconsole.log(1);\n`,
    errors: 1,
  },
  {
    rule: suppression,
    name: "reports @ts-expect-error without a reason",
    code: `// @ts-expect-error\nexport const x: string = 1;\n`,
    errors: 1,
  },
  {
    rule: suppression,
    name: "reports an empty reason",
    code: `console.log(1); // oxlint-disable-line no-console --\n`,
    errors: 1,
  },
  {
    rule: suppression,
    name: "reports @ts-ignore even with a reason",
    code: `// The fixture is wrong on purpose.\n// @ts-ignore\nexport const x: string = 1;\n`,
    errors: 1,
    message: /@ts-expect-error/,
  },

  {
    rule: title,
    name: "allows title as the accessible name of abbr and iframe",
    code: `export const a = (
  <p>
    <abbr title="Coordinated Universal Time">UTC</abbr>
    <iframe title="Preview" src="about:blank" />
  </p>
);
`,
    errors: 0,
  },
  {
    rule: title,
    name: "allows a title prop on a component",
    code: `declare function Row(props: { title: string }): null;\nexport const a = <Row title="Width" />;\n`,
    errors: 0,
  },
  {
    rule: title,
    name: "allows an svg title element",
    code: `export const a = (\n  <svg>\n    <title>Mark</title>\n  </svg>\n);\n`,
    errors: 0,
  },
  {
    rule: title,
    name: "reports title on a button",
    code: `export const a = <button title="Copy">Copy</button>;\n`,
    errors: 1,
    message: /components\/ui\/tooltip/,
  },
  {
    rule: title,
    name: "reports an expression title on a span",
    code: `declare const label: string;\nexport const a = <span title={label}>x</span>;\n`,
    errors: 1,
  },

  {
    rule: gutter,
    name: "allows a stable gutter",
    code: `export const a = (
  <main className="overflow-y-auto [scrollbar-gutter:stable_both-edges]">
    <div className="mx-auto max-w-2xl" />
  </main>
);
`,
    errors: 0,
  },
  {
    rule: gutter,
    name: "allows a hidden scrollbar read through cn",
    code: `declare function cn(...classes: string[]): string;
export const a = (
  <nav className={cn("overflow-y-auto", "[scrollbar-width:none]")}>
    <div className="mx-auto" />
  </nav>
);
`,
    errors: 0,
  },
  {
    rule: gutter,
    name: "allows a scroll area that does not centre",
    code: `export const a = (
  <div className="overflow-y-auto">
    <div className="flex" />
  </div>
);
`,
    errors: 0,
  },
  {
    rule: gutter,
    name: "allows centring two wrappers down",
    code: `export const a = (
  <div className="overflow-auto">
    <section>
      <div>
        <p className="mx-auto" />
      </div>
    </section>
  </div>
);
`,
    errors: 0,
  },
  {
    rule: gutter,
    name: "reports a centred child",
    code: `export const a = (
  <main className="min-h-0 overflow-y-auto">
    <div className="mx-auto max-w-2xl" />
  </main>
);
`,
    errors: 1,
  },
  {
    rule: gutter,
    name: "reports centring through one wrapper, from a template literal",
    code: `export const a = (
  <div className={\`overflow-y-scroll\`}>
    <section>
      <div className="mx-auto" />
    </section>
  </div>
);
`,
    errors: 1,
  },
  {
    rule: gutter,
    name: "reports a variant read through clsx",
    code: `declare function clsx(...classes: string[]): string;
export const a = (
  <div className={clsx("flex", "md:overflow-auto")}>
    <div className="mx-auto" />
  </div>
);
`,
    errors: 1,
  },

  {
    rule: gutter,
    name: "allows a gutter switched on through a cn object",
    code: `declare function cn(...classes: unknown[]): string;
declare const scrolls: boolean;
export const a = (
  <div className={cn("overflow-y-auto", { "[scrollbar-gutter:stable_both-edges]": scrolls })}>
    <div className="mx-auto" />
  </div>
);
`,
    errors: 0,
  },
  {
    rule: gutter,
    name: "ignores a class cut by a template expression",
    code: `declare const axis: string;
export const a = (
  <div className={\`flex overflow-\${axis}-auto\`}>
    <div className="mx-auto" />
  </div>
);
`,
    errors: 0,
  },
  {
    rule: gutter,
    name: "reports a template literal with an expression",
    code: `declare const extra: string;
export const a = (
  <div className={\`overflow-y-auto \${extra}\`}>
    <div className="mx-auto" />
  </div>
);
`,
    errors: 1,
  },
  {
    rule: gutter,
    name: "reports a cn object key",
    code: `declare function cn(...classes: unknown[]): string;
declare const scrolls: boolean;
export const a = (
  <div className={cn("flex", { "overflow-y-auto": scrolls })}>
    <div className="mx-auto" />
  </div>
);
`,
    errors: 1,
  },
  {
    rule: gutter,
    name: "reports an array argument to clsx",
    code: `declare function clsx(...classes: unknown[]): string;
export const a = (
  <div className={clsx(["flex", "overflow-auto"])}>
    <div className="mx-auto" />
  </div>
);
`,
    errors: 1,
  },
  {
    rule: gutter,
    name: "reports a class read through twMerge",
    code: `declare function twMerge(...classes: string[]): string;
declare const extra: string;
export const a = (
  <div className={twMerge("overflow-y-auto", extra)}>
    <div className="mx-auto" />
  </div>
);
`,
    errors: 1,
  },
  {
    rule: gutter,
    name: "reports a fallback behind ?? and a type assertion",
    code: `declare const custom: string | undefined;
export const a = (
  <div className={(custom ?? "overflow-y-auto") as string}>
    <div className="mx-auto" />
  </div>
);
`,
    errors: 1,
  },

  {
    rule: has,
    name: "allows a variant on the element itself",
    code: `export const a = "[&:has([data-open])]:bg-fill";\n`,
    errors: 0,
  },
  {
    rule: has,
    name: "allows the has-* variants",
    code: `export const a = "has-[input:checked]:ring group-has-[:focus]:opacity-100";\n`,
    errors: 0,
  },
  {
    rule: has,
    name: "allows a variant anchored to a class",
    code: `export const a = "[.card:has(img)_&]:p-0";\n`,
    errors: 0,
  },
  {
    rule: has,
    name: "reports the document root",
    code: `export const a = "[:root:has(dialog[open])_&]:overflow-hidden";\n`,
    errors: 1,
  },
  {
    rule: has,
    name: "reports a bare star",
    code: `export const a = "[*:has(:focus-visible)]:outline";\n`,
    errors: 1,
  },
  {
    rule: has,
    name: "reports nothing before :has in a template literal",
    code: `export const a = \`flex [:has(.x)]:p-2\`;\n`,
    errors: 1,
  },
  {
    rule: has,
    name: "reports the html element",
    code: `export const a = "[html:has(.menu)_&]:hidden";\n`,
    errors: 1,
  },
  {
    rule: has,
    name: "reports the body element",
    code: `export const a = "[body:has(dialog[open])_&]:overflow-hidden";\n`,
    errors: 1,
  },

  {
    rule: resize,
    name: "allows the observer in observe-resize",
    code: `export const observer = new ResizeObserver(() => {});\n`,
    file: "src/lib/observe-resize.ts",
    errors: 0,
  },
  {
    rule: resize,
    name: "allows a suppressed observer",
    code: `// oxlint-disable-next-line macarchy/no-raw-resize-observer -- reports native hit regions
export const observer = new ResizeObserver(() => {});
`,
    file: "src/shell/titlebar.ts",
    errors: 0,
  },
  {
    rule: resize,
    name: "reports an observer elsewhere",
    code: `export const observer = new ResizeObserver(() => {});\n`,
    file: "src/features/panel.ts",
    errors: 1,
  },
  {
    rule: resize,
    name: "reports an observer read off window",
    code: `export const observer = new window.ResizeObserver(() => {});\n`,
    file: "src/features/panel.ts",
    errors: 1,
  },

  {
    rule: comments,
    name: "allows a TODO with an issue link",
    code: `// TODO(https://github.com/example/macarchy/issues/12): drop once yabai 8 ships.
export const a = 1;
`,
    errors: 0,
  },
  {
    rule: comments,
    name: "allows directives",
    code: `// prettier-ignore
export const grid = [1, 0, 0, 1];
// #region Fixtures
export const b = 2;
// #endregion
`,
    errors: 0,
  },
  {
    rule: comments,
    name: "allows a comment that says why",
    code: `// The gap yabai leaves between tiled windows, in points.\nexport const windowGap = 8;\n`,
    errors: 0,
  },
  {
    rule: comments,
    name: "allows prose that mentions a call",
    code: `// Settles once, as load() does for every page.\nexport const a = 1;\n`,
    errors: 0,
  },
  {
    rule: comments,
    name: "allows a trailing comment above a declaration",
    code: `declare function readId(): string;
declare function load(id: string): unknown;
const id = readId(); // the user
export const user = load(id);
`,
    errors: 0,
  },
  {
    rule: comments,
    name: "reports a name repeated below a trailing comment",
    code: `export const id = "1"; // read once
// The user.
export const user = { id };
`,
    errors: 1,
  },
  {
    rule: comments,
    name: "reports a divider",
    code: `// ----------\nexport const a = 1;\n`,
    errors: 1,
  },
  {
    rule: comments,
    name: "reports a titled divider",
    code: `// ===== Helpers =====\nexport const a = 1;\n`,
    errors: 1,
  },
  {
    rule: comments,
    name: "reports a TODO without an issue",
    code: `// TODO: tidy this up\nexport const a = 1;\n`,
    errors: 1,
  },
  {
    rule: comments,
    name: "checks prose that starts with global",
    code: `// global TODO: share this cache\nexport const a = 1;\n`,
    errors: 1,
  },
  {
    rule: comments,
    name: "reports test narration",
    code: `// Act\nexport const a = 1;\n`,
    errors: 1,
  },
  {
    rule: comments,
    name: "reports commented-out code",
    code: `// const old = compute();\nexport const a = 1;\n`,
    errors: 1,
  },
  {
    rule: comments,
    name: "reports a comment that repeats the name",
    code: `// The window gap.\nexport const windowGap = 8;\n`,
    errors: 1,
  },
  {
    rule: comments,
    name: "reports a doc comment that repeats a function name",
    code: `/** Gets the theme name. */\nexport function themeName() {\n  return "";\n}\n`,
    errors: 1,
  },

  {
    rule: timeouts,
    name: "allows a skip explained above",
    code: `// Needs yabai 8, which CI does not have yet.\nit.skip("signals", () => {});\n`,
    errors: 0,
  },
  {
    rule: timeouts,
    name: "allows an expected failure explained on the same line",
    code: `it.fails("rejects a cycle", () => {}); // The cycle check is not written yet.\n`,
    errors: 0,
  },
  {
    rule: timeouts,
    name: "allows skipIf and runIf",
    code: `it.skipIf(process.platform !== "darwin")("reads defaults", () => {});
it.runIf(true)("runs", () => {});
`,
    errors: 0,
  },
  {
    rule: timeouts,
    name: "allows an each table",
    code: `it.each([1, 2])("handles %i", () => {});\n`,
    errors: 0,
  },
  {
    rule: timeouts,
    name: "reports a timeout argument",
    code: `it("waits", () => {}, 10_000);\n`,
    errors: 1,
  },
  {
    rule: timeouts,
    name: "reports a timeout option",
    code: `it("waits", { timeout: 10_000 }, () => {});\n`,
    errors: 1,
  },
  {
    rule: timeouts,
    name: "reports a timeout on describe",
    code: `describe("slow", { timeout: 1 }, () => {});\n`,
    errors: 1,
  },
  {
    rule: timeouts,
    name: "reports a timeout on an each table",
    code: `it.each([1])("handles %i", () => {}, 500);\n`,
    errors: 1,
  },
  {
    rule: timeouts,
    name: "reports a raised timeout in config",
    code: `vi.setConfig({ testTimeout: 20_000 });\n`,
    errors: 1,
  },
  {
    rule: timeouts,
    name: "reports an unexplained skip",
    code: `it.skip("flaky", () => {});\n`,
    errors: 1,
    message: /\.skip/,
  },
  {
    rule: timeouts,
    name: "reports an unexplained todo",
    code: `describe.todo("later");\n`,
    errors: 1,
  },

  {
    rule: clock,
    name: "allows the clock inside setSystemTime",
    code: `vi.setSystemTime(new Date());
vi.setSystemTime(Date.now() + 1000);
export const fixed = new Date("2026-10-21T09:00:00Z");
`,
    errors: 0,
  },
  {
    rule: clock,
    name: "allows reading the clock after fake timers pin it",
    code: `vi.useFakeTimers();
vi.setSystemTime(new Date(2026, 0, 1));
export const created = Date.now();
export const today = new Date();
export const started = performance.now();
`,
    errors: 0,
  },
  {
    rule: clock,
    name: "allows Date once setSystemTime pins it in a hook",
    code: `beforeEach(() => vi.setSystemTime(new Date(2026, 0, 1)));
export const created = () => Date.now();
`,
    errors: 0,
  },
  {
    rule: clock,
    name: "reports performance.now() when only Date is pinned",
    code: `vi.setSystemTime(new Date(2026, 0, 1));
export const started = performance.now();
`,
    errors: 1,
  },
  {
    rule: clock,
    name: "reports Date.now()",
    code: `export const now = Date.now();\n`,
    errors: 1,
  },
  {
    rule: clock,
    name: "reports new Date()",
    code: `export const today = new Date();\n`,
    errors: 1,
  },
  {
    rule: clock,
    name: "reports performance.now()",
    code: `export const started = performance.now();\n`,
    errors: 1,
  },
  {
    rule: clock,
    name: "reports process.hrtime",
    code: `export const started = process.hrtime.bigint();\n`,
    errors: 1,
  },

  {
    rule: waits,
    name: "allows timers once the file uses fake timers",
    code: `vi.useFakeTimers();
setTimeout(() => {}, 50);
await vi.advanceTimersByTimeAsync(50);
export {};
`,
    errors: 0,
  },
  {
    rule: waits,
    name: "allows fake timers switched on in a hook",
    code: `beforeEach(() => vi.useFakeTimers());
export const wait = new Promise((resolve) => setTimeout(resolve, 10));
`,
    errors: 0,
  },
  {
    rule: waits,
    name: "reports a sleep",
    code: `await new Promise((resolve) => setTimeout(resolve, 50));\nexport {};\n`,
    errors: 1,
  },
  {
    rule: waits,
    name: "reports an interval",
    code: `setInterval(() => {}, 10);\n`,
    errors: 1,
  },
  {
    rule: waits,
    name: "reports timers/promises",
    code: `import { setTimeout as sleep } from "node:timers/promises";\nexport { sleep };\n`,
    errors: 1,
  },

  {
    rule: polling,
    name: "allows a loop over data",
    code: `${pollingHelpers}for (const value of [1, 2]) await tick();\nexport {};\n`,
    errors: 0,
  },
  {
    rule: polling,
    name: "allows a counted loop",
    code: `${pollingHelpers}for (let attempt = 0; attempt < 3; attempt++) await tick();\nexport {};\n`,
    errors: 0,
  },
  {
    rule: polling,
    name: "allows a loop that does not await",
    code: `${pollingHelpers}while (!done()) tick();\n`,
    errors: 0,
  },
  {
    rule: polling,
    name: "allows an await inside a callback",
    code: `${pollingHelpers}while (!done()) [1].forEach(async () => {\n  await tick();\n});\n`,
    errors: 0,
  },
  {
    rule: polling,
    name: "allows a loop that reads a stream",
    code: `declare const reader: ReadableStreamDefaultReader<string>;
const chunks: string[] = [];
let done = false;
let value: string | undefined;
while (!done) {
  ({ done, value } = await reader.read());
  if (value) chunks.push(value);
}
export { chunks };
`,
    errors: 0,
  },
  {
    rule: polling,
    name: "allows a loop whose condition assigns the awaited value",
    code: `declare function next(): Promise<string | null>;
const lines: string[] = [];
let line: string | null;
while ((line = await next()) !== null) lines.push(line);
export { lines };
`,
    errors: 0,
  },
  {
    rule: polling,
    name: "reports a stream loop that also waits",
    code: `${pollingHelpers}declare const reader: ReadableStreamDefaultReader<string>;
let ended = false;
while (!ended) {
  ({ done: ended } = await reader.read());
  await tick();
}
export {};
`,
    errors: 1,
  },
  {
    rule: polling,
    name: "reports a while loop",
    code: `${pollingHelpers}while (!done()) await tick();\nexport {};\n`,
    errors: 1,
  },
  {
    rule: polling,
    name: "reports a do loop",
    code: `${pollingHelpers}do {\n  await tick();\n} while (!done());\nexport {};\n`,
    errors: 1,
  },
  {
    rule: polling,
    name: "reports a for loop that breaks",
    code: `${pollingHelpers}for (;;) {\n  if (done()) break;\n  await tick();\n}\nexport {};\n`,
    errors: 1,
  },

  {
    rule: loops,
    name: "allows it.each",
    code: `it.each([1, 2])("handles %i", () => {});\n`,
    errors: 0,
  },
  {
    rule: loops,
    name: "allows a loop inside a test",
    code: `it("checks every value", () => {\n  for (const n of [1, 2]) expect(n).toBeGreaterThan(0);\n});\n`,
    errors: 0,
  },
  {
    rule: loops,
    name: "reports it in a for loop",
    code: `for (const n of [1, 2]) {\n  it("handles " + n, () => {});\n}\n`,
    errors: 1,
  },
  {
    rule: loops,
    name: "reports describe in forEach",
    code: `[1, 2].forEach((n) => describe(String(n), () => {}));\n`,
    errors: 1,
  },
  {
    rule: loops,
    name: "allows map inside a test",
    code: `it("doubles", () => {\n  expect([1, 2].map((n) => n * 2)).toEqual([2, 4]);\n});\n`,
    errors: 0,
  },
  {
    rule: loops,
    name: "reports it in a map callback",
    code: `const cases = [1, 2];\ncases.map((n) => it("handles " + n, () => {}));\n`,
    errors: 1,
  },
  {
    rule: loops,
    name: "reports test in a while loop",
    code: `let round = 0;\nwhile (round++ < 2) test("again", () => {});\n`,
    errors: 1,
  },

  {
    rule: dom,
    name: "allows Vitest itself",
    code: `import { describe } from "vitest";\nexport { describe };\n`,
    errors: 0,
  },
  {
    rule: dom,
    name: "allows asking for the node environment",
    code: `// ${pragma} node\nexport {};\n`,
    errors: 0,
  },
  {
    rule: dom,
    name: "reports an environment pragma",
    code: `// ${pragma} jsdom\nexport {};\n`,
    errors: 1,
  },
  {
    rule: dom,
    name: "reports Testing Library",
    code: `import { render } from "@testing-library/react";\nexport { render };\n`,
    errors: 1,
  },
  {
    rule: dom,
    name: "reports jsdom",
    code: `import { JSDOM } from "jsdom";\nexport { JSDOM };\n`,
    errors: 1,
  },
  {
    rule: dom,
    name: "reports a dynamic happy-dom import",
    code: `export const dom = await import("happy-dom");\n`,
    errors: 1,
  },
];

/** Each case gets its own folder, so a file name can matter to a rule. */
function pathOf(item: Case) {
  const index = cases.findIndex((other) => other.rule === item.rule && other.name === item.name);
  return `cases/${index}/${item.file ?? "case.tsx"}`;
}

let root = "";
let diagnostics: Diagnostic[] = [];

beforeAll(() => {
  root = mkdtempSync(join(tmpdir(), "macarchy-lint-"));
  for (const item of cases) {
    const path = join(root, pathOf(item));
    mkdirSync(dirname(path), { recursive: true });
    writeFileSync(path, item.code);
  }
  const rules = Object.fromEntries(ruleNames.map((rule) => [`macarchy/${rule}`, "error"]));
  const config = join(root, "oxlintrc.json");
  writeFileSync(
    config,
    JSON.stringify({ plugins: [], categories: { correctness: "off" }, jsPlugins: [plugin], rules }),
  );
  const result = spawnSync(oxlint, ["--config", config, "--format", "json", "cases"], {
    cwd: root,
    encoding: "utf8",
  });
  if (result.error) throw result.error;
  let output: unknown;
  try {
    output = JSON.parse(result.stdout);
  } catch {
    throw new Error(`oxlint printed no JSON (exit ${result.status}):\n${result.stderr}`);
  }
  diagnostics = Array.isArray(output)
    ? output
    : ((output as { diagnostics?: Diagnostic[] }).diagnostics ?? []);
});

afterAll(() => {
  if (root) rmSync(root, { recursive: true, force: true });
});

describe("the macarchy oxlint plugin", () => {
  it.each(cases)("$rule $name", (item) => {
    const path = pathOf(item);
    const messages = diagnostics
      .filter(
        (diagnostic) =>
          diagnostic.code?.includes(item.rule) &&
          diagnostic.filename?.replaceAll("\\", "/").endsWith(path),
      )
      .map((diagnostic) => diagnostic.message);
    expect(messages).toHaveLength(item.errors);
    expect(messages.every((message) => (item.message ?? /./).test(message))).toBe(true);
  });
});
