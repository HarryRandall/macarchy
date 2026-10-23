/**
 * Macarchy's own lint rules, loaded by oxlint as a JS plugin. Plain ESM with
 * JSDoc types so oxlint can load it on Node without a build step. Rules use
 * the ESLint-compatible API that oxlint's JS plugins implement.
 */

/**
 * @typedef {{ type: string, range?: [number, number], start?: number, end?: number } & Record<string, any>} Node
 * @typedef {{ type: "Line" | "Block", value: string, range?: [number, number], start?: number, end?: number }} Comment
 * @typedef {{ comment: Comment, text: string, startLine: number, endLine: number, directive: boolean }} CommentEntry
 * @typedef {{
 *   filename: string,
 *   report(descriptor: { node: Node | Comment, message: string }): void,
 *   sourceCode: {
 *     getAllComments(): Comment[],
 *     getLocFromIndex(index: number): { line: number, column: number },
 *   },
 * }} Context
 */

/** @param {Node | Comment} node */
function startOf(node) {
  return node.range ? node.range[0] : (node.start ?? 0);
}

/** @param {Node | Comment} node */
function endOf(node) {
  return node.range ? node.range[1] : (node.end ?? 0);
}

/**
 * @param {Context} context
 * @param {Node | Comment} node
 */
function lineOf(context, node) {
  return context.sourceCode.getLocFromIndex(startOf(node)).line;
}

const DIRECTIVE =
  /^\s*\*?\s*(?:(?:oxlint|eslint)-(?:disable|enable)|eslint\s|globals?\s|@ts-|@vitest-environment|prettier-ignore|#(?:end)?region\b|\/\s*<reference\b)/;

/**
 * @param {Context} context
 * @returns {CommentEntry[]}
 */
function commentEntries(context) {
  const { sourceCode } = context;
  return sourceCode.getAllComments().map((comment) => ({
    comment,
    text: comment.value,
    startLine: sourceCode.getLocFromIndex(startOf(comment)).line,
    endLine: sourceCode.getLocFromIndex(endOf(comment)).line,
    directive: DIRECTIVE.test(comment.value),
  }));
}

/**
 * True when a non-directive comment ends on the line above `line`, or sits
 * on `line` itself when `sameLine` is set.
 * @param {CommentEntry[]} comments
 * @param {number} line
 * @param {boolean} sameLine
 */
function explainedAt(comments, line, sameLine) {
  return comments.some(
    (entry) =>
      !entry.directive &&
      entry.text.trim() !== "" &&
      (entry.endLine === line - 1 || (sameLine && entry.startLine === line)),
  );
}

/**
 * @param {Node | null | undefined} node
 * @param {string} object
 * @param {string} property
 */
function isMember(node, object, property) {
  return (
    node?.type === "MemberExpression" &&
    !node.computed &&
    node.object.type === "Identifier" &&
    node.object.name === object &&
    node.property.type === "Identifier" &&
    node.property.name === property
  );
}

const GLOBAL_OBJECTS = new Set(["window", "globalThis", "self", "global"]);

/**
 * `name` itself, or `name` read off a global object such as `window`.
 * @param {Node} node
 * @param {string} name
 */
function isGlobal(node, name) {
  if (node.type === "Identifier") return node.name === name;
  return (
    node.type === "MemberExpression" &&
    !node.computed &&
    node.object.type === "Identifier" &&
    GLOBAL_OBJECTS.has(node.object.name) &&
    node.property.type === "Identifier" &&
    node.property.name === name
  );
}

/**
 * @param {Node} object
 * @param {string} name
 */
function hasKey(object, name) {
  return object.properties.some(
    (/** @type {Node} */ property) =>
      property.type === "Property" &&
      !property.computed &&
      ((property.key.type === "Identifier" && property.key.name === name) ||
        (property.key.type === "Literal" && property.key.value === name)),
  );
}

const TEST_FUNCTIONS = new Set(["it", "test", "describe"]);

/**
 * The Vitest function a callee calls and the modifiers chained onto it, as in
 * `it.skip.each`. Calls such as `.each(table)` are passed through only when
 * `throughCalls` is set, so each call in a chain is examined once.
 * @param {Node} node
 * @param {boolean} throughCalls
 * @param {string[]} [modifiers]
 * @returns {{ name: string, modifiers: string[] } | null}
 */
function testCall(node, throughCalls, modifiers = []) {
  if (node.type === "Identifier") {
    return TEST_FUNCTIONS.has(node.name) ? { name: node.name, modifiers } : null;
  }
  if (node.type === "MemberExpression" && !node.computed && node.property.type === "Identifier") {
    return testCall(node.object, throughCalls, [node.property.name, ...modifiers]);
  }
  if (throughCalls && node.type === "CallExpression") {
    return testCall(node.callee, throughCalls, modifiers);
  }
  return null;
}

/** @param {Node} node */
function isForEach(node) {
  return (
    node.callee.type === "MemberExpression" &&
    !node.callee.computed &&
    node.callee.property.type === "Identifier" &&
    node.callee.property.name === "forEach"
  );
}

const SUPPRESSION = /^\s*\*?\s*(oxlint-disable|eslint-disable|@ts-expect-error|@ts-ignore)/;
const INLINE_REASON = /\s--\s+\S/;

const requireSuppressionReason = {
  meta: {
    type: "problem",
    docs: { description: "Requires a reason on every lint or type-check suppression." },
  },
  /** @param {Context} context */
  create(context) {
    return {
      Program() {
        const comments = commentEntries(context);
        for (const entry of comments) {
          const kind = SUPPRESSION.exec(entry.text)?.[1];
          if (!kind) continue;
          if (kind === "@ts-ignore") {
            context.report({
              node: entry.comment,
              message: "Use @ts-expect-error with a reason instead of @ts-ignore.",
            });
          } else if (
            !INLINE_REASON.test(entry.text) &&
            !explainedAt(comments, entry.startLine, false)
          ) {
            context.report({
              node: entry.comment,
              message: `Give a reason for this ${kind}, after " -- " or in a comment on the line above.`,
            });
          }
        }
      },
    };
  },
};

/** Elements whose `title` is their accessible name rather than a tooltip. */
const TITLE_NAMES_ELEMENT = new Set(["abbr", "iframe", "frame"]);

const noNativeTitleTooltip = {
  meta: {
    type: "suggestion",
    docs: { description: "Disallows native title tooltips on intrinsic elements." },
  },
  /** @param {Context} context */
  create(context) {
    return {
      /** @param {Node} node */
      JSXOpeningElement(node) {
        if (node.name.type !== "JSXIdentifier") return;
        const tag = node.name.name;
        if (!/^[a-z]/.test(tag) || TITLE_NAMES_ELEMENT.has(tag)) return;
        for (const attribute of node.attributes) {
          if (
            attribute.type === "JSXAttribute" &&
            attribute.name.type === "JSXIdentifier" &&
            attribute.name.name === "title"
          ) {
            context.report({
              node: attribute,
              message:
                "Native title tooltips are slow, unstyled and unreachable by keyboard. Use Tooltip from ~/components/ui/tooltip.",
            });
          }
        }
      },
    };
  },
};

const CLASS_HELPERS = new Set(["cn", "clsx"]);

/**
 * The class strings an expression is known to contain without running it.
 * @param {Node} node
 * @returns {string[]}
 */
function staticStrings(node) {
  switch (node.type) {
    case "Literal":
      return typeof node.value === "string" ? [node.value] : [];
    case "TemplateLiteral":
      return node.expressions.length === 0
        ? node.quasis.map((/** @type {Node} */ quasi) => quasi.value.cooked ?? quasi.value.raw)
        : [];
    case "JSXExpressionContainer":
      return staticStrings(node.expression);
    case "LogicalExpression":
      return staticStrings(node.right);
    case "ConditionalExpression":
      return [...staticStrings(node.consequent), ...staticStrings(node.alternate)];
    case "CallExpression":
      return node.callee.type === "Identifier" && CLASS_HELPERS.has(node.callee.name)
        ? node.arguments.flatMap((/** @type {Node} */ argument) => staticStrings(argument))
        : [];
    default:
      return [];
  }
}

/**
 * @param {Node} element
 * @returns {string[]}
 */
function classTokens(element) {
  const attribute = element.openingElement.attributes.find(
    (/** @type {Node} */ candidate) =>
      candidate.type === "JSXAttribute" &&
      candidate.name.type === "JSXIdentifier" &&
      (candidate.name.name === "className" || candidate.name.name === "class"),
  );
  if (!attribute?.value) return [];
  return staticStrings(attribute.value)
    .flatMap((text) => text.split(/\s+/))
    .filter(Boolean);
}

/**
 * A class without its variants or important marker: `md:!overflow-auto`
 * becomes `overflow-auto`. Colons inside brackets belong to the value.
 * @param {string} token
 */
function utility(token) {
  let depth = 0;
  let cut = 0;
  for (let index = 0; index < token.length; index++) {
    const char = token[index];
    if (char === "[" || char === "(") depth++;
    else if (char === "]" || char === ")") depth--;
    else if (char === ":" && depth === 0) cut = index + 1;
  }
  return token.slice(cut).replace(/^!|!$/g, "");
}

/**
 * @param {Node | null | undefined} node
 * @returns {Node[]}
 */
function expressionElements(node) {
  if (!node) return [];
  switch (node.type) {
    case "JSXElement":
      return [node];
    case "JSXFragment":
      return childElements(node);
    case "LogicalExpression":
      return expressionElements(node.right);
    case "ConditionalExpression":
      return [...expressionElements(node.consequent), ...expressionElements(node.alternate)];
    default:
      return [];
  }
}

/**
 * Elements rendered directly inside `node`, looking through fragments and
 * conditional expressions.
 * @param {Node} node
 * @returns {Node[]}
 */
function childElements(node) {
  return (node.children ?? []).flatMap((/** @type {Node} */ child) => {
    if (child.type === "JSXElement") return [child];
    if (child.type === "JSXFragment") return childElements(child);
    if (child.type === "JSXExpressionContainer") return expressionElements(child.expression);
    return [];
  });
}

/** @param {Node} element */
function isCentred(element) {
  return classTokens(element).some((token) => utility(token) === "mx-auto");
}

const SCROLLS = new Set(["overflow-auto", "overflow-y-auto", "overflow-y-scroll"]);
const KEEPS_GUTTER =
  /^(?:\[scrollbar-gutter:stable[^\]]*\]|\[scrollbar-width:none\]|scrollbar-none|scrollbar-hidden|no-scrollbar)$/;
const HIDES_WEBKIT_SCROLLBAR = /\[&::-webkit-scrollbar\]:hidden$/;

const requireCenteredScrollGutter = {
  meta: {
    type: "problem",
    docs: {
      description:
        "Requires a stable or hidden scrollbar gutter on scroll areas that centre their content.",
    },
  },
  /** @param {Context} context */
  create(context) {
    return {
      /** @param {Node} node */
      JSXElement(node) {
        const tokens = classTokens(node);
        const utilities = tokens.map(utility);
        if (!utilities.some((name) => SCROLLS.has(name))) return;
        if (
          utilities.some((name) => KEEPS_GUTTER.test(name)) ||
          tokens.some((token) => HIDES_WEBKIT_SCROLLBAR.test(token))
        ) {
          return;
        }
        const centred = childElements(node).some(
          (child) => isCentred(child) || childElements(child).some(isCentred),
        );
        if (centred) {
          context.report({
            node: node.openingElement,
            message:
              "This scroll area centres content with mx-auto, so a classic scrollbar shifts it sideways. Add [scrollbar-gutter:stable_both-edges] or hide the scrollbar.",
          });
        }
      },
    };
  },
};

/**
 * @param {string} text
 * @param {number} open
 */
function closingBracket(text, open) {
  let depth = 0;
  for (let index = open; index < text.length; index++) {
    if (text[index] === "[") {
      depth++;
    } else if (text[index] === "]") {
      depth--;
      if (depth === 0) return index;
    }
  }
  return -1;
}

const COMBINATORS = new Set([" ", "_", ">", "+", "~", ","]);

/**
 * The compound selector that ends at `end`, back to the previous combinator
 * or the opening of an enclosing pseudo-class.
 * @param {string} selector
 * @param {number} end
 */
function compoundBefore(selector, end) {
  let depth = 0;
  let index = end - 1;
  for (; index >= 0; index--) {
    const char = selector[index];
    if (char === ")" || char === "]") {
      depth++;
    } else if (char === "(" || char === "[") {
      if (depth === 0) break;
      depth--;
    } else if (depth === 0 && COMBINATORS.has(char)) {
      break;
    }
  }
  return selector.slice(index + 1, end);
}

/**
 * Tailwind's `&` is the utility's own generated class, so it anchors too.
 * @param {string} compound
 */
function isAnchored(compound) {
  const bare = compound.replace(/\((?:[^()]|\([^()]*\))*\)/g, "");
  if (/[&.#[]/.test(bare)) return true;
  const tag = /^[a-z][\w-]*/i.exec(bare)?.[0];
  return tag !== undefined && tag.toLowerCase() !== "html";
}

/**
 * The first arbitrary variant in `text` whose `:has()` hangs off the
 * document root, `*` or nothing at all.
 * @param {string} text
 */
function unscopedHasVariant(text) {
  if (!text.includes(":has(")) return null;
  for (const token of text.split(/\s+/)) {
    let open = token.indexOf("[");
    while (open !== -1) {
      const close = closingBracket(token, open);
      if (close === -1) break;
      const isVariant = (open === 0 || token[open - 1] === ":") && token[close + 1] === ":";
      if (isVariant) {
        const selector = token.slice(open + 1, close);
        let at = selector.indexOf(":has(");
        while (at !== -1) {
          if (!isAnchored(compoundBefore(selector, at))) return token;
          at = selector.indexOf(":has(", at + 1);
        }
      }
      open = token.indexOf("[", close + 1);
    }
  }
  return null;
}

const noUnscopedHas = {
  meta: {
    type: "problem",
    docs: { description: "Requires :has() in arbitrary variants to be anchored to a selector." },
  },
  /** @param {Context} context */
  create(context) {
    /**
     * @param {Node} node
     * @param {string} text
     */
    const check = (node, text) => {
      const variant = unscopedHasVariant(text);
      if (variant) {
        context.report({
          node,
          message: `${variant} matches :has() from the document root or every element. Anchor it to a class, attribute, id or tag, or use the has-* variants.`,
        });
      }
    };
    return {
      /** @param {Node} node */
      Literal(node) {
        if (typeof node.value === "string") check(node, node.value);
      },
      /** @param {Node} node */
      TemplateElement(node) {
        check(node, node.value.cooked ?? node.value.raw);
      },
    };
  },
};

const noRawResizeObserver = {
  meta: {
    type: "suggestion",
    docs: { description: "Routes size observation through observeResize." },
  },
  /** @param {Context} context */
  create(context) {
    if (context.filename.replaceAll("\\", "/").endsWith("/src/lib/observe-resize.ts")) return {};
    return {
      /** @param {Node} node */
      NewExpression(node) {
        if (!isGlobal(node.callee, "ResizeObserver")) return;
        context.report({
          node,
          message:
            "Use observeResize from ~/lib/observe-resize, which commits React state before the next paint.",
        });
      },
    };
  },
};

const DIVIDER = /^([-=*#_~+/])\1{2,}|([-=*#_~+/])\2{2,}$/;
const TASK = /\b(?:TODO|FIXME|XXX|HACK)\b/;
const ISSUE = /https?:\/\/\S|(?:^|[\s(])#\d+\b|\b[A-Z][A-Z\d]+-\d+\b/;
const NARRATION = new Set(["arrange", "act", "assert", "given", "when", "then"]);
const CODE = [
  /^(?:const|let|var)\s+[\w${[][^=]*=/,
  /^(?:import|export)\s.*(?:\sfrom\s+["']|;$)/,
  /^(?:if|for|while|switch)\s*\(.*\)\s*\{?$/,
  /^(?:return|throw)\b.*;$/,
  /^(?:await\s+)?[\w$]+(?:\.[\w$]+)*\(.*\);?$/,
  /^[\w$.[\]]+\s*(?:[-+*/%]|\?\?|&&|\|\|)?=\s*[^=].*;$/,
  /^\}\s*(?:else\b.*)?[{);]*$/,
];
const FILLER = new Set([
  "a",
  "an",
  "the",
  "of",
  "get",
  "gets",
  "set",
  "sets",
  "return",
  "returns",
  "to",
  "for",
  "is",
  "this",
]);

/** @param {string} name */
function nameWords(name) {
  return name
    .replace(/([a-z\d])([A-Z])/g, "$1 $2")
    .replace(/([A-Z]+)([A-Z][a-z])/g, "$1 $2")
    .toLowerCase()
    .split(/[^a-z\d]+/)
    .filter(Boolean);
}

/**
 * @param {string} text
 * @param {string} name
 */
function repeatsName(text, name) {
  const named = new Set(nameWords(name));
  const said = (text.toLowerCase().match(/[a-z\d]+/g) ?? []).filter((word) => !FILLER.has(word));
  return (
    said.length > 0 && said.every((word) => named.has(word) || named.has(word.replace(/s$/, "")))
  );
}

/**
 * @param {CommentEntry} entry
 * @param {Map<number, string>} declared
 * @param {Set<number>} commentLines
 * @returns {string | null}
 */
function lowValueReason(entry, declared, commentLines) {
  const isLine = entry.comment.type === "Line";
  const text = (isLine ? entry.text : entry.text.replace(/^\s*\*+/gm, "")).trim();
  if (DIVIDER.test(text)) {
    return "Remove divider comments; let functions and files carry the structure.";
  }
  if (TASK.test(text) && !ISSUE.test(text)) {
    return "Link an issue from this TODO, FIXME, XXX or HACK, or remove it.";
  }
  if (isLine && NARRATION.has(text.replace(/[.:!\s]+$/, "").toLowerCase())) {
    return "Remove arrange, act and assert narration; let blank lines and names show the steps.";
  }
  if (isLine && CODE.some((pattern) => pattern.test(text))) {
    return "Delete commented-out code; version control keeps it.";
  }
  const alone = entry.startLine === entry.endLine && !commentLines.has(entry.startLine - 1);
  const name = alone ? declared.get(entry.endLine + 1) : undefined;
  if (name && repeatsName(text, name)) {
    return `This comment only repeats the name ${name}. Say why instead, or remove it.`;
  }
  return null;
}

const noLowValueComments = {
  meta: {
    type: "suggestion",
    docs: {
      description:
        "Flags dividers, unlinked TODOs, test narration, commented-out code and comments that repeat a name.",
    },
  },
  /** @param {Context} context */
  create(context) {
    /** @type {Map<number, string>} */
    const declared = new Map();
    /**
     * @param {Node} node
     * @param {Node | null | undefined} id
     */
    const declare = (node, id) => {
      if (id?.type !== "Identifier") return;
      const line = lineOf(context, node);
      if (!declared.has(line)) declared.set(line, id.name);
    };
    /** @param {Node} node */
    const declareNamed = (node) => declare(node, node.id);
    /** @param {Node} node */
    const declareMember = (node) => {
      if (!node.computed) declare(node, node.key);
    };
    return {
      /** @param {Node} node */
      VariableDeclaration(node) {
        if (node.declarations.length === 1) declare(node, node.declarations[0].id);
      },
      FunctionDeclaration: declareNamed,
      ClassDeclaration: declareNamed,
      TSInterfaceDeclaration: declareNamed,
      TSTypeAliasDeclaration: declareNamed,
      TSEnumDeclaration: declareNamed,
      TSPropertySignature: declareMember,
      TSMethodSignature: declareMember,
      PropertyDefinition: declareMember,
      MethodDefinition: declareMember,
      "Program:exit"() {
        const comments = commentEntries(context);
        const commentLines = new Set(comments.map((entry) => entry.endLine));
        for (const entry of comments) {
          if (entry.directive) continue;
          const message = lowValueReason(entry, declared, commentLines);
          if (message) context.report({ node: entry.comment, message });
        }
      },
    };
  },
};

const SKIPPING = new Set(["skip", "todo", "fails"]);

const noTestTimeoutOrUnreasonedSkip = {
  meta: {
    type: "problem",
    docs: { description: "Disallows test timeouts and skipped tests without a reason." },
  },
  /** @param {Context} context */
  create(context) {
    /** @type {CommentEntry[]} */
    let comments = [];
    const timeout =
      "Do not raise a test timeout; make the test wait on a real signal or use fake timers.";
    return {
      Program() {
        comments = commentEntries(context);
      },
      /** @param {Node} node */
      CallExpression(node) {
        if (isMember(node.callee, "vi", "setConfig")) {
          const options = node.arguments[0];
          if (
            options?.type === "ObjectExpression" &&
            (hasKey(options, "testTimeout") || hasKey(options, "hookTimeout"))
          ) {
            context.report({ node: options, message: timeout });
          }
          return;
        }
        if (testCall(node.callee, true)) {
          for (const argument of node.arguments.slice(1)) {
            const isNumber = argument.type === "Literal" && typeof argument.value === "number";
            if (isNumber || (argument.type === "ObjectExpression" && hasKey(argument, "timeout"))) {
              context.report({ node: argument, message: timeout });
            }
          }
        }
        const skipped = testCall(node.callee, false)?.modifiers.find((name) => SKIPPING.has(name));
        if (skipped && !explainedAt(comments, lineOf(context, node), true)) {
          context.report({
            node,
            message: `Say why this test uses .${skipped}, in a comment on the line above or the same line.`,
          });
        }
      },
    };
  },
};

const noWallClockInTests = {
  meta: {
    type: "problem",
    docs: { description: "Disallows reading the real clock in tests." },
  },
  /** @param {Context} context */
  create(context) {
    let systemTime = 0;
    let fakeTimers = false;
    let pinnedDate = false;
    /**
     * Reads of `Date`, which `vi.setSystemTime` pins even without fake
     * timers, and of the monotonic clocks, which only fake timers replace.
     * @type {{ date: Node[], monotonic: Node[] }}
     */
    const reads = { date: [], monotonic: [] };
    return {
      /** @param {Node} node */
      CallExpression(node) {
        if (isMember(node.callee, "vi", "useFakeTimers")) fakeTimers = true;
        if (isMember(node.callee, "vi", "setSystemTime")) {
          pinnedDate = true;
          systemTime++;
        } else if (systemTime === 0 && isMember(node.callee, "Date", "now")) {
          reads.date.push(node);
        } else if (systemTime === 0 && isMember(node.callee, "performance", "now")) {
          reads.monotonic.push(node);
        }
      },
      /** @param {Node} node */
      "CallExpression:exit"(node) {
        if (isMember(node.callee, "vi", "setSystemTime")) systemTime--;
      },
      /** @param {Node} node */
      NewExpression(node) {
        if (systemTime === 0 && isGlobal(node.callee, "Date") && node.arguments.length === 0) {
          reads.date.push(node);
        }
      },
      /** @param {Node} node */
      MemberExpression(node) {
        if (systemTime === 0 && isMember(node, "process", "hrtime")) reads.monotonic.push(node);
      },
      "Program:exit"() {
        const real = [
          ...(fakeTimers || pinnedDate ? [] : reads.date),
          ...(fakeTimers ? [] : reads.monotonic),
        ];
        for (const node of real) {
          context.report({
            node,
            message:
              "Tests must not read the real clock. Use vi.useFakeTimers() with vi.setSystemTime(), or pass a clock in.",
          });
        }
      },
    };
  },
};

const TIMER_MODULES = new Set(["timers/promises", "node:timers/promises"]);

/** @param {Node | null | undefined} source */
function importsTimers(source) {
  return source?.type === "Literal" && TIMER_MODULES.has(String(source.value));
}

const noRealTimeWaitInTests = {
  meta: {
    type: "problem",
    docs: { description: "Disallows real-time waits in tests that do not use fake timers." },
  },
  /** @param {Context} context */
  create(context) {
    let fakeTimers = false;
    /** @type {Node[]} */
    const waits = [];
    return {
      /** @param {Node} node */
      CallExpression(node) {
        if (isMember(node.callee, "vi", "useFakeTimers")) fakeTimers = true;
        if (isGlobal(node.callee, "setTimeout") || isGlobal(node.callee, "setInterval")) {
          waits.push(node);
        }
      },
      /** @param {Node} node */
      ImportDeclaration(node) {
        if (importsTimers(node.source)) waits.push(node);
      },
      /** @param {Node} node */
      ImportExpression(node) {
        if (importsTimers(node.source)) waits.push(node);
      },
      "Program:exit"() {
        if (fakeTimers) return;
        for (const node of waits) {
          context.report({
            node,
            message:
              "Real-time waits make tests slow and flaky. Await the real promise, use vi.waitFor, or call vi.useFakeTimers() in this file.",
          });
        }
      },
    };
  },
};

/**
 * A loop that re-tests a condition on every pass, rather than counting.
 * @param {Node} loop
 */
function rechecks(loop) {
  return loop.type !== "ForStatement" || !loop.update;
}

const noPollingLoopInTests = {
  meta: {
    type: "suggestion",
    docs: { description: "Flags loops that await while re-checking a condition." },
  },
  /** @param {Context} context */
  create(context) {
    /** @type {({ node: Node, awaits: boolean } | null)[]} */
    const scopes = [];
    /** @param {Node} node */
    const enterLoop = (node) => {
      scopes.push({ node, awaits: false });
    };
    const exitLoop = () => {
      const loop = scopes.pop();
      if (loop?.awaits && rechecks(loop.node)) {
        context.report({
          node: loop.node,
          message:
            "This loop polls for state. Use vi.waitFor, or await the promise that settles when the state changes.",
        });
      }
    };
    const enterFunction = () => {
      scopes.push(null);
    };
    const exitFunction = () => {
      scopes.pop();
    };
    return {
      WhileStatement: enterLoop,
      "WhileStatement:exit": exitLoop,
      DoWhileStatement: enterLoop,
      "DoWhileStatement:exit": exitLoop,
      ForStatement: enterLoop,
      "ForStatement:exit": exitLoop,
      FunctionDeclaration: enterFunction,
      "FunctionDeclaration:exit": exitFunction,
      FunctionExpression: enterFunction,
      "FunctionExpression:exit": exitFunction,
      ArrowFunctionExpression: enterFunction,
      "ArrowFunctionExpression:exit": exitFunction,
      AwaitExpression() {
        for (let index = scopes.length - 1; index >= 0; index--) {
          const scope = scopes[index];
          if (!scope) break;
          scope.awaits = true;
        }
      },
    };
  },
};

const noTestInLoop = {
  meta: {
    type: "problem",
    docs: { description: "Disallows declaring tests inside loops." },
  },
  /** @param {Context} context */
  create(context) {
    let loops = 0;
    const enter = () => {
      loops++;
    };
    const exit = () => {
      loops--;
    };
    return {
      ForStatement: enter,
      "ForStatement:exit": exit,
      ForInStatement: enter,
      "ForInStatement:exit": exit,
      ForOfStatement: enter,
      "ForOfStatement:exit": exit,
      WhileStatement: enter,
      "WhileStatement:exit": exit,
      DoWhileStatement: enter,
      "DoWhileStatement:exit": exit,
      /** @param {Node} node */
      CallExpression(node) {
        if (isForEach(node)) {
          loops++;
        } else if (loops > 0 && testCall(node.callee, false)) {
          context.report({
            node,
            message:
              "Tests declared in a loop hide which case failed. Use it.each or describe.each.",
          });
        }
      },
      /** @param {Node} node */
      "CallExpression:exit"(node) {
        if (isForEach(node)) loops--;
      },
    };
  },
};

/** @param {string} source */
function isDomLibrary(source) {
  return (
    source === "jsdom" ||
    source === "happy-dom" ||
    source.startsWith("jsdom/") ||
    source.startsWith("happy-dom/") ||
    source.startsWith("@happy-dom/") ||
    source.startsWith("@testing-library/")
  );
}

const noDomTestEnvironment = {
  meta: {
    type: "problem",
    docs: { description: "Keeps Vitest in the node environment." },
  },
  /** @param {Context} context */
  create(context) {
    const message =
      "UI tests run in the node environment. Test DOM behaviour in WKWebView from Swift, in tests/desktop/web.";
    /**
     * @param {Node} node
     * @param {Node | null | undefined} source
     */
    const check = (node, source) => {
      if (source?.type === "Literal" && isDomLibrary(String(source.value))) {
        context.report({ node, message });
      }
    };
    return {
      Program() {
        for (const entry of commentEntries(context)) {
          if (/@vitest-environment\b/.test(entry.text)) {
            context.report({ node: entry.comment, message });
          }
        }
      },
      /** @param {Node} node */
      ImportDeclaration(node) {
        check(node, node.source);
      },
      /** @param {Node} node */
      ImportExpression(node) {
        check(node, node.source);
      },
    };
  },
};

export default {
  meta: { name: "macarchy" },
  rules: {
    "require-suppression-reason": requireSuppressionReason,
    "no-native-title-tooltip": noNativeTitleTooltip,
    "require-centered-scroll-gutter": requireCenteredScrollGutter,
    "no-unscoped-has": noUnscopedHas,
    "no-raw-resize-observer": noRawResizeObserver,
    "no-low-value-comments": noLowValueComments,
    "no-test-timeout-or-unreasoned-skip": noTestTimeoutOrUnreasonedSkip,
    "no-wall-clock-in-tests": noWallClockInTests,
    "no-real-time-wait-in-tests": noRealTimeWaitInTests,
    "no-polling-loop-in-tests": noPollingLoopInTests,
    "no-test-in-loop": noTestInLoop,
    "no-dom-test-environment": noDomTestEnvironment,
  },
};
