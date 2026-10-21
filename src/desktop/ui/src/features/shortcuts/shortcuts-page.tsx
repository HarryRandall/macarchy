import { ChevronDown, ChevronUp, Keyboard, MoreHorizontal } from "lucide-react";
import { Fragment, useState } from "react";

import type { ShortcutBinding } from "~/bridge/protocol";
import { PageHeader } from "~/components/layout/page-header";
import { CardContent, SettingsCard } from "~/components/layout/settings-section";
import { Button } from "~/components/ui/button";
import { ConfirmDialog } from "~/components/ui/confirm-dialog";
import { EmptyState } from "~/components/ui/empty-state";
import { HelpTooltip } from "~/components/ui/help-tooltip";
import { IconButton } from "~/components/ui/icon-button";
import { KbdGroup } from "~/components/ui/kbd";
import { ListGroupHeader, ListRow } from "~/components/ui/list-row";
import {
  Menu,
  MenuCheckboxItem,
  MenuGroup,
  MenuGroupLabel,
  MenuItem,
  MenuPopup,
  MenuRadioGroup,
  MenuRadioItem,
  MenuSeparator,
  MenuTrigger,
} from "~/components/ui/menu";
import { Notice } from "~/components/ui/notice";
import { SearchField } from "~/components/ui/search-field";
import { useStore } from "~/lib/store";

import { ShortcutDetails, ShortcutEditor } from "./shortcut-editor";
import {
  emptyFilters,
  filterBindings,
  type ShortcutFilters,
  shortcutLabel,
} from "./shortcut-presentation";
import type { ShortcutsStore } from "./shortcuts-store";

function ShortcutRow({
  binding,
  all,
  store,
}: {
  binding: ShortcutBinding;
  all: ShortcutBinding[];
  store: ShortcutsStore;
}) {
  const [expanded, setExpanded] = useState(false);
  const label = shortcutLabel(binding, all);
  return (
    <div data-shortcut-id={binding.id}>
      <ListRow
        size="compact"
        title={label}
        titleMono={label === binding.command}
        detail={binding.appOverrides.length ? "Per app" : undefined}
        trailing={
          <Button
            variant="ghost"
            aria-label={`Edit shortcut: ${binding.caps.join(" ")}`}
            onClick={() => store.edit(binding)}
          >
            <KbdGroup variant="key" keys={binding.caps} />
          </Button>
        }
        actions={
          <IconButton
            label={`${expanded ? "Hide" : "Show"} command details: ${label}`}
            aria-expanded={expanded}
            onClick={() => setExpanded(!expanded)}
          >
            {expanded ? <ChevronUp /> : <ChevronDown />}
          </IconButton>
        }
      />
      {expanded ? (
        <CardContent className="bg-well">
          <ShortcutDetails binding={binding} />
        </CardContent>
      ) : null}
    </div>
  );
}

export function ShortcutsPage({ store }: { store: ShortcutsStore }) {
  const snapshot = useStore(store);
  const [filters, setFilters] = useState<ShortcutFilters>(emptyFilters);
  const [resetRevision, setResetRevision] = useState<string | null>(null);
  const state = snapshot.state;
  const all = state?.bindings ?? [];
  const sections = [
    ...new Set(all.flatMap((binding) => (binding.section ? [binding.section] : []))),
  ];
  const filtered = filterBindings(all, filters);
  const groups = [
    ...new Set(filtered.map((binding) => binding.section).filter((section) => section !== null)),
    null,
  ];
  const hasFilters =
    filters.search !== "" ||
    !!filters.modifiers.length ||
    filters.scope !== "all" ||
    filters.section !== "";
  if (snapshot.status === "loading") return null;
  return (
    <>
      <PageHeader
        title="Shortcuts"
        actions={
          <>
            <SearchField
              label="Find a shortcut"
              help="Search keys, source comments and commands"
              className="w-56"
              value={filters.search}
              onValueChange={(search) => setFilters({ ...filters, search })}
            />
            <Menu>
              <MenuTrigger render={<IconButton label="Shortcut actions" />}>
                <MoreHorizontal />
              </MenuTrigger>
              <MenuPopup align="end">
                <MenuGroup>
                  <MenuGroupLabel>Scope</MenuGroupLabel>
                  <MenuRadioGroup
                    value={filters.scope}
                    onValueChange={(scope) =>
                      setFilters({ ...filters, scope: scope as ShortcutFilters["scope"] })
                    }
                  >
                    <MenuRadioItem value="all">All apps and scopes</MenuRadioItem>
                    <MenuRadioItem value="global">Global shortcuts</MenuRadioItem>
                    <MenuRadioItem value="perApp">Per-app shortcuts</MenuRadioItem>
                  </MenuRadioGroup>
                </MenuGroup>
                <MenuSeparator />
                <MenuGroup>
                  <MenuGroupLabel>Modifiers</MenuGroupLabel>
                  {[
                    ["cmd", "⌘ Command"],
                    ["alt", "⌥ Option"],
                    ["ctrl", "⌃ Control"],
                    ["shift", "⇧ Shift"],
                  ].map(([value = "", label]) => (
                    <MenuCheckboxItem
                      key={value}
                      checked={filters.modifiers.includes(value)}
                      onCheckedChange={(checked) =>
                        setFilters({
                          ...filters,
                          modifiers: checked
                            ? [...filters.modifiers, value]
                            : filters.modifiers.filter((item) => item !== value),
                        })
                      }
                    >
                      {label}
                    </MenuCheckboxItem>
                  ))}
                </MenuGroup>
                <MenuSeparator />
                <MenuGroup>
                  <MenuGroupLabel>Source group</MenuGroupLabel>
                  <MenuRadioGroup
                    value={filters.section}
                    onValueChange={(section) => setFilters({ ...filters, section })}
                  >
                    <MenuRadioItem value="">All groups</MenuRadioItem>
                    {sections.map((section) => (
                      <MenuRadioItem key={section} value={section}>
                        {section}
                      </MenuRadioItem>
                    ))}
                  </MenuRadioGroup>
                </MenuGroup>
                {hasFilters ? (
                  <MenuItem onClick={() => setFilters(emptyFilters)}>Clear filters</MenuItem>
                ) : null}
                <MenuSeparator />
                <MenuItem
                  disabled={snapshot.busy || snapshot.refreshing}
                  onClick={() => void store.refresh()}
                >
                  Refresh shortcuts
                </MenuItem>
                <MenuItem onClick={() => void store.openConfiguration()}>
                  Open configuration
                </MenuItem>
                <MenuSeparator />
                <MenuItem
                  disabled={!state || snapshot.busy}
                  onClick={() => setResetRevision(state?.revision ?? null)}
                >
                  Reset to default shortcuts…
                </MenuItem>
              </MenuPopup>
            </Menu>
          </>
        }
      />
      {snapshot.error ? (
        <Notice.Root variant="error">
          <Notice.Title>
            {state ? "Could not change or refresh shortcuts" : "Could not read your shortcuts"}
          </Notice.Title>
          <Notice.Description>{snapshot.error}</Notice.Description>
          <Notice.Actions>
            <Button
              disabled={snapshot.refreshing || snapshot.busy}
              onClick={() => void store.refresh()}
            >
              Try again
            </Button>
          </Notice.Actions>
        </Notice.Root>
      ) : null}
      {snapshot.warning ? (
        <Notice.Root variant="warning">
          <Notice.Description>{snapshot.warning}</Notice.Description>
        </Notice.Root>
      ) : null}
      {state ? (
        <>
          <div className="flex items-center gap-2 text-meta text-fg-secondary">
            <p role="status">
              {snapshot.busy
                ? "Saving…"
                : snapshot.refreshing
                  ? "Refreshing…"
                  : hasFilters
                    ? `${filtered.length} of ${all.length} shortcuts`
                    : `${all.length} shortcuts`}
            </p>
            <div className="ml-auto flex items-center gap-2">
              {hasFilters ? (
                <Button size="sm" variant="ghost" onClick={() => setFilters(emptyFilters)}>
                  Clear filters
                </Button>
              ) : null}
              <HelpTooltip text="Click a key combination to change it. Expand a row to see its command." />
            </div>
          </div>
          {filtered.length ? (
            <SettingsCard>
              {groups.map((section) => {
                const bindings = filtered.filter((binding) => binding.section === section);
                if (!bindings.length) return null;
                return (
                  <Fragment key={section ?? "ungrouped"}>
                    {section && bindings.length > 1 ? (
                      <ListGroupHeader title={section} count={bindings.length} />
                    ) : null}
                    {bindings.map((binding) => (
                      <ShortcutRow key={binding.id} binding={binding} all={all} store={store} />
                    ))}
                  </Fragment>
                );
              })}
            </SettingsCard>
          ) : (
            <EmptyState icon={<Keyboard />} title="No shortcuts found" />
          )}
        </>
      ) : null}
      {snapshot.draft ? (
        <ShortcutEditor
          key={`${snapshot.draft.revision}-${snapshot.draft.binding.id}`}
          store={store}
        />
      ) : null}
      <ConfirmDialog
        open={resetRevision !== null}
        onOpenChange={(open) => {
          if (!open) setResetRevision(null);
        }}
        title="Reset to default shortcuts?"
        description="Your current shortcuts are saved as a snapshot you can restore from Advanced."
        confirmLabel="Reset"
        busyLabel="Resetting…"
        onConfirm={() => store.reset(resetRevision!)}
      />
    </>
  );
}
