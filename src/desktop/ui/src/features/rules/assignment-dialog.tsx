import { ChevronsUpDown, Trash2 } from "lucide-react";
import { type KeyboardEvent, useRef, useState } from "react";

import { AppIcon } from "~/components/ui/app-icon";
import { Button } from "~/components/ui/button";
import { Dialog } from "~/components/ui/dialog";
import { focusRing } from "~/components/ui/focus-ring";
import { Tooltip } from "~/components/ui/tooltip";
import { cn } from "~/lib/cn";

import { AppPicker } from "./app-picker";
import { gridStep } from "./rule-apps";
import { type Assignment, workspaceName, workspaces } from "./rules-mock";

const COLUMNS = 3;

/** Nine desktops as radio buttons in three columns, with the apps already on each. */
function WorkspaceGrid({
  value,
  onChange,
  others,
  icons,
}: {
  value: string;
  onChange: (workspace: string) => void;
  others: readonly Assignment[];
  icons: Readonly<Record<string, string>>;
}) {
  const refs = useRef<(HTMLButtonElement | null)[]>([]);
  const selected = Math.max(0, workspaces.indexOf(value));
  const onKeyDown = (event: KeyboardEvent<HTMLButtonElement>, index: number) => {
    const next = gridStep(index, event.key, workspaces.length, COLUMNS);
    const workspace = next === undefined ? undefined : workspaces[next];
    if (next === undefined || workspace === undefined) return;
    event.preventDefault();
    refs.current[next]?.focus();
    onChange(workspace);
  };
  return (
    <div role="radiogroup" aria-label="Workspace" className="grid grid-cols-3 gap-1.5">
      {workspaces.map((workspace, index) => {
        const on = workspace === value;
        const here = others.filter((other) => other.workspace === workspace);
        const name = workspaceName(workspace);
        return (
          <button
            key={workspace}
            ref={(element) => {
              refs.current[index] = element;
            }}
            type="button"
            role="radio"
            aria-checked={on}
            aria-label={
              here.length
                ? `${workspace} ${name}, with ${here.map((other) => other.app).join(", ")}`
                : `${workspace} ${name}`
            }
            tabIndex={index === selected ? 0 : -1}
            onClick={() => onChange(workspace)}
            onKeyDown={(event) => onKeyDown(event, index)}
            className={cn(
              "flex h-[34px] min-w-0 items-center gap-2 rounded-control border px-2.5 text-left text-detail transition-colors",
              focusRing,
              on
                ? "border-accent bg-accent-soft text-accent-text"
                : "border-hairline text-fg hover:bg-hover",
            )}
          >
            <span className="font-mono text-caption font-semibold">{workspace}</span>
            <span className="min-w-0 flex-1 truncate">{name}</span>
            {here.length ? (
              <span aria-hidden className="flex shrink-0 -space-x-[5px]">
                {here.slice(0, 2).map((other) => (
                  <AppIcon key={other.id} src={icons[other.app]} name={other.app} size={18} />
                ))}
              </span>
            ) : null}
          </button>
        );
      })}
    </div>
  );
}

/** A small form for adding or editing a workspace assignment. */
export function AssignmentDialog({
  initial,
  apps,
  icons,
  taken,
  others,
  onSave,
  onRemove,
  onClose,
}: {
  initial: Assignment | null;
  apps: readonly string[];
  icons: Readonly<Record<string, string>>;
  /** Apps with an assignment already, left out of the picker. */
  taken: readonly string[];
  others: readonly Assignment[];
  onSave: (app: string, workspace: string) => void;
  onRemove?: () => void;
  onClose: () => void;
}) {
  const [app, setApp] = useState(initial?.app ?? "");
  const [workspace, setWorkspace] = useState(initial?.workspace ?? "1");
  const [picking, setPicking] = useState(!initial);
  const choices = apps.filter((name) => name === initial?.app || !taken.includes(name));
  return (
    <Dialog.Root
      open
      onOpenChange={(open) => {
        if (!open) onClose();
      }}
      dismissOnOutsidePress={false}
    >
      <Dialog.Popup size="sm" className="w-[460px]">
        <form
          className="contents"
          onSubmit={(event) => {
            event.preventDefault();
            if (app) onSave(app, workspace);
          }}
        >
          <Dialog.Header>
            <Dialog.Title>
              {initial ? "Edit assignment" : "Assign an app to a workspace"}
            </Dialog.Title>
          </Dialog.Header>
          <Dialog.Body>
            <div className="flex flex-col gap-1.5">
              <span className="text-small font-medium text-fg">App</span>
              {app && !picking ? (
                <button
                  type="button"
                  onClick={() => setPicking(true)}
                  aria-label={`App: ${app}. Change`}
                  className={cn(
                    "flex h-12 w-full items-center gap-2.5 rounded-tile border border-hairline bg-card px-2 text-left shadow-card hover:border-line-strong",
                    focusRing,
                  )}
                >
                  <AppIcon src={icons[app]} name={app} size={32} />
                  <span className="min-w-0 flex-1 truncate text-body font-medium text-fg">
                    {app}
                  </span>
                  <span className="text-meta text-fg-tertiary">Change</span>
                  <ChevronsUpDown aria-hidden className="size-3.5 text-fg-tertiary" />
                </button>
              ) : (
                <AppPicker
                  apps={choices}
                  icons={icons}
                  value={app}
                  onPick={(next) => {
                    setApp(next);
                    setPicking(false);
                  }}
                  onCancel={app ? () => setPicking(false) : undefined}
                />
              )}
            </div>
            <div className="flex flex-col gap-1.5">
              <span className="text-small font-medium text-fg">Workspace</span>
              <WorkspaceGrid
                value={workspace}
                onChange={setWorkspace}
                others={others.filter((other) => other.id !== initial?.id)}
                icons={icons}
              />
            </div>
          </Dialog.Body>
          <Dialog.Footer
            leading={
              onRemove ? (
                <Button variant="ghost" size="sm" className="text-danger" onClick={onRemove}>
                  <Trash2 aria-hidden />
                  Remove
                </Button>
              ) : undefined
            }
          >
            <Button size="sm" onClick={onClose}>
              Cancel
            </Button>
            <Tooltip content="Choose an app first" disabled={Boolean(app)}>
              <Button
                type="submit"
                size="sm"
                variant="primary"
                aria-disabled={!app || undefined}
                className={cn(!app && "opacity-50")}
              >
                {initial ? "Save" : "Add assignment"}
              </Button>
            </Tooltip>
          </Dialog.Footer>
        </form>
      </Dialog.Popup>
    </Dialog.Root>
  );
}
