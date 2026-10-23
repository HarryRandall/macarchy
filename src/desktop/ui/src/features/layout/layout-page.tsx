import { ChevronDown, FileCode2 } from "lucide-react";
import { useId, useState } from "react";

import type {
  LayoutMode,
  LayoutValues,
  MouseDropAction,
  MouseModifier,
  SplitType,
  WindowPlacement,
} from "~/bridge/protocol";
import { PageHeader } from "~/components/layout/page-header";
import { Button } from "~/components/ui/button";
import { Card, CardHeader, CardRows, Row } from "~/components/ui/card";
import { focusRingInset } from "~/components/ui/focus-ring";
import { Notice } from "~/components/ui/notice";
import { Stepper } from "~/components/ui/number-field";
import { SegmentedControl, type SegmentedOption } from "~/components/ui/segmented-control";
import { Switch } from "~/components/ui/switch";
import { ValueSlider } from "~/components/ui/value-slider";
import { cn } from "~/lib/cn";
import { useStore } from "~/lib/store";

import type { LayoutStore } from "./layout-store";
import { type Monitor, savedValueLines, splitHint } from "./tiling";
import { TilingPreview } from "./tiling-preview";

const modeOptions: SegmentedOption<LayoutMode>[] = [
  { value: "bsp", label: "BSP" },
  { value: "stack", label: "Stack" },
  { value: "float", label: "Float" },
];

const splitOptions: SegmentedOption<SplitType>[] = [
  { value: "auto", label: "Auto" },
  { value: "vertical", label: "Vertical" },
  { value: "horizontal", label: "Horizontal" },
];

const placementOptions: SegmentedOption<WindowPlacement>[] = [
  { value: "first_child", label: "First child" },
  { value: "second_child", label: "Second child" },
];

const modifierOptions: SegmentedOption<MouseModifier>[] = [
  { value: "ctrl", label: "ctrl" },
  { value: "alt", label: "alt" },
  { value: "cmd", label: "cmd" },
  { value: "shift", label: "shift" },
];

const dropOptions: SegmentedOption<MouseDropAction>[] = [
  { value: "stack", label: "Stack" },
  { value: "swap", label: "Swap" },
];

const monitorOptions: SegmentedOption<Monitor>[] = [
  { value: "landscape", label: "Landscape" },
  { value: "portrait", label: "Portrait" },
];

const sliderWidth = 120;

function summary(values: LayoutValues): string {
  if (values.layout === "stack") return "Stacked";
  if (values.layout === "float") return "Floating";
  return `BSP, ${values.windowGap}pt gaps`;
}

export function LayoutPage({ store }: { store: LayoutStore }) {
  const snapshot = useStore(store);
  const gapId = useId();
  const paddingId = useId();
  const savedId = useId();
  const [monitor, setMonitor] = useState<Monitor>("landscape");
  const [windows, setWindows] = useState(3);
  const [showSaved, setShowSaved] = useState(false);

  if (snapshot.status === "loading") return null;

  if (snapshot.status === "failed" || !snapshot.state) {
    return (
      <>
        <PageHeader title="Layout" />
        <Notice.Root variant="error">
          <Notice.Title>Could not read your layout</Notice.Title>
          <Notice.Description>{snapshot.loadError}</Notice.Description>
          <Notice.Actions>
            <Button busy={snapshot.refreshing} onClick={() => void store.refresh()}>
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
  const tiling = values.layout === "bsp";
  const edit =
    <F extends keyof LayoutValues>(field: F) =>
    (value: LayoutValues[F]) =>
      store.edit(field, value);

  return (
    <>
      <PageHeader title="Layout" />

      <div className="flex flex-col">
        {snapshot.error ? (
          <Notice.Root variant="error" className="mb-4">
            <Notice.Header onDismiss={() => store.dismissError()}>
              <Notice.Title>Could not apply that change</Notice.Title>
              <Notice.Description>{snapshot.error}</Notice.Description>
            </Notice.Header>
          </Notice.Root>
        ) : null}

        {readOnly ? (
          <Notice.Root variant="warning" className="mb-4">
            <Notice.Title>Showing your saved layout</Notice.Title>
            <Notice.Description>
              {state.unavailableReason ??
                "The desktop could not be reached, so changes cannot apply."}
            </Notice.Description>
            <Notice.Actions>
              <Button busy={snapshot.refreshing} onClick={() => void store.refresh()}>
                Try again
              </Button>
            </Notice.Actions>
          </Notice.Root>
        ) : null}

        <Card className="mb-6 overflow-hidden">
          <div className="flex flex-wrap items-center justify-between gap-3 px-4 py-3">
            <div className="min-w-0">
              <h2 className="text-emphasis font-semibold tracking-[-0.01em] text-fg">Preview</h2>
              <p className="text-small text-fg-secondary">{summary(values)}</p>
            </div>
            <div className="flex items-center gap-2">
              <Stepper label="Windows" value={windows} min={1} max={4} onValueChange={setWindows} />
              <SegmentedControl
                label="Monitor"
                size="sm"
                value={monitor}
                options={monitorOptions}
                onValueChange={setMonitor}
              />
            </div>
          </div>
          <div className="border-y border-hairline">
            <TilingPreview
              mode={values.layout}
              split={values.splitType}
              placement={values.windowPlacement}
              gap={values.windowGap}
              padding={values.padding}
              monitor={monitor}
              windows={windows}
            />
          </div>
          <button
            type="button"
            aria-expanded={showSaved}
            aria-controls={savedId}
            onClick={() => setShowSaved(!showSaved)}
            className={cn(
              "flex w-full items-center gap-2 bg-side px-4 py-2 text-left text-small text-fg-secondary transition-colors hover:text-fg",
              focusRingInset,
            )}
          >
            <FileCode2 aria-hidden size={13} />
            <span className="min-w-0 flex-1 truncate font-mono">
              ~/Library/Application Support/Macarchy/settings.json
            </span>
            <span className="shrink-0">{showSaved ? "Hide" : "Show"} saved values</span>
            <ChevronDown
              aria-hidden
              size={13}
              className={cn(
                "shrink-0 transition-transform motion-reduce:transition-none",
                showSaved && "rotate-180",
              )}
            />
          </button>
          {showSaved ? (
            <pre
              id={savedId}
              className="overflow-x-auto border-t border-hairline bg-side px-4 py-3 font-mono text-mono leading-[1.65] text-fg-secondary select-text"
            >
              {savedValueLines(values).join("\n")}
            </pre>
          ) : null}
        </Card>

        <div className="@container">
          <div className="grid grid-cols-1 items-start gap-5 @[720px]:grid-cols-2">
            <Card>
              <CardHeader
                title="Tiling"
                help={tiling ? undefined : "Split, new windows and balance apply only to BSP."}
              />
              <CardRows>
                <Row
                  title="Layout"
                  control={
                    <SegmentedControl
                      label="Layout"
                      size="sm"
                      value={values.layout}
                      options={modeOptions}
                      disabled={readOnly}
                      onValueChange={edit("layout")}
                    />
                  }
                />
                <Row
                  title="Split"
                  description={splitHint(values.splitType, monitor)}
                  control={
                    <SegmentedControl
                      label="Split"
                      size="sm"
                      value={values.splitType}
                      options={splitOptions}
                      disabled={readOnly || !tiling}
                      onValueChange={edit("splitType")}
                    />
                  }
                />
                <Row
                  title="New windows"
                  description={
                    values.windowPlacement === "second_child" ? "Right or below" : "Left or above"
                  }
                  control={
                    <SegmentedControl
                      label="New windows"
                      size="sm"
                      value={values.windowPlacement}
                      options={placementOptions}
                      disabled={readOnly || !tiling}
                      onValueChange={edit("windowPlacement")}
                    />
                  }
                />
                <Row
                  title="Auto balance"
                  description="Equal window sizes"
                  control={
                    <Switch
                      aria-label="Auto balance"
                      checked={values.autoBalance}
                      disabled={readOnly || !tiling}
                      onCheckedChange={edit("autoBalance")}
                    />
                  }
                />
              </CardRows>
            </Card>

            <div className="flex min-w-0 flex-col gap-5">
              <Card>
                <CardHeader title="Gaps" />
                <CardRows>
                  <Row
                    title="Window gap"
                    controlId={gapId}
                    control={
                      <ValueSlider
                        id={gapId}
                        label="Window gap"
                        value={values.windowGap}
                        min={0}
                        max={32}
                        unit="pt"
                        width={sliderWidth}
                        disabled={readOnly}
                        onValueChange={edit("windowGap")}
                      />
                    }
                  />
                  <Row
                    title={linkPadding ? "Screen padding" : "Top padding"}
                    controlId={paddingId}
                    control={
                      <ValueSlider
                        id={paddingId}
                        label={linkPadding ? "Screen padding" : "Top padding"}
                        value={values.padding}
                        min={0}
                        max={40}
                        unit="pt"
                        width={sliderWidth}
                        disabled={readOnly}
                        onValueChange={edit("padding")}
                      />
                    }
                  />
                  <Row
                    title="Match all screen edges"
                    description={linkPadding ? "Every edge" : "Only the top edge"}
                    control={
                      <Switch
                        aria-label="Match all screen edges"
                        checked={linkPadding}
                        disabled={readOnly}
                        onCheckedChange={(checked) => store.setLinkPadding(checked)}
                      />
                    }
                  />
                </CardRows>
              </Card>

              <Card>
                <CardHeader title="Mouse" />
                <CardRows>
                  <Row
                    title="Modifier"
                    description="Hold to drag and resize windows"
                    control={
                      <SegmentedControl
                        label="Modifier"
                        size="sm"
                        value={values.mouseModifier}
                        options={modifierOptions}
                        disabled={readOnly}
                        onValueChange={edit("mouseModifier")}
                      />
                    }
                  />
                  <Row
                    title="On drop"
                    description={
                      values.mouseDropAction === "stack"
                        ? "Stack the two windows together"
                        : "Swap the two windows"
                    }
                    control={
                      <SegmentedControl
                        label="On drop"
                        size="sm"
                        value={values.mouseDropAction}
                        options={dropOptions}
                        disabled={readOnly}
                        onValueChange={edit("mouseDropAction")}
                      />
                    }
                  />
                  <Row
                    title="Mouse follows focus"
                    control={
                      <Switch
                        aria-label="Mouse follows focus"
                        checked={values.mouseFollowsFocus}
                        disabled={readOnly}
                        onCheckedChange={edit("mouseFollowsFocus")}
                      />
                    }
                  />
                </CardRows>
              </Card>
            </div>
          </div>
        </div>
      </div>
    </>
  );
}
