import { useId } from "react";
import { PageHeader } from "~/components/layout/page-header";
import { SettingRow } from "~/components/layout/setting-row";
import { CardContent, SectionAction, SettingsSection } from "~/components/layout/settings-section";
import { AppIcon } from "~/components/ui/app-icon";
import { Button } from "~/components/ui/button";
import { ColourWell } from "~/components/ui/colour-well";
import { HelpTooltip } from "~/components/ui/help-tooltip";
import { Notice } from "~/components/ui/notice";
import { SegmentedControl } from "~/components/ui/segmented-control";
import { Switch } from "~/components/ui/switch";
import { ValueSlider } from "~/components/ui/value-slider";
import { useStore } from "~/lib/store";
import { BorderPreview } from "./border-preview";
import type { BordersStore } from "./borders-store";

export function BordersPage({ store }: { store: BordersStore }) {
  const snapshot = useStore(store);
  const widthId = useId();
  const radiusId = useId();
  const { state, draft, applied, applying, live } = snapshot;
  if (snapshot.status === "loading") return null;
  const header = (
    <PageHeader title="Borders" subtitle="The outline drawn around the focused window." />
  );
  if (!state || !draft || !applied)
    return (
      <>
        {header}
        <Notice.Root variant="error">
          <Notice.Title>Could not read your borders</Notice.Title>
          <Notice.Description>{snapshot.loadError}</Notice.Description>
          <Notice.Actions>
            <Button onClick={() => void store.load()}>Try again</Button>
          </Notice.Actions>
        </Notice.Root>
      </>
    );
  const dirty = JSON.stringify(draft) !== JSON.stringify(applied);
  const disabled = applying || !!state.unavailableReason;
  const preset =
    draft.radius === null
      ? "system"
      : draft.radius === 0.3
        ? "square"
        : draft.radius === 8
          ? "rounded"
          : "custom";
  return (
    <>
      {header}
      {state.unavailableReason ? (
        <Notice.Root variant="warning">
          <Notice.Title>Showing your saved borders</Notice.Title>
          <Notice.Description>{state.unavailableReason}</Notice.Description>
          <Notice.Actions>
            <Button onClick={() => void store.load()}>Try again</Button>
          </Notice.Actions>
        </Notice.Root>
      ) : null}
      <div className={live ? "" : "sticky top-0 z-10 bg-page pb-4"}>
        <SettingsSection>
          <CardContent>
            <div className="flex items-center gap-2">
              <Switch
                aria-label="Live preview"
                checked={live}
                disabled={!live && (applying || dirty || disabled)}
                onCheckedChange={(value) => store.setLive(value)}
              />
              <span className="text-row-title">Live preview</span>
              <HelpTooltip text="Apply edits straight away, or hold them for a before and after" />
              {!live ? (
                <div className="ml-auto flex gap-2">
                  <Button disabled={!dirty || applying} onClick={() => store.discard()}>
                    Discard
                  </Button>
                  <Button
                    variant="primary"
                    disabled={!dirty || disabled}
                    onClick={() => void store.apply()}
                  >
                    {applying ? "Applying..." : "Apply"}
                  </Button>
                </div>
              ) : null}
            </div>
            <BorderPreview
              draft={draft}
              before={live ? null : applied}
              wallpaper={state.wallpaper}
            />
            {applying || dirty ? (
              <p role="status" className="text-right text-row-detail text-fg-secondary">
                {applying ? "Applying..." : "Unsaved changes"}
              </p>
            ) : null}
            {snapshot.externalChange ? (
              <p role="status" className="text-row-detail text-fg-secondary">
                Borders changed elsewhere. Your draft is kept. Discard to load the latest settings.
              </p>
            ) : null}
            {snapshot.error ? (
              <Notice.Root variant="error">
                <Notice.Description>{snapshot.error}</Notice.Description>
              </Notice.Root>
            ) : null}
          </CardContent>
        </SettingsSection>
      </div>
      <SettingsSection
        title="Colour"
        help="Edit colour, opacity or hex values. Apply saves them to the active theme."
        action={
          <SectionAction
            disabled={
              disabled ||
              !state.defaults ||
              (draft.activeColour === state.defaults.activeColour &&
                draft.inactiveColour === state.defaults.inactiveColour)
            }
            tooltip="Restore this theme's original border colours"
            onClick={() =>
              state.defaults &&
              store.edit({
                activeColour: state.defaults.activeColour,
                inactiveColour: state.defaults.inactiveColour,
              })
            }
          >
            Theme colours
          </SectionAction>
        }
      >
        <SettingRow title="Active" help="The window with focus">
          <ColourWell
            label="Active border colour"
            format="argb"
            value={draft.activeColour}
            disabled={disabled}
            onValueChange={(activeColour) => store.edit({ activeColour })}
          />
        </SettingRow>
        <SettingRow title="Inactive" help="Every other window">
          <ColourWell
            label="Inactive border colour"
            format="argb"
            value={draft.inactiveColour}
            disabled={disabled}
            onValueChange={(inactiveColour) => store.edit({ inactiveColour })}
          />
        </SettingRow>
      </SettingsSection>
      <SettingsSection
        title="Geometry"
        help="Width applies to every outlined window."
        action={
          <SectionAction
            disabled={disabled || (draft.width === 6 && draft.visible)}
            tooltip="Restore 6 pt width and turn borders on"
            onClick={() => store.edit({ width: 6, visible: true })}
          >
            Reset
          </SectionAction>
        }
      >
        <SettingRow title="Show borders" help="Outline the window that has focus">
          <Switch
            aria-label="Show borders"
            checked={draft.visible}
            disabled={disabled}
            onCheckedChange={(visible) => store.edit({ visible })}
          />
        </SettingRow>
        <SettingRow title="Width" help="Thickness of the outline" controlId={widthId}>
          <ValueSlider
            id={widthId}
            label="Width"
            value={draft.width}
            min={0}
            max={16}
            step={0.5}
            unit="pt"
            disabled={disabled || !draft.visible}
            onValueChange={(width) => store.edit({ width })}
          />
        </SettingRow>
      </SettingsSection>
      <SettingsSection
        title="Corners"
        help="Corner changes affect newly opened windows. Relaunch an app to see them."
        action={
          <SectionAction
            disabled={disabled || draft.radius === null}
            tooltip="Let macOS choose corners for new windows"
            onClick={() => store.edit({ radius: null })}
          >
            Use default
          </SectionAction>
        }
      >
        <SettingRow title="Shape">
          <SegmentedControl
            label="Shape"
            value={preset}
            disabled={disabled}
            options={[
              { value: "system", label: "Default" },
              { value: "square", label: "Square" },
              { value: "rounded", label: "Rounded" },
            ]}
            onValueChange={(value) =>
              store.edit({ radius: value === "system" ? null : value === "square" ? 0.3 : 8 })
            }
          />
        </SettingRow>
        <SettingRow
          title="Corner radius"
          controlId={draft.radius === null ? undefined : radiusId}
          detail={
            preset === "system"
              ? "Managed by macOS"
              : preset === "square"
                ? "Square preset"
                : preset === "rounded"
                  ? "Rounded preset"
                  : "Custom radius"
          }
        >
          {draft.radius === null ? (
            <span className="text-row-title text-fg-secondary">System default</span>
          ) : (
            <ValueSlider
              id={radiusId}
              label="Corner radius"
              value={draft.radius}
              min={0.3}
              max={12}
              step={0.1}
              unit="pt"
              disabled={disabled}
              onValueChange={(radius) => store.edit({ radius })}
            />
          )}
        </SettingRow>
      </SettingsSection>
      <SettingsSection
        title="Excluded apps"
        help="These apps are never outlined. Add or remove apps to choose which windows have borders."
        action={
          <SectionAction
            disabled={disabled || !draft.excludedApps.length}
            tooltip="Remove all exclusions"
            onClick={() => store.edit({ excludedApps: [] })}
          >
            Clear all
          </SectionAction>
        }
      >
        {draft.excludedApps.map((app) => (
          <SettingRow key={app} title={app}>
            <div className="flex items-center gap-3">
              <AppIcon src={state.applicationIcons[app]} />
              <Button
                variant="ghost"
                size="sm"
                disabled={disabled}
                aria-label={"Stop excluding " + app}
                onClick={() =>
                  store.edit({ excludedApps: draft.excludedApps.filter((name) => name !== app) })
                }
              >
                −
              </Button>
            </div>
          </SettingRow>
        ))}
        <CardContent>
          <div>
            <Button disabled={disabled} onClick={() => void store.pickApplication()}>
              Add Application…
            </Button>
          </div>
        </CardContent>
      </SettingsSection>
    </>
  );
}
