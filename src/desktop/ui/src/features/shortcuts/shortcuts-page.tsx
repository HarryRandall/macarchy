import { Keyboard, MoreHorizontal, RotateCcw, SearchX } from "lucide-react";
import { useState } from "react";

import { usePageSearch } from "~/components/layout/page-chrome";
import { PageHeader } from "~/components/layout/page-header";
import { Button } from "~/components/ui/button";
import { Card, Row } from "~/components/ui/card";
import { ConfirmDialog } from "~/components/ui/confirm-dialog";
import { EmptyState } from "~/components/ui/empty-state";
import { IconButton } from "~/components/ui/icon-button";
import { ListGroupHeader } from "~/components/ui/list-row";
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
import { Switch } from "~/components/ui/switch";
import { TabPanel, Tabs } from "~/components/ui/tabs";
import { useStore } from "~/lib/store";

import { ShortcutEditor } from "./shortcut-editor";
import {
  findConflicts,
  foldRuns,
  groupByCategory,
  type ShortcutCategory,
  shortcutCategory,
  shortcutTitle,
} from "./shortcut-groups";
import { emptyFilters, filterBindings, type ShortcutFilters } from "./shortcut-presentation";
import { ShortcutRow, ShortcutRunRow } from "./shortcut-row";
import type { ShortcutsStore } from "./shortcuts-store";
import { UsageCard } from "./shortcuts-usage";

type Tab = "all" | ShortcutCategory;

const modifierChoices = [
  ["cmd", "⌘ Command"],
  ["alt", "⌥ Option"],
  ["ctrl", "⌃ Control"],
  ["shift", "⇧ Shift"],
] as const;

const total = (n: number) => (n === 1 ? "1 shortcut" : `${n} shortcuts`);

export function ShortcutsPage({ store }: { store: ShortcutsStore }) {
  const snapshot = useStore(store);
  const [query, setQuery] = usePageSearch("Search shortcuts");
  const [chosenTab, setTab] = useState<Tab>("all");
  const [filters, setFilters] = useState<Omit<ShortcutFilters, "search">>(emptyFilters);
  const [resetRevision, setResetRevision] = useState<string | null>(null);
  const state = snapshot.state;
  const all = state?.bindings ?? [];
  if (snapshot.status === "loading") return null;

  const sections = [
    ...new Set(all.flatMap((binding) => (binding.section ? [binding.section] : []))),
  ];
  const groups = groupByCategory(all);
  // A group can empty out when skhdrc changes; its tab goes and the view falls back to All.
  const tab = groups.some((group) => group.category === chosenTab) ? chosenTab : "all";
  const searched = filterBindings(all, { ...filters, search: query });
  const shown = tab === "all" ? searched : searched.filter((b) => shortcutCategory(b) === tab);
  const shownGroups = groupByCategory(shown);
  const conflicts = findConflicts(all);
  const disabledCount = all.filter((binding) => binding.disabled).length;
  const firstConflict = all.find((binding) => conflicts.has(binding.id));
  const menuFilters =
    !!filters.modifiers.length || filters.scope !== "all" || filters.section !== "";
  const hasFilters = query.trim() !== "" || menuFilters || tab !== "all";
  const clear = () => {
    setQuery("");
    setFilters(emptyFilters);
    setTab("all");
  };

  return (
    <div className="@container">
      <PageHeader
        title="Shortcuts"
        actions={
          <Menu>
            <MenuTrigger render={<IconButton label="Shortcut actions" />}>
              <MoreHorizontal aria-hidden />
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
                  <MenuRadioItem value="disabled">Disabled shortcuts</MenuRadioItem>
                </MenuRadioGroup>
              </MenuGroup>
              <MenuSeparator />
              <MenuGroup>
                <MenuGroupLabel>Modifiers</MenuGroupLabel>
                {modifierChoices.map(([value, label]) => (
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
              {hasFilters ? <MenuItem onClick={clear}>Clear filters</MenuItem> : null}
              <MenuSeparator />
              <MenuItem
                disabled={snapshot.busy || snapshot.refreshing}
                onClick={() => void store.refresh()}
              >
                Refresh shortcuts
              </MenuItem>
              <MenuItem onClick={() => void store.openConfiguration()}>Open configuration</MenuItem>
              <MenuSeparator />
              <MenuItem
                disabled={!state || snapshot.busy}
                onClick={() => setResetRevision(state?.revision ?? null)}
              >
                Reset to default shortcuts…
              </MenuItem>
            </MenuPopup>
          </Menu>
        }
      />
      <div className="flex flex-col gap-4">
        {snapshot.error ? (
          <Notice.Root variant="error">
            <Notice.Title>
              {state ? "Could not change or refresh shortcuts" : "Could not read your shortcuts"}
            </Notice.Title>
            <Notice.Description>{snapshot.error}</Notice.Description>
            <Notice.Actions>
              <Button
                size="sm"
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
            <Tabs
              id="shortcut-groups"
              label="Shortcut groups"
              value={tab}
              onChange={setTab}
              tabs={[
                { id: "all", label: "All", count: all.length },
                ...groups.map((group) => ({
                  id: group.category,
                  label: group.category,
                  count: group.bindings.length,
                })),
              ]}
            />
            <TabPanel tabs="shortcut-groups" value={tab} className="flex flex-col gap-4">
              {tab === "all" && !query.trim() && all.length ? (
                <UsageCard
                  bindings={all}
                  onPick={(name) => {
                    setTab("all");
                    setQuery(name);
                  }}
                />
              ) : null}
              {firstConflict ? (
                <Notice.Root variant="warning">
                  <Notice.Title>
                    {conflicts.size === 1
                      ? "1 shortcut conflicts"
                      : `${conflicts.size} shortcuts conflict`}
                  </Notice.Title>
                  <Notice.Description>
                    {shortcutTitle(firstConflict, all).title}: {conflicts.get(firstConflict.id)}
                  </Notice.Description>
                  <Notice.Actions>
                    <Button
                      size="sm"
                      disabled={snapshot.busy}
                      onClick={() => store.edit(firstConflict)}
                    >
                      <Keyboard aria-hidden />
                      Record new
                    </Button>
                  </Notice.Actions>
                </Notice.Root>
              ) : null}
              {shownGroups.map((group) => (
                <Card key={group.category} aria-label={group.category} className="overflow-hidden">
                  <ListGroupHeader
                    title={group.category}
                    count={group.bindings.length}
                    level={2}
                    className="px-4"
                  />
                  {foldRuns(group.bindings).map((item) =>
                    item.kind === "run" ? (
                      <ShortcutRunRow
                        key={`run-${item.bindings[0]!.id}`}
                        run={item}
                        all={all}
                        conflicts={conflicts}
                        desktops={state.desktops}
                        disabled={snapshot.busy}
                        onEdit={(binding) => store.edit(binding)}
                        onEnable={(binding) => void store.enable(binding)}
                      />
                    ) : (
                      <ShortcutRow
                        key={item.binding.id}
                        binding={item.binding}
                        all={all}
                        conflict={conflicts.get(item.binding.id)}
                        desktops={state.desktops}
                        disabled={snapshot.busy}
                        onEdit={() => store.edit(item.binding)}
                        onEnable={() => void store.enable(item.binding)}
                      />
                    ),
                  )}
                </Card>
              ))}
              {shown.length === 0 ? (
                <EmptyState
                  icon={all.length ? <SearchX /> : <Keyboard />}
                  title={
                    query.trim() ? `No shortcuts match "${query.trim()}"` : "No shortcuts found"
                  }
                  action={
                    hasFilters ? (
                      <Button size="sm" onClick={clear}>
                        {query.trim() && !menuFilters ? "Clear search" : "Clear filters"}
                      </Button>
                    ) : undefined
                  }
                />
              ) : null}
            </TabPanel>
            <Card>
              <Row
                title="Vim-style direction keys"
                description="H J K L. Not available yet."
                control={
                  // Mock: there is no Vim key setting yet, so the switch stays off and disabled.
                  <Switch aria-label="Vim-style direction keys" checked={false} disabled />
                }
              />
              <div data-row="" className="flex items-center justify-between gap-3 px-5 py-3">
                <p role="status" className="text-small text-fg-secondary">
                  {snapshot.busy
                    ? "Saving…"
                    : snapshot.refreshing
                      ? "Refreshing…"
                      : hasFilters
                        ? `${shown.length} of ${total(all.length)}`
                        : total(all.length) + (disabledCount ? `, ${disabledCount} disabled` : "")}
                </p>
                <Button
                  size="sm"
                  variant="ghost"
                  disabled={snapshot.busy}
                  onClick={() => setResetRevision(state.revision)}
                >
                  <RotateCcw aria-hidden />
                  Restore defaults
                </Button>
              </div>
            </Card>
          </>
        ) : null}
      </div>
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
    </div>
  );
}
