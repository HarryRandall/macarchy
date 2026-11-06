import { LayoutGrid, Plus, RotateCcw, Trash2 } from "lucide-react";
import { useRef, useState } from "react";

import { Badge } from "~/components/ui/badge";
import { Button } from "~/components/ui/button";
import { Card, CardHeader, CardRows } from "~/components/ui/card";
import { IconButton } from "~/components/ui/icon-button";
import { PreviewTag } from "~/components/ui/preview-tag";
import { Select } from "~/components/ui/select";
import { Switch } from "~/components/ui/switch";

import { AppRow, CardEmpty } from "./app-row";
import { AssignmentDialog } from "./assignment-dialog";
import { type Assignment, initialAssignments, workspaceName, workspaces } from "./rules-mock";

const workspaceOptions = workspaces.map((workspace) => ({
  value: workspace,
  label: `${workspace}  ${workspaceName(workspace)}`,
}));

/** A strip under a list after a removal, offering to put it back. */
export function UndoStrip({ text, onUndo }: { text: string; onUndo: () => void }) {
  return (
    <div
      data-row=""
      className="flex items-center justify-between gap-3 bg-side px-5 py-2 text-small text-fg-secondary"
    >
      <span role="status">{text}</span>
      <Button size="sm" variant="ghost" onClick={onUndo}>
        <RotateCcw aria-hidden />
        Undo
      </Button>
    </div>
  );
}

/**
 * Which desktop an app opens on. Macarchy cannot apply these yet, so the
 * card is marked Preview and every edit stays on this page.
 */
export function WorkspaceAssignments({
  apps,
  icons,
  hot,
  onHot,
}: {
  apps: readonly string[];
  icons: Readonly<Record<string, string>>;
  hot: string | null;
  onHot: (app: string | null) => void;
}) {
  // Mock: assignments are not saved or applied yet.
  const [assignments, setAssignments] = useState<Assignment[]>(() => [...initialAssignments]);
  const [removed, setRemoved] = useState<{ item: Assignment; index: number } | null>(null);
  const [dialog, setDialog] = useState<{ editing: Assignment | null } | null>(null);
  const nextId = useRef(initialAssignments.length + 1);

  const sorted = assignments.toSorted(
    (a, b) => Number(a.workspace) - Number(b.workspace) || a.app.localeCompare(b.app),
  );
  const patch = (id: number, change: Partial<Assignment>) =>
    setAssignments((current) => current.map((a) => (a.id === id ? { ...a, ...change } : a)));
  const remove = (item: Assignment) => {
    setRemoved({ item, index: assignments.findIndex((a) => a.id === item.id) });
    setAssignments((current) => current.filter((a) => a.id !== item.id));
    setDialog(null);
  };
  const undo = () => {
    if (!removed) return;
    setAssignments((current) => current.toSpliced(removed.index, 0, removed.item));
    setRemoved(null);
  };

  return (
    <Card aria-labelledby="rules-assignments">
      <CardHeader
        id="rules-assignments"
        title={
          <span className="flex items-center gap-2">
            Workspace assignments
            <PreviewTag />
          </span>
        }
        help="Not applied yet: changes here stay on this page."
        action={
          <Button size="sm" onClick={() => setDialog({ editing: null })}>
            <Plus aria-hidden />
            Add
          </Button>
        }
      />
      <CardRows>
        {sorted.length === 0 ? (
          <CardEmpty icon={<LayoutGrid />} title="No assignments" />
        ) : (
          sorted.map((assignment) => (
            <AppRow
              key={assignment.id}
              app={assignment.app}
              icon={icons[assignment.app]}
              muted={!assignment.enabled}
              hot={hot === assignment.app}
              onHot={onHot}
              onOpen={() => setDialog({ editing: assignment })}
              openLabel={`Edit assignment for ${assignment.app}`}
              badge={assignment.enabled ? null : <Badge>Paused</Badge>}
            >
              <span className="hidden text-small text-fg-tertiary @[560px]:inline">Opens on</span>
              <Select
                size="sm"
                label={`Workspace for ${assignment.app}`}
                value={assignment.workspace}
                options={workspaceOptions}
                disabled={!assignment.enabled}
                onValueChange={(workspace) => patch(assignment.id, { workspace })}
              />
              <span aria-hidden className="mx-1 h-5 w-px bg-hairline" />
              <Switch
                aria-label={`Assign ${assignment.app}`}
                checked={assignment.enabled}
                onCheckedChange={(enabled) => patch(assignment.id, { enabled })}
              />
              <IconButton
                label={`Remove ${assignment.app}`}
                tone="danger"
                onClick={() => remove(assignment)}
              >
                <Trash2 aria-hidden />
              </IconButton>
            </AppRow>
          ))
        )}
        {removed ? (
          <UndoStrip text={`${removed.item.app} assignment removed`} onUndo={undo} />
        ) : null}
      </CardRows>
      {dialog ? (
        <AssignmentDialog
          key={dialog.editing?.id ?? "new"}
          initial={dialog.editing}
          apps={apps}
          icons={icons}
          taken={assignments.map((a) => a.app)}
          others={assignments}
          onClose={() => setDialog(null)}
          onRemove={dialog.editing ? () => dialog.editing && remove(dialog.editing) : undefined}
          onSave={(app, workspace) => {
            if (dialog.editing) patch(dialog.editing.id, { app, workspace });
            else
              setAssignments((current) => [
                ...current,
                { id: nextId.current++, app, workspace, enabled: true },
              ]);
            setRemoved(null);
            setDialog(null);
          }}
        />
      ) : null}
    </Card>
  );
}
