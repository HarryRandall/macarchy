import { ChevronDown, TriangleAlert } from "lucide-react";
import { useId, useState } from "react";

import type { ShortcutBinding } from "~/bridge/protocol";
import { Badge } from "~/components/ui/badge";
import { Button } from "~/components/ui/button";
import { IconButton } from "~/components/ui/icon-button";
import { KbdGroup } from "~/components/ui/kbd";
import { cn } from "~/lib/cn";

import { ShortcutDetails } from "./shortcut-editor";
import { missingDesktop, runSummary, type ShortcutItem, shortcutTitle } from "./shortcut-groups";

/**
 * One binding: its action, badges and keys. The whole row opens the editor;
 * the chevron beside it shows the command in place. A disabled binding is
 * dimmed and offers Enable instead of the editor.
 */
export function ShortcutRow({
  binding,
  all,
  conflict,
  desktops = null,
  disabled,
  onEdit,
  onEnable,
}: {
  binding: ShortcutBinding;
  all: readonly ShortcutBinding[];
  conflict?: string;
  /** How many desktops exist, so a binding for one that does not is dimmed. */
  desktops?: number | null;
  disabled?: boolean;
  onEdit: () => void;
  onEnable: () => void;
}) {
  const [expanded, setExpanded] = useState(false);
  const detailsId = useId();
  const { title, command } = shortcutTitle(binding, all);
  const mono = title === binding.command;
  const off = binding.disabled;
  const missing = missingDesktop(binding, desktops);
  const note = missing === null ? null : `No desktop ${missing} yet`;
  const name = [
    `Edit shortcut: ${title}, ${binding.caps.join(" ")}`,
    note,
    conflict ? `conflict: ${conflict}` : null,
  ]
    .filter(Boolean)
    .join(", ");
  const content = (
    <>
      <span className="flex min-w-0 flex-1 flex-col">
        <span className="flex min-w-0 items-center gap-2">
          <span
            className={cn(
              "truncate",
              note ? "text-fg-tertiary" : "text-fg",
              mono ? "font-mono text-mono" : "text-body",
            )}
          >
            {title}
          </span>
          {off ? <Badge>Disabled</Badge> : null}
          {binding.appOverrides.length ? <Badge>Per app</Badge> : null}
          {conflict ? (
            <Badge tone="warn">
              <TriangleAlert aria-hidden className="size-3" />
              Conflict
            </Badge>
          ) : null}
        </span>
        {command && !mono ? (
          <span className="mt-0.5 truncate font-mono text-caption text-fg-tertiary">{command}</span>
        ) : null}
        {note ? <span className="mt-0.5 text-caption text-fg-tertiary">{note}</span> : null}
      </span>
      {off ? null : (
        <span
          aria-hidden
          className="hidden shrink-0 text-meta text-fg-tertiary opacity-0 transition-opacity group-hover/row:opacity-100 @[520px]:inline"
        >
          Click to edit
        </span>
      )}
      <KbdGroup
        variant="key"
        keys={binding.caps}
        className={cn("shrink-0", note && "opacity-50")}
      />
    </>
  );
  return (
    <div
      data-row=""
      data-shortcut-id={binding.id}
      data-missing-desktop={missing ?? undefined}
      className="group/row"
    >
      <div
        className={cn(
          "relative flex min-h-[46px] min-w-0 items-center gap-2 py-2 pr-2 pl-4 transition-colors duration-150 hover:bg-hover",
          "has-[[data-row-primary]:focus-visible]:ring-2 has-[[data-row-primary]:focus-visible]:ring-accent has-[[data-row-primary]:focus-visible]:ring-inset",
        )}
      >
        {off ? (
          <div className="flex min-w-0 flex-1 items-center gap-4 opacity-60">{content}</div>
        ) : (
          <button
            type="button"
            data-row-primary
            aria-label={name}
            disabled={disabled}
            onClick={onEdit}
            // The box stretches over the row, under the chevron, so the row is one target.
            className="flex min-w-0 flex-1 items-center gap-4 text-left outline-none after:absolute after:inset-0 after:rounded-[inherit]"
          >
            {content}
          </button>
        )}
        {off ? (
          <Button
            size="sm"
            aria-label={`Enable shortcut: ${title}, ${binding.caps.join(" ")}`}
            disabled={disabled}
            onClick={onEnable}
          >
            Enable
          </Button>
        ) : null}
        <IconButton
          size="sm"
          label={`${expanded ? "Hide" : "Show"} command: ${title}`}
          aria-expanded={expanded}
          aria-controls={expanded ? detailsId : undefined}
          className="relative z-10"
          onClick={() => setExpanded(!expanded)}
        >
          <ChevronDown
            aria-hidden
            className={cn("transition-transform duration-150", expanded && "rotate-180")}
          />
        </IconButton>
      </div>
      {expanded ? (
        <div
          id={detailsId}
          className="flex flex-col gap-2 border-t border-hairline bg-side px-4 py-3"
        >
          <ShortcutDetails binding={binding} />
        </div>
      ) : null}
    </div>
  );
}

/**
 * A numbered run, such as "Go to desktop 1–9", as one row. The row opens the
 * run in place, where each binding is its own row to edit.
 */
export function ShortcutRunRow({
  run,
  all,
  conflicts,
  desktops,
  disabled,
  onEdit,
  onEnable,
}: {
  run: Extract<ShortcutItem, { kind: "run" }>;
  all: readonly ShortcutBinding[];
  conflicts: ReadonlyMap<number, string>;
  desktops: number | null;
  disabled?: boolean;
  onEdit: (binding: ShortcutBinding) => void;
  onEnable: (binding: ShortcutBinding) => void;
}) {
  const [expanded, setExpanded] = useState(false);
  const listId = useId();
  const { title, caps } = runSummary(run, all);
  const count = run.bindings.length;
  const conflicted = run.bindings.some((binding) => conflicts.has(binding.id));
  const missing = run.bindings.filter(
    (binding) => missingDesktop(binding, desktops) !== null,
  ).length;
  const caption =
    missing === 0
      ? `${count} shortcuts`
      : `${count} shortcuts, ${missing} for desktops you do not have yet`;
  const name = [
    `${expanded ? "Hide" : "Show"} ${count} shortcuts: ${title}, ${caps.join(" ")}`,
    missing ? `${missing} for desktops you do not have yet` : null,
    conflicted ? "has a conflict" : null,
  ]
    .filter(Boolean)
    .join(", ");
  return (
    // Not `group/row`, which would show every nested row's "Click to edit" at once.
    <div data-row="" data-shortcut-run={run.numbers.join(",")}>
      <div
        className={cn(
          "relative flex min-h-[46px] min-w-0 items-center gap-2 py-2 pr-2 pl-4 transition-colors duration-150 hover:bg-hover",
          "has-[[data-row-primary]:focus-visible]:ring-2 has-[[data-row-primary]:focus-visible]:ring-accent has-[[data-row-primary]:focus-visible]:ring-inset",
        )}
      >
        <button
          type="button"
          data-row-primary
          aria-label={name}
          aria-expanded={expanded}
          aria-controls={expanded ? listId : undefined}
          onClick={() => setExpanded(!expanded)}
          className="flex min-w-0 flex-1 items-center gap-4 text-left outline-none after:absolute after:inset-0 after:rounded-[inherit]"
        >
          <span className="flex min-w-0 flex-1 flex-col">
            <span className="flex min-w-0 items-center gap-2">
              <span className="truncate text-body text-fg">{title}</span>
              {conflicted ? (
                <Badge tone="warn">
                  <TriangleAlert aria-hidden className="size-3" />
                  Conflict
                </Badge>
              ) : null}
            </span>
            <span className="mt-0.5 truncate text-caption text-fg-tertiary">{caption}</span>
          </span>
          <KbdGroup variant="key" keys={caps} className="shrink-0" />
          {/* The whole row is the toggle, so the chevron only shows its state. */}
          <span
            aria-hidden
            className="grid size-6 shrink-0 place-items-center text-fg-secondary [&_svg]:size-[13px]"
          >
            <ChevronDown
              className={cn("transition-transform duration-150", expanded && "rotate-180")}
            />
          </span>
        </button>
      </div>
      {expanded ? (
        <div
          id={listId}
          role="group"
          aria-label={title}
          className="border-t border-hairline bg-side pl-4 [&>[data-row]+[data-row]]:border-t [&>[data-row]+[data-row]]:border-hairline"
        >
          {run.bindings.map((binding) => (
            <ShortcutRow
              key={binding.id}
              binding={binding}
              all={all}
              conflict={conflicts.get(binding.id)}
              desktops={desktops}
              disabled={disabled}
              onEdit={() => onEdit(binding)}
              onEnable={() => onEnable(binding)}
            />
          ))}
        </div>
      ) : null}
    </div>
  );
}
