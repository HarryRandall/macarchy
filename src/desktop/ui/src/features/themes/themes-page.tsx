import { ArrowRight, FolderInput, Palette } from "lucide-react";
import { useEffect, useRef, useState } from "react";
import { PageHeader } from "~/components/layout/page-header";
import { Button } from "~/components/ui/button";
import { SectionLabel } from "~/components/ui/card";
import { EmptyState } from "~/components/ui/empty-state";
import { focusRing } from "~/components/ui/focus-ring";
import { Notice } from "~/components/ui/notice";
import { cn } from "~/lib/cn";
import { useStore } from "~/lib/store";
import type { PageContext } from "~/shell/page";
import { ThemeCard } from "./theme-card";
import { ThemeDetail } from "./theme-detail";
import { themeLook } from "./theme-look";
import type { ThemesStore } from "./themes-store";

function Failure({ message }: { message: string }) {
  return (
    <Notice.Root variant="error" className="mb-4">
      <Notice.Title>Could not complete that change</Notice.Title>
      <Notice.Description>{message}</Notice.Description>
    </Notice.Root>
  );
}

export function ThemesPage({ store, context }: { store: ThemesStore; context: PageContext }) {
  const snapshot = useStore(store);
  const [selected, setSelected] = useState<string | null>(null);
  const returnTo = useRef<string | null>(null);
  const state = snapshot.state;
  const theme = state?.themes.find((item) => item.summary.name === selected);

  // Closing the detail puts focus back on the card that opened it.
  useEffect(() => {
    if (theme || !returnTo.current) return;
    const name = returnTo.current;
    returnTo.current = null;
    document
      .querySelector<HTMLButtonElement>(
        `[data-theme="${CSS.escape(name)}"] button[aria-label^="View"]`,
      )
      ?.focus();
  }, [theme]);

  if (snapshot.status === "loading") return <PageHeader title="Themes" />;
  if (!state)
    return (
      <>
        <PageHeader title="Themes" />
        <Notice.Root variant="error">
          <Notice.Title>Could not read your themes</Notice.Title>
          <Notice.Description>{snapshot.error}</Notice.Description>
          <Notice.Actions>
            <Button onClick={() => void store.load()}>Try again</Button>
          </Notice.Actions>
        </Notice.Root>
      </>
    );

  const importButton = (
    <Button size="sm" disabled={snapshot.busy} onClick={() => void store.importFolder()}>
      <FolderInput aria-hidden />
      Import…
    </Button>
  );
  const workshop = () => context.navigate("workshop");

  return (
    <>
      <PageHeader title="Themes" actions={importButton} />
      {snapshot.error ? <Failure message={snapshot.error} /> : null}
      {state.warnings.length ? (
        <Notice.Root variant="warning" className="mb-4">
          <Notice.Title>Some themes could not be read</Notice.Title>
          <Notice.Description className="whitespace-pre-line">
            {state.warnings.join("\n")}
          </Notice.Description>
        </Notice.Root>
      ) : null}
      <p role="status" className={snapshot.busy ? "mb-3 text-meta text-fg-secondary" : "sr-only"}>
        {snapshot.busy ? (snapshot.applying ? "Applying…" : "Saving…") : ""}
      </p>

      {theme ? (
        <ThemeDetail
          store={store}
          themes={state.themes}
          theme={theme}
          current={state.current}
          busy={snapshot.busy}
          applying={snapshot.applying}
          colourschemes={state.colourschemes}
          onOpen={setSelected}
          onClose={() => {
            returnTo.current = theme.summary.name;
            setSelected(null);
          }}
          onWorkshop={workshop}
        />
      ) : (
        <>
          <SectionLabel
            action={
              <button
                type="button"
                onClick={workshop}
                className={cn(
                  "group inline-flex items-center gap-1 rounded-small text-small font-medium text-fg-secondary transition-colors hover:text-fg",
                  focusRing,
                )}
              >
                Browse more in Workshop
                <ArrowRight
                  aria-hidden
                  className="size-3 transition-transform duration-150 group-hover:translate-x-[2px] motion-reduce:transition-none"
                />
              </button>
            }
          >
            Installed · {state.themes.length}
          </SectionLabel>
          {state.themes.length ? (
            <div className="@container">
              <div className="grid grid-cols-1 gap-x-5 gap-y-7 @[520px]:grid-cols-2 @[1080px]:grid-cols-4">
                {state.themes.map((item) => (
                  <ThemeCard
                    key={item.summary.name}
                    look={themeLook(item)}
                    preview={item.summary.preview}
                    applied={item.summary.name === state.current}
                    busy={snapshot.busy}
                    onOpen={() => setSelected(item.summary.name)}
                    onApply={() => void store.apply(item.summary.name)}
                  />
                ))}
              </div>
            </div>
          ) : (
            <EmptyState
              icon={<Palette />}
              title="Your collection starts here"
              description="Import a theme folder to make it your own."
              action={
                <Button disabled={snapshot.busy} onClick={() => void store.importFolder()}>
                  Import…
                </Button>
              }
            />
          )}
        </>
      )}
    </>
  );
}
