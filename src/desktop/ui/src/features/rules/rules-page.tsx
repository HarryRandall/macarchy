import { MinusCircle, Pencil, Plus } from "lucide-react";
import { useState } from "react";

import type { CustomWindowRule } from "~/bridge/protocol";
import { PageHeader } from "~/components/layout/page-header";
import { SettingRow } from "~/components/layout/setting-row";
import { SettingsSection } from "~/components/layout/settings-section";
import { AppIcon } from "~/components/ui/app-icon";
import { Badge } from "~/components/ui/badge";
import { Button } from "~/components/ui/button";
import { ConfirmDialog } from "~/components/ui/confirm-dialog";
import { IconButton } from "~/components/ui/icon-button";
import { ListRow } from "~/components/ui/list-row";
import { Menu, MenuItem, MenuPopup, MenuSeparator, MenuTrigger } from "~/components/ui/menu";
import { Notice } from "~/components/ui/notice";
import { Tooltip } from "~/components/ui/tooltip";
import { useStore } from "~/lib/store";

import { createRuleDraft } from "./rule-draft";
import type { RulesStore } from "./rules-store";
import { finderTitles, WindowRuleEditor } from "./window-rule-editor";

export function RulesPage({ store }: { store: RulesStore }) {
  const { status, state, busy, refreshing, error } = useStore(store);
  const [draft, setDraft] = useState<{ rule: CustomWindowRule; editing: boolean } | null>(null);
  // The rule stays set while the dialog animates closed, so its wording does not change.
  const [removing, setRemoving] = useState<CustomWindowRule | null>(null);
  const [confirming, setConfirming] = useState(false);
  const add = (app = "", title = "") =>
    setDraft({ rule: createRuleDraft(app, title), editing: false });
  const locked = busy || !!state?.unavailableReason;
  async function remove(rule: CustomWindowRule) {
    if (!(await store.removeCustom(rule.id)))
      throw new Error(store.getSnapshot().error ?? "Could not remove the rule.");
  }

  return (
    <>
      <PageHeader
        title="Rules"
        subtitle="Apps that sit outside the layout."
        actions={
          state ? (
            <Tooltip content="Add an app to float all its windows, or a custom rule for specific window titles.">
              <span>
                <Menu>
                  <MenuTrigger render={<Button disabled={locked} />}>
                    <Plus aria-hidden />
                    Add
                  </MenuTrigger>
                  <MenuPopup align="end">
                    <MenuItem onClick={() => void store.addApplication()}>
                      Add application…
                    </MenuItem>
                    <MenuItem onClick={() => add()}>Add custom rule…</MenuItem>
                    <MenuSeparator />
                    <MenuItem onClick={() => add("Finder", finderTitles)}>
                      Finder file dialogs…
                    </MenuItem>
                    <MenuItem onClick={() => add("Calculator")}>Calculator…</MenuItem>
                  </MenuPopup>
                </Menu>
              </span>
            </Tooltip>
          ) : undefined
        }
      />
      {error ? (
        <Notice.Root variant="error">
          <Notice.Title>
            {status === "failed" ? "Could not read your rules" : "Window rules failed"}
          </Notice.Title>
          <Notice.Description>{error}</Notice.Description>
          <Notice.Actions>
            <Button disabled={busy || refreshing} onClick={() => void store.refresh()}>
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
            <Button disabled={busy || refreshing} onClick={() => void store.refresh()}>
              Try again
            </Button>
          </Notice.Actions>
        </Notice.Root>
      ) : null}
      {busy ? (
        <p role="status" className="text-meta text-fg-secondary">
          Updating rules…
        </p>
      ) : null}
      {state ? (
        <>
          <SettingsSection
            title="Floating apps"
            help="These apps keep their own window size and position instead of being tiled. The list survives a restart of the window manager."
          >
            {state.floatingApps.length === 0 ? (
              <SettingRow
                title="No floating apps yet"
                help="Use Add application to choose an app that should stay outside the tiled layout."
              />
            ) : null}
            {state.floatingApps
              .toSorted((a, b) => a.localeCompare(b))
              .map((app) => (
                <ListRow
                  key={app}
                  title={app}
                  leading={<AppIcon src={state.icons[app]} />}
                  actions={
                    <IconButton
                      label={`Stop floating ${app}`}
                      disabled={locked}
                      onClick={() => void store.removeFloating(app)}
                    >
                      <MinusCircle aria-hidden />
                    </IconButton>
                  }
                />
              ))}
          </SettingsSection>
          <SettingsSection
            title="Custom rules"
            help="Match an application and optional window title pattern. Use a preset or add your own."
          >
            {state.customRules.length === 0 ? (
              <SettingRow
                title="No custom rules"
                help="Choose Add custom rule or a preset from the Add menu."
              />
            ) : null}
            {state.customRules.map((rule) => (
              <ListRow
                key={rule.id}
                title={rule.app}
                detail={rule.title || "All windows"}
                leading={<AppIcon src={state.icons[rule.app]} />}
                actions={
                  <>
                    <IconButton
                      label={`Edit rule for ${rule.app}`}
                      disabled={locked}
                      onClick={() => setDraft({ rule: { ...rule }, editing: true })}
                    >
                      <Pencil aria-hidden />
                    </IconButton>
                    <IconButton
                      label={`Remove rule for ${rule.app}`}
                      disabled={locked}
                      onClick={() => {
                        setRemoving(rule);
                        setConfirming(true);
                      }}
                    >
                      <MinusCircle aria-hidden />
                    </IconButton>
                  </>
                }
              />
            ))}
          </SettingsSection>
          {state.externalRules.length ? (
            <SettingsSection
              title="External rules"
              help="Rules managed outside Macarchy. Change them in your window manager configuration."
            >
              {state.externalRules
                .toSorted((a, b) => a.app.localeCompare(b.app))
                .map((rule, index) => (
                  <ListRow
                    key={index}
                    title={rule.app}
                    detail={rule.title ? `Windows matching ${rule.title}` : undefined}
                    leading={<AppIcon src={state.icons[rule.app]} />}
                    trailing={<Badge>Read only</Badge>}
                  />
                ))}
            </SettingsSection>
          ) : null}
        </>
      ) : null}
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
    </>
  );
}
