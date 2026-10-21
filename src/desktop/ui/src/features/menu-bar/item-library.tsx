import { Check, Plus, Search } from "lucide-react";
import { useId, useState } from "react";

import { Button } from "~/components/ui/button";
import { Dialog } from "~/components/ui/dialog";
import { EmptyState } from "~/components/ui/empty-state";
import { IconButton } from "~/components/ui/icon-button";
import { SearchField } from "~/components/ui/search-field";
import { SegmentedControl } from "~/components/ui/segmented-control";
import { TextField } from "~/components/ui/text-field";

import { matchesLibrary, zoneLabels } from "./menu-bar-items";
import { ItemIcon } from "./menu-bar-icon";
import {
  type BarIconName,
  type BarItem,
  customIcons,
  type Interval,
  intervals,
  library,
  libraryCategories,
  type Zone,
} from "./menu-bar-mock";
import type { BarLook } from "./menu-bar-store";

type Tab = "built-in" | "custom";

const tabs = [
  { value: "built-in" as const, label: "Built-in" },
  { value: "custom" as const, label: "Custom item" },
];

const intervalOptions = intervals.map((value) => ({ value, label: value }));

/** Spoken names for the custom icons, which lucide names in code. */
const iconNames: Partial<Record<BarIconName, string>> = {
  Terminal: "Terminal",
  Activity: "Activity",
  Globe: "Globe",
  Zap: "Lightning",
  Coffee: "Coffee",
  Mail: "Mail",
  Rocket: "Rocket",
  Music: "Music",
  CloudSun: "Weather",
  HardDrive: "Disk",
};

/**
 * Built-in items to add to one zone, or a custom item that runs a command.
 * Open while `zone` is set. The last zone stays drawn while the dialog fades
 * out, and each opening starts afresh on Built-in with an empty form.
 */
export function ItemLibrary({
  zone,
  present,
  look,
  onAdd,
  onClose,
}: {
  zone: Zone | null;
  present: ReadonlySet<string>;
  look: BarLook;
  onAdd: (item: BarItem) => void;
  onClose: () => void;
}) {
  const [last, setLast] = useState<{ zone: Zone; opening: number }>({ zone: "left", opening: 0 });
  const [wasOpen, setWasOpen] = useState(false);
  if ((zone !== null) !== wasOpen) {
    setWasOpen(zone !== null);
    if (zone !== null) setLast({ zone, opening: last.opening + 1 });
  }
  return (
    <Dialog.Root open={zone !== null} onOpenChange={(open) => (open ? undefined : onClose())}>
      <Dialog.Popup className="h-[560px] w-[560px]">
        <LibraryContent
          key={last.opening}
          zone={zone ?? last.zone}
          present={present}
          look={look}
          onAdd={onAdd}
          onClose={onClose}
        />
      </Dialog.Popup>
    </Dialog.Root>
  );
}

function LibraryContent({
  zone,
  present,
  look,
  onAdd,
  onClose,
}: {
  zone: Zone;
  present: ReadonlySet<string>;
  look: BarLook;
  onAdd: (item: BarItem) => void;
  onClose: () => void;
}) {
  const [tab, setTab] = useState<Tab>("built-in");
  const [query, setQuery] = useState("");
  const [name, setName] = useState("");
  const [icon, setIcon] = useState<BarIconName>("Terminal");
  const [command, setCommand] = useState("");
  const [every, setEvery] = useState<Interval>("30s");
  const iconLabelId = useId();
  const matches = library.filter((entry) => matchesLibrary(entry, query));
  const zoneName = zoneLabels[zone].toLowerCase();
  const canAdd = name.trim().length > 0 && command.trim().length > 0;

  return (
    <>
      <Dialog.Header>
        <Dialog.Title>Add to the {zoneName} zone</Dialog.Title>
      </Dialog.Header>
      <div className="flex shrink-0 flex-wrap items-center gap-2 border-b border-hairline px-5 py-3">
        <SegmentedControl
          label="Kind of item"
          size="sm"
          value={tab}
          options={tabs}
          onValueChange={setTab}
        />
        {tab === "built-in" ? (
          <SearchField
            label="Search items"
            value={query}
            onValueChange={setQuery}
            className="ml-auto w-[220px]"
          />
        ) : null}
      </div>

      {tab === "built-in" ? (
        <Dialog.Body className="gap-0 px-2 pt-0 pb-2">
          {matches.length === 0 ? (
            <EmptyState
              variant="plain"
              icon={<Search />}
              title="No items match"
              action={
                <Button
                  size="sm"
                  onClick={() => {
                    setName(query.trim());
                    setTab("custom");
                  }}
                >
                  <Plus aria-hidden size={12} /> Custom item
                </Button>
              }
            />
          ) : (
            libraryCategories.map((category) => {
              const group = matches.filter((entry) => entry.category === category);
              if (group.length === 0) return null;
              return (
                <section key={category} aria-label={category}>
                  <h3 className="px-3 pt-3 pb-1 text-label text-fg-tertiary uppercase">
                    {category}
                  </h3>
                  <ul>
                    {group.map((entry) => (
                      <li
                        key={entry.id}
                        className="flex items-center gap-3 rounded-control px-3 py-2 transition-colors hover:bg-hover"
                      >
                        <span className="grid size-8 shrink-0 place-items-center rounded-tile border border-hairline bg-card text-fg-secondary">
                          <ItemIcon icon={entry.icon} size={14} />
                        </span>
                        <div className="min-w-0 flex-1">
                          <div className="text-body font-medium text-fg">{entry.name}</div>
                          {entry.detail ? (
                            <div className="truncate text-small text-fg-secondary">
                              {entry.detail}
                            </div>
                          ) : null}
                        </div>
                        {present.has(entry.id) ? (
                          <span className="inline-flex h-7 items-center gap-1 px-2.5 text-small font-medium text-fg-tertiary">
                            <Check aria-hidden size={12} /> Added
                          </span>
                        ) : (
                          <Button
                            size="sm"
                            aria-label={`Add ${entry.name}`}
                            onClick={() =>
                              onAdd({
                                id: entry.id,
                                label: entry.name,
                                zone,
                                on: true,
                                sample: entry.sample,
                                icon: entry.icon,
                              })
                            }
                          >
                            <Plus aria-hidden size={12} /> Add
                          </Button>
                        )}
                      </li>
                    ))}
                  </ul>
                </section>
              );
            })
          )}
        </Dialog.Body>
      ) : (
        <Dialog.Body>
          <TextField
            label="Name"
            placeholder="VPN status"
            value={name}
            onChange={(event) => setName(event.currentTarget.value)}
          />
          <div className="flex flex-col gap-1.5">
            <span id={iconLabelId} className="text-small font-medium text-fg">
              Icon
            </span>
            <div role="group" aria-labelledby={iconLabelId} className="flex flex-wrap gap-1.5">
              {customIcons.map((option) => (
                <IconButton
                  key={option}
                  label={iconNames[option] ?? option}
                  size="md"
                  pressed={option === icon}
                  onClick={() => setIcon(option)}
                >
                  <ItemIcon icon={option} size={14} />
                </IconButton>
              ))}
            </div>
          </div>
          <TextField
            label="Shell command or script path"
            description="Runs in zsh; shows the first line of output"
            variant="mono"
            placeholder="~/.config/sketchybar/plugins/vpn.sh"
            value={command}
            onChange={(event) => setCommand(event.currentTarget.value)}
          />
          <div className="flex flex-col gap-1.5">
            <span className="text-small font-medium text-fg">Update every</span>
            <SegmentedControl
              label="Update every"
              size="sm"
              value={every}
              options={intervalOptions}
              onValueChange={setEvery}
              className="self-start"
            />
          </div>
          <div className="flex flex-col gap-1.5">
            <span className="text-small font-medium text-fg">Preview</span>
            <div
              className="flex h-[30px] items-center justify-end gap-1 rounded-control px-2 font-mono text-[11px]"
              style={{ background: look.background, color: look.foreground }}
            >
              <span className="flex items-center gap-1 px-1.5">
                <ItemIcon icon={icon} size={11} style={{ color: look.accent }} />
                {name.trim() || "My item"}
              </span>
            </div>
          </div>
        </Dialog.Body>
      )}

      <Dialog.Footer
        leading={
          tab === "built-in" ? (
            <span className="text-small text-fg-tertiary">{present.size} items in the bar</span>
          ) : null
        }
      >
        {tab === "built-in" ? (
          <Button variant="primary" onClick={onClose}>
            Done
          </Button>
        ) : (
          <>
            <Button variant="ghost" onClick={onClose}>
              Cancel
            </Button>
            <Button
              variant="primary"
              disabled={!canAdd}
              onClick={() => {
                onAdd({
                  id: `custom-${Date.now()}`,
                  label: name.trim(),
                  zone,
                  on: true,
                  sample: name.trim(),
                  icon,
                  custom: { command: command.trim(), interval: every },
                });
                onClose();
              }}
            >
              <Plus aria-hidden size={13} /> Add to {zoneLabels[zone]}
            </Button>
          </>
        )}
      </Dialog.Footer>
    </>
  );
}
