import { useId } from "react";

import type {
  LayoutMode,
  LayoutValues,
  MouseDropAction,
  MouseModifier,
  SplitType,
  WindowPlacement,
} from "~/bridge/protocol";
import { PageHeader } from "~/components/layout/page-header";
import { SectionHeading } from "~/components/layout/section-heading";
import { SettingRow } from "~/components/layout/setting-row";
import { SettingsSection } from "~/components/layout/settings-section";
import { Button } from "~/components/ui/button";
import { ChoiceCard } from "~/components/ui/choice-card";
import { Notice } from "~/components/ui/notice";
import { Select, type SelectOption } from "~/components/ui/select";
import { Switch } from "~/components/ui/switch";
import { Tooltip } from "~/components/ui/tooltip";
import { ValueSlider } from "~/components/ui/value-slider";
import { useStore } from "~/lib/store";

import { LayoutPreview } from "./layout-preview";
import type { LayoutStore } from "./layout-store";

const layoutChoices: { mode: LayoutMode; title: string; help: string }[] = [
  { mode: "bsp", title: "Tile", help: "Fit windows neatly beside each other" },
  { mode: "stack", title: "Stack", help: "Keep windows together and switch between them" },
  { mode: "float", title: "Freeform", help: "Move and resize windows yourself" },
];

const splitOptions: SelectOption<SplitType>[] = [
  { value: "auto", label: "Automatic" },
  { value: "vertical", label: "Side by side" },
  { value: "horizontal", label: "Above and below" },
];

const placementOptions: SelectOption<WindowPlacement>[] = [
  { value: "second_child", label: "After current" },
  { value: "first_child", label: "Before current" },
];

const modifierOptions: SelectOption<MouseModifier>[] = [
  { value: "ctrl", label: "Control" },
  { value: "alt", label: "Option" },
  { value: "cmd", label: "Command" },
  { value: "shift", label: "Shift" },
];

const dropOptions: SelectOption<MouseDropAction>[] = [
  { value: "stack", label: "Stack together" },
  { value: "swap", label: "Swap places" },
];

export function LayoutPage({ store }: { store: LayoutStore }) {
  const snapshot = useStore(store);
  const gapId = useId();
  const paddingId = useId();

  if (snapshot.status === "loading") return null;

  if (snapshot.status === "failed" || !snapshot.state) {
    return (
      <>
        <PageHeader title="Layout" subtitle="Give every window a place." />
        <Notice.Root variant="error">
          <Notice.Title>Could not read your layout</Notice.Title>
          <Notice.Description>{snapshot.loadError}</Notice.Description>
          <Notice.Actions>
            <Button disabled={snapshot.refreshing} onClick={() => void store.refresh()}>
              Try again
            </Button>
          </Notice.Actions>
        </Notice.Root>
      </>
    );
  }

  const { state, linkPadding } = snapshot;
  const values = state.values;
  const readOnly = state.source !== "daemon";
  const edit =
    <F extends keyof LayoutValues>(field: F) =>
    (value: LayoutValues[F]) =>
      store.edit(field, value);

  return (
    <>
      <PageHeader title="Layout" subtitle="Give every window a place." />

      {snapshot.error ? (
        <Notice.Root variant="error">
          <div className="flex items-start gap-2">
            <div className="flex min-w-0 flex-1 flex-col gap-0.5">
              <Notice.Title>Could not apply that change</Notice.Title>
              <Notice.Description>{snapshot.error}</Notice.Description>
            </div>
            <Notice.Dismiss onClick={() => store.dismissError()} />
          </div>
        </Notice.Root>
      ) : null}

      {readOnly ? (
        <Notice.Root variant="warning">
          <Notice.Title>Showing your saved layout</Notice.Title>
          <Notice.Description>
            {state.unavailableReason ??
              "The desktop could not be reached, so changes cannot apply."}
          </Notice.Description>
          <Notice.Actions>
            <Button disabled={snapshot.refreshing} onClick={() => void store.refresh()}>
              Try again
            </Button>
          </Notice.Actions>
        </Notice.Root>
      ) : null}

      <SettingsSection
        title="Your workspace"
        help="Illustrative preview. Changes apply to the desktop as you edit."
      >
        <div className="h-[254px] p-3">
          <LayoutPreview
            mode={values.layout}
            gap={values.windowGap}
            padding={values.padding}
            wallpaper={state.wallpaper}
          />
        </div>
      </SettingsSection>

      <div className="flex flex-col gap-3">
        <SectionHeading title="Choose your layout" />
        <div role="group" aria-label="Choose your layout" className="grid grid-cols-3 gap-4">
          {layoutChoices.map((choice) => (
            <Tooltip key={choice.mode} content={choice.help}>
              <ChoiceCard
                label={choice.title}
                selected={values.layout === choice.mode}
                previewHeight={95}
                disabled={readOnly}
                onClick={() => store.edit("layout", choice.mode)}
                preview={
                  <LayoutPreview mode={choice.mode} gap={12} padding={18} wallpaper={null} />
                }
              />
            </Tooltip>
          ))}
        </div>
      </div>

      <SettingsSection
        title="Window arrangement"
        help="Choose where new windows appear and how they share the available space."
        disabled={values.layout !== "bsp"}
      >
        <SettingRow
          title="Split direction"
          help="Place tiled windows side by side or one above the other. Automatic chooses for the available space."
        >
          <Select
            label="Split direction"
            value={values.splitType}
            options={splitOptions}
            disabled={readOnly || values.layout !== "bsp"}
            onValueChange={edit("splitType")}
          />
        </SettingRow>
        <SettingRow
          title="New windows"
          help="Choose which side of the current window gets a newly opened window."
        >
          <Select
            label="New windows"
            value={values.windowPlacement}
            options={placementOptions}
            disabled={readOnly || values.layout !== "bsp"}
            onValueChange={edit("windowPlacement")}
          />
        </SettingRow>
        <SettingRow
          title="Balance window sizes"
          help="Automatically share space more evenly when windows are added or removed."
        >
          <Switch
            aria-label="Balance window sizes"
            checked={values.autoBalance}
            disabled={readOnly || values.layout !== "bsp"}
            onCheckedChange={edit("autoBalance")}
          />
        </SettingRow>
      </SettingsSection>

      <SettingsSection title="Room to breathe">
        <SettingRow
          title="Between windows"
          help="The empty space separating neighbouring windows."
          controlId={gapId}
        >
          <ValueSlider
            id={gapId}
            label="Between windows"
            value={values.windowGap}
            min={0}
            max={32}
            unit="pt"
            disabled={readOnly}
            onValueChange={edit("windowGap")}
          />
        </SettingRow>
        <SettingRow
          title="Match all screen edges"
          help="Keep the same margin around every edge. When off, the margin control changes only the top edge."
        >
          <Switch
            aria-label="Match all screen edges"
            checked={linkPadding}
            disabled={readOnly}
            onCheckedChange={(checked) => store.setLinkPadding(checked)}
          />
        </SettingRow>
        <SettingRow
          title={linkPadding ? "Screen margins" : "Top margin"}
          help="Leave space between your windows and the edge of the display."
          controlId={paddingId}
        >
          <ValueSlider
            id={paddingId}
            label={linkPadding ? "Screen margins" : "Top margin"}
            value={values.padding}
            min={0}
            max={40}
            unit="pt"
            disabled={readOnly}
            onValueChange={edit("padding")}
          />
        </SettingRow>
      </SettingsSection>

      <SettingsSection title="Mouse and movement">
        <SettingRow
          title="Hold to move or resize"
          help="Hold this key while dragging a window to move or resize it."
        >
          <Select
            label="Modifier key"
            value={values.mouseModifier}
            options={modifierOptions}
            disabled={readOnly}
            onValueChange={edit("mouseModifier")}
          />
        </SettingRow>
        <SettingRow
          title="Move pointer to focused window"
          help="Bring the pointer to the window you switch to using your keyboard."
        >
          <Switch
            aria-label="Move pointer to focused window"
            checked={values.mouseFollowsFocus}
            disabled={readOnly}
            onCheckedChange={edit("mouseFollowsFocus")}
          />
        </SettingRow>
        <SettingRow
          title="Drop onto another window"
          help="Group the two windows into a stack, or exchange their positions."
        >
          <Select
            label="Drop action"
            value={values.mouseDropAction}
            options={dropOptions}
            disabled={readOnly}
            onValueChange={edit("mouseDropAction")}
          />
        </SettingRow>
      </SettingsSection>
    </>
  );
}
