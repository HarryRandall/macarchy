import { AppWindow, LayoutGrid, ListFilter, Plus, Trash2 } from "lucide-react";
import { useState } from "react";

import type { CustomWindowRule } from "~/bridge/protocol";
import { PageHeader } from "~/components/layout/page-header";
import { Badge } from "~/components/ui/badge";
import { Button } from "~/components/ui/button";
import { Card, CardHeader, CardRows, Row } from "~/components/ui/card";
import { ConfirmDialog } from "~/components/ui/confirm-dialog";
import { focusRing } from "~/components/ui/focus-ring";
import { IconButton } from "~/components/ui/icon-button";
import { Menu, MenuItem, MenuPopup, MenuSeparator, MenuTrigger } from "~/components/ui/menu";
import { Notice } from "~/components/ui/notice";
import { Tooltip } from "~/components/ui/tooltip";
import { cn } from "~/lib/cn";
import { useStore } from "~/lib/store";

import { AppRow, CardEmpty } from "./app-row";
import { createRuleDraft } from "./rule-draft";
import { knownApps, sortedNames } from "./rule-apps";
import { initialAssignments } from "./rules-mock";
import type { RulesStore } from "./rules-store";
import { finderTitles, WindowRuleEditor } from "./window-rule-editor";
import { WorkspaceAssignments } from "./workspace-assignments";

const count = (n: number) => (n === 1 ? "1 app" : `${n} apps`);

export function RulesPage({ store }: { store: RulesStore }) {
  const { status, state, busy, refreshing, error } = useStore(store);
  const [draft, setDraft] = useState<{ rule: CustomWindowRule; editing: boolean } | null>(null);
  // The rule stays set while the dialog animates closed, so its wording does not change.
  const [removing, setRemoving] = useState<CustomWindowRule | null>(null);
  const [confirming, setConfirming] = useState(false);
  const [hot, setHot] = useState<string | null>(null);
  const add = (app = "", title = "") =>
    setDraft({ rule: createRuleDraft(app, title), editing: false });
  const locked = busy || !!state?.unavailableReason;
  async function remove(rule: CustomWindowRule) {
    if (!(await store.removeCustom(rule.id)))
      throw new Error(store.getSnapshot().error ?? "Could not remove the rule.");
  }

  return (
    <div className="@container">
      <PageHeader
        title="Rules"
        actions={
          state ? (
            <Menu>
              <Tooltip content="Float an app, or only some of its windows">
                <MenuTrigger render={<Button size="sm" disabled={locked} />}>
                  <Plus aria-hidden />
                  Add
                </MenuTrigger>
              </Tooltip>
              <MenuPopup align="end">
                <MenuItem onClick={() => void store.addApplication()}>Add application…</MenuItem>
                <MenuItem onClick={() => add()}>Add custom rule…</MenuItem>
                <MenuSeparator />
                <MenuItem onClick={() => add("Finder", finderTitles)}>
                  Finder file dialogs…
                </MenuItem>
                <MenuItem onClick={() => add("Calculator")}>Calculator…</MenuItem>
              </MenuPopup>
            </Menu>
          ) : undefined
        }
      />
      <div className="flex flex-col gap-4">
        {error ? (
          <Notice.Root variant="error">
            <Notice.Title>
              {status === "failed" ? "Could not read your rules" : "Window rules failed"}
            </Notice.Title>
            <Notice.Description>{error}</Notice.Description>
            <Notice.Actions>
              <Button size="sm" disabled={busy || refreshing} onClick={() => void store.refresh()}>
                Try again
              </Button>
            </Notice.Actions>
          </Notice.Root>
        ) : null}
        {state?.unavailableReason ? (
          <Notice.Root variant="warning">
            <Notice.Title>Showing your saved rules</Notice.Title>
            <Notice.Description>{state.unavailableReason}</Notice.Description>
            <Notice.Actions>
              <Button size="sm" disabled={busy || refreshing} onClick={() => void store.refresh()}>
                Try again
              </Button>
            </Notice.Actions>
          </Notice.Root>
        ) : null}
        <p role="status" className={cn("text-meta text-fg-secondary", !busy && "sr-only")}>
          {busy ? "Updating rules…" : ""}
        </p>
        {state ? (
          <>
            <Card aria-labelledby="rules-floating">
              <CardHeader
                id="rules-floating"
                title="Floating apps"
                help="These apps keep their own window size and position instead of being tiled. The list survives a restart of the window manager."
                action={<Badge>{count(state.floatingApps.length)}</Badge>}
              />
              <CardRows>
                {state.floatingApps.length === 0 ? (
                  <CardEmpty icon={<AppWindow />} title="No floating apps" />
                ) : (
                  sortedNames(state.floatingApps).map((app) => (
                    <AppRow
                      key={app}
                      app={app}
                      icon={state.icons[app]}
                      hot={hot === app}
                      onHot={setHot}
                    >
                      <Button
                        size="sm"
                        variant="ghost"
                        disabled={locked}
                        onClick={() => void store.removeFloating(app)}
                      >
                        <LayoutGrid aria-hidden />
                        Tile instead
                        <span className="sr-only"> of floating {app}</span>
                      </Button>
                    </AppRow>
                  ))
                )}
                <div data-row="" className="px-5 py-3.5">
                  <Tooltip content="Choose from your applications">
                    <button
                      type="button"
                      aria-label="Add an app to float"
                      disabled={locked}
                      onClick={() => void store.addApplication()}
                      className={cn(
                        "flex h-[34px] w-full items-center gap-2 rounded-control border border-hairline bg-card px-2.5 text-left text-body text-fg-tertiary transition-colors hover:border-line-strong hover:text-fg-secondary disabled:pointer-events-none disabled:opacity-50",
                        focusRing,
                      )}
                    >
                      <Plus aria-hidden className="size-3.5 shrink-0" />
                      <span className="min-w-0 flex-1 truncate">Add an app to float</span>
                      <span aria-hidden className="shrink-0 text-caption">
                        Choose…
                      </span>
                    </button>
                  </Tooltip>
                </div>
              </CardRows>
            </Card>

            <Card aria-labelledby="rules-custom">
              <CardHeader
                id="rules-custom"
                title="Custom rules"
                help="Match an application and optional window title pattern. Use a preset from Add, or write your own."
                action={
                  <Button size="sm" disabled={locked} onClick={() => add()}>
                    <Plus aria-hidden />
                    Add
                  </Button>
                }
              />
              <CardRows>
                {state.customRules.length === 0 ? (
                  <CardEmpty icon={<ListFilter />} title="No custom rules" />
                ) : (
                  state.customRules.map((rule) => (
                    <AppRow
                      key={rule.id}
                      app={rule.app}
                      icon={state.icons[rule.app]}
                      detail={rule.title || "All windows"}
                      detailMono={!!rule.title}
                      hot={hot === rule.app}
                      onHot={setHot}
                      disabled={locked}
                      onOpen={() => setDraft({ rule: { ...rule }, editing: true })}
                      openLabel={`Edit rule for ${rule.app}`}
                    >
                      <IconButton
                        label={`Remove rule for ${rule.app}`}
                        tone="danger"
                        disabled={locked}
                        onClick={() => {
                          setRemoving(rule);
                          setConfirming(true);
                        }}
                      >
                        <Trash2 aria-hidden />
                      </IconButton>
                    </AppRow>
                  ))
                )}
              </CardRows>
            </Card>

            {state.externalRules.length ? (
              <Card aria-labelledby="rules-external">
                <CardHeader
                  id="rules-external"
                  title="External rules"
                  help="Rules managed outside Macarchy. Change them in your window manager configuration."
                />
                <CardRows>
                  {state.externalRules
                    .toSorted((a, b) => a.app.localeCompare(b.app))
                    .map((rule, index) => (
                      <AppRow
                        // External rules have no identifier, and one app can have several.
                        key={index}
                        app={rule.app}
                        icon={state.icons[rule.app]}
                        detail={rule.title ? `Windows matching ${rule.title}` : "All windows"}
                        hot={hot === rule.app}
                        onHot={setHot}
                        badge={<Badge>Read only</Badge>}
                      />
                    ))}
                </CardRows>
              </Card>
            ) : null}

            <WorkspaceAssignments
              // Mock: the sample assignments name apps the rules may not know yet.
              apps={knownApps(
                state,
                initialAssignments.map((assignment) => assignment.app),
              )}
              icons={state.icons}
              hot={hot}
              onHot={setHot}
            />

            <Card>
              <Row
                title="Every other app"
                control={
                  <Badge>
                    <LayoutGrid aria-hidden className="size-3" />
                    Tiled
                  </Badge>
                }
              />
            </Card>
          </>
        ) : null}
      </div>
      {draft ? (
        <WindowRuleEditor
          rule={draft.rule}
          editing={draft.editing}
          store={store}
          close={() => setDraft(null)}
        />
      ) : null}
      <ConfirmDialog
        open={confirming && removing !== null}
        onOpenChange={setConfirming}
        title={`Remove the rule for ${removing?.app ?? "this app"}?`}
        description={
          removing?.title
            ? `Windows matching ${removing.title} go back to being tiled. Your current rules are kept in a backup you can restore from Advanced.`
            : "Its windows go back to being tiled. Your current rules are kept in a backup you can restore from Advanced."
        }
        confirmLabel="Remove rule"
        busyLabel="Removing…"
        tone="danger"
        onConfirm={() => remove(removing!)}
      />
    </div>
  );
}
