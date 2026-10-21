import { ChevronDown, FileCode2, RotateCw, SquareDashed } from "lucide-react";
import { useId, useState } from "react";
import { PageHeader } from "~/components/layout/page-header";
import { Button } from "~/components/ui/button";
import { Card, SectionLabel } from "~/components/ui/card";
import { focusRingInset } from "~/components/ui/focus-ring";
import { Notice } from "~/components/ui/notice";
import { SegmentedControl } from "~/components/ui/segmented-control";
import { Switch } from "~/components/ui/switch";
import { Tooltip } from "~/components/ui/tooltip";
import { themeLook } from "~/features/themes/theme-look";
import type { ThemesStore } from "~/features/themes/themes-store";
import { cn } from "~/lib/cn";
import { useStore } from "~/lib/store";
import { BorderPreview, neutralScene, type PreviewScene } from "./border-preview";
import { bordersArguments, isNoop, presetColours, themeReset } from "./borders-format";
import { BordersSettings } from "./borders-settings";
import type { BordersStore } from "./borders-store";

type Version = "after" | "before";

export function BordersPage({ store, themes }: { store: BordersStore; themes: ThemesStore }) {
  const snapshot = useStore(store);
  const themesSnapshot = useStore(themes);
  const [focused, setFocused] = useState<0 | 1>(0);
  const [showCommand, setShowCommand] = useState(false);
  const [version, setVersion] = useState<Version>("after");
  const commandId = useId();
  const { state, draft, applied, applying, live } = snapshot;
  if (snapshot.status === "loading") return <PageHeader title="Borders" />;
  if (!state || !draft || !applied)
    return (
      <>
        <PageHeader title="Borders" />
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
  const locked = !!state.unavailableReason;
  const comparing = !live && dirty;
  const shown = comparing && version === "before" ? applied : draft;
  const current = themesSnapshot.state?.themes.find(
    (item) => item.summary.name === (state.theme ?? themesSnapshot.state?.current),
  );
  const look = current ? themeLook(current) : null;
  const scene: PreviewScene = look ?? neutralScene;
  const reset = themeReset(state.defaults);
  const activePresets = presetColours([
    state.defaults?.activeColour,
    look?.accent,
    ...(look?.palette.slice(1, 7) ?? []),
  ]);
  const inactivePresets = presetColours([
    state.defaults?.inactiveColour,
    look?.palette[0],
    look?.background,
    "#2a2a2a",
    "#4a4a4a",
    look?.foreground,
  ]);

  const actions = (
    <>
      <span className="flex items-center gap-2 pr-1 text-small text-fg-secondary">
        <Tooltip content="Apply edits straight away, or hold them for a before and after">
          <Switch
            size="sm"
            aria-label="Live preview"
            checked={live}
            disabled={!live && (applying || dirty || locked)}
            onCheckedChange={(value) => store.setLive(value)}
          />
        </Tooltip>
        Live
      </span>
      {live ? null : (
        <>
          <Button size="sm" variant="ghost" disabled={!dirty || applying} onClick={store.discard}>
            Discard
          </Button>
          <Button
            size="sm"
            variant="primary"
            busy={applying}
            disabled={!dirty || locked}
            onClick={() => void store.apply()}
          >
            {applying ? "Applying…" : "Apply"}
          </Button>
        </>
      )}
    </>
  );

  return (
    <>
      <PageHeader title="Borders" actions={actions} />
      {state.unavailableReason ? (
        <Notice.Root variant="warning" className="mb-4">
          <Notice.Title>Showing your saved borders</Notice.Title>
          <Notice.Description>{state.unavailableReason}</Notice.Description>
          <Notice.Actions>
            <Button onClick={() => void store.load()}>Try again</Button>
          </Notice.Actions>
        </Notice.Root>
      ) : null}
      {snapshot.error ? (
        <Notice.Root variant="error" className="mb-4">
          <Notice.Title>Could not apply your borders</Notice.Title>
          <Notice.Description>{snapshot.error}</Notice.Description>
        </Notice.Root>
      ) : null}

      <SectionLabel
        action={
          <span className="flex items-center gap-2 text-small text-fg-secondary">
            {draft.visible ? "Enabled" : "Disabled"}
            <Switch
              aria-label="Show borders"
              checked={draft.visible}
              disabled={locked}
              onCheckedChange={(visible) => store.edit({ visible })}
            />
          </span>
        }
      >
        JankyBorders
      </SectionLabel>

      <Card className="mb-6 overflow-hidden">
        <BorderPreview
          appearance={shown}
          wallpaper={state.wallpaper}
          scene={scene}
          focused={focused}
          onFocus={setFocused}
          caption={comparing ? (version === "before" ? "Applied" : "Draft") : undefined}
        />
        <div className="flex flex-wrap items-center gap-x-2 gap-y-1 border-t border-hairline bg-side pr-2">
          <button
            type="button"
            aria-expanded={showCommand}
            aria-controls={commandId}
            onClick={() => setShowCommand(!showCommand)}
            className={cn(
              "flex min-w-0 flex-1 items-center gap-2 px-4 py-2 text-left text-small text-fg-secondary hover:text-fg",
              focusRingInset,
            )}
          >
            <FileCode2 aria-hidden className="size-[13px] shrink-0" />
            <span className="font-medium">Generated command</span>
            <ChevronDown
              aria-hidden
              className={cn(
                "size-[13px] shrink-0 transition-transform motion-reduce:transition-none",
                showCommand && "rotate-180",
              )}
            />
          </button>
          <p role="status" className="text-meta text-fg-tertiary">
            {applying ? "Applying…" : dirty ? "Unsaved changes" : ""}
          </p>
          {comparing ? (
            <SegmentedControl
              label="Preview"
              size="sm"
              value={version}
              options={[
                { value: "before", label: "Before" },
                { value: "after", label: "After" },
              ]}
              onValueChange={setVersion}
            />
          ) : null}
          <Tooltip content="Restore 6 pt width and this theme's border colours">
            <Button
              size="sm"
              variant="ghost"
              disabled={locked || isNoop(draft, reset)}
              onClick={() => store.edit(reset)}
            >
              <RotateCw aria-hidden /> Reset to theme
            </Button>
          </Tooltip>
        </div>
        {showCommand ? (
          <pre
            id={commandId}
            className="overflow-x-auto border-t border-hairline bg-side px-4 py-3 font-mono text-mono leading-[1.65] whitespace-pre-wrap text-fg-secondary select-text"
          >
            <span className="text-fg">borders</span> {bordersArguments(draft).join(" ")}
          </pre>
        ) : null}
        {snapshot.externalChange ? (
          <p
            role="status"
            className="border-t border-hairline px-4 py-2 text-detail text-fg-secondary"
          >
            Borders changed elsewhere. Your draft is kept. Discard to load the latest settings.
          </p>
        ) : null}
      </Card>

      {!draft.visible && !locked ? (
        <div className="mb-4 flex items-center gap-3 rounded-card border border-hairline bg-side px-4 py-3">
          <SquareDashed aria-hidden className="size-4 text-fg-secondary" />
          <p className="flex-1 text-detail text-fg-secondary">Borders are off</p>
          <Button size="sm" variant="primary" onClick={() => store.edit({ visible: true })}>
            Turn on
          </Button>
        </div>
      ) : null}

      <BordersSettings
        state={state}
        draft={draft}
        themeTitle={look?.title ?? null}
        activePresets={activePresets}
        inactivePresets={inactivePresets}
        locked={locked}
        onEdit={(patch) => store.edit(patch)}
        onPickApplication={() => void store.pickApplication()}
      />
    </>
  );
}
