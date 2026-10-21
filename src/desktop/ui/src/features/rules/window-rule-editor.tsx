import { ChevronDown } from "lucide-react";
import { useState } from "react";

import type { CustomWindowRule } from "~/bridge/protocol";
import { Button } from "~/components/ui/button";
import { Dialog } from "~/components/ui/dialog";
import { Menu, MenuItem, MenuPopup, MenuTrigger } from "~/components/ui/menu";
import { Notice } from "~/components/ui/notice";
import { TextField } from "~/components/ui/text-field";
import { Tooltip } from "~/components/ui/tooltip";
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
  const { busy, state } = useStore(store);
  const unavailable = state?.unavailableReason ?? null;
  const preset = (presetApp: string, presetTitle: string) => {
    setApp(presetApp);
    setTitle(presetTitle);
    setError(null);
  };

  async function save() {
    if (await store.saveCustom({ id: rule.id, app, title }, editing)) close();
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
      <Dialog.Popup size="sm" className="w-[460px]">
        <form
          className="contents"
          onSubmit={(event) => {
            event.preventDefault();
            if (!busy && !unavailable && app.trim()) void save();
          }}
        >
          <Dialog.Header
            closable={!busy}
            actions={
              <Menu>
                <Tooltip content="Fill the fields with a common rule">
                  <MenuTrigger render={<Button size="sm" variant="ghost" disabled={busy} />}>
                    Presets
                    <ChevronDown aria-hidden />
                  </MenuTrigger>
                </Tooltip>
                <MenuPopup align="end">
                  <MenuItem onClick={() => preset("Finder", finderTitles)}>
                    Finder file dialogs
                  </MenuItem>
                  <MenuItem onClick={() => preset("Calculator", "")}>Calculator</MenuItem>
                  <MenuItem onClick={() => preset("", "")}>Blank rule</MenuItem>
                </MenuPopup>
              </Menu>
            }
          >
            <Dialog.Title help="Matching windows float outside the tiled layout. Nothing changes until you Save.">
              {editing ? "Edit custom rule" : "Add custom rule"}
            </Dialog.Title>
          </Dialog.Header>
          <Dialog.Body>
            <TextField
              label="Application"
              description="The app's name exactly as macOS shows it."
              placeholder="For example, Finder"
              value={app}
              disabled={busy}
              onValueChange={setApp}
            />
            <TextField
              label="Window title"
              variant="mono"
              description="Optional regular expression, such as ^Copy$. Empty matches every window."
              placeholder="All windows"
              value={title}
              disabled={busy}
              onValueChange={setTitle}
            />
            {unavailable ? (
              <Notice.Root variant="warning">
                <Notice.Description>{unavailable}</Notice.Description>
              </Notice.Root>
            ) : null}
            {error ? (
              <Notice.Root variant="error">
                <Notice.Description>{error}</Notice.Description>
              </Notice.Root>
            ) : null}
          </Dialog.Body>
          <Dialog.Footer>
            <Button size="sm" disabled={busy} onClick={close}>
              Cancel
            </Button>
            <Button
              type="submit"
              size="sm"
              variant="primary"
              disabled={!app.trim() || !!unavailable}
              busy={busy}
            >
              {busy ? "Saving…" : "Save"}
            </Button>
          </Dialog.Footer>
        </form>
      </Dialog.Popup>
    </Dialog.Root>
  );
}
