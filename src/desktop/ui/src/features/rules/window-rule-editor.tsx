import { useState } from "react";

import type { CustomWindowRule } from "~/bridge/protocol";
import { SettingRow } from "~/components/layout/setting-row";
import { SettingsSection } from "~/components/layout/settings-section";
import { Button } from "~/components/ui/button";
import { Dialog } from "~/components/ui/dialog";
import { HelpTooltip } from "~/components/ui/help-tooltip";
import { Menu, MenuItem, MenuPopup, MenuTrigger } from "~/components/ui/menu";
import { Notice } from "~/components/ui/notice";
import { TextField } from "~/components/ui/text-field";
import { useStore } from "~/lib/store";

import type { RulesStore } from "./rules-store";

export const finderTitles = "^Copy$|^Move$|^Delete$|^Trash$";

export function WindowRuleEditor({
  rule,
  editing,
  store,
  close,
}: {
  rule: CustomWindowRule;
  editing: boolean;
  store: RulesStore;
  close(): void;
}) {
  const [app, setApp] = useState(rule.app);
  const [title, setTitle] = useState(rule.title);
  const [error, setError] = useState<string | null>(null);
  const { busy } = useStore(store);
  const preset = (presetApp: string, presetTitle: string) => {
    setApp(presetApp);
    setTitle(presetTitle);
    setError(null);
  };

  async function save() {
    if (await store.saveCustom({ id: rule.id, app, title })) close();
    else setError(store.getSnapshot().error);
  }

  return (
    <Dialog.Root
      open
      onOpenChange={(open) => {
        if (!open && !busy) close();
      }}
      dismissOnEscape={!busy}
      dismissOnOutsidePress={false}
    >
      <Dialog.Popup>
        <form
          className="contents"
          onSubmit={(event) => {
            event.preventDefault();
            if (!busy && app.trim()) void save();
          }}
        >
          <Dialog.Header closable={!busy}>
            <Dialog.Title help="Matching windows float outside the tiled layout. Nothing changes until you Save.">
              {editing ? "Edit custom rule" : "Add custom rule"}
            </Dialog.Title>
          </Dialog.Header>
          <Dialog.Body>
            <SettingsSection title="Match windows">
              <SettingRow
                title="Application"
                help="Enter the application's display name exactly, for example Finder or Calculator."
              >
                <TextField
                  label="Application"
                  hideLabel
                  placeholder="For example, Finder"
                  value={app}
                  disabled={busy}
                  onValueChange={setApp}
                  fieldClassName="w-56"
                />
              </SettingRow>
              <SettingRow
                title="Window title"
                help="Optional regular expression. For example, ^Copy$ matches Copy exactly. Leave empty for all windows."
              >
                <TextField
                  label="Window title"
                  hideLabel
                  placeholder="All windows"
                  value={title}
                  disabled={busy}
                  onValueChange={setTitle}
                  fieldClassName="w-56"
                />
              </SettingRow>
            </SettingsSection>
            <div className="flex items-center gap-1">
              <Menu>
                <MenuTrigger render={<Button disabled={busy} />}>Presets</MenuTrigger>
                <MenuPopup>
                  <MenuItem onClick={() => preset("Finder", finderTitles)}>
                    Finder file dialogs
                  </MenuItem>
                  <MenuItem onClick={() => preset("Calculator", "")}>Calculator</MenuItem>
                  <MenuItem onClick={() => preset("", "")}>Blank rule</MenuItem>
                </MenuPopup>
              </Menu>
              <HelpTooltip text="Presets fill the fields. Adjust them and Save to enable the rule." />
            </div>
            {error ? (
              <Notice.Root variant="error">
                <Notice.Description>{error}</Notice.Description>
              </Notice.Root>
            ) : null}
          </Dialog.Body>
          <Dialog.Footer>
            <Button disabled={busy} onClick={close}>
              Cancel
            </Button>
            <Button type="submit" variant="primary" disabled={!app.trim() || busy}>
              {busy ? "Saving…" : "Save"}
            </Button>
          </Dialog.Footer>
        </form>
      </Dialog.Popup>
    </Dialog.Root>
  );
}
