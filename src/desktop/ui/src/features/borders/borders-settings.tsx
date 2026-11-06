import { Plus, X } from "lucide-react";
import type { BorderAppearance, BordersState } from "~/bridge/contract/borders";
import { AppIcon } from "~/components/ui/app-icon";
import { Button } from "~/components/ui/button";
import { Card, Row } from "~/components/ui/card";
import { Chip } from "~/components/ui/chip";
import { ColourWell } from "~/components/ui/colour-well";
import { IconButton } from "~/components/ui/icon-button";
import { SegmentedControl } from "~/components/ui/segmented-control";
import { SwatchPicker } from "~/components/ui/swatches";
import { Switch } from "~/components/ui/switch";
import { Tooltip } from "~/components/ui/tooltip";
import { ValueSlider } from "~/components/ui/value-slider";
import { cn } from "~/lib/cn";
import { borderHex, cornerPreset, followsTheme, presetRadius, withHex } from "./borders-format";

/** Heading strip that starts a group of rows inside the settings card. */
function GroupHeader({ title, first }: { title: string; first?: boolean }) {
  return (
    <h3
      className={cn(
        "border-b border-hairline bg-side px-5 py-2 text-label text-fg-tertiary uppercase",
        !first && "border-t",
      )}
    >
      {title}
    </h3>
  );
}

function ColourControl({
  label,
  value,
  presets,
  disabled,
  onChange,
}: {
  label: string;
  value: string | null;
  presets: readonly string[];
  disabled: boolean;
  onChange: (value: string) => void;
}) {
  return (
    <div className="flex flex-wrap items-center justify-end gap-3">
      <ColourWell
        label={label}
        format="argb"
        value={value}
        disabled={disabled}
        onValueChange={onChange}
      />
      {presets.length ? (
        <SwatchPicker
          label={`${label} presets`}
          colours={presets}
          value={borderHex(value) ?? ""}
          disabled={disabled}
          onValueChange={(hex) => {
            const next = withHex(value, hex);
            if (next) onChange(next);
          }}
        />
      ) : null}
    </div>
  );
}

/** Shape, colour and behaviour, each edit going into the store's draft. */
export function BordersSettings({
  state,
  draft,
  themeTitle,
  activePresets,
  inactivePresets,
  locked,
  onEdit,
  onPickApplication,
}: {
  state: BordersState;
  draft: BorderAppearance;
  themeTitle: string | null;
  activePresets: readonly string[];
  inactivePresets: readonly string[];
  /** Borders cannot be changed at all, such as when the tool is missing. */
  locked: boolean;
  onEdit: (patch: Partial<BorderAppearance>) => void;
  onPickApplication: () => void;
}) {
  const off = locked || !draft.visible;
  const preset = cornerPreset(draft.radius);
  const following = followsTheme(draft, state.defaults);
  const defaults = state.defaults;
  return (
    <Card
      className={cn(
        "overflow-hidden transition-opacity motion-reduce:transition-none",
        !draft.visible && "opacity-60",
      )}
    >
      <GroupHeader title="Shape" first />
      <Row
        title="Width"
        control={
          <ValueSlider
            label="Border width"
            value={draft.width}
            min={0}
            max={16}
            step={0.5}
            unit="pt"
            width={140}
            disabled={off}
            onValueChange={(width) => onEdit({ width })}
          />
        }
      />
      <Row
        title="Corners"
        description={
          draft.radius === null ? "Managed by macOS" : "New windows only; relaunch an app to see it"
        }
        control={
          <SegmentedControl
            label="Corners"
            size="sm"
            value={preset}
            disabled={off}
            options={[
              { value: "system", label: "Default" },
              { value: "square", label: "Square" },
              { value: "rounded", label: "Rounded" },
            ]}
            onValueChange={(value) => {
              if (value !== "custom") onEdit({ radius: presetRadius(value) });
            }}
          />
        }
      />
      {draft.radius === null ? null : (
        <Row
          title="Radius"
          description={preset === "custom" ? "Custom radius" : undefined}
          control={
            <ValueSlider
              label="Corner radius"
              value={draft.radius}
              min={0.3}
              max={12}
              step={0.1}
              unit="pt"
              width={140}
              disabled={off}
              onValueChange={(radius) => onEdit({ radius })}
            />
          }
        />
      )}

      <GroupHeader title="Colour" />
      <Row
        title="Follow theme"
        description={
          following
            ? `${themeTitle ?? "The theme"}'s colours`
            : defaults
              ? "Custom colours"
              : "This theme sets none"
        }
        control={
          <Tooltip
            content={
              following ? "Edit a colour below to use your own" : "Use this theme's border colours"
            }
          >
            <Switch
              aria-label="Follow theme"
              checked={following}
              readOnly={following}
              disabled={off || !defaults}
              onCheckedChange={(value) => {
                if (value && defaults)
                  onEdit({
                    activeColour: defaults.activeColour,
                    inactiveColour: defaults.inactiveColour,
                  });
              }}
            />
          </Tooltip>
        }
      />
      <Row
        title="Focused"
        control={
          <ColourControl
            label="Active border colour"
            value={draft.activeColour}
            presets={activePresets}
            disabled={off}
            onChange={(activeColour) => onEdit({ activeColour })}
          />
        }
      />
      <Row
        title="Unfocused"
        control={
          <ColourControl
            label="Inactive border colour"
            value={draft.inactiveColour}
            presets={inactivePresets}
            disabled={off}
            onChange={(inactiveColour) => onEdit({ inactiveColour })}
          />
        }
      />

      <GroupHeader title="Behaviour" />
      <Row
        title="HiDPI"
        control={
          <Tooltip content="Always on. Changing it is not available yet">
            <Switch
              aria-label="HiDPI rendering"
              aria-disabled
              checked
              readOnly
              className="opacity-50"
            />
          </Tooltip>
        }
      />
      <Row
        title="Excluded apps"
        description={draft.excludedApps.length ? undefined : "Every window is outlined"}
        control={
          <div className="flex flex-wrap items-center justify-end gap-1.5">
            {draft.excludedApps.map((app) => (
              <Chip
                key={app}
                className="max-w-48"
                icon={<AppIcon src={state.applicationIcons[app]} size={14} />}
                action={
                  <IconButton
                    label={`Stop excluding ${app}`}
                    size="sm"
                    tone="danger"
                    disabled={off}
                    className="size-4"
                    onClick={() =>
                      onEdit({ excludedApps: draft.excludedApps.filter((name) => name !== app) })
                    }
                  >
                    <X aria-hidden />
                  </IconButton>
                }
              >
                {app}
              </Chip>
            ))}
            <Button size="sm" variant="ghost" disabled={off} onClick={onPickApplication}>
              <Plus aria-hidden /> Add app
            </Button>
            {draft.excludedApps.length ? (
              <Button
                size="sm"
                variant="ghost"
                disabled={off}
                onClick={() => onEdit({ excludedApps: [] })}
              >
                Clear all
              </Button>
            ) : null}
          </div>
        }
      />
    </Card>
  );
}
