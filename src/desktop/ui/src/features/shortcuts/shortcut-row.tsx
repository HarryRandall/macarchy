import { ChevronDown, TriangleAlert } from "lucide-react";
import { useId, useState } from "react";

import type { ShortcutBinding } from "~/bridge/protocol";
import { Badge } from "~/components/ui/badge";
import { Button } from "~/components/ui/button";
import { IconButton } from "~/components/ui/icon-button";
import { KbdGroup } from "~/components/ui/kbd";
import { cn } from "~/lib/cn";

import { ShortcutDetails } from "./shortcut-editor";
import { shortcutTitle } from "./shortcut-groups";

/**
 * One binding: its action, badges and keys. The whole row opens the editor;
 * the chevron beside it shows the command in place. A disabled binding is
 * dimmed and offers Enable instead of the editor.
 */
export function ShortcutRow({
  binding,
  all,
  conflict,
  disabled,
  onEdit,
  onEnable,
}: {
  binding: ShortcutBinding;
  all: readonly ShortcutBinding[];
  conflict?: string;
  disabled?: boolean;
  onEdit: () => void;
  onEnable: () => void;
}) {
  const [expanded, setExpanded] = useState(false);
  const detailsId = useId();
  const { title, command } = shortcutTitle(binding, all);
  const mono = title === binding.command;
  const off = binding.disabled;
  const name = [
    `Edit shortcut: ${title}, ${binding.caps.join(" ")}`,
    conflict ? `conflict: ${conflict}` : null,
  ]
    .filter(Boolean)
    .join(", ");
  const content = (
    <>
      <span className="flex min-w-0 flex-1 flex-col">
        <span className="flex min-w-0 items-center gap-2">
          <span className={cn("truncate text-fg", mono ? "font-mono text-mono" : "text-body")}>
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
      </span>
      {off ? null : (
        <span
          aria-hidden
          className="hidden shrink-0 text-meta text-fg-tertiary opacity-0 transition-opacity group-hover/row:opacity-100 @[520px]:inline"
        >
          Click to edit
        </span>
      )}
      <KbdGroup variant="key" keys={binding.caps} className="shrink-0" />
    </>
  );
  return (
    <div data-row="" data-shortcut-id={binding.id} className="group/row">
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
